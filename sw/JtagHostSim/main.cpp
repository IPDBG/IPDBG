#include <iostream>
#include <thread>
#include <queue>
#include <boost/thread/mutex.hpp>
#include "JtagHostLoop.h"

extern "C" int ghdl_main(int argc, char **argv);

void ghdl_run()
{
    std::cout << "calling the vhdl simulator!" << std::endl;
    //char *ghdl_args[] = {(char*)"uut", (char*)"--stop-time=5000ns", (char*)"--assert-level=failure", (char*)"--wave=wave.ghw"};
    char *ghdl_args[] = {(char*)"tb_top"};
    ghdl_main(1, ghdl_args);

    return;
}

int main(int argc, const char *argv[])
{
    std::thread ghdl(ghdl_run);
    std::thread jtagHost(jtagHostLoop);

    std::cout << "main, ghdl and main now execute concurrently...\n";

    ghdl.join();
    jtagHost.join();


    return jtagHostLoop();
}
