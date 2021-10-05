// linux:
// mkoctfile IPDBG_WFG.cpp
//
// windows:
// mkoctfile IPDBG_WFG.cpp -lws2_32


#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#endif
#include <string.h>
#include <unistd.h>
#ifndef _WIN32
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif
#include <errno.h>

#include <cassert>

#include <tgmath.h>

#include <octave/oct.h>
#include <iostream>
#include <fstream>
#include <cmath>


using std::exception;
using std::shared_ptr;
using std::string;

using namespace std;

#define RET_OK 0
#define RET_ERR -1

#define RESET_SYMBOL  0xEE
#define ESCAPE_SYMBOL 0x55

#define TERM_ACKNOWLEDGE 0xFB

#define START_COMMAND                   0xF0
#define STOP_COMMAND                    0xF1
#define RETURN_SIZES_COMMAND            0xF2
#define WRITE_SAMPLES_COMMAND           0xF3
#define SET_NUMBEROFSAMPLES_COMMAND     0xF4
#define RETURN_STATUS_COMMAND           0xF5
#define ONE_SHOT_STROBE_COMMAND         0xF6

#ifdef _WIN32
    WSADATA wsaData;
#endif

struct ipdbg_wfg_sizes_t
{
    uint32_t DATA_WIDTH = 0;
    uint32_t ADDR_WIDTH = 0;
    uint32_t DATA_WIDTH_BYTES = 0;
    uint32_t ADDR_WIDTH_BYTES = 0;
    uint32_t limit_samples_max = 0;
    uint32_t limit_samples = 0;
};

int ipdbg_wfg_open(int *socket_handle, string *ipAddrStr, string *portNumberStr);
int ipdbg_wfg_close(int *socket_handle);
int ipdbg_wfg_send(int *socket_handle, const uint8_t *buf, size_t len);
int ipdbg_wfg_receive(int *socket_handle, uint8_t *buf, int bufsize);
int ipdbg_wfg_send_escaping(int *socket_handle, uint8_t *dataToSend, int length);
int ipdbg_wfg_send_command(string commandStr, int *socket_handle);
int ipdbg_wfg_send_reset(int *socket_handle);
int ipdbg_wfg_get_sizes(int *socket_handle, struct ipdbg_wfg_sizes_t *ipdbg_wfg_sizes);
int ipdbg_wfg_send_waveform(int *socket_handle,
        struct ipdbg_wfg_sizes_t *ipdbg_wfg_sizes, int64NDArray *data_to_send);
int ipdbg_wfg_read_status(int *socket_handle, uint8_t *status, int silent);

DEFUN_DLD (IPDBG_WFG,args,nargout,
          "IPDBG_WFG Help String")
{
    int nargin = args.length();
    if (nargin < 2)
    {
        printf("Error: IPDBG_WFG(ipAddrStr, portNumberStr) or\n");
        printf("Error: IPDBG_WFG(ipAddrStr, portNumberStr, signal)\n");
        return octave_value_list();
    }

    const octave_value &arg0 = args(0);
    string ipAddrStr;
    ipAddrStr = arg0.is_string() ? arg0.string_value() : "127.0.0.1";

    const octave_value &arg1 = args(1);
    string portNumberStr;
    portNumberStr = arg1.is_string() ? arg1.string_value() : "4245";

    int socket = -1;
    struct ipdbg_wfg_sizes_t ipdbg_wfg_sizes;

    if (ipdbg_wfg_open(&socket, &ipAddrStr, &portNumberStr) != RET_OK)
        return octave_value_list();

    if (ipdbg_wfg_send_reset(&socket) != RET_OK)
        return octave_value_list();


    if (ipdbg_wfg_get_sizes(&socket, &ipdbg_wfg_sizes) != RET_OK)
    {
#ifdef _WIN32
        WSACleanup();
#endif
        return octave_value_list();
    }

    if (nargin > 2)
    {
        const octave_value &arg2 = args(2);

        if (arg2.is_string())
            ipdbg_wfg_send_command(arg2.string_value(), &socket);
        else
        {
            int64NDArray data_to_send = arg2.array_value();
            ipdbg_wfg_sizes.limit_samples = data_to_send.numel();

            if (ipdbg_wfg_sizes.limit_samples > ipdbg_wfg_sizes.limit_samples_max)
                printf("Error: too many samples\n");
            else
                ipdbg_wfg_send_waveform(&socket, &ipdbg_wfg_sizes, &data_to_send);
        }
    }
    else
    {
        ipdbg_wfg_read_status(&socket, NULL, 0);
    }
    ipdbg_wfg_close(&socket);

    return octave_value_list();
}

int ipdbg_wfg_open(int *socket_handle, string *ipAddrStr, string *portNumberStr)
{
#ifdef _WIN32
    if (WSAStartup(0x0202, &wsaData) != NO_ERROR)
    {
        printf("WSAStartup failed!");
        return RET_ERR;
    }
#endif

    struct addrinfo hints;
    struct addrinfo *results, *res;

    string ipAddr= *ipAddrStr;
    string portNumber = *portNumberStr;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    getaddrinfo(ipAddr.c_str(), portNumber.c_str(), &hints, &results);

    for (res = results; res; res = res->ai_next)
    {
        if ((*socket_handle = socket(res->ai_family, res->ai_socktype, res->ai_protocol)) < 0)
            continue;
        if (connect(*socket_handle, res->ai_addr, res->ai_addrlen) != 0) {
            close(*socket_handle);
            *socket_handle = -1;
            continue;
        }
        break;
    }

    freeaddrinfo(results);

    if (*socket_handle < 0)
    {
#ifdef _WIN32
        WSACleanup();
#endif
        printf("Error: unable to open socket!\n");
        return RET_ERR;
    }

    return RET_OK;
}

int ipdbg_wfg_close(int *socket_handle)
{
    int ret = -1;
#ifdef _WIN32
    if (shutdown(*socket_handle, SD_SEND) != SOCKET_ERROR)
    {
        char recvbuf[16];
        int recvbuflen = 16;
        // Receive until the peer closes the connection
        while (recv(*socket_handle, recvbuf, recvbuflen, 0) > 0);
    }
#endif
    /// Close Socket faster, so the socket_handle can be reopened earlier
    struct linger ls{1, 1};
    if (setsockopt(*socket_handle, SOL_SOCKET, SO_LINGER, &ls, sizeof(ls)) == -1)
        printf("Error: SOL_SOCKET Error\n");

    if (close(*socket_handle) >= 0)
        ret = 0;

    *socket_handle = -1;

#ifdef _WIN32
    WSACleanup();
#endif

    return ret;
}


int ipdbg_wfg_send(int *socket_handle, const uint8_t *buf, size_t len)
{
    int out = 0;

    out = send(*socket_handle, (char*)buf, len, 0);

    if (out < 0)
        return RET_ERR;

    if ((unsigned int)out < len)
        printf("Only sent %d/%d bytes of data.", out, (int)len);

    return RET_OK;
}

int ipdbg_wfg_receive(int *socket_handle, uint8_t *buf, int bufsize)
{
    int received = 0;

    while (received < bufsize)
    {
        int len;

        len = recv(*socket_handle, (char*)(buf+received), bufsize-received, 0);

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

int ipdbg_wfg_send_escaping(int *socket_handle, uint8_t *dataToSend, int length)
{
    int ret;
    while (length--)
    {
        uint8_t payload = *dataToSend++;

        if (payload == RESET_SYMBOL ||
            payload == ESCAPE_SYMBOL)
        {
            uint8_t escapeSymbol = ESCAPE_SYMBOL;
            ret = ipdbg_wfg_send(socket_handle, &escapeSymbol, 1);
            if (ret != RET_OK)
                return ret;
        }

        ret = ipdbg_wfg_send(socket_handle, &payload, 1);
        if (ret != RET_OK)
            return ret;
    }
    return RET_OK;
}

int ipdbg_wfg_send_command(string commandStr, int *socket_handle)
{
    uint8_t buf;
    if (commandStr == std::string("start"))
    {
        printf("sending start\n");
        buf = START_COMMAND;
    }
    else if (commandStr == std::string("oneshot"))
    {
        printf("sending one shot\n");
        buf = ONE_SHOT_STROBE_COMMAND;
    }
    else
    {
        printf("sending stop\n");
        buf = STOP_COMMAND;
    }

    int ret = ipdbg_wfg_send(socket_handle, &buf, 1);
    if (ret != RET_OK)
    {
        printf("Error: unable to send command\n");
        return 1;
    }

    return ret;
}

int ipdbg_wfg_send_reset(int *socket_handle)
{
    uint8_t buf[2] = {RESET_SYMBOL, RESET_SYMBOL};
    int ret = ipdbg_wfg_send(socket_handle, buf, 2);
    if (ret != RET_OK)
        printf("Error: sending reset failed\n");

    return ret;
}

int ipdbg_wfg_get_sizes(int *socket_handle, struct ipdbg_wfg_sizes_t *ipdbg_wfg_sizes)
{
    uint8_t buf[8];

    /// get sizes
    buf[0] = RETURN_SIZES_COMMAND;
    int ret = ipdbg_wfg_send(socket_handle, buf, 1);
    if (ret != RET_OK)
    {
        printf("Error: unable to send RETURN_SIZES_COMMAND command\n");
        return ret;
    }

    int received = ipdbg_wfg_receive(socket_handle, buf, 8);
    if (received != 8)
    {
        printf("Error: response to RETURN_SIZES_COMMAND with wrong length\n");
        return RET_ERR;
    }

    ipdbg_wfg_sizes->DATA_WIDTH  =  buf[0]        & 0x000000FF;
    ipdbg_wfg_sizes->DATA_WIDTH |= (buf[1] <<  8) & 0x0000FF00;
    ipdbg_wfg_sizes->DATA_WIDTH |= (buf[2] << 16) & 0x00FF0000;
    ipdbg_wfg_sizes->DATA_WIDTH |= (buf[3] << 24) & 0xFF000000;

    ipdbg_wfg_sizes->ADDR_WIDTH  =  buf[4]        & 0x000000FF;
    ipdbg_wfg_sizes->ADDR_WIDTH |= (buf[5] <<  8) & 0x0000FF00;
    ipdbg_wfg_sizes->ADDR_WIDTH |= (buf[6] << 16) & 0x00FF0000;
    ipdbg_wfg_sizes->ADDR_WIDTH |= (buf[7] << 24) & 0xFF000000;

    printf("DATA_WIDTH = %d\n", ipdbg_wfg_sizes->DATA_WIDTH);
    printf("ADDR_WIDTH = %d\n", ipdbg_wfg_sizes->ADDR_WIDTH);
    const int HOST_WORD_SIZE = 8; // bits / word

    ipdbg_wfg_sizes->DATA_WIDTH_BYTES =
        (ipdbg_wfg_sizes->DATA_WIDTH + HOST_WORD_SIZE -1) / HOST_WORD_SIZE;
    ipdbg_wfg_sizes->ADDR_WIDTH_BYTES =
        (ipdbg_wfg_sizes->ADDR_WIDTH + HOST_WORD_SIZE -1) / HOST_WORD_SIZE;

    ipdbg_wfg_sizes->limit_samples_max = (0x01 << ipdbg_wfg_sizes->ADDR_WIDTH);
    printf("limit_samples_max = %d\n", ipdbg_wfg_sizes->limit_samples_max);

    return RET_OK;
}

int ipdbg_wfg_send_limit_samples(int *socket_handle,
    struct ipdbg_wfg_sizes_t *ipdbg_wfg_sizes)
{
    uint8_t buf[1];

    ///set number of samples
    buf[0] = SET_NUMBEROFSAMPLES_COMMAND;
    int ret = ipdbg_wfg_send(socket_handle, buf, 1);
    if (ret != RET_OK)
    {
        printf("Error: unable to send SET_NUMBEROFSAMPLES_COMMAND command\n");
        return ret;
    }

    printf("limit_samples: %d\n", ipdbg_wfg_sizes->limit_samples);
    uint8_t buffer[4] =
        {(uint8_t)(( ipdbg_wfg_sizes->limit_samples - 1)         & 0x000000ff),
        ((uint8_t)(((ipdbg_wfg_sizes->limit_samples - 1) >>  8)  & 0x000000ff)),
        ((uint8_t)(((ipdbg_wfg_sizes->limit_samples - 1) >>  16) & 0x000000ff)),
        ((uint8_t)(((ipdbg_wfg_sizes->limit_samples - 1) >>  24) & 0x000000ff))};

    for (size_t i = 0 ; i < ipdbg_wfg_sizes->ADDR_WIDTH_BYTES ; ++i)
    {
        ret = ipdbg_wfg_send_escaping(socket_handle, &(buffer[ipdbg_wfg_sizes->ADDR_WIDTH_BYTES - 1 - i]), 1);
        if (ret != RET_OK)
            return ret;
    }

    return RET_OK;
}

int ipdbg_wfg_send_waveform_data(int *socket_handle,
    struct ipdbg_wfg_sizes_t *ipdbg_wfg_sizes, int64NDArray *data_to_send)
{
    uint8_t buf[1];
    /// write samples
    buf[0] = WRITE_SAMPLES_COMMAND;
    int ret = ipdbg_wfg_send(socket_handle, buf, 1);
    if (ret != RET_OK)
    {
        printf("Error: unable to send WRITE_SAMPLES_COMMAND command\n");
        return ret;
    }

    for (unsigned int i = 0; i < ipdbg_wfg_sizes->limit_samples; i++)
    {
        int64_t val = (*data_to_send)(i);
        uint8_t buffer[8] = {(uint8_t)( val         & 0x000000ff),
                             (uint8_t)((val >>   8) & 0x000000ff),
                             (uint8_t)((val >>  16) & 0x000000ff),
                             (uint8_t)((val >>  24) & 0x000000ff),
                             (uint8_t)((val >>  32) & 0x000000ff),
                             (uint8_t)((val >>  40) & 0x000000ff),
                             (uint8_t)((val >>  48) & 0x000000ff),
                             (uint8_t)((val >>  56) & 0x000000ff)};
        for (size_t i = 0 ; i < ipdbg_wfg_sizes->DATA_WIDTH_BYTES ; ++i)
        {
            ret = ipdbg_wfg_send_escaping(socket_handle, &(buffer[ipdbg_wfg_sizes->DATA_WIDTH_BYTES - 1 - i]), 1);
            if (ret != RET_OK)
                return ret;
        }
    }

    bool recievedTermAck = false;
    uint8_t retry_count = 0;
    while (!recievedTermAck)
    {
        int received = ipdbg_wfg_receive(socket_handle, buf, 1);
        if (received < 0)
        {
            printf("Error: reading from socket failed\n");
            break;
        }
        else if (received == 0)
        {
            if (++retry_count >= 10)
            {
                printf("Error: timeout while writing samples\n");
                break;
            }
        }
        else
        {
            retry_count = 0;
            if (buf[0] == TERM_ACKNOWLEDGE)
                recievedTermAck = true;
        }
    }

    if (!recievedTermAck)
    {
        printf("Error: Didn't receive terminating acknowledge\n");
        return RET_ERR;
    }

    return RET_OK;
}

int ipdbg_wfg_send_waveform(int *socket_handle,
    struct ipdbg_wfg_sizes_t *ipdbg_wfg_sizes, int64NDArray *data_to_send)
{
    int ret = ipdbg_wfg_send_limit_samples(socket_handle, ipdbg_wfg_sizes);
    if (ret != RET_OK)
    {
        printf("Error: sending waveform length failed\n");
        return ret;
    }
    ret = ipdbg_wfg_send_waveform_data(socket_handle, ipdbg_wfg_sizes, data_to_send);
    if (ret != RET_OK)
    {
        printf("Error:sending waveform data failed\n");
        return ret;
    }

    /// get status to ensure socket stays open until
    /// all data has been processed by the remote
    ret = ipdbg_wfg_read_status(socket_handle, NULL, 1);

    return ret;
}

int ipdbg_wfg_read_status(int *socket_handle, uint8_t *status, int silent)
{
    /// get and print status
    const uint8_t enabledFlag      = 0x01;
    const uint8_t doubleBufferFlag = 0x02;

    uint8_t buf[1] = {RETURN_STATUS_COMMAND};
    int ret = ipdbg_wfg_send(socket_handle, buf, 1);
    if (ret != RET_OK)
    {
        printf("Error: unable to send RETURN_STATUS_COMMAND command\n");
        return ret;
    }

    if (ipdbg_wfg_receive(socket_handle, buf, 1) != 1)
    {
        printf("Error: receiving status byte failed\n");
        return RET_ERR;
    }

    if (status)
        *status = buf[0];

    if (!silent)
    {
        if (buf[0] & enabledFlag)
            printf("WFG is running, ");
        else
            printf("WFG is not running, ");

        if (buf[0] & doubleBufferFlag)
            printf("has double buffer\n");
        else
            printf("has no double buffer\n");
    }

    return RET_OK;
}

