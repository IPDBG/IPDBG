#ifndef TCP_CLIENT_H
#define TCP_CLIENT_H

#include <boost/asio.hpp>

class tcp_client
{
    public:
        tcp_client(std::string address, uint16_t port):
            resolver_(io_context_),
            //turn specified server name into TCP endpoint
            endpoints_(resolver_.resolve(address, std::to_string(port))),
            //create a socket
            socket_(io_context_) {}
        int connect_to_server();
        size_t read(uint8_t* data, size_t length);
        size_t write(uint8_t* data, size_t length);
        inline size_t data_available(){return socket_.available();}

    private:
        boost::asio::io_context io_context_;
        boost::asio::ip::tcp::resolver resolver_;
        boost::asio::ip::tcp::resolver::results_type endpoints_;
        boost::asio::ip::tcp::socket socket_;
};

#endif // TCP_CLIENT_H
