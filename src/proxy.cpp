#include <boost/asio.hpp>
#include <boost/array.hpp>
#include <fstream>
#include <iostream>
#include <json/json.h>
#include "proxy.h"
#include "tcp_client.h"
#include "tcp_server.h"
#include "concrete_proxy_states.h"

proxy::proxy(const std::string file_name) : file_name(file_name)
{
    bool success = false;
    while (!success)
    {
        //get server/client ip/port from json-file
        std::string server_ip, client_ip, server_port, client_port;
        success = true;
        if ((get_value(server_ip, "server_ip") == 0) && (get_value(server_port, "server_port") == 0))
        {
            try
            {
                //instantiate a tcp_server
                proxy_server = std::make_unique<tcp_server>(server_ip, std::stoi(server_port));
            }
            catch (const boost::system::system_error& e)
            {
                    std::cerr << "Server instantiation failed: " << e.what() << std::endl;
                    success = false;
            }
        }
    }

    success = false;
    while (!success)
    {
        //get server/client ip/port from json-file
        std::string server_ip, client_ip, server_port, client_port;
        success = true;
        if ((get_value(client_ip, "client_ip") == 0) && (get_value(client_port, "client_port") == 0))
        {
            try
            {
                //instantiate a tcp_client
                proxy_client = std::make_unique<tcp_client>(client_ip, std::stoi(client_port));
            }
            catch (const boost::system::system_error& e)
            {
                    std::cerr << "Server instantiation failed: " << e.what() << std::endl;
                    success = false;
            }
        }
    }
    //connect client and open server for incoming connections
    while (connect_proxy() != 0)
        ;
    currentState = &init::getInstance(); //initial state
    currentState->enter(this);
}

int proxy::connect_proxy()
{
    //connect proxy-client to server
    if (proxy_client->connect_to_server() == 0)
    {
        //open proxy-server before incoming connections
        if (proxy_server->start_accept() == 0)
            return 0;
    }
    return -1;
}

int proxy::connect_server()
{
    if (proxy_server->start_accept() == 0)
        return 0;
    return -1;
}

int proxy::read_from_client(uint8_t* data, size_t len)
{
    if (proxy_client->read(data, len) == len)
        return 0;

    else
        return -1;
}

int proxy::write_to_client(uint8_t* data, size_t len)
{
    if (proxy_client->write(data, len) == len)
        return 0;
    else
        return -1;
}

int proxy::read_from_server(uint8_t* data, size_t len)
{
    if (proxy_server->read(data, len) == len)
        return 0;

    else
        return -1;
}

int proxy::write_to_server(const uint8_t* data, size_t len)
{
    if (proxy_server->write(data, len) == len)
        return 0;
    else
        return -1;
}

int proxy::write_to_server(const char* data, size_t len)
{
    if (proxy_server->write(data, len) == len)
        return 0;
    else
        return -1;
}

void proxy::setState(proxy_state& newState)
{
    currentState->exit(this); //work to do before state exit
    currentState = &newState; //change state
    currentState->enter(this); //work to do after state entry
}

void proxy::toggle()
{
    currentState->toggle(this);
}

int proxy::get_value(std::string& value, std::string key)
{
    int ret = 0;
    Json::Value root;
    std::ifstream file_stream(file_name, std::ifstream::in);
    if (!file_stream.is_open())
    {
        value = "failed_to_open_data_file";
        std::cerr << "failed to open file "<<file_name<<std::endl;
        ret = -1;
    }
    else
    {
        file_stream >> root; //parse json data from file
        if (!root.isMember(key))
        {
            value = "not_found";
            std::cerr << "failed to find key: "<< key <<std::endl;
            ret = -1;
        }
        else
        {
            value = root[key].asString();
            ret = 0;
        }
    }
    return ret;
}

int proxy::get_value(uint64_t& value, std::string key)
{
    int ret = 0;
    Json::Value root;
    std::ifstream file_stream(file_name);
    if (!file_stream.is_open())
    {
        value = 1;
        std::cerr << "failed to open file"<<file_name<<std::endl;
        ret = -1;
    }
    else
    {
       file_stream >> root; //parse json data from file
        if (!root.isMember(key))
        {
            value = 1;
            std::cerr << "failed to find key: "<< key <<std::endl;
            ret = -1;
        }
        else
        {
            value = root[key].asUInt64();
            ret = 0;
        }
    }
    return ret;
}
