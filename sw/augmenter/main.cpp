#include <iostream>
#include "proxy.h"

int main(int argc, char* argv[])
{
    if (argc != 2)
    {
        std::cerr<<"Usage error: filename is required" << std::endl;
        return 1;
    }

    proxy proxy(argv[1]);

    while (1)
        proxy.toggle();

    return 0;
}
