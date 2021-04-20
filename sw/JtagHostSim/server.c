#include <stdio.h>
#include <assert.h>

#define __USE_LARGEFILE64
#include <apr_general.h>
#include <apr_file_io.h>
#include <apr_strings.h>
#include <apr_network_io.h>
#include <apr_poll.h>

#include "jtaghost.h"

//#include <stdio.h>
//#include <stdlib.h>
//#include <string.h>

/* default listen port number */
#define DEF_LISTEN_PORT		4242

/* default socket backlog number. SOMAXCONN is a system default value */
#define DEF_SOCKET_BACKLOG	SOMAXCONN

#define DEF_POLLSET_NUM		32

/* default socket timeout */
#define DEF_POLL_TIMEOUT	(APR_USEC_PER_SEC * 30)

/* default buffer size */
#define BUFSIZE			4096

/* useful macro */
#define CRLF_STR		"\r\n"

#define IPDBG_VALID_MASK 0x800
//#define IPDBG_IOVIEW_VALID_MASK 0xA00
//#define IPDBG_LA_VALID_MASK     0xC00
//#define IPDBG_GDB_VALID_MASK    0x900
//#define IPDBG_WFG_VALID_MASK    0xB00
#define IPDBG_CHANNELS          7

#define MIN_TRANSFERS            1

typedef struct _serv_ctx_t serv_ctx_t;

/**
 * network event callback function type
 */
typedef int (*socket_callback_t)(serv_ctx_t *serv_ctx, apr_pollset_t *pollset, apr_socket_t *sock);

/**
 * network server context
 */
struct _serv_ctx_t
{
    enum
    {
        listening,
        connected
    } channel_state;
    uint8_t channel_number;

    uint8_t down_buf[BUFSIZE];
    size_t down_buf_level;

    uint8_t up_buf[BUFSIZE];
    size_t up_buf_level;

    apr_pool_t *mp;
};

static apr_socket_t* create_listen_sock(apr_pool_t *mp, unsigned short channel);
static int do_accept(serv_ctx_t *serv_ctx, apr_pollset_t *pollset, apr_socket_t *lsock, apr_pool_t *mp);

static int connection_rx_cb(serv_ctx_t *serv_ctx, apr_pollset_t *pollset, apr_socket_t *sock);
static int connection_tx_cb(serv_ctx_t *serv_ctx, apr_pollset_t *pollset, apr_socket_t *sock);

void distribute_to_up_buffer(uint16_t val, serv_ctx_t *channel_contexts[]);

int jtagHostLoop()
{


    apr_status_t rv;
    apr_pool_t *mp;
    apr_pollset_t *pollset;
    apr_int32_t num;
    const apr_pollfd_t *ret_pfd;

    apr_initialize();
    apr_pool_create(&mp, NULL);

    serv_ctx_t *channel_contexts[IPDBG_CHANNELS];


    apr_pollset_create(&pollset, DEF_POLLSET_NUM, mp, 0);
    for(uint8_t ch = 0; ch < IPDBG_CHANNELS; ++ch)
    {
        serv_ctx_t *serv_ctx = apr_palloc(mp, sizeof(serv_ctx_t));
        channel_contexts[ch] = serv_ctx;
        serv_ctx->channel_number = ch;
        serv_ctx->channel_state = listening;
        serv_ctx->up_buf_level = 0;
        serv_ctx->down_buf_level = 0;

        apr_socket_t *listening_sock = create_listen_sock(mp, ch);
        assert(listening_sock);

        apr_pollfd_t pfd = { mp, APR_POLL_SOCKET, APR_POLLIN, 0, { NULL }, serv_ctx };
        pfd.desc.s = listening_sock;
        apr_pollset_add(pollset, &pfd);
    }

    // reset JtagCDC
    uint16_t val;
    ipdbgJTAGtransfer(&val, 0xf00);

    while (1)
    {
        size_t transfers = 0;
        for(size_t ch = 0 ; ch < IPDBG_CHANNELS ; ++ch)
        {
            for(size_t idx = 0 ; idx < channel_contexts[ch]->down_buf_level; ++idx)
            {
                uint16_t val;
                ipdbgJTAGtransfer(&val, channel_contexts[ch]->down_buf[idx] | IPDBG_VALID_MASK | (ch << 8));
                transfers++;

                distribute_to_up_buffer(val, channel_contexts);
            }
            channel_contexts[ch]->down_buf_level = 0;
        }
        for(size_t k = transfers ; k < MIN_TRANSFERS ; ++k)
        {
            uint16_t val;
            ipdbgJTAGtransfer(&val, 0x000);
            distribute_to_up_buffer(val, channel_contexts);
        }

        rv = apr_pollset_poll(pollset, DEF_POLL_TIMEOUT, &num, &ret_pfd);
        if (rv == APR_SUCCESS)
        {
            int i;
            /* scan the active sockets */
            for (i = 0; i < num; i++)
            {
                serv_ctx_t *serv_ctx = ret_pfd[i].client_data;
                if(serv_ctx)
                {
                    if (serv_ctx->channel_state == listening)
                    {
                        apr_socket_t *listening_sock = ret_pfd[i].desc.s;
                         /* the listen socket is readable. that indicates we accepted a new connection */
                        do_accept(serv_ctx, pollset, listening_sock, mp);
                        apr_socket_close(listening_sock);
                        apr_pollset_remove(pollset, &ret_pfd[i]);
                    }
                    else
                    {
                        int ret = TRUE;
                        if(ret_pfd[i].rtnevents & (APR_POLLIN | APR_POLLHUP))
                        {
                            ret = connection_rx_cb(serv_ctx, pollset, ret_pfd[i].desc.s);
                        }
                        else // (ret_pfd[i].rtnevents & APR_POLLOUT)
                        {
                            ret = connection_tx_cb(serv_ctx, pollset, ret_pfd[i].desc.s);
                        }
                        if (ret == FALSE)
                        {
                            //printf("closing connection %d", serv_ctx->channel_number);
                            apr_socket_t *sock = ret_pfd[i].desc.s;

                            apr_socket_close(sock);
                            apr_pollset_remove(pollset, &ret_pfd[i]);

                            apr_socket_t *listening_sock = create_listen_sock(mp, serv_ctx->channel_number);
                            serv_ctx->channel_state = listening;

                            apr_pollfd_t pfd = { mp, APR_POLL_SOCKET, APR_POLLIN, 0, { NULL }, serv_ctx };
                            pfd.desc.s = listening_sock;
                            apr_pollset_add(pollset, &pfd);
                        }
                    }
                }
            }
        }
    }

    return 0;
}


static apr_socket_t* create_listen_sock(apr_pool_t *mp, unsigned short channel)
{
    apr_status_t rv;
    apr_socket_t *s;
    apr_sockaddr_t *sa;

    rv = apr_sockaddr_info_get(&sa, NULL, APR_INET, DEF_LISTEN_PORT+channel, 0, mp); // Create apr_sockaddr_t from hostname, address family, and port.
    if (rv != APR_SUCCESS)
        return NULL;

    rv = apr_socket_create(&s, sa->family, SOCK_STREAM, APR_PROTO_TCP, mp); //CREATE A SOCKET
    if (rv != APR_SUCCESS)
        return NULL;

    /* non-blocking socket */
    apr_socket_opt_set(s, APR_SO_NONBLOCK, 1); //Setup socket options for the specified socke

    apr_socket_timeout_set(s, 0); //Setup socket timeout for the specified socket
    apr_socket_opt_set(s, APR_SO_REUSEADDR, 1);/* this is useful for a server(socket listening) process */

    rv = apr_socket_bind(s, sa); //Bind the socket to its associated port
    if (rv != APR_SUCCESS)
        return NULL;

    rv = apr_socket_listen(s, DEF_SOCKET_BACKLOG); //Listen to a bound socket for connections.
    if (rv != APR_SUCCESS)
        return NULL;

    return s;
}

static int do_accept(serv_ctx_t *serv_ctx, apr_pollset_t *pollset, apr_socket_t *lsock, apr_pool_t *mp)
{
    apr_socket_t *ns;/* accepted socket */

    apr_status_t rv = apr_socket_accept(&ns, lsock, mp);
    if (rv == APR_SUCCESS)
    {
        serv_ctx->up_buf_level = 0;
        serv_ctx->down_buf_level = 0;
        serv_ctx->channel_state = connected;


        apr_pollfd_t pfd = { mp, APR_POLL_SOCKET, APR_POLLIN|APR_POLLOUT|APR_POLLHUP, 0, { NULL }, serv_ctx };
        pfd.desc.s = ns;
        serv_ctx->mp = mp;

        /* non-blocking socket. We can't expect that @ns inherits non-blocking mode from @lsock */
        apr_socket_opt_set(ns, APR_SO_NONBLOCK, 1); //Setup socket options for the specified socket
        apr_socket_timeout_set(ns, 0);

        apr_pollset_add(pollset, &pfd); //Add a socket or file descriptor to a pollset

        printf("connected client to channel %d\n", serv_ctx->channel_number);
    }
    return TRUE;
}


static int connection_tx_cb(serv_ctx_t *serv_ctx, apr_pollset_t *pollset, apr_socket_t *sock)
{
    if(serv_ctx->up_buf_level != 0)
    {
        apr_size_t wlen = serv_ctx->up_buf_level;
        apr_status_t rv = apr_socket_send(sock, (const char *)serv_ctx->up_buf, &wlen);
        serv_ctx->up_buf_level = 0;
        if (rv == APR_EOF)
            return FALSE;
    }

    return TRUE;
}

static int connection_rx_cb(serv_ctx_t *serv_ctx, apr_pollset_t *pollset, apr_socket_t *sock)
{
    apr_size_t len = BUFSIZE - serv_ctx->down_buf_level;

    apr_status_t rv = apr_socket_recv(sock, (char*)&serv_ctx->down_buf[serv_ctx->down_buf_level], &len); //Daten empfangen
    if (APR_STATUS_IS_EAGAIN(rv))
    {
        /* we have no data to read. we should keep polling the socket */
        return TRUE;
    }
    else if (APR_STATUS_IS_EOF(rv) || len == 0)
    {
        /* we lost TCP session.
         * XXX On Windows, rv would equal to APR_SUCCESS and len==0 in this case. So, we should check @len in addition to APR_EOF check */
        return FALSE;
    }
    else
    {
         //we got data
//        printf("rx(%d): ", serv_ctx->channel_number);
//        for(size_t i = 0; i < len ;++i)
//            printf("0x%02x ", (int)serv_ctx->down_buf[serv_ctx->down_buf_level+i]);
//        printf("\n");

        serv_ctx->down_buf_level += len;

    }


    return TRUE;
}

void distribute_to_up_buffer(uint16_t val, serv_ctx_t *channel_contexts[])
{
    /* flow control missing here */
    if (val & IPDBG_VALID_MASK)
    {
        size_t ch = (val >> 8) & 0x7;
        size_t index = channel_contexts[ch]->up_buf_level;
        channel_contexts[ch]->up_buf[index] = val & 0x00FF;
        channel_contexts[ch]->up_buf_level++;
    }
}
