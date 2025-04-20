#include "BusAccess.h"
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
#endif
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

#define ROUND_UP(a, b) ((a + b - 1) / b)

#define max(a,b) \
   ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; })

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
};

static int IpdbgBusAccess_send(int handle_socket, const uint8_t *buf, size_t len)
{
    int out = 0;

    out = send(handle_socket, (char*)buf, len, 0);

    if (out < 0)
        return RET_ERROR;

    if ((unsigned int)out < len)
        printf("Only sent %d/%d bytes of data.", out, (int)len);

    return RET_OK;
}

static int IpdbgBusAccess_receive(int handle_socket, uint8_t *buf, int bufsize)
{
    int received = 0;

    while (received < bufsize)
    {
        int len;

        len = recv(handle_socket, (char*)(buf + received), bufsize - received, 0);

        if (len < 0)
        {
            printf("Receive error: %d; len = %d\n", errno, len);
            return len;
        }
        else
            received += len;
    }

    return received;
}

static int IpdbgBusAccess_sendWithEscaping(int handle_socket, const uint8_t *dataToSend, int length)
{
    int ret;
    while (length--)
    {
        uint8_t payload = *dataToSend++;

        if (payload == RESET_SYMBOL || payload == ESCAPE_SYMBOL)
        {
            uint8_t escapeSymbol = ESCAPE_SYMBOL;
            ret = IpdbgBusAccess_send(handle_socket, &escapeSymbol, 1);
            if (ret != RET_OK)
                return ret;
        }

        ret = IpdbgBusAccess_send(handle_socket, &payload, 1);
        if (ret != RET_OK)
            return ret;
    }
    return RET_OK;
}

static int IpdbgBusAccess_sendReset(int handle_socket)
{
    uint8_t buf[2] = {RESET_SYMBOL, RESET_SYMBOL};
    int ret = IpdbgBusAccess_send(handle_socket, buf, 2);
    if (ret != 0)
        printf("Error: sending reset failed\n");

    return ret;
}

static int IpdbgBusAccess_getSizes(struct IpdbgBusAccessHandle *handle)
{
    if (!handle || handle->socket == INVALD_SOCKET)
        return RET_ERROR;

    const size_t numSizes = 6;
    const size_t answerLength = numSizes * 4;
    uint8_t buf[answerLength];

    buf[0] = READ_WIDTHS_CMD;
    int ret = IpdbgBusAccess_send(handle->socket, buf, 1);
    if (ret != 0)
    {
        printf("Error: unable to send READ_WIDTHS_CMD command\n");
        return ret;
    }

    int received = IpdbgBusAccess_receive(handle->socket, buf, answerLength);
    if (received != answerLength)
    {
        printf("Error: response to READ_WIDTHS_CMD with wrong length\n");
        return RET_ERROR;
    }

    uint32_t tmp[numSizes];
    for (size_t i = 0; i < numSizes; ++i)
    {
        tmp[i]  = (buf[i * 4]            & 0x000000ff) |
                 ((buf[i * 4 + 1] <<  8) & 0x0000ff00) |
                 ((buf[i * 4 + 2] << 16) & 0x00ff0000) |
                 ((buf[i * 4 + 3] << 24) & 0xff000000);
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

    int ret = IpdbgBusAccess_close(handle);

    free(handle->buffer);
    free(handle->AddressShadow);
    free(handle);

    return ret;
}

static size_t IpdbgBusAccess_getBuffeSize(struct IpdbgBusAccessHandle *handle)
{
    size_t res = max(handle->AddressWidthBytes, handle->ReadDataWidthBytes);

    res = max(res, handle->WriteDataWidthBytes);
    res = max(res, handle->MiscDataWidthBytes);
    res = max(res, handle->StrobeWidthBytes);

    return res;
}

static int IpdbgBusAccess_sendAddress(struct IpdbgBusAccessHandle *handle, const uint8_t *address)
{
    if (!handle || handle->socket == INVALD_SOCKET)
        return RET_ERROR;

    if (handle->AddressWidthBytes == 0)
        return RET_OK;

    *handle->buffer = SET_ADDR_CMD;

    int ret = IpdbgBusAccess_send(handle->socket, handle->buffer, 1);
    if (ret != RET_OK)
    {
        printf("Error: unable to send SET_ADDR_CMD command\n");
        return ret;
    }

    return IpdbgBusAccess_sendWithEscaping(handle->socket, address, handle->AddressWidthBytes);
}

int API IpdbgBusAccess_open(struct IpdbgBusAccessHandle *handle, const char *ipAddrStr, const char *portNumberStr)
{
    if (!handle || handle->socket != INVALD_SOCKET)
        return RET_ERROR;

#ifdef _WIN32
    static WSADATA wsaData;
    if (WSAStartup(0x0202, &wsaData) != 0)
    {
        printf("WSAStartup failed, could not find Winsock 2.2 dll!");
        return RET_ERROR;
    }
#endif

    struct addrinfo hints;
    struct addrinfo *results, *res;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    getaddrinfo(ipAddrStr, portNumberStr, &hints, &results);

    for (res = results; res; res = res->ai_next)
    {
        if ((handle->socket = socket(res->ai_family, res->ai_socktype, res->ai_protocol)) < 0)
            continue;
        if (connect(handle->socket, res->ai_addr, res->ai_addrlen) != 0) {
            close(handle->socket);
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
        printf("Error: unable to open socket!\n");
        return RET_ERROR;
    }

    int ret = IpdbgBusAccess_sendReset(handle->socket);
    if (ret != RET_OK)
        return ret;

    ret = IpdbgBusAccess_getSizes(handle);
    if (ret != RET_OK)
        return ret;

    size_t bufferSize = IpdbgBusAccess_getBuffeSize(handle);
    if (bufferSize == 0)
        return RET_ERROR;

    handle->buffer = (uint8_t *)malloc(bufferSize + 1); // 1 for the acknowledge
    if (!handle->buffer)
    {
        printf("Error: unable to allocate buffer memory!\n");
        return RET_ERROR;
    }

    handle->AddressShadow = (uint8_t *)calloc(1, handle->AddressWidthBytes);
    if (!handle->AddressShadow)
    {
        free(handle->buffer);
        handle->buffer = NULL;
        printf("Error: unable to allocate buffer memory!\n");
        return RET_ERROR;
    }

    return IpdbgBusAccess_sendAddress(handle, handle->AddressShadow);
}

int API IpdbgBusAccess_close(struct IpdbgBusAccessHandle *handle)
{
    if (!handle)
        return RET_ERROR;

    if (!IpdbgBusAccess_isOpen(handle))
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

    int ret = (close(handle->socket) >= 0) ? RET_OK : RET_ERROR;
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
    if (!handle || handle->socket == INVALD_SOCKET)
        return RET_ERROR;

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
    if (!handle || handle->socket == INVALD_SOCKET || handle->WriteDataWidthBytes == 0)
    {
        printf("preconditions failed\n");
        return RET_ERROR;
    }

    int ret = IpdbgBusAccess_setAddress(handle, address);
    if (ret != RET_OK)
    {
        printf("failed to set address\n");
        return ret;
    }

    *handle->buffer = locked ? WRITE_CMD_LOCK : WRITE_CMD_UNLOCK;

    ret = IpdbgBusAccess_send(handle->socket, handle->buffer, 1);
    if (ret != 0)
    {
        printf("Error: unable to send WRITE_CMD command\n");
        return ret;
    }

    ret = IpdbgBusAccess_sendWithEscaping(handle->socket, data, handle->WriteDataWidthBytes);
    if (ret != RET_OK)
    {
        printf("Error: BusAccess_sendWithEscaping() failed\n");
        return ret;
    }

    int received = IpdbgBusAccess_receive(handle->socket, handle->buffer, 1);
    if (received != 1)
    {
        printf("Error: response to WRITE_CMD with wrong length\n");
        return RET_ERROR;
    }

    if (handle->buffer[0] == ACK_RESP)
        return RET_ACK;
    if (handle->buffer[0] == NACK_RESP)
        return RET_NAK;

    return RET_ERROR;
}

int API IpdbgBusAccess_read_ctrllock(struct IpdbgBusAccessHandle *handle,  const uint8_t *address, uint8_t *result, bool locked)
{
    if (!handle || handle->socket == INVALD_SOCKET || handle->ReadDataWidthBytes == 0)
    {
        printf("preconditions failed\n");
        return RET_ERROR;
    }

    int ret = IpdbgBusAccess_setAddress(handle, address);
    if (ret != RET_OK)
    {
        printf("failed to set address\n");
        return ret;
    }

    *handle->buffer = locked ? READ_CMD_LOCK : READ_CMD_UNLOCK;

    ret = IpdbgBusAccess_send(handle->socket, handle->buffer, 1);
    if (ret != 0)
    {
        printf("Error: unable to send READ_CMD command\n");
        return ret;
    }

    int received = IpdbgBusAccess_receive(handle->socket, handle->buffer, handle->ReadDataWidthBytes + 1);
    if (received != (int)handle->ReadDataWidthBytes + 1)
    {
        printf("Error: response to READ_CMD with wrong length\n");
        return RET_ERROR;
    }

    if (handle->buffer[0] == ACK_RESP)
        ret = RET_ACK;
    else if (handle->buffer[0] == NACK_RESP)
        ret = RET_NAK;
    else
        return RET_ERROR;

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
    if (!handle || handle->socket == INVALD_SOCKET)
        return RET_ERROR;
    assert(handle->ReadDataWidth == handle->WriteDataWidth && "read and write data have to have the same width");

    uint8_t buffer[handle->ReadDataWidth];

    int ret = IpdbgBusAccess_read_ctrllock(handle, address, buffer, true);

    if (ret != RET_ACK)
    {
        printf("read of read-modify-write failed\n");
        return ret;
    }
    if (modify)
        modify(buffer);

    return IpdbgBusAccess_write_ctrllock(handle, address, buffer, false);
}

int API IpdbgBusAccess_setMiscellaneous(struct IpdbgBusAccessHandle *handle, const uint8_t *data)
{
    if (!handle || handle->socket == INVALD_SOCKET || handle->MiscDataWidthBytes == 0)
        return RET_ERROR;

    *handle->buffer = SET_MISC_CMD;

    int ret = IpdbgBusAccess_send(handle->socket, handle->buffer, 1);
    if (ret != RET_OK)
    {
        printf("Error: unable to send SET_MISC_CMD command\n");
        return ret;
    }

    return IpdbgBusAccess_sendWithEscaping(handle->socket, data, handle->MiscDataWidthBytes);
}

int API IpdbgBusAccess_setStrobe(struct IpdbgBusAccessHandle *handle, const uint8_t *data)
{
    //
    if (!handle || handle->socket == INVALD_SOCKET || handle->StrobeWidthBytes == 0)
        return RET_ERROR;

    *handle->buffer = SET_STRB_CMD;

    int ret = IpdbgBusAccess_send(handle->socket, handle->buffer, 1);
    if (ret != RET_OK)
    {
        printf("Error: unable to send SET_STRB_CMD command\n");
        return ret;
    }

    return IpdbgBusAccess_sendWithEscaping(handle->socket, data, handle->StrobeWidthBytes);
}

int API IpdbgBusAccess_getFieldSize(struct IpdbgBusAccessHandle *handle, enum BusAccessField field, size_t *result)
{
    if (!handle || !result || handle->socket == INVALD_SOCKET)
        return RET_ERROR;

    switch (field)
    {
    case ADDRESS:    *result = handle->AddressWidth;   break;
    case READ_DATA:  *result = handle->ReadDataWidth;  break;
    case WRITE_DATA: *result = handle->WriteDataWidth; break;
    case STROBE:     *result = handle->StrobeWidth;    break;
    default:
    case MISC:       *result = handle->MiscDataWidth;  break;
    }
    return 0;
}

int API IpdbgAxi4lAccess_setAxprot(struct IpdbgBusAccessHandle *handle, uint8_t arprot, uint8_t awprot)
{
    if (!handle || handle->socket == INVALD_SOCKET)
        return RET_ERROR;

    if (handle->MiscDataWidth != 6)
    {
        printf("Error: probably not an AXI4 light master (width of arprot and awprot is not 3)\n");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        printf("Error: probably not an AXI4 light master (read has not the sane width as write)\n");
        return RET_ERROR;
    }

    uint8_t misc = ((awprot & 0x7) << 3) | (arprot & 0x7);
    return IpdbgBusAccess_setMiscellaneous(handle, &misc);
}

int API IpdbgApbAccess_setPprot(struct IpdbgBusAccessHandle *handle, uint8_t pprot)
{
    if (!handle || handle->socket == INVALD_SOCKET)
        return RET_ERROR;

    if (handle->MiscDataWidth != 3)
    {
        printf("Error: probably not an APB master (width of pprot is not 3)\n");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        printf("Error: probably not an APB master (read has not the sane width as write)\n");
        return RET_ERROR;
    }

    uint8_t misc = pprot & 0x7;
    return IpdbgBusAccess_setMiscellaneous(handle, &misc);
}

int API IpdbgAvalonAccess_setDebugAccess(struct IpdbgBusAccessHandle *handle, uint8_t debug)
{
    if (!handle || handle->socket == INVALD_SOCKET)
        return RET_ERROR;

    if (handle->MiscDataWidth != 1)
    {
        printf("Error: probably not an Avalon master (debug width is not 1)\n");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        printf("Error: probably not an Avalon master (read has not the sane width as write)\n");
        return RET_ERROR;
    }

    uint8_t misc = debug ? 0x1 : 0x0;
    return IpdbgBusAccess_setMiscellaneous(handle, &misc);
}

int API IpdbgAhbAccess_setHprotHsize(struct IpdbgBusAccessHandle *handle, uint8_t hprot, uint8_t hsize)
{
    if (!handle || handle->socket == INVALD_SOCKET)
        return RET_ERROR;

    const uint32_t hsize_width = 3;
    uint32_t hprot_width = handle->MiscDataWidth - hsize_width;

    if (hprot_width != 0 && hprot_width != 4 && hprot_width != 7)
    {
        printf("Error: probably not an Ahb master (width of hprot is not 0, 4 or 7)\n");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        printf("Error: probably not an Ahb master (read has not the sane width as write)\n");
        return RET_ERROR;
    }

    hsize &= 0x7;
    hprot &= (1 << hprot_width) - 1;

    uint16_t sz = 8;
    for (size_t i = 0; i < hsize; ++i)
        sz *= 2;

    if (handle->WriteDataWidth < sz)
    {
        printf("Error: hsize is bigger than write data bus\n");
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
    if (!handle || handle->socket == INVALD_SOCKET)
        return RET_ERROR;

    const uint32_t misc_width = 2; /* dmi-reset and dmi-hardreset*/

    if (handle->MiscDataWidth != misc_width)
    {
        printf("Error: probably not an Dtm master (width of misc is not 2)\n");
        return RET_ERROR;
    }

    if (handle->WriteDataWidth != handle->ReadDataWidth)
    {
        printf("Error: probably not an Dtm master (read has not the sane width as write)\n");
        return RET_ERROR;
    }

    uint8_t misc = (reset ? 1 : 0) | (hardreset ? 2 : 0);

    return IpdbgBusAccess_setMiscellaneous(handle, &misc);
}
