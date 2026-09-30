// SPDX-FileCopyrightText: The IPDBG authors
// SPDX-License-Identifier: MPL-2.0

// UartBridge: TCP <-> serial port bridge for the IPDBG UART transport
// (rtl/Uart, IpdbgUart). IpdbgUart connects a single IPDBG core, there is no
// hub, so the bridge forwards the bytes 1:1 in both directions. The frame
// format is fixed to 8N1, like IpdbgUart.
//
// One client at a time: while a client is connected, further connections are
// closed right away. After the client disconnects, the bridge waits for the
// next one. The serial port stays open; if it fails (e.g. the USB adapter is
// unplugged), the bridge exits.
//
// Usage: see usage() or UartBridge --help

#include <libserialport.h>

#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
    using socket_t = SOCKET;
    #define CLOSE_SOCKET closesocket
    #define SHUT_BOTH    SD_BOTH
    #define SEND_FLAGS   0
#else
    #include <arpa/inet.h>
    #include <netinet/in.h>
    #include <netinet/tcp.h>
    #include <sys/socket.h>
    #include <unistd.h>
    #include <csignal>
    using socket_t = int;
    #define INVALID_SOCKET (-1)
    #define CLOSE_SOCKET   close
    #define SHUT_BOTH      SHUT_RDWR
    #ifdef MSG_NOSIGNAL
        #define SEND_FLAGS MSG_NOSIGNAL
    #else
        #define SEND_FLAGS 0
    #endif
#endif

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>

namespace {

struct Options {
    std::string device;
    int baudrate = 0;
    int tcpPort = 0;
    std::string bind = "127.0.0.1";
};

struct sp_port *port = nullptr;
std::atomic<bool> sessionActive{false};
std::atomic<bool> serialFailed{false};

void usage(const char *prog)
{
    std::printf(
        "Usage: %s [options] <serial-port> <baudrate> <tcp-port>\n"
        "       %s --list\n"
        "\n"
        "Forwards a TCP port to a serial port, for the IPDBG UART transport\n"
        "(rtl/Uart). 8 data bits, no parity, 1 stop bit (8N1), no flow control.\n"
        "\n"
        "Options:\n"
        "  --list                 list the serial ports and exit\n"
        "  --bind <address>       IPv4 address to listen on (default 127.0.0.1,\n"
        "                         0.0.0.0 for all interfaces)\n"
        "  -h, --help             show this help\n"
        "\n"
        "Example: %s /dev/ttyUSB1 115200 4242\n"
        "         %s COM4 115200 4242\n",
        prog, prog, prog, prog);
}

bool parseInt(const char *s, long min, long max, int *result)
{
    char *end = nullptr;
    long v = std::strtol(s, &end, 10);
    if (end == s || *end != '\0' || v < min || v > max)
        return false;
    *result = static_cast<int>(v);
    return true;
}

bool parseOptions(int argc, char **argv, Options *o, bool *list)
{
    int positional = 0;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        auto value = [&](const char *name) -> const char * {
            if (i + 1 >= argc) {
                std::fprintf(stderr, "%s needs a value\n", name);
                return nullptr;
            }
            return argv[++i];
        };
        if (a == "-h" || a == "--help") {
            usage(argv[0]);
            std::exit(0);
        } else if (a == "--list") {
            *list = true;
        } else if (a == "--bind") {
            const char *v = value("--bind");
            if (!v)
                return false;
            o->bind = v;
        } else if (!a.empty() && a[0] == '-') {
            std::fprintf(stderr, "unknown option '%s'\n", a.c_str());
            return false;
        } else {
            switch (positional++) {
            case 0:
                o->device = a;
                break;
            case 1:
                if (!parseInt(a.c_str(), 1, 100000000, &o->baudrate)) {
                    std::fprintf(stderr, "invalid baudrate '%s'\n", a.c_str());
                    return false;
                }
                break;
            case 2:
                if (!parseInt(a.c_str(), 1, 65535, &o->tcpPort)) {
                    std::fprintf(stderr, "invalid TCP port '%s' (1..65535)\n", a.c_str());
                    return false;
                }
                break;
            default:
                std::fprintf(stderr, "too many arguments\n");
                return false;
            }
        }
    }
    if (*list)
        return true;
    if (positional != 3) {
        usage(argv[0]);
        return false;
    }
    return true;
}

int listPorts()
{
    struct sp_port **ports = nullptr;
    if (sp_list_ports(&ports) != SP_OK) {
        std::fprintf(stderr, "listing the serial ports failed: %s\n", sp_last_error_message());
        return 1;
    }
    if (!ports[0])
        std::printf("no serial ports found\n");
    for (int i = 0; ports[i]; ++i) {
        struct sp_port *p = ports[i];
        const char *desc = sp_get_port_description(p);
        std::printf("%s", sp_get_port_name(p));
        if (desc)
            std::printf("  %s", desc);
        if (sp_get_port_transport(p) == SP_TRANSPORT_USB) {
            int vid = 0, pid = 0;
            if (sp_get_port_usb_vid_pid(p, &vid, &pid) == SP_OK)
                std::printf("  [USB %04x:%04x", vid, pid);
            else
                std::printf("  [USB");
            const char *serial = sp_get_port_usb_serial(p);
            if (serial)
                std::printf(", serial %s", serial);
            std::printf("]");
        }
        std::printf("\n");
    }
    sp_free_port_list(ports);
    return 0;
}

bool check(enum sp_return r, const char *what)
{
    if (r == SP_OK)
        return true;
    std::fprintf(stderr, "%s failed: %s\n", what, sp_last_error_message());
    return false;
}

bool openSerial(const Options &o)
{
    if (sp_get_port_by_name(o.device.c_str(), &port) != SP_OK) {
        std::fprintf(stderr, "serial port '%s' not found (see --list)\n", o.device.c_str());
        return false;
    }
    if (sp_open(port, SP_MODE_READ_WRITE) != SP_OK) {
        std::fprintf(stderr, "could not open '%s': %s\n", o.device.c_str(), sp_last_error_message());
        return false;
    }
    return check(sp_set_baudrate(port, o.baudrate), "setting the baudrate") &&
           check(sp_set_bits(port, 8), "setting 8 data bits") &&
           check(sp_set_parity(port, SP_PARITY_NONE), "disabling the parity") &&
           check(sp_set_stopbits(port, 1), "setting 1 stop bit") &&
           check(sp_set_flowcontrol(port, SP_FLOWCONTROL_NONE), "disabling flow control");
}

socket_t makeListenSocket(const Options &o)
{
    socket_t fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (fd == INVALID_SOCKET) {
        std::fprintf(stderr, "socket() failed\n");
        return INVALID_SOCKET;
    }

    int yes = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char *>(&yes), sizeof(yes));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(static_cast<uint16_t>(o.tcpPort));
    if (inet_pton(AF_INET, o.bind.c_str(), &addr.sin_addr) != 1) {
        std::fprintf(stderr, "invalid bind address '%s'\n", o.bind.c_str());
        CLOSE_SOCKET(fd);
        return INVALID_SOCKET;
    }
    if (bind(fd, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) != 0) {
        std::fprintf(stderr, "binding %s:%d failed (port in use?)\n", o.bind.c_str(), o.tcpPort);
        CLOSE_SOCKET(fd);
        return INVALID_SOCKET;
    }
    if (listen(fd, 4) != 0) {
        std::fprintf(stderr, "listen() failed\n");
        CLOSE_SOCKET(fd);
        return INVALID_SOCKET;
    }
    return fd;
}

// socket -> serial (host -> FPGA)
void pumpSocketToSerial(socket_t fd, std::atomic<bool> *running)
{
    char buf[4096];
    while (*running) {
        int n = recv(fd, buf, sizeof(buf), 0);
        if (n <= 0)
            break; // closed by the client, error, or shutdown by the other pump
        if (sp_blocking_write(port, buf, static_cast<size_t>(n), 0) < 0) {
            std::fprintf(stderr, "writing to the serial port failed: %s\n", sp_last_error_message());
            serialFailed = true;
            break;
        }
    }
    *running = false;
    shutdown(fd, SHUT_BOTH); // wakes the other pump
}

// serial -> socket (FPGA -> host)
void pumpSerialToSocket(socket_t fd, std::atomic<bool> *running)
{
    const unsigned int timeoutMs = 100;
    struct sp_event_set *events = nullptr;
    if (sp_new_event_set(&events) != SP_OK || sp_add_port_events(events, port, SP_EVENT_RX_READY) != SP_OK) {
        std::fprintf(stderr, "waiting for the serial port failed: %s\n", sp_last_error_message());
        serialFailed = true;
        *running = false;
        shutdown(fd, SHUT_BOTH);
        sp_free_event_set(events);
        return;
    }

    int endOfFile = 0;
    char buf[4096];
    while (*running) {
        // returns as soon as data is available; timeout: check 'running'
        // regularly once the other direction has ended
        auto start = std::chrono::steady_clock::now();
        if (sp_wait(events, timeoutMs) != SP_OK) {
            std::fprintf(stderr, "waiting for the serial port failed: %s\n", sp_last_error_message());
            serialFailed = true;
            break;
        }
        int n = sp_nonblocking_read(port, buf, sizeof(buf));
        if (n < 0) {
            std::fprintf(stderr, "reading from the serial port failed: %s\n", sp_last_error_message());
            serialFailed = true;
            break;
        }
        if (n == 0) {
            // readable, but nothing to read, long before the timeout: end of
            // file, the device is gone (e.g. a USB adapter unplugged on Linux)
            if (std::chrono::steady_clock::now() - start < std::chrono::milliseconds(timeoutMs / 2)) {
                if (++endOfFile >= 3) {
                    std::fprintf(stderr, "the serial port was closed by the system\n");
                    serialFailed = true;
                    break;
                }
            }
            continue;
        }
        endOfFile = 0;

        int sent = 0;
        while (sent < n) {
            int s = send(fd, buf + sent, n - sent, SEND_FLAGS);
            if (s <= 0)
                break;
            sent += s;
        }
        if (sent < n)
            break;
    }
    sp_free_event_set(events);
    *running = false;
    shutdown(fd, SHUT_BOTH); // wakes the other pump
}

void runSession(socket_t fd)
{
    // no delay for the short request/response exchanges of the host tools
    int yes = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, reinterpret_cast<const char *>(&yes), sizeof(yes));

    // drop what is left from the previous session
    sp_flush(port, SP_BUF_BOTH);

    std::atomic<bool> running{true};
    std::thread down(pumpSocketToSerial, fd, &running);
    std::thread up(pumpSerialToSocket, fd, &running);
    down.join();
    up.join();
    CLOSE_SOCKET(fd);

    if (serialFailed) {
        std::fprintf(stderr, "serial port lost, exiting\n");
        std::exit(1);
    }
    std::printf("connection closed, waiting for the next one\n");
    std::fflush(stdout);
    sessionActive = false;
}

} // namespace

int main(int argc, char **argv)
{
    Options o;
    bool list = false;
    if (!parseOptions(argc, argv, &o, &list))
        return 1;
    if (list)
        return listPorts();

#ifdef _WIN32
    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        std::fprintf(stderr, "WSAStartup failed\n");
        return 1;
    }
#else
    std::signal(SIGPIPE, SIG_IGN); // a closed client must not terminate the bridge
#endif

    if (!openSerial(o))
        return 1;

    socket_t listenFd = makeListenSocket(o);
    if (listenFd == INVALID_SOCKET)
        return 1;

    std::printf("UartBridge: %s, %d baud, 8N1 <-> TCP %s:%d\n",
                o.device.c_str(), o.baudrate, o.bind.c_str(), o.tcpPort);
    std::printf("waiting for a connection\n");
    std::fflush(stdout);

    std::thread session;
    for (;;) {
        sockaddr_in client{};
        socklen_t len = sizeof(client);
        socket_t fd = accept(listenFd, reinterpret_cast<sockaddr *>(&client), &len);
        if (fd == INVALID_SOCKET)
            continue;

        char ip[INET_ADDRSTRLEN] = "?";
        inet_ntop(AF_INET, &client.sin_addr, ip, sizeof(ip));

        if (sessionActive) {
            std::printf("rejected %s:%d, already connected to another client\n", ip, ntohs(client.sin_port));
            std::fflush(stdout);
            CLOSE_SOCKET(fd);
            continue;
        }
        if (session.joinable())
            session.join();

        std::printf("connected: %s:%d\n", ip, ntohs(client.sin_port));
        std::fflush(stdout);
        sessionActive = true;
        session = std::thread(runSession, fd);
    }
}
