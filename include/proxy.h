#ifndef PROXY_H_INCLUDED
#define PROXY_H_INCLUDED

#include "tcp_client.h"
#include "tcp_server.h"

class proxy_state;

class proxy{
    public:
        //from: libsigrok/src/hardware/ipdbg-la/protocol.c
        enum commands : unsigned char {
            /* Top-level command opcodes */
            CMD_SET_TRIGGER = 0x00,
            CMD_CFG_TRIGGER = 0xF0,
            CMD_CFG_LA = 0x0F,
            CMD_START = 0xFE,
            CMD_RESET = 0xEE,

            CMD_GET_BUS_WIDTHS = 0xAA,
            CMD_GET_LA_ID = 0xBB,
            CMD_ESCAPE = 0x55,

            /* Trigger subfunction command opcodes */
            CMD_TRIG_MASKS = 0xF1,
            CMD_TRIG_MASK = 0xF3,
            CMD_TRIG_VALUE = 0xF7,

            CMD_TRIG_MASKS_LAST = 0xF9,
            CMD_TRIG_MASK_LAST = 0xFB,
            CMD_TRIG_VALUE_LAST = 0xFF,

            CMD_TRIG_SELECT_EDGE_MASK = 0xF5,
            CMD_TRIG_SET_EDGE_MASK = 0xF6,

            /* LA subfunction command opcodes */
            CMD_LA_DELAY = 0x1F,
            CMD_GET_FEATURES = 0x10,
            CMD_GET_RLC_WIDTH = 0x60,
            CMD_GET_CHANNEL_NAMES = 0x70,
            CMD_GET_SAMPLE_RATE = 0x80
        };

        enum feature_flags : unsigned char {
            FEATURE_AUGMENTER_APP_ENABLED  = 0x01,
            //Flag 2: FEATURE_RUNLENGTH_CODER_ENABLED, not set by the proxy
            FEATURE_AUGMENTER_SAMPLERATE_ENABLED = 0x04,
            FEATURE_AUGMENTER_CH_NAMES_ENABLED = 0x08
        };

        const char* OLD_LA_ID = "IDBG";
        const char* NEW_LA_ID = "idbg";

        proxy(const std::string file_name);
        ~proxy();
        int connect_proxy();
        int connect_server();

        // client I/O
        int read_from_client(uint8_t* data, size_t len);
        int write_to_client(uint8_t* data, size_t len);
        inline size_t client_data_available(){return proxy_client->data_available();}

        // server I/O
        int read_from_server(uint8_t* data, size_t len);
        inline int read_from_server(uint8_t* data, size_t length, int timeout_ms)
            {return proxy_server->read(data, length, timeout_ms);}
        int write_to_server(const uint8_t* data, size_t len);
        int write_to_server(const char* data, size_t len);
        inline size_t server_data_available(){return proxy_server->data_available();}

        // state machine
        inline proxy_state* getCurrentState() const {return currentState;}
        void toggle();
        void setState(proxy_state& newState);
        int run_proxy();

        // Json I/O
        int get_value(std::string& value, std::string key);
        int get_value(uint64_t& value, std::string key);

        // Get-/Set functions
        inline void set_old_idbg_la_flag(bool is_old_id_value){old_ipdbg_la_connected = is_old_id_value;}
        inline bool is_old_idbg_la(){return old_ipdbg_la_connected;}

    private:
        const std::string file_name;
        proxy_state* currentState;
        bool old_ipdbg_la_connected = true;
        std::unique_ptr<tcp_client> proxy_client;
        std::unique_ptr<tcp_server> proxy_server;
};
#endif // PROXY_H_INCLUDED
