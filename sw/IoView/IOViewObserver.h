#ifndef IOVIEWOBSERVER_H_INCLUDED
#define IOVIEWOBSERVER_H_INCLUDED


#include <cstdint>

class IOViewPanelObserver
{
public:
    virtual void setOutput(uint8_t *buffer, size_t len) = 0;
};


#endif // IOVIEWOBSERVER_H_INCLUDED
