#include <iostream>
#include <boost/asio.hpp>
#include <boost/array.hpp>
#include <ctime>

#include "tcp_server.h"


int tcp_server::start_accept(){
    try{
        //create a socket to connect to the client and wait for a connection
        acceptor_.accept(socket_);
    }catch (const boost::system::system_error& e){
            std::cerr << "Server connection failed: " << e.what() << std::endl;
            return -1;
        }
        return 0;
}

//non-blocking read function, returning whatever data is available
size_t tcp_server::read(uint8_t* data, size_t max_length){
    boost::system::error_code error;
    size_t len = 0;
    len = socket_.read_some(boost::asio::buffer(data, max_length), error);
    if (error){
        //reset and open socket for incoming connections
        std::cerr << "Server read failed: "<<error.message()<<std::endl;
        socket_.close();
        start_accept();//wait for a connection
        len = 0;
    }
    return len;
}

//handler for asynchronous read function
void tcp_server::read_handler(const boost::system::error_code& error, size_t bytes_transferred, int& ret){
    if(!error){
        ret = bytes_transferred; //return number of read bytes
        }
    else{
        if(error == boost::asio::error::operation_aborted){
            ret = 0; //no data was available
        }
        else{
            if(error == boost::asio::error::eof){
                ret = -2; //client disconnected
            }
            else{
                ret = -1; //other error occurred
            }
        }
    }
}

//blocking read function with timeout
int tcp_server::read(uint8_t* data, size_t length, int timeout_ms){
    int ret = -1;
    boost::asio::steady_timer timeout_timer(io_context_, boost::asio::chrono::milliseconds(timeout_ms));

    timeout_timer.async_wait([&](boost::system::error_code ec) {
        if (!ec) {
            socket_.cancel();
        }
    });

    async_read(socket_, boost::asio::buffer(data, length),
           [&](const boost::system::error_code& error, size_t bytes_transferred) {
               tcp_server::read_handler(error, bytes_transferred, ret);
           });
    if(io_context_.stopped())
        io_context_.restart();
    // Run the io_context until all asynchronous operations are completed
    while (io_context_.run_one()) {
        // Continue running until no more operations are pending
    }
    if(ret == -2){
        //reset and open socket for incoming connections
        std::cerr << "server: read failed, no connection to client "<<std::endl;
        socket_.close();
        start_accept();
    }
    return ret;
}

size_t tcp_server::write(const uint8_t* data, size_t length){
    boost::system::error_code error;
    size_t len = socket_.write_some(boost::asio::buffer(data, length), error);
    if (error){
        //reset and open socket for incoming connections
        std::cerr << "Server write failed: "<<error.message()<<std::endl;
        socket_.close();
        start_accept();
        len = 0;
    }
    return len;
}

size_t tcp_server::write(const char* data, size_t length){
    boost::system::error_code error;
    size_t len = socket_.write_some(boost::asio::buffer(data, length), error);
    if (error){
        //reset and open socket for incoming connections
        std::cerr << "Server write failed: "<<error.message()<<std::endl;
        socket_.close();
        start_accept();
        len = 0;
    }
    return len;
}
