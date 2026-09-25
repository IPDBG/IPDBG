/* winsock2.h has to be included before windows.h (included by BusAccess.h) */
#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #ifdef _MSC_VER
        #pragma comment(lib, "ws2_32.lib") /* MSVC only, MinGW links -lws2_32 */
    #endif
#endif

#include "BusAccess.h"
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

#define RESET_SYMBOL     0xEE
#define ESCAPE_SYMBOL    0x55

#define READ_WIDTHS_CMD  0xAB
#define WRITE_CMD_LOCK   0xBE
#define WRITE_CMD_UNLOCK 0xBF
#define READ_CMD_LOCK    0xCE
#define READ_CMD_UNLOCK  0xCF
#define SET_ADDR_CMD     0xD0
#define SET_MISC_CMD     0xE5
#define SET_STRB_CMD     0x92

#define ACK_RESP         0x55
#define NACK_RESP        0x33

#define INVALD_SOCKET      -1

/* sockets are closed with closesocket() on Windows, close() does not work for them */
#ifdef _WIN32
    #define CLOSE_SOCKET closesocket
#else
    #define CLOSE_SOCKET close
#endif

#define ROUND_UP(a, b) ((a + b - 1) / b)

static size_t max_size(size_t a, size_t b)
{
    return a > b ? a : b;
}

struct IpdbgBusAccessHandle
{
    uint32_t Version;
    uint32_t AddressWidth;
    uint32_t ReadDataWidth;
    uint32_t WriteDataWidth;
    uint32_t MiscDataWidth;
    uint32_t StrobeWidth;
    uint32_t AddressWidthBytes;
    uint32_t ReadDataWidthBytes;
    uint32_t WriteDataWidthBytes;
    uint32_t MiscDataWidthBytes;
    uint32_t StrobeWidthBytes;

    int socket;

    uint8_t *buffer;
    uint8_t *AddressShadow;

    char lastError[256];
};

static void IpdbgBusAccess_setError(struct IpdbgBusAccessHandle *handle, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    vsnprintf(handle->lastError, sizeof(handle->lastError), format, args);
    va_end(args);
}

static const char *IpdbgBusAccess_socketError(void)
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
static int IpdbgBusAccess_begin(struct IpdbgBusAccessHandle *handle, bool mustBeOpen)
{
    if (!handle)
        return RET_ERROR;

    handle->lastError[0] = '\0';

    if (mustBeOpen && handle->socket == INVALD_SOCKET)
    {
        IpdbgBusAccess_setError(handle, "not connected");
        return RET_ERROR;
    }

    return RET_OK;
}

static int IpdbgBusAccess_closeSocket(struct IpdbgBusAccessHandle *handle);

static int IpdbgBusAccess_send(struct IpdbgBusAccessHandle *handle, const uint8_t *buf, size_t len)
{
    size_t sent = 0;

    while (sent < len)
    {
        int out = send(handle->socket, (const char*)(buf + sent), len - sent, 0);

        if (out <= 0)
        {
            IpdbgBusAccess_setError(handle, "send failed (%s)", IpdbgBusAccess_socketError());
            return RET_ERROR;
        }

        sent += (size_t)out;
    }

    return RET_OK;
}

/* receives exactly len bytes */
static int IpdbgBusAccess_receive(struct IpdbgBusAccessHandle *handle, uint8_t *buf, size_t len)
{
    size_t received = 0;

    while (received < len)
    {
        int n = recv(handle->socket, (char*)(buf + received), len - received, 0);

        if (n < 0)
        {
            IpdbgBusAccess_setError(handle, "receive failed (%s)", IpdbgBusAccess_socketError());
            return RET_ERROR;
        }
        if (n == 0)
        {
            IpdbgBusAccess_setError(handle, "connection closed by peer");
            return RET_ERROR;
        }

        received += (size_t)n;
    }

    return RET_OK;
}

static int IpdbgBusAccess_sendWithEscaping(struct IpdbgBusAccessHandle *handle, const uint8_t *dataToSend, size_t length)
{
    int ret;
    while (length--)
    {
        uint8_t payload = *dataToSend++;

        if (payload == RESET_SYMBOL || payload == ESCAPE_SYMBOL)
        {
            uint8_t escapeSymbol = ESCAPE_SYMBOL;
            ret = IpdbgBusAccess_send(handle, &escapeSymbol, 1);
            if (ret != RET_OK)
                return ret;
        }

        ret = IpdbgBusAccess_send(handle, &payload, 1);
        if (ret != RET_OK)
            return ret;
    }
    return RET_OK;
}

static int IpdbgBusAccess_sendReset(struct IpdbgBusAccessHandle *handle)
{
    uint8_t buf[2] = {RESET_SYMBOL, RESET_SYMBOL};
    return IpdbgBusAccess_send(handle, buf, 2);
}

static int IpdbgBusAccess_sendCommand(struct IpdbgBusAccessHandle *handle, uint8_t command)
{
    return IpdbgBusAccess_send(handle, &command, 1);
}

static int IpdbgBusAccess_getSizes(struct IpdbgBusAccessHandle *handle)
{
    enum { numSizes = 6, answerLength = numSizes * 4 };
    uint8_t buf[answerLength];

    int ret = IpdbgBusAccess_sendCommand(handle, READ_WIDTHS_CMD);
    if (ret != RET_OK)
        return ret;

    ret = IpdbgBusAccess_receive(handle, buf, answerLength);
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
    handle->Version        = tmp[0];
    handle->WriteDataWidth = tmp[1];
    handle->ReadDataWidth  = tmp[2];
    handle->AddressWidth   = tmp[3];
    handle->MiscDataWidth  = tmp[4];
    handle->StrobeWidth    = tmp[5];

    const int HOST_WORD_SIZE = 8; // bits / word

    handle->AddressWidthBytes   = ROUND_UP(handle->AddressWidth, HOST_WORD_SIZE);
    handle->ReadDataWidthBytes  = ROUND_UP(handle->ReadDataWidth, HOST_WORD_SIZE);
    handle->WriteDataWidthBytes = ROUND_UP(handle->WriteDataWidth, HOST_WORD_SIZE);
    handle->MiscDataWidthBytes  = ROUND_UP(handle->MiscDataWidth, HOST_WORD_SIZE);
    handle->StrobeWidthBytes    = ROUND_UP(handle->StrobeWidth, HOST_WORD_SIZE);

    return RET_OK;
}

struct IpdbgBusAccessHandle API *IpdbgBusAccess_new()
{
    struct IpdbgBusAccessHandle *handle = (struct IpdbgBusAccessHandle *)calloc(1, sizeof(struct IpdbgBusAccessHandle));
    if (!handle)
        return NULL;

    handle->socket = INVALD_SOCKET;

    return handle;
}

int API IpdbgBusAccess_delete(struct IpdbgBusAccessHandle *handle)
{
    if (!handle)
        return RET_ERROR;

    int ret = IpdbgBusAccess_closeSocket(handle);

    free(handle);

    return ret;
}

static size_t IpdbgBusAccess_getBuffeSize(struct IpdbgBusAccessHandle *handle)
{
    size_t res = max_size(handle->AddressWidthBytes, handle->ReadDataWidthBytes);

    res = max_size(res, handle->WriteDataWidthBytes);
    res = max_size(res, handle->MiscDataWidthBytes);
    res = max_size(res, handle->StrobeWidthBytes);

    return res;
}

static int IpdbgBusAccess_sendAddress(struct IpdbgBusAccessHandle *handle, const uint8_t *address)
{
    if (handle->AddressWidthBytes == 0)
        return RET_OK;

    int ret = IpdbgBusAccess_sendCommand(handle, SET_ADDR_CMD);
    if (ret != RET_OK)
        return ret;

    return IpdbgBusAccess_sendWithEscaping(handle, address, handle->AddressWidthBytes);
}

int API IpdbgBusAccess_open(struct IpdbgBusAccessHandle *handle, const char *ipAddrStr, const char *portNumberStr)
{
    if (IpdbgBusAccess_begin(handle, false) != RET_OK)
        return RET_ERROR;

    if (handle->socket != INVALD_SOCKET)
    {
        IpdbgBusAccess_setError(handle, "already connected");
        return RET_ERROR;
    }

    if (!ipAddrStr || !portNumberStr)
    {
        IpdbgBusAccess_setError(handle, "no host or port given");
        return RET_ERROR;
    }

#ifdef _WIN32
    static WSADATA wsaData;
    if (WSAStartup(0x0202, &wsaData) != 0)
    {
        IpdbgBusAccess_setError(handle, "WSAStartup failed, could not find Winsock 2.2 dll");
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
        IpdbgBusAccess_setError(handle, "unable to resolve %s:%s (%s)", ipAddrStr, portNumberStr, gai_strerror(gaiRet));
        return RET_ERROR;
    }

    const char *connectError = "no address found";

    for (res = results; res; res = res->ai_next)
    {
        if ((handle->socket = socket(res->ai_family, res->ai_socktype, res->ai_protocol)) < 0)
        {
            handle->socket = INVALD_SOCKET;
            connectError = IpdbgBusAccess_socketError();
            continue;
        }
        if (connect(handle->socket, res->ai_addr, res->ai_addrlen) != 0) {
            connectError = IpdbgBusAccess_socketError();
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
        IpdbgBusAccess_setError(handle, "unable to connect to %s:%s (%s)", ipAddrStr, portNumberStr, connectError);
        return RET_ERROR;
    }

    size_t bufferSize;
    int ret = IpdbgBusAccess_sendReset(handle);
    if (ret != RET_OK)
        goto error;

    ret = IpdbgBusAccess_getSizes(handle);
    if (ret != RET_OK)
        goto error;

    ret = RET_ERROR;
    bufferSize = IpdbgBusAccess_getBuffeSize(handle);
    if (bufferSize == 0)
    {
        IpdbgBusAccess_setError(handle, "bus master reports no fields");
        goto error;
    }

    handle->buffer = (uint8_t *)malloc(bufferSize + 1); // 1 for the acknowledge
    // at least 1 byte, so the pointer is valid for address width 0 as well
    handle->AddressShadow = (uint8_t *)calloc(1, max_size(handle->AddressWidthBytes, 1));
    if (!handle->buffer || !handle->AddressShadow)
    {
        IpdbgBusAccess_setError(handle, "unable to allocate buffer memory");
        goto error;
    }

    ret = IpdbgBusAccess_sendAddress(handle, handle->AddressShadow);
    if (ret != RET_OK)
        goto error;

    return RET_OK;

error:
    // don't leave a half opened connection behind (frees the buffers as well)
    IpdbgBusAccess_closeSocket(handle);
    return ret;
}

int API IpdbgBusAccess_close(struct IpdbgBusAccessHandle *handle)
{
    if (IpdbgBusAccess_begin(handle, false) != RET_OK)
        return RET_ERROR;

    return IpdbgBusAccess_closeSocket(handle);
}

/* closes the connection and frees the buffers, does not clear the last error */
static int IpdbgBusAccess_closeSocket(struct IpdbgBusAccessHandle *handle)
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
            IpdbgBusAccess_setError(handle, "close failed (%s)", IpdbgBusAccess_socketError());
        ret = RET_ERROR;
    }
    handle->socket = INVALD_SOCKET;
    free(handle->buffer);
    handle->buffer = NULL;
    free(handle->AddressShadow);
    handle->AddressShadow = NULL;

#ifdef _WIN32
    WSACleanup();
#endif

    return ret;
}

int API IpdbgBusAccess_isOpen(struct IpdbgBusAccessHandle *handle)
{
    if (!handle)
        return 0;

    return handle->socket != INVALD_SOCKET;
}

static int IpdbgBusAccess_setAddress(struct IpdbgBusAccessHandle *handle, const uint8_t *address)
{
    if (handle->AddressWidthBytes == 0)
        return RET_OK;

    if (memcmp(address, handle->AddressShadow, handle->AddressWidthBytes) == 0)
        return RET_OK;

    int ret = IpdbgBusAccess_sendAddress(handle, address);
    if (ret != RET_OK)
        return ret;

    memcpy(handle->AddressShadow, address, handle->AddressWidthBytes);

    return RET_OK;
}

int API IpdbgBusAccess_write_ctrllock(struct IpdbgBusAccessHandle *handle, const uint8_t *address, const uint8_t *data, bool locked)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (handle->WriteDataWidthBytes == 0)
    {
        IpdbgBusAccess_setError(handle, "bus master has no write data");
        return RET_ERROR;
    }

    int ret = IpdbgBusAccess_setAddress(handle, address);
    if (ret != RET_OK)
        return ret;

    ret = IpdbgBusAccess_sendCommand(handle, locked ? WRITE_CMD_LOCK : WRITE_CMD_UNLOCK);
    if (ret != RET_OK)
        return ret;

    ret = IpdbgBusAccess_sendWithEscaping(handle, data, handle->WriteDataWidthBytes);
    if (ret != RET_OK)
        return ret;

    ret = IpdbgBusAccess_receive(handle, handle->buffer, 1);
    if (ret != RET_OK)
        return ret;

    if (handle->buffer[0] == ACK_RESP)
        return RET_ACK;
    if (handle->buffer[0] == NACK_RESP)
    {
        IpdbgBusAccess_setError(handle, "write answered with NAK");
        return RET_NAK;
    }

    IpdbgBusAccess_setError(handle, "invalid response 0x%02x to write", handle->buffer[0]);
    return RET_ERROR;
}

int API IpdbgBusAccess_read_ctrllock(struct IpdbgBusAccessHandle *handle,  const uint8_t *address, uint8_t *result, bool locked)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (handle->ReadDataWidthBytes == 0)
    {
        IpdbgBusAccess_setError(handle, "bus master has no read data");
        return RET_ERROR;
    }

    int ret = IpdbgBusAccess_setAddress(handle, address);
    if (ret != RET_OK)
        return ret;

    ret = IpdbgBusAccess_sendCommand(handle, locked ? READ_CMD_LOCK : READ_CMD_UNLOCK);
    if (ret != RET_OK)
        return ret;

    ret = IpdbgBusAccess_receive(handle, handle->buffer, handle->ReadDataWidthBytes + 1);
    if (ret != RET_OK)
        return ret;

    if (handle->buffer[0] == ACK_RESP)
        ret = RET_ACK;
    else if (handle->buffer[0] == NACK_RESP)
    {
        IpdbgBusAccess_setError(handle, "read answered with NAK");
        ret = RET_NAK;
    }
    else
    {
        IpdbgBusAccess_setError(handle, "invalid response 0x%02x to read", handle->buffer[0]);
        return RET_ERROR;
    }

    memcpy(result, &(handle->buffer[1]), handle->ReadDataWidthBytes);

    return ret;
}

int API IpdbgBusAccess_write(struct IpdbgBusAccessHandle *handle, const uint8_t *address, const uint8_t *data)
{
    return IpdbgBusAccess_write_ctrllock(handle, address, data, false);
}

int API IpdbgBusAccess_read(struct IpdbgBusAccessHandle *handle,  const uint8_t *address, uint8_t *result)
{
    return IpdbgBusAccess_read_ctrllock(handle, address, result, false);
}

int API IpdbgBusAccess_read_modify_write(struct IpdbgBusAccessHandle *handle, const uint8_t *address, void(*modify)(uint8_t *buffer))
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (handle->ReadDataWidth != handle->WriteDataWidth)
    {
        IpdbgBusAccess_setError(handle, "read-modify-write requires read and write data of the same width");
        return RET_ERROR;
    }

    uint8_t *buffer = (uint8_t *)malloc(max_size(handle->ReadDataWidthBytes, 1));
    if (!buffer)
    {
        IpdbgBusAccess_setError(handle, "unable to allocate buffer memory");
        return RET_ERROR;
    }

    int ret = IpdbgBusAccess_read_ctrllock(handle, address, buffer, true);

    if (ret != RET_ACK)
    {
        free(buffer);
        return ret;
    }
    if (modify)
        modify(buffer);

    ret = IpdbgBusAccess_write_ctrllock(handle, address, buffer, false);
    free(buffer);
    return ret;
}

int API IpdbgBusAccess_setMiscellaneous(struct IpdbgBusAccessHandle *handle, const uint8_t *data)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (handle->MiscDataWidthBytes == 0)
    {
        IpdbgBusAccess_setError(handle, "bus master has no misc signals");
        return RET_ERROR;
    }

    int ret = IpdbgBusAccess_sendCommand(handle, SET_MISC_CMD);
    if (ret != RET_OK)
        return ret;

    return IpdbgBusAccess_sendWithEscaping(handle, data, handle->MiscDataWidthBytes);
}

int API IpdbgBusAccess_setStrobe(struct IpdbgBusAccessHandle *handle, const uint8_t *data)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (handle->StrobeWidthBytes == 0)
    {
        IpdbgBusAccess_setError(handle, "bus master has no strobe");
        return RET_ERROR;
    }

    int ret = IpdbgBusAccess_sendCommand(handle, SET_STRB_CMD);
    if (ret != RET_OK)
        return ret;

    return IpdbgBusAccess_sendWithEscaping(handle, data, handle->StrobeWidthBytes);
}

int API IpdbgBusAccess_getFieldSize(struct IpdbgBusAccessHandle *handle, enum BusAccessField field, size_t *result)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (!result)
    {
        IpdbgBusAccess_setError(handle, "no result pointer given");
        return RET_ERROR;
    }

    switch (field)
    {
    case ADDRESS:    *result = handle->AddressWidth;   break;
    case READ_DATA:  *result = handle->ReadDataWidth;  break;
    case WRITE_DATA: *result = handle->WriteDataWidth; break;
    case STROBE:     *result = handle->StrobeWidth;    break;
    default:
    case MISC:       *result = handle->MiscDataWidth;  break;
    }
    return RET_OK;
}

int API IpdbgAxi4lAccess_setAxprot(struct IpdbgBusAccessHandle *handle, uint8_t arprot, uint8_t awprot)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (handle->MiscDataWidth != 6)
    {
        IpdbgBusAccess_setError(handle, "probably not an AXI4-Lite master (width of arprot and awprot is not 3)");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        IpdbgBusAccess_setError(handle, "probably not an AXI4-Lite master (read has not the same width as write)");
        return RET_ERROR;
    }

    uint8_t misc = ((awprot & 0x7) << 3) | (arprot & 0x7);
    return IpdbgBusAccess_setMiscellaneous(handle, &misc);
}

int API IpdbgApbAccess_setPprot(struct IpdbgBusAccessHandle *handle, uint8_t pprot)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (handle->MiscDataWidth != 3)
    {
        IpdbgBusAccess_setError(handle, "probably not an APB master (width of pprot is not 3)");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        IpdbgBusAccess_setError(handle, "probably not an APB master (read has not the same width as write)");
        return RET_ERROR;
    }

    uint8_t misc = pprot & 0x7;
    return IpdbgBusAccess_setMiscellaneous(handle, &misc);
}

int API IpdbgAvalonAccess_setDebugAccess(struct IpdbgBusAccessHandle *handle, uint8_t debug)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    if (handle->MiscDataWidth != 1)
    {
        IpdbgBusAccess_setError(handle, "probably not an Avalon master (debug width is not 1)");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        IpdbgBusAccess_setError(handle, "probably not an Avalon master (read has not the same width as write)");
        return RET_ERROR;
    }

    uint8_t misc = debug ? 0x1 : 0x0;
    return IpdbgBusAccess_setMiscellaneous(handle, &misc);
}

int API IpdbgAhbAccess_setHprotHsize(struct IpdbgBusAccessHandle *handle, uint8_t hprot, uint8_t hsize)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    const uint32_t hsize_width = 3;
    uint32_t hprot_width = handle->MiscDataWidth - hsize_width;

    if (hprot_width != 0 && hprot_width != 4 && hprot_width != 7)
    {
        IpdbgBusAccess_setError(handle, "probably not an AHB master (width of hprot is not 0, 4 or 7)");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        IpdbgBusAccess_setError(handle, "probably not an AHB master (read has not the same width as write)");
        return RET_ERROR;
    }

    hsize &= 0x7;
    hprot &= (1 << hprot_width) - 1;

    uint16_t sz = 8;
    for (size_t i = 0; i < hsize; ++i)
        sz *= 2;

    if (handle->WriteDataWidth < sz)
    {
        IpdbgBusAccess_setError(handle, "hsize is bigger than write data bus");
        return RET_ERROR;
    }

    uint8_t misc[2] = {
        (uint8_t)(hsize | (hprot << 3)),
        (uint8_t)(hprot >> 3)
    };

    return IpdbgBusAccess_setMiscellaneous(handle, misc);
}

int API IpdbgDtm_setResets(struct IpdbgBusAccessHandle *handle, bool reset, bool hardreset)
{
    if (IpdbgBusAccess_begin(handle, true) != RET_OK)
        return RET_ERROR;

    const uint32_t misc_width = 2; /* dmi-reset and dmi-hardreset*/

    if (handle->MiscDataWidth != misc_width)
    {
        IpdbgBusAccess_setError(handle, "probably not a RISC-V DTM (width of misc is not 2)");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        IpdbgBusAccess_setError(handle, "probably not a RISC-V DTM (read has not the same width as write)");
        return RET_ERROR;
    }

    uint8_t misc = (reset ? 1 : 0) | (hardreset ? 2 : 0);

    return IpdbgBusAccess_setMiscellaneous(handle, &misc);
}

const char API *IpdbgBusAccess_getLastError(struct IpdbgBusAccessHandle *handle)
{
    if (!handle)
        return "invalid handle";

    return handle->lastError;
}
