#include <stdio.h>
#include <unistd.h>
#include "BusAccess.h"


int main(int argc, char *argv[])
{
    char *addr = "127.0.0.1";
    char *port = "4245";

    struct IpdbgBusAccessHandle *ba;

    printf("start\n");

    ba = IpdbgBusAccess_new();

    if (!ba)
    {
        printf("creating ba handler failed!\n");
        return -1;
    }

    int ret = IpdbgBusAccess_open(ba, addr, port);
    if (ret != RET_OK)
    {
        printf("opening BusAccessor feature failed!\n");
        return -1;
    }


    size_t sz = 0;

    for (int k = ADDRESS; k <= MISC; ++k)
    {
        ret = IpdbgBusAccess_getFieldSize(ba, k, &sz);
        char *field;
        switch(k)
        {
            case 0: field = "ADDRESS";    break;
            case 1: field = "READ_DATA";  break;
            case 2: field = "WRITE_DATA"; break;
            case 3: field = "STROBE";     break;
            default:
            case 4: field = "MISC";       break;
        }

        if (ret == RET_OK)
            printf("Field %s has size of %d\n", field, sz);

        else
        {
            printf("failed to get size of field &s\n", field);
            return -2;
        }

    }

    uint8_t stb = 0;
    for (size_t k = 0; k < 4 ; ++k)
    {
        stb = k & 0x03;
        ret = IpdbgBusAccess_setStrobe(ba, &stb);
        if (ret != RET_OK)
        {
            printf("failed to set strobe\n");
            return -3;
        }
        sleep(1);
    }

    uint8_t address[2] = {0x55, 0x00};
    uint8_t data[4] = {0x00, 0x00, 0x00, 0x00};
    for (size_t k = 0; k < 10; ++k)
    {
        ret = IpdbgBusAccess_write(ba, address, data);
        if (ret != RET_ACK)
        {
            printf("failed to write data\n");
            return -3;
        }

        ret = IpdbgBusAccess_read(ba, address, data);
        if (ret != RET_ACK)
        {
            printf("failed to read data back\n");
            return -3;
        }
        printf("received data: 0x%x\n", data[0]);
        sleep(1);
        data[1] += 2;
        data[0] += 3;
    }

    IpdbgBusAccess_close(ba);
    IpdbgBusAccess_delete(ba);

    return 0;
}
