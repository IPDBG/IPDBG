#include <cstring>
#include "concrete_proxy_states.h"

// ------- init --------------
void init::enter(proxy* proxy)
{
    //read from sigrok
    while (proxy->read_from_server(&command, 1) != 0)
        ;

    //discard pending data from the client before sending start
    size_t nr_data_pendig = proxy->client_data_available();
    if (nr_data_pendig > 0)
    {
        //read and ignore data
        uint8_t data[nr_data_pendig];
        proxy->read_from_client(data, nr_data_pendig);
    }
}

void init::toggle(proxy* proxy)
{
    if (command == proxy->CMD_START)
    {
        //forward command to ipdbg_la
        while (proxy->write_to_client(&command, 1) != 0)
            ;
        proxy->setState(start::getInstance());
    }
    else if (command == proxy->CMD_GET_BUS_WIDTHS)
    {
        //forward command to ipdbg_la
        while (proxy->write_to_client(&command, 1) != 0)
            ;
        proxy->setState(get_bus_widths::getInstance());
    }
    else if (command == proxy->CMD_GET_LA_ID)
    {
        //forward command to ipdbg_la
        while (proxy->write_to_client(&command, 1) != 0)
            ;
        proxy->setState(get_la_id::getInstance());
    }
    else if (command == proxy->CMD_GET_RLC_WIDTH)
    {
        //forward command to ipdbg_la
        while (proxy->write_to_client(&command, 1) != 0)
            ;
        proxy->setState(get_rlc_width::getInstance());
    }
    else if (command == proxy->CMD_GET_FEATURES)
    {
        if (!proxy->is_old_idbg_la())
        {
            //forward command to ipdbg_la
            while (proxy->write_to_client(&command, 1) != 0)
                ;
        }
        proxy->setState(get_features::getInstance());
    }
    else if (command == proxy->CMD_GET_CHANNEL_NAMES)
    {
        proxy->setState(get_channel_names::getInstance());
    }
    else if (command == proxy->CMD_GET_SAMPLE_RATE)
    {
        proxy->setState(get_sample_rate::getInstance());
    }
    else
    {
        //default: init -> init
        //forward command to ipdbg_la
        while (proxy->write_to_client(&command, 1) != 0)
            ;
        proxy->setState(init::getInstance());
    }
}

proxy_state& init::getInstance()
{
    static init singleton;
    return singleton;
}

// ------- start --------------
void start::enter(proxy* proxy)
{
    const int server_read_timeout_ms = 1;
    const size_t buffer_size = 128;
    const size_t command_size = 1;
    uint8_t data_buffer[buffer_size];
    uint8_t command;
    size_t nr_of_client_data_available;

    int read_return = proxy->read_from_server(&command, command_size, server_read_timeout_ms);
    //acquire data until sigrok sends a command
    while (read_return == 0)
    {
        nr_of_client_data_available = proxy->client_data_available();
        if (nr_of_client_data_available > 0)
        {
            nr_of_client_data_available = (nr_of_client_data_available > buffer_size) ?
                buffer_size : nr_of_client_data_available;
            //read data from ipdbg_la
            if (proxy->read_from_client(data_buffer, nr_of_client_data_available) == 0)
            {
                //forward data to sigrok
                proxy->write_to_server(data_buffer, nr_of_client_data_available);
            }
        }
        /* check, if server sent data
        socket_.available() does not detect whether or not the socket is connected to a remote endpoint.
        Only by actually reading from a socket, can the connection status be determined */
        read_return = proxy->read_from_server(&command, command_size, server_read_timeout_ms);
    }

    if (read_return > 0)
        //forward command to ipdb_la
        while (proxy->write_to_client(&command, command_size) != 0)
            ;
}

void start::toggle(proxy* proxy)
{
    proxy->setState(init::getInstance());
}

proxy_state& start::getInstance()
{
    static start singleton;
    return singleton;
}

// ------- get_bus_widths --------------
void get_bus_widths::enter(proxy* proxy)
{
    const size_t buffer_size = 8;
    uint8_t bus_widths[buffer_size];
    //read bus widths from ipdbg_la
    while (proxy->client_data_available() < buffer_size)
        ;
    if (proxy->read_from_client(bus_widths, buffer_size) == 0)
        //forward bus widths to sigrok
        proxy->write_to_server(bus_widths, buffer_size);
}

void get_bus_widths::toggle(proxy* proxy)
{
    proxy->setState(init::getInstance());
}

proxy_state& get_bus_widths::getInstance()
{
    static get_bus_widths singleton;
    return singleton;
}

// ------- get_la_id --------------
void get_la_id::enter(proxy* proxy)
{
    const size_t buffer_size = 4;
    uint8_t la_id[buffer_size];
    //read id from ipdbg_la
    while (proxy->client_data_available() < buffer_size)
        ;
    if (proxy->read_from_client(la_id, buffer_size) == 0)
    {
        bool cmp_IDBG = strncmp(reinterpret_cast<const char*>(la_id), proxy->OLD_LA_ID, buffer_size) == 0;
        bool cmp_idbg = strncmp(reinterpret_cast<const char*>(la_id), proxy->NEW_LA_ID, buffer_size) == 0;
        if (cmp_IDBG || cmp_idbg)
            proxy->set_old_idbg_la_flag(cmp_IDBG);

        //send id of new_idbg_la_to sigrok
        proxy->write_to_server(proxy->NEW_LA_ID, buffer_size);
    }
}

void get_la_id::toggle(proxy* proxy)
{
    proxy->setState(init::getInstance());
}

proxy_state& get_la_id::getInstance()
{
    static get_la_id singleton;
    return singleton;
}

// ------- get_rlc_width --------------
void get_rlc_width::enter(proxy* proxy)
{
    const size_t buffer_size = 1;
    uint8_t rlc_width;
    //read command from ipdb_la
    while (proxy->client_data_available() < buffer_size)
        ;
    if (proxy->read_from_client(&rlc_width, buffer_size) == 0)
        //forward rlc width to sigrok
        proxy->write_to_server(&rlc_width, buffer_size);
}

void get_rlc_width::toggle(proxy* proxy)
{
    proxy->setState(init::getInstance());
}

proxy_state& get_rlc_width::getInstance()
{
    static get_rlc_width singleton;
    return singleton;
}

// ------- get_features --------------
void get_features::enter(proxy* proxy)
{
    const size_t buffer_size = 4;
    uint8_t features[buffer_size] = {0};
    if (!proxy->is_old_idbg_la())
    {
        //read command from ipdb_la
        while (proxy->client_data_available() < buffer_size)
            ;
        if (proxy->read_from_client(features, buffer_size) == 0)
        {
            //set augmented features bit
            features[0] = features[0] | proxy->FEATURE_AUGMENTER_APP_ENABLED;
            features[0] = features[0] | proxy->FEATURE_AUGMENTER_SAMPLERATE_ENABLED;
            features[0] = features[0] | proxy->FEATURE_AUGMENTER_CH_NAMES_ENABLED;
            //forward features to sigrok
        }
///        else ???
        //proxy->write_to_server(features, buffer_size);
    }

    proxy->write_to_server(features, buffer_size);
}

void get_features::toggle(proxy* proxy)
{
    proxy->setState(init::getInstance());
}

proxy_state& get_features::getInstance()
{
    static get_features singleton;
    return singleton;
}

// ------- get_channel_names --------------
void get_channel_names::enter(proxy* proxy)
{
    uint8_t number_of_channels;
    //get number of channels
    while (proxy->server_data_available() < 1)
        ;
    if (proxy->read_from_server(&number_of_channels, 1) == 0)
    {
        //get channel names
        for (int i = 0; i<number_of_channels; i++)
        {
            std::string key = "CH" + std::to_string(i);
            std::string channel_name;
            proxy->get_value(channel_name, key);

            //send channel name lenght
            uint8_t name_lenght = channel_name.size();
            if (proxy->write_to_server(&name_lenght, 1) == 0)
            {
                 //send channel name
                proxy->write_to_server(&channel_name[0], name_lenght);
            }
        }
    }
}

void get_channel_names::toggle(proxy* proxy)
{
    proxy->setState(init::getInstance());
}

proxy_state& get_channel_names::getInstance()
{
    static get_channel_names singleton;
    return singleton;
}


// ------- get_sample_rate --------------
void get_sample_rate::enter(proxy* proxy)
{
    //get channel names
    std::string key = "sample_rate";
    uint64_t sample_rate;
    if (proxy->get_value(sample_rate, key) != 0)
        sample_rate = 0; //sample rate could not be read from file

    //send channel name
    const size_t buffer_size = 8;
    uint8_t buffer[buffer_size] = {
        static_cast<uint8_t>(sample_rate & 0xFF),
        static_cast<uint8_t>((sample_rate >> 8)  & 0xFF),
        static_cast<uint8_t>((sample_rate >> 16) & 0xFF),
        static_cast<uint8_t>((sample_rate >> 24) & 0xFF),
        static_cast<uint8_t>((sample_rate >> 32) & 0xFF),
        static_cast<uint8_t>((sample_rate >> 40) & 0xFF),
        static_cast<uint8_t>((sample_rate >> 48) & 0xFF),
        static_cast<uint8_t>((sample_rate >> 56) & 0xFF)
    };
    proxy->write_to_server(buffer, buffer_size);
}

void get_sample_rate::toggle(proxy* proxy)
{
    proxy->setState(init::getInstance());
}

proxy_state& get_sample_rate::getInstance()
{
    static get_sample_rate singleton;
    return singleton;
}
