#ifndef CONCRETE_PROXY_STATES_H
#define CONCRETE_PROXY_STATES_H

#include "proxy_state.h"
#include "proxy.h"

class init : public proxy_state
{
    public:
        void enter(proxy* proxy);
        void toggle(proxy* proxy);
        void exit(proxy* proxy){}
        static proxy_state& getInstance();

    private:
        init(): command(0x00) {}
        uint8_t command;
};

class start : public proxy_state
{
    public:
        void enter(proxy* proxy);
        void toggle(proxy* proxy);
        void exit(proxy* proxy){}
        static proxy_state& getInstance();
};

class get_bus_widths : public proxy_state
{
    public:
        void enter(proxy* proxy);
        void toggle(proxy* proxy);
        void exit(proxy* proxy) {}
        static proxy_state& getInstance();
};

class get_la_id : public proxy_state
{
    public:
        void enter(proxy* proxy);
        void toggle(proxy* proxy);
        void exit(proxy* proxy) {}
        static proxy_state& getInstance();
};

class get_rlc_width : public proxy_state
{
    public:
        void enter(proxy* proxy);
        void toggle(proxy* proxy);
        void exit(proxy* proxy) {}
        static proxy_state& getInstance();
};

class get_features : public proxy_state
{
    public:
        void enter(proxy* proxy);
        void toggle(proxy* proxy);
        void exit(proxy* proxy) {}
        static proxy_state& getInstance();
};

class get_channel_names : public proxy_state
{
    public:
        void enter(proxy* proxy);
        void toggle(proxy* proxy);
        void exit(proxy* proxy) {}
        static proxy_state& getInstance();
};

class get_sample_rate : public proxy_state
{
    public:
        void enter(proxy* proxy);
        void toggle(proxy* proxy);
        void exit(proxy* proxy) {}
        static proxy_state& getInstance();
};
#endif // CONCRETE_PROXY_STATES_H
