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


int ipdbg_org_wfg_open(int *socket_handle);
int ipdbg_org_wfg_send(int *socket_handle, const uint8_t *buf, size_t len);
int ipdbg_org_wfg_receive(int *socket_handle, uint8_t *buf, int bufsize);
int ipdbg_org_wfg_close(int *socket_handle);

int main()
{

    int socket = -1;

    if( ipdbg_org_wfg_open(&socket) < 0)
    {
        printf("not able to open!\n");
        return -1;
    }

    uint8_t buf[4] = {0xee, 0xee, 0x00, 0x00};
    ipdbg_org_wfg_send(&socket, buf, 2);

    buf[0] = 0xbb; // get id command
    ipdbg_org_wfg_send(&socket, buf, 1);


    ipdbg_org_wfg_receive(&socket, buf, 4);

    printf("%x %x %x %x" , buf[0], buf[1], buf[2], buf[3]);


    ipdbg_org_wfg_close(&socket);

    return 0;
}

int ipdbg_org_wfg_open(int *socket_handle)
{
    struct addrinfo hints;
    struct addrinfo *results, *res;
    int err;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    err = getaddrinfo("127.0.0.1", "4242", &hints, &results);


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
        return -1;
    }

    return 0;
}


int ipdbg_org_wfg_send(int *socket_handle, const uint8_t *buf, size_t len)
{
    int out;
    out = send(*socket_handle, (char*)buf, len, 0);

    if (out < 0)
    {
        return -1;
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
            //printf("Receive error: %s", g_strerror(errno));
            return -1;
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
