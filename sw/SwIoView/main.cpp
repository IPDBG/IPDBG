#include <iostream>
#include <string>
#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <netdb.h>
#include <sys/uio.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <fstream>
#include "SwIoView.hpp"

class Obs: public SwIoViewObserver
{
public:
    void writeData(uint8_t *data, size_t length) override
    {
        std::cout << "received data:\n";
        for (size_t i = 0 ; i < length ; ++i)
        {
            uint32_t d = data[i];
            std::cout << i << ": 0x" << std::hex << d << "\n";
        }
    }
    void readData(uint8_t **data, size_t length) override
    {
        if (readData_)
            delete[] readData_;
        readData_ = new uint8_t[length];

        demoCnt_ += 42;
        size_t temp = demoCnt_;
        for (size_t idx = 0 ; idx < length ; ++idx)
        {
            readData_[idx] = temp % 0xff;
            temp /= 256;
        }
        *data = readData_;
    }
    Obs():
        demoCnt_(0)
    {}
    ~Obs()
    {
        if (readData_)
            delete[] readData_;
    }

private:
    size_t demoCnt_;
    uint8_t *readData_;
};

Obs obs;

SwIoView<24, 12> swIoView(&obs);


int main(int argc, char *argv[])
{
    int port = 4243;

    //setup a socket and connection tools
    sockaddr_in servAddr;
    memset((char*)&servAddr, 0, sizeof(servAddr));
    servAddr.sin_family = AF_INET;
    servAddr.sin_addr.s_addr = htonl(INADDR_ANY);
    servAddr.sin_port = htons(port);

    //open stream oriented socket with internet address
    //also keep track of the socket descriptor
    int serverSd = socket(AF_INET, SOCK_STREAM, 0);
    if(serverSd < 0)
    {
        std::cerr << "Error establishing the server socket\n";
        exit(0);
    }
    //bind the socket to its local address
    int bindStatus = bind(serverSd, (struct sockaddr*) &servAddr,
        sizeof(servAddr));
    if(bindStatus < 0)
    {
        std::cerr << "Error binding socket to local address\n";
        exit(0);
    }
    std::cout << "Waiting for a client to connect...\n";
    //listen for up to 5 requests at a time
    listen(serverSd, 1);
    sockaddr_in newSockAddr;
    socklen_t newSockAddrSize = sizeof(newSockAddr);
    int newSd = accept(serverSd, (sockaddr *)&newSockAddr, &newSockAddrSize);
    if(newSd < 0)
    {
        std::cerr << "Error accepting request from client!\n";
        exit(1);
    }
    if(fcntl(newSd, F_SETFL, fcntl(newSd, F_GETFL) | O_NONBLOCK) < 0)
    {
        std::cerr << "Error going to non blocking!\n";
        exit(1);
    }
    std::cout << "Connected with client!\n";

    uint8_t buffer;
    while(1)
    {
        int bytesRead = recv(newSd, (char*)&buffer, sizeof(buffer), 0);
        if (bytesRead > 0)
            swIoView.ctrlWrite(buffer);
        if (swIoView.ctrlRead(buffer))
            send(newSd, (char*)&buffer, sizeof(buffer), 0);

    }

    close(newSd);
    close(serverSd);
    return 0;
}
