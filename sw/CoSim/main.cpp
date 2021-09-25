#include <unistd.h>
#include <stdio.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <string.h>

#define PORT 3421


extern "C" int ghdl_main(int argc, char **argv);

static int bitbang_socket;

void ghdl_run(int genWaveform)
{
    printf("calling the vhdl simulator!\n");
    char *ghdl_argv[] = {(char*)"tb_top", (char*)"--wave=wave.ghw"};
    int ghdl_argc = 1;
    if (genWaveform)
        ++ghdl_argc;
    ghdl_main(ghdl_argc, ghdl_argv);
}


int init_socket(int *server_fd, struct sockaddr_in *address)
{
    int opt = 1;
    // Creating socket file descriptor
    if ((*server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0)
    {
        printf("socket failed");
        return -1;
    }

    // Forcefully attaching socket to the port
    if (setsockopt(*server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT,
                   &opt, sizeof(opt)))
    {
        printf("setsockopt failed");
        return -1;
    }
    address->sin_family = AF_INET;
    address->sin_addr.s_addr = INADDR_ANY;
    address->sin_port = htons(PORT);

    // Forcefully attaching socket to the port
    if (bind(*server_fd, (struct sockaddr*)address,
             sizeof(struct sockaddr_in)) < 0)
    {
        printf("bind failed");
        return -1;
    }

    if (listen(*server_fd, 3) < 0)
    {
        printf("listen failed");
        return -1;
    }
    return 0;
}

int accept_socket(int *server_fd, struct sockaddr_in *address)
{
    int new_socket;
    const int addrlen = sizeof(struct sockaddr_in);
    new_socket = accept(*server_fd, (struct sockaddr*)&address,
                        (socklen_t*)&addrlen);
    if (new_socket < 0)
    {
        printf("accept failed");
        return -1;
    }

    return new_socket;
}


int main(int argc, char const *argv[])
{
    int server_fd;
    struct sockaddr_in address;

    if (init_socket(&server_fd, &address) < 0)
        return -1;

    bitbang_socket = accept_socket(&server_fd, &address);

    if (bitbang_socket < 0)
        return -1;

    ghdl_run(argc > 1);

    return 0;
}


/** called from JtagAdapter.vhd */
extern "C" uint32_t get_bitbang_function()
{
    if (bitbang_socket < 0)
        return 0;
    char buffer;
    size_t valread = read(bitbang_socket, &buffer, 1);
    if (valread < 0)
        exit(-1);
    if (valread == 0)
        return 0;

    return (uint32_t)buffer;
}

extern "C" void set_binbang_readresponse(uint32_t data)
{
    if (bitbang_socket < 0)
        return;
    uint8_t buffer = data & 0xff;
    send(bitbang_socket, &buffer, 1, 0);
}

