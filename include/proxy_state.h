#ifndef PROXYSTATE_H
#define PROXYSTATE_H

class proxy;

class proxy_state
{
    public:
        virtual void enter(proxy* proxy) = 0;
        virtual void toggle(proxy* proxy) = 0;
        virtual void exit(proxy* proxy) = 0;
        virtual ~proxy_state(){}
};

#endif // PROXYSTATE_H
