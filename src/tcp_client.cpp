#include <iostream>
#include <boost/array.hpp>
#include <boost/asio.hpp>

#include "tcp_client.h"

int tcp_client::connect_to_server() {
    try {
        boost::asio::connect(socket_, endpoints_);
        return 0; // Connection successful
    } catch (const boost::system::system_error& e) {
        std::cerr << "Client connection failed: " << e.what() << std::endl;
        return -1;
    }
}

size_t tcp_client::read(uint8_t* data, size_t length){
    boost::system::error_code error;
    size_t len = socket_.read_some(boost::asio::buffer(data, length), error);
    if (error){
        //close and reconnect socket
        std::cerr << "Client read failed: "<<error.message()<<std::endl;
        socket_.close();
        connect_to_server();
        len = 0;
    }
    return len;
}

size_t tcp_client::write(uint8_t* data, size_t length){
    boost::system::error_code error;
    size_t len = socket_.write_some(boost::asio::buffer(data, length), error);
    if (error){
        //close and reconnect socket
        std::cerr << "Client write failed: "<<error.message()<<std::endl;
        socket_.close();
        connect_to_server();
        len = 0;
    }
    return len;
}

