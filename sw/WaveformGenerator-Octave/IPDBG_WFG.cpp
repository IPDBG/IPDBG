#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#define _WIN32_WINNT 0x0501
#include <winsock2.h>
#include <ws2tcpip.h>
#endif
//#include <glib.h>
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
#include <glib.h>

#include <octave/oct.h>
#include <iostream>
#include <fstream>
#include <cmath>

using ctype=gboolean;
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




int ipdbg_org_wfg_open(int *socket_handle, string *ipAddrStr, string *portNumberStr);
int ipdbg_org_wfg_send(int *socket_handle, const uint8_t *buf, size_t len);
int ipdbg_org_wfg_receive(int *socket_handle, uint8_t *buf, int bufsize);
int ipdbg_org_wfg_close(int *socket_handle);
int send_escaping(int *socket_handle, uint8_t *dataToSend, int length);

DEFUN_DLD (IPDBG_WFG,args,nargout,
          "IPDBG_WFG Help String")
{
    int nargin = args.length();
    if(nargin < 3 )
    {
        printf("ERROR: WFG_ADC(ipAddrStr,portNumberStr, signal)\n");
        return octave_value_list();
    }

    const octave_value &arg0 = args(0);
    string ipAddrStr;

    if(!arg0.is_string())
    {
        ipAddrStr = "127.0.0.1";
    }
    else
    {
        ipAddrStr = arg0.string_value();
    }

    const octave_value &arg1 = args(1);
    string portNumberStr;

    if(!arg1.is_string())
    {
        portNumberStr = "4245";

    }
    else
    {
        portNumberStr = arg1.string_value();
    }

    unsigned int DATA_WIDTH = 0;
    unsigned int ADDR_WIDTH = 0;
    unsigned int limit_samples_max = 0;
    unsigned int limit_samples = 0;

    const octave_value &arg2 = args(2);
    uint64NDArray data_to_send= arg2.array_value();
    dim_vector dv = data_to_send.dims();
    limit_samples = data_to_send.numel();

    int socket = -1;

    if( ipdbg_org_wfg_open(&socket, &ipAddrStr, &portNumberStr) > 0)
    {
        printf("ERROR: Port not able to open!\n");
        return octave_value_list ();
    }

    uint8_t buf[2] = {0xee, 0xee};
    if (ipdbg_org_wfg_send(&socket, buf, 2)>0)
        printf("ERROR: not able to send reset");

    /// get sizes
    buf[0] = RETURN_SIZES_COMMAND;
    if(ipdbg_org_wfg_send(&socket, buf, 1))
        printf("ERROR: not able to send command");

    uint8_t buf1[8];
    if (ipdbg_org_wfg_receive(&socket, buf1, 8));

    DATA_WIDTH  =  buf1[0]        & 0x000000FF;
    DATA_WIDTH |= (buf1[1] <<  8) & 0x0000FF00;
    DATA_WIDTH |= (buf1[2] << 16) & 0x00FF0000;
    DATA_WIDTH |= (buf1[3] << 24) & 0xFF000000;

    ADDR_WIDTH  =  buf1[4]        & 0x000000FF;
    ADDR_WIDTH |= (buf1[5] <<  8) & 0x0000FF00;
    ADDR_WIDTH |= (buf1[6] << 16) & 0x00FF0000;
    ADDR_WIDTH |= (buf1[7] << 24) & 0xFF000000;


    printf("DataWidth = %d\n", DATA_WIDTH);
    printf("AddrWidth = %d\n", ADDR_WIDTH);
    int HOST_WORD_SIZE = 8; // bits/ word

    unsigned int DATA_WIDTH_BYTES = (DATA_WIDTH+HOST_WORD_SIZE -1)/HOST_WORD_SIZE;
    unsigned int ADDR_WIDTH_BYTES = (ADDR_WIDTH+HOST_WORD_SIZE -1)/HOST_WORD_SIZE;

    limit_samples_max = (0x01 << ADDR_WIDTH);
    printf("limit_samples_max = %d\n", limit_samples_max);


    ///set number of samples

    buf[0] = SET_NUMBEROFSAMPLES_COMMAND;
    if (ipdbg_org_wfg_send(&socket, buf, 1)>0)
        printf("ERROR: not able to send command");


    if(limit_samples>limit_samples_max)
    {
        printf("limitsamples zu gross!!! ");
        return octave_value_list ();
    }
    else
    {
        printf("limit_samples: %d\n",limit_samples);

        uint8_t  buffer[4] = { (uint8_t)((limit_samples-1)         & 0x000000ff),
                             ( (uint8_t)(((limit_samples-1) >>  8)  & 0x000000ff)),
                             ( (uint8_t)(((limit_samples-1) >>  16) & 0x000000ff)),
                             ( (uint8_t)(((limit_samples-1) >>  24) & 0x000000ff))};

        for(size_t i = 0 ; i < ADDR_WIDTH_BYTES ; ++i)
        {
            //printf("buffer_limitsamples: %x\n",buffer[ADDR_WIDTH_BYTES-1-i]);
            send_escaping(&socket, &(buffer[ADDR_WIDTH_BYTES-1-i]), 1);
        }



        /// write samples
        buf[0] = WRITE_SAMPLES_COMMAND;
        if (ipdbg_org_wfg_send(&socket, buf, 1)>0)
            printf("not able to send command");


        for(unsigned int i = 0; i < limit_samples; i++)
        {

            uint8_t buffer [4] = { (uint8_t) ((data_to_send(i))         & 0x000000ff),
                                 ( (uint8_t)(((data_to_send(i)) >>  8)  & 0x000000ff)),
                                 ( (uint8_t)(((data_to_send(i)) >>  16) & 0x000000ff)),
                                 ( (uint8_t)(((data_to_send(i)) >>  24) & 0x000000ff))};
            for(size_t i = 0 ; i < DATA_WIDTH_BYTES ; ++i)
            {
                //printf("buffer: %x\n",buffer[DATA_WIDTH_BYTES-1-i]);
                send_escaping(&socket, &(buffer[DATA_WIDTH_BYTES-1-i]), 1);
            }


        }

        ///send start
        buf[0] = START_COMMAND;
        if (ipdbg_org_wfg_send(&socket, buf, 1))
            printf("not able to send command");

    }
    ipdbg_org_wfg_close(&socket);

    return octave_value_list();
}

int ipdbg_org_wfg_open(int *socket_handle, string *ipAddrStr, string *portNumberStr)
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
    {
        return 1;
    }

    return 0;
}


int ipdbg_org_wfg_send(int *socket_handle, const uint8_t *buf, size_t len)
{
    int out;
    out = send(*socket_handle, (char*)buf, len, 0);

    if (out < 0)
    {
        return 1;
    }

    if ((unsigned int)out < len)
    {
        printf("Only sent %d/%d bytes of data.", out, (int)len);
    }

    return 0;
}


int ipdbg_org_wfg_receive(int *socket_handle, uint8_t *buf, int bufsize)
{
    int received = 0;

    while(received < bufsize)
    {
        int len;

        len = recv(*socket_handle, (char*)(buf+received), bufsize-received, 0);

        if (len < 0)
        {
            printf("Receive error: %s", g_strerror(errno));
        }
        else
        {
            received += len;
        }
    }

    return received;
}


int ipdbg_org_wfg_close(int *socket_handle)
{
    int ret = -1;
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

        if ( payload == (uint8_t)RESET_SYMBOL )
        {
            uint8_t escapeSymbol = ESCAPE_SYMBOL;

            ipdbg_org_wfg_send(socket_handle, &escapeSymbol, 1);
        }

        if ( payload == (uint8_t)ESCAPE_SYMBOL )
        {
            uint8_t escapeSymbol = ESCAPE_SYMBOL;

            ipdbg_org_wfg_send(socket_handle, &escapeSymbol, 1);
        }

        ipdbg_org_wfg_send(socket_handle, &payload, 1);

    }
    return 0;
}
