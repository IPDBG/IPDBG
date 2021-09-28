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


#define RESET_SYMBOL  0xEE
#define ESCAPE_SYMBOL 0x55


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


int ipdbg_wfg_open(int *socket_handle, string *ipAddrStr, string *portNumberStr);
int ipdbg_wfg_send(int *socket_handle, const uint8_t *buf, size_t len);
int ipdbg_wfg_receive(int *socket_handle, uint8_t *buf, int bufsize);
int ipdbg_wfg_close(int *socket_handle);
int send_escaping(int *socket_handle, uint8_t *dataToSend, int length);

DEFUN_DLD (IPDBG_WFG,args,nargout,
          "IPDBG_WFG Help String")
{
    int nargin = args.length();
    if(nargin < 2 )
    {
        printf("ERROR: WFG_ADC(ipAddrStr, portNumberStr) or\n");
        printf("ERROR: WFG_ADC(ipAddrStr, portNumberStr, signal)\n");
        return octave_value_list();
    }
    const octave_value &arg0 = args(0);
    string ipAddrStr;

    if(!arg0.is_string())
        ipAddrStr = "127.0.0.1";
    else
        ipAddrStr = arg0.string_value();

    const octave_value &arg1 = args(1);
    string portNumberStr;

    if(!arg1.is_string())
        portNumberStr = "4245";
    else
        portNumberStr = arg1.string_value();

    unsigned int DATA_WIDTH = 0;
    unsigned int ADDR_WIDTH = 0;
    unsigned int limit_samples_max = 0;
    unsigned int limit_samples = 0;

    int socket = -1;

#ifdef _WIN32
    if (WSAStartup(0x0202, &wsaData) != NO_ERROR)
    {
      printf("WSAStartup failed!");
      return octave_value_list();
    }
#endif
    if( ipdbg_wfg_open(&socket, &ipAddrStr, &portNumberStr) > 0)
    {
        printf("ERROR: Port not able to open!\n");
#ifdef _WIN32
        WSACleanup();
#endif
        return octave_value_list();
    }

    uint8_t buf[2] = {0xee, 0xee};
    if (ipdbg_wfg_send(&socket, buf, 2) > 0)
        printf("ERROR: not able to send reset\n");

    /// get sizes
    buf[0] = RETURN_SIZES_COMMAND;
    if(ipdbg_wfg_send(&socket, buf, 1))
        printf("ERROR: not able to send command\n");

    uint8_t buf1[8];
    int received = ipdbg_wfg_receive(&socket, buf1, 8);
    if (received < 0)
    {
#ifdef _WIN32
        WSACleanup();
#endif
        return octave_value_list();
    }

    DATA_WIDTH  =  buf1[0]        & 0x000000FF;
    DATA_WIDTH |= (buf1[1] <<  8) & 0x0000FF00;
    DATA_WIDTH |= (buf1[2] << 16) & 0x00FF0000;
    DATA_WIDTH |= (buf1[3] << 24) & 0xFF000000;

    ADDR_WIDTH  =  buf1[4]        & 0x000000FF;
    ADDR_WIDTH |= (buf1[5] <<  8) & 0x0000FF00;
    ADDR_WIDTH |= (buf1[6] << 16) & 0x00FF0000;
    ADDR_WIDTH |= (buf1[7] << 24) & 0xFF000000;


    printf("DATA_WIDTH = %d\n", DATA_WIDTH);
    printf("ADDR_WIDTH = %d\n", ADDR_WIDTH);
    int HOST_WORD_SIZE = 8; // bits/ word

    unsigned int DATA_WIDTH_BYTES = (DATA_WIDTH+HOST_WORD_SIZE -1) / HOST_WORD_SIZE;
    unsigned int ADDR_WIDTH_BYTES = (ADDR_WIDTH+HOST_WORD_SIZE -1) / HOST_WORD_SIZE;

    limit_samples_max = (0x01 << ADDR_WIDTH);
    printf("limit_samples_max = %d\n", limit_samples_max);

    if(nargin > 2 )
    {
        const octave_value &arg2 = args(2);

        if(arg2.is_string())
        {
            string commandStr = arg2.string_value();

            if ( commandStr == std::string("start") )/// send start
            {
                printf("sending start\n");
                buf[0] = START_COMMAND;
            }
            else if(commandStr == std::string("oneshot"))
            {
                printf("sending one shot\n");
                buf[0] = ONE_SHOT_STROBE_COMMAND;
            }
            else
            {
                printf("sending stop\n");
                buf[0] = STOP_COMMAND;
            }

            if (ipdbg_wfg_send(&socket, buf, 1))
                printf("ERROR: not able to send command\n");
        }
        else
        {
            int64NDArray data_to_send = arg2.array_value();
            dim_vector dv = data_to_send.dims();
            limit_samples = data_to_send.numel();

            ///set number of samples
            buf[0] = SET_NUMBEROFSAMPLES_COMMAND;
            if (ipdbg_wfg_send(&socket, buf, 1) > 0)
                printf("ERROR: not able to send command\n");

            if(limit_samples > limit_samples_max)
                printf("ERROR: too many samples\n");

            else
            {
                printf("limit_samples: %d\n", limit_samples);
                uint8_t  buffer[4] = { (uint8_t)((limit_samples-1)          & 0x000000ff),
                                     ( (uint8_t)(((limit_samples-1) >>  8)  & 0x000000ff)),
                                     ( (uint8_t)(((limit_samples-1) >>  16) & 0x000000ff)),
                                     ( (uint8_t)(((limit_samples-1) >>  24) & 0x000000ff))};

                for(size_t i = 0 ; i < ADDR_WIDTH_BYTES ; ++i)
                    send_escaping(&socket, &(buffer[ADDR_WIDTH_BYTES-1-i]), 1);

                /// write samples
                buf[0] = WRITE_SAMPLES_COMMAND;
                if (ipdbg_wfg_send(&socket, buf, 1) > 0)
                    printf("ERROR: not able to send command\n");

                for(unsigned int i = 0; i < limit_samples; i++)
                {
                    int64_t val = data_to_send(i);
                    uint8_t buffer [4] = { (uint8_t) (val         & 0x000000ff),
                                         ( (uint8_t)((val >>   8) & 0x000000ff)),
                                         ( (uint8_t)((val >>  16) & 0x000000ff)),
                                         ( (uint8_t)((val >>  24) & 0x000000ff))};
                    for(size_t i = 0 ; i < DATA_WIDTH_BYTES ; ++i)
                        send_escaping(&socket, &(buffer[DATA_WIDTH_BYTES-1-i]), 1);
                }


                int receivedAcknowledge = (limit_samples * DATA_WIDTH_BYTES / 64) +1;
                bool recievedTermAck;
                uint8_t retry_count = 0;
                while (receivedAcknowledge)
                {
                    int received = ipdbg_wfg_receive(&socket, buf1, 1); //??? timeout
                    if (received < 0)
                    {
                        printf("ERROR: reading from socket failed\n");
                        break;
                    }
                    else if (received == 0)
                    {
                        if (++retry_count >= 10)
                        {
                            printf("ERROR: timeout while writing samples\n");
                            break;
                        }
                    }
                    else
                    {
                        retry_count = 0;
                        if (*buf1 == 0xFB)
                        {
                            recievedTermAck = true;
                            break;
                        }
                    }
                    receivedAcknowledge -= received;
                }

                if (!recievedTermAck)
                    printf("ERROR: Didn't receive terminating acknowledge\n");

                buf[0] = buf[1] = 0xee;
                if (ipdbg_wfg_send(&socket, buf, 2) > 0)
                    printf("ERROR: not able to send reset\n");

            }
        }

        /// get status to ensure socket stays open until all data from the actual command is out of the socket
        buf[0] = RETURN_STATUS_COMMAND;
        if (ipdbg_wfg_send(&socket, buf, 1))
            printf("ERROR: not able to send command\n");
        received = ipdbg_wfg_receive(&socket, buf1, 1);
    }
    else
    {
        /// get and print status
        const uint8_t enabledFlag       = 0x01;
        const uint8_t doubleBufferFlag 	= 0x02;

        buf[0] = RETURN_STATUS_COMMAND;
        if (ipdbg_wfg_send(&socket, buf, 1))
            printf("ERROR: not able to send command\n");

        received = ipdbg_wfg_receive(&socket, buf1, 1);

        if(buf1[0] & enabledFlag)
            printf("WFG is running, ");
        else
            printf("WFG is not running, ");

        if(buf1[0] & doubleBufferFlag)
            printf("has double buffer\n ");
        else
            printf("has no double buffer\n ");
    }
    ipdbg_wfg_close(&socket);

#ifdef _WIN32
    WSACleanup();
#endif

    return octave_value_list();
}

int ipdbg_wfg_open(int *socket_handle, string *ipAddrStr, string *portNumberStr)
{
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
        return 1;

    return 0;
}


int ipdbg_wfg_send(int *socket_handle, const uint8_t *buf, size_t len)
{
    int out;
    out = send(*socket_handle, (char*)buf, len, 0);

    if (out < 0)
        return 1;

    if ((unsigned int)out < len)
        printf("Only sent %d/%d bytes of data.", out, (int)len);

    return 0;
}


int ipdbg_wfg_receive(int *socket_handle, uint8_t *buf, int bufsize)
{
    int received = 0;

    while(received < bufsize)
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


int ipdbg_wfg_close(int *socket_handle)
{
    int ret = -1;
#ifdef _WIN32
    if (shutdown(*socket_handle, SD_SEND) != SOCKET_ERROR)
    {
        char recvbuf[16];
        int recvbuflen = 16;
        // Receive until the peer closes the connection
        while(recv(*socket_handle, recvbuf, recvbuflen, 0) > 0);
    }
#endif
    /// Close Socket faster, so the socket can be reopened earlier
    struct linger ls{1, 1};
    if(setsockopt(*socket_handle, SOL_SOCKET, SO_LINGER, &ls, sizeof(ls)) == -1) //
        perror("SOL_SOCKET Error: ");

    if (close(*socket_handle) >= 0)
        ret = 0;

    *socket_handle = -1;
    return ret;
}

int send_escaping(int *socket_handle, uint8_t *dataToSend, int length)
{
    while(length--)
    {
        uint8_t payload = *dataToSend++;

        if (payload == (uint8_t)RESET_SYMBOL || payload == (uint8_t)ESCAPE_SYMBOL)
        {
            uint8_t escapeSymbol = ESCAPE_SYMBOL;
            ipdbg_wfg_send(socket_handle, &escapeSymbol, 1);
        }

        ipdbg_wfg_send(socket_handle, &payload, 1);

    }
    return 0;
}
