/* winsock2.h has to be included before windows.h (included by WaveformGenerator.h) */
#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #ifdef _MSC_VER
        #pragma comment(lib, "ws2_32.lib") /* MSVC only, MinGW links -lws2_32 */
    #endif
#endif

#include "WaveformGenerator.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#ifndef _WIN32
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <netdb.h>
    #include <errno.h>
#endif

#define RESET_SYMBOL                0xEE
#define ESCAPE_SYMBOL               0x55

#define START_CMD                   0xF0
#define STOP_CMD                    0xF1
#define RETURN_SIZES_CMD            0xF2
#define WRITE_SAMPLES_CMD           0xF3
#define SET_NUMBER_OF_SAMPLES_CMD   0xF4
#define RETURN_STATUS_CMD           0xF5
#define ONE_SHOT_CMD                0xF6

/* sent by the core while receiving samples (every 64 bytes) and after the last sample */
#define WRITE_PROGRESS_RESP         0xFA
#define WRITE_DONE_RESP             0xFB

#define STATUS_ENABLED              0x01
#define STATUS_DOUBLE_BUFFER        0x02

#define INVALD_SOCKET               -1

/* sockets are closed with closesocket() on Windows, close() does not work for them */
#ifdef _WIN32
    #define CLOSE_SOCKET closesocket
#else
    #define CLOSE_SOCKET close
#endif

#define ROUND_UP(a, b) ((a + b - 1) / b)

struct IpdbgWaveformGeneratorHandle
{
    uint32_t DataWidth;
    uint32_t AddressWidth;
    uint32_t DataWidthBytes;
    uint32_t AddressWidthBytes;

    int socket;

    char lastError[256];
};

static void IpdbgWaveformGenerator_setError(struct IpdbgWaveformGeneratorHandle *handle, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    vsnprintf(handle->lastError, sizeof(handle->lastError), format, args);
    va_end(args);
}

static const char *IpdbgWaveformGenerator_socketError(void)
{
#ifdef _WIN32
    static char msg[32];
    snprintf(msg, sizeof(msg), "WSA error %d", WSAGetLastError());
    return msg;
#else
    return strerror(errno);
#endif
}

/* clears the last error, returns RET_ERROR if the handle is invalid or (when requested) not connected */
static int IpdbgWaveformGenerator_begin(struct IpdbgWaveformGeneratorHandle *handle, bool mustBeOpen)
{
    if (!handle)
        return RET_ERROR;

    handle->lastError[0] = '\0';

    if (mustBeOpen && handle->socket == INVALD_SOCKET)
    {
        IpdbgWaveformGenerator_setError(handle, "not connected");
        return RET_ERROR;
    }

    return RET_OK;
}

static int IpdbgWaveformGenerator_closeSocket(struct IpdbgWaveformGeneratorHandle *handle);

static int IpdbgWaveformGenerator_send(struct IpdbgWaveformGeneratorHandle *handle, const uint8_t *buf, size_t len)
{
    size_t sent = 0;

    while (sent < len)
    {
        int out = send(handle->socket, (const char*)(buf + sent), len - sent, 0);

        if (out <= 0)
        {
            IpdbgWaveformGenerator_setError(handle, "send failed (%s)", IpdbgWaveformGenerator_socketError());
            return RET_ERROR;
        }

        sent += (size_t)out;
    }

    return RET_OK;
}

/* receives exactly len bytes */
static int IpdbgWaveformGenerator_receive(struct IpdbgWaveformGeneratorHandle *handle, uint8_t *buf, size_t len)
{
    size_t received = 0;

    while (received < len)
    {
        int n = recv(handle->socket, (char*)(buf + received), len - received, 0);

        if (n < 0)
        {
            IpdbgWaveformGenerator_setError(handle, "receive failed (%s)", IpdbgWaveformGenerator_socketError());
            return RET_ERROR;
        }
        if (n == 0)
        {
            IpdbgWaveformGenerator_setError(handle, "connection closed by peer");
            return RET_ERROR;
        }

        received += (size_t)n;
    }

    return RET_OK;
}

/* appends payload to buf, escaped; buf must have room for 2 bytes */
static size_t IpdbgWaveformGenerator_escape(uint8_t payload, uint8_t *buf)
{
    size_t n = 0;
    if (payload == RESET_SYMBOL || payload == ESCAPE_SYMBOL)
        buf[n++] = ESCAPE_SYMBOL;
    buf[n++] = payload;
    return n;
}

static int IpdbgWaveformGenerator_sendReset(struct IpdbgWaveformGeneratorHandle *handle)
{
    uint8_t buf[2] = {RESET_SYMBOL, RESET_SYMBOL};
    return IpdbgWaveformGenerator_send(handle, buf, 2);
}

static int IpdbgWaveformGenerator_sendCommand(struct IpdbgWaveformGeneratorHandle *handle, uint8_t command)
{
    return IpdbgWaveformGenerator_send(handle, &command, 1);
}

static int IpdbgWaveformGenerator_getSizes(struct IpdbgWaveformGeneratorHandle *handle)
{
    enum { numSizes = 2, answerLength = numSizes * 4 };
    uint8_t buf[answerLength];

    int ret = IpdbgWaveformGenerator_sendCommand(handle, RETURN_SIZES_CMD);
    if (ret != RET_OK)
        return ret;

    ret = IpdbgWaveformGenerator_receive(handle, buf, answerLength);
    if (ret != RET_OK)
        return ret;

    uint32_t tmp[numSizes];
    for (size_t i = 0; i < numSizes; ++i)
    {
        tmp[i]  =  (uint32_t)buf[i * 4] |
                  ((uint32_t)buf[i * 4 + 1] <<  8) |
                  ((uint32_t)buf[i * 4 + 2] << 16) |
                  ((uint32_t)buf[i * 4 + 3] << 24);
    }
    handle->DataWidth    = tmp[0];
    handle->AddressWidth = tmp[1];

    if (handle->DataWidth == 0 || handle->AddressWidth == 0)
    {
        IpdbgWaveformGenerator_setError(handle, "invalid widths reported by the core (data %u bit, address %u bit)",
                                        handle->DataWidth, handle->AddressWidth);
        return RET_ERROR;
    }

    const int HOST_WORD_SIZE = 8; // bits / word

    handle->DataWidthBytes    = ROUND_UP(handle->DataWidth, HOST_WORD_SIZE);
    handle->AddressWidthBytes = ROUND_UP(handle->AddressWidth, HOST_WORD_SIZE);

    return RET_OK;
}

static int IpdbgWaveformGenerator_readStatus(struct IpdbgWaveformGeneratorHandle *handle, uint8_t *status)
{
    int ret = IpdbgWaveformGenerator_sendCommand(handle, RETURN_STATUS_CMD);
    if (ret != RET_OK)
        return ret;

    return IpdbgWaveformGenerator_receive(handle, status, 1);
}

static size_t IpdbgWaveformGenerator_maxSamples(struct IpdbgWaveformGeneratorHandle *handle)
{
    if (handle->AddressWidth >= sizeof(size_t) * 8)
        return (size_t)-1;
    return (size_t)1 << handle->AddressWidth;
}

struct IpdbgWaveformGeneratorHandle API *IpdbgWaveformGenerator_new()
{
    struct IpdbgWaveformGeneratorHandle *handle = (struct IpdbgWaveformGeneratorHandle *)calloc(1, sizeof(struct IpdbgWaveformGeneratorHandle));
    if (!handle)
        return NULL;

    handle->socket = INVALD_SOCKET;

    return handle;
}

int API IpdbgWaveformGenerator_delete(struct IpdbgWaveformGeneratorHandle *handle)
{
    if (!handle)
        return RET_ERROR;

    int ret = IpdbgWaveformGenerator_closeSocket(handle);

    free(handle);

    return ret;
}

int API IpdbgWaveformGenerator_open(struct IpdbgWaveformGeneratorHandle *handle, const char *ipAddrStr, const char *portNumberStr)
{
    if (IpdbgWaveformGenerator_begin(handle, false) != RET_OK)
        return RET_ERROR;

    if (handle->socket != INVALD_SOCKET)
    {
        IpdbgWaveformGenerator_setError(handle, "already connected");
        return RET_ERROR;
    }

    if (!ipAddrStr || !portNumberStr)
    {
        IpdbgWaveformGenerator_setError(handle, "no host or port given");
        return RET_ERROR;
    }

#ifdef _WIN32
    static WSADATA wsaData;
    if (WSAStartup(0x0202, &wsaData) != 0)
    {
        IpdbgWaveformGenerator_setError(handle, "WSAStartup failed, could not find Winsock 2.2 dll");
        return RET_ERROR;
    }
#endif

    struct addrinfo hints;
    struct addrinfo *results, *res;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    int gaiRet = getaddrinfo(ipAddrStr, portNumberStr, &hints, &results);
    if (gaiRet != 0)
    {
#ifdef _WIN32
        WSACleanup();
#endif
        IpdbgWaveformGenerator_setError(handle, "unable to resolve %s:%s (%s)", ipAddrStr, portNumberStr, gai_strerror(gaiRet));
        return RET_ERROR;
    }

    const char *connectError = "no address found";

    for (res = results; res; res = res->ai_next)
    {
        if ((handle->socket = socket(res->ai_family, res->ai_socktype, res->ai_protocol)) < 0)
        {
            handle->socket = INVALD_SOCKET;
            connectError = IpdbgWaveformGenerator_socketError();
            continue;
        }
        if (connect(handle->socket, res->ai_addr, res->ai_addrlen) != 0) {
            connectError = IpdbgWaveformGenerator_socketError();
            CLOSE_SOCKET(handle->socket);
            handle->socket = INVALD_SOCKET;
            continue;
        }
        break;
    }

    freeaddrinfo(results);

    if (handle->socket < 0)
    {
#ifdef _WIN32
        WSACleanup();
#endif
        IpdbgWaveformGenerator_setError(handle, "unable to connect to %s:%s (%s)", ipAddrStr, portNumberStr, connectError);
        return RET_ERROR;
    }

    int ret = IpdbgWaveformGenerator_sendReset(handle);
    if (ret != RET_OK)
        goto error;

    ret = IpdbgWaveformGenerator_getSizes(handle);
    if (ret != RET_OK)
        goto error;

    return RET_OK;

error:
    // don't leave a half opened connection behind
    IpdbgWaveformGenerator_closeSocket(handle);
    return ret;
}

int API IpdbgWaveformGenerator_close(struct IpdbgWaveformGeneratorHandle *handle)
{
    if (IpdbgWaveformGenerator_begin(handle, false) != RET_OK)
        return RET_ERROR;

    return IpdbgWaveformGenerator_closeSocket(handle);
}

/* closes the connection, does not clear the last error */
static int IpdbgWaveformGenerator_closeSocket(struct IpdbgWaveformGeneratorHandle *handle)
{
    if (handle->socket == INVALD_SOCKET)
        return RET_OK;

#ifdef _WIN32
    if (shutdown(handle->socket, SD_SEND) != SOCKET_ERROR)
    {
        char recvbuf[16];
        int recvbuflen = 16;
        // Receive until the peer closes the connection
        while (recv(handle->socket, recvbuf, recvbuflen, 0) > 0);
    }
#endif

    int ret = RET_OK;
    if (CLOSE_SOCKET(handle->socket) < 0)
    {
        if (handle->lastError[0] == '\0') // keep the original error when cleaning up after a failure
            IpdbgWaveformGenerator_setError(handle, "close failed (%s)", IpdbgWaveformGenerator_socketError());
        ret = RET_ERROR;
    }
    handle->socket = INVALD_SOCKET;

#ifdef _WIN32
    WSACleanup();
#endif

    return ret;
}

int API IpdbgWaveformGenerator_isOpen(struct IpdbgWaveformGeneratorHandle *handle)
{
    if (!handle)
        return 0;

    return handle->socket != INVALD_SOCKET;
}

int API IpdbgWaveformGenerator_getDataWidth(struct IpdbgWaveformGeneratorHandle *handle, size_t *bits)
{
    if (IpdbgWaveformGenerator_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (!bits)
    {
        IpdbgWaveformGenerator_setError(handle, "no result pointer given");
        return RET_ERROR;
    }

    *bits = handle->DataWidth;
    return RET_OK;
}

int API IpdbgWaveformGenerator_getAddressWidth(struct IpdbgWaveformGeneratorHandle *handle, size_t *bits)
{
    if (IpdbgWaveformGenerator_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (!bits)
    {
        IpdbgWaveformGenerator_setError(handle, "no result pointer given");
        return RET_ERROR;
    }

    *bits = handle->AddressWidth;
    return RET_OK;
}

int API IpdbgWaveformGenerator_getMaxSamples(struct IpdbgWaveformGeneratorHandle *handle, size_t *samples)
{
    if (IpdbgWaveformGenerator_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (!samples)
    {
        IpdbgWaveformGenerator_setError(handle, "no result pointer given");
        return RET_ERROR;
    }

    *samples = IpdbgWaveformGenerator_maxSamples(handle);
    return RET_OK;
}

int API IpdbgWaveformGenerator_getStatus(struct IpdbgWaveformGeneratorHandle *handle, bool *running, bool *doubleBuffer)
{
    if (IpdbgWaveformGenerator_begin(handle, true) != RET_OK)
        return RET_ERROR;

    uint8_t status;
    int ret = IpdbgWaveformGenerator_readStatus(handle, &status);
    if (ret != RET_OK)
        return ret;

    if (running)
        *running = (status & STATUS_ENABLED) != 0;
    if (doubleBuffer)
        *doubleBuffer = (status & STATUS_DOUBLE_BUFFER) != 0;

    return RET_OK;
}

int API IpdbgWaveformGenerator_write(struct IpdbgWaveformGeneratorHandle *handle, const uint8_t *samples, size_t count)
{
    if (IpdbgWaveformGenerator_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (!samples)
    {
        IpdbgWaveformGenerator_setError(handle, "no samples given");
        return RET_ERROR;
    }

    const size_t maxSamples = IpdbgWaveformGenerator_maxSamples(handle);
    if (count == 0 || count > maxSamples)
    {
        IpdbgWaveformGenerator_setError(handle, "number of samples (%zu) must be between 1 and %zu", count, maxSamples);
        return RET_ERROR;
    }

    /* worst case every byte is escaped: 2 bytes per byte, plus the two commands */
    if (count > (SIZE_MAX / 2 - 2 - handle->AddressWidthBytes) / handle->DataWidthBytes)
    {
        IpdbgWaveformGenerator_setError(handle, "too many samples");
        return RET_ERROR;
    }
    const size_t payloadBytes = handle->AddressWidthBytes + count * handle->DataWidthBytes;
    uint8_t *buffer = (uint8_t *)malloc(2 + 2 * payloadBytes);
    if (!buffer)
    {
        IpdbgWaveformGenerator_setError(handle, "unable to allocate buffer memory");
        return RET_ERROR;
    }

    /* number of samples - 1 and the samples are sent most significant byte first */
    size_t n = 0;
    buffer[n++] = SET_NUMBER_OF_SAMPLES_CMD;
    const uint64_t lastIndex = (uint64_t)count - 1;
    for (size_t i = handle->AddressWidthBytes; i-- > 0;)
        n += IpdbgWaveformGenerator_escape(i < 8 ? (uint8_t)(lastIndex >> (i * 8)) : 0, &buffer[n]);

    buffer[n++] = WRITE_SAMPLES_CMD;
    for (size_t s = 0; s < count; ++s)
    {
        const uint8_t *sample = &samples[s * handle->DataWidthBytes];
        for (size_t i = handle->DataWidthBytes; i-- > 0;)
            n += IpdbgWaveformGenerator_escape(sample[i], &buffer[n]);
    }

    int ret = IpdbgWaveformGenerator_send(handle, buffer, n);
    free(buffer);
    if (ret != RET_OK)
        return ret;

    /* the core sends 0xFA every 64 bytes and 0xFB after the last sample */
    for (;;)
    {
        uint8_t resp;
        ret = IpdbgWaveformGenerator_receive(handle, &resp, 1);
        if (ret != RET_OK)
            return ret;
        if (resp == WRITE_DONE_RESP)
            return RET_OK;
        if (resp != WRITE_PROGRESS_RESP)
        {
            IpdbgWaveformGenerator_setError(handle, "invalid response 0x%02x while writing samples", resp);
            return RET_ERROR;
        }
    }
}

/* sends a command without response, then waits until the core has processed it */
static int IpdbgWaveformGenerator_control(struct IpdbgWaveformGeneratorHandle *handle, uint8_t command)
{
    if (IpdbgWaveformGenerator_begin(handle, true) != RET_OK)
        return RET_ERROR;

    int ret = IpdbgWaveformGenerator_sendCommand(handle, command);
    if (ret != RET_OK)
        return ret;

    uint8_t status;
    return IpdbgWaveformGenerator_readStatus(handle, &status);
}

int API IpdbgWaveformGenerator_start(struct IpdbgWaveformGeneratorHandle *handle)
{
    return IpdbgWaveformGenerator_control(handle, START_CMD);
}

int API IpdbgWaveformGenerator_stop(struct IpdbgWaveformGeneratorHandle *handle)
{
    return IpdbgWaveformGenerator_control(handle, STOP_CMD);
}

int API IpdbgWaveformGenerator_oneShot(struct IpdbgWaveformGeneratorHandle *handle)
{
    return IpdbgWaveformGenerator_control(handle, ONE_SHOT_CMD);
}

const char API *IpdbgWaveformGenerator_getLastError(struct IpdbgWaveformGeneratorHandle *handle)
{
    if (!handle)
        return "invalid handle";

    return handle->lastError;
}
