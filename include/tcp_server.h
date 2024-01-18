#ifndef TCP_SERVER_H
#define TCP_SERVER_H

#include <boost/asio.hpp>

class tcp_server
{
    public:
        tcp_server(std::string address, uint16_t port):
            socket_(io_context_),
            acceptor_(io_context_,
                      boost::asio::ip::tcp::endpoint(boost::asio::ip::address::from_string(address),port)
                      ){}
        int start_accept();
        size_t read(uint8_t* data, size_t max_length);
        int read(uint8_t* data, size_t length, int timeout_ms);
        size_t write(const uint8_t* data, size_t length);
        size_t write(const char* data, size_t length);
        inline bool is_open(){return socket_.is_open();}
        inline size_t data_available(){return socket_.available();}

    private:
        void read_handler(const boost::system::error_code& error, size_t bytes_transferred, int& ret);

        boost::asio::io_context io_context_;
        boost::asio::ip::tcp::socket socket_;
        boost::asio::ip::tcp::acceptor acceptor_;
};

#endif
