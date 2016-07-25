#ifndef IOVIEWPROTOCOL_H_INCLUDED
#define IOVIEWPROTOCOL_H_INCLUDED

#include <wx/timer.h>
#include "IOViewObserver.h"
#include "IOViewProtocolI.h"

class wxSocketClient;

class IOViewProtocol: public wxTimer, public IOViewProtocolI
{
public:
    IOViewProtocol(IOViewProtocolObserver *obs);
    virtual ~IOViewProtocol(){};

    virtual void open()override;
    virtual void close()override;
    virtual bool isOpen()override;
    virtual void setOutput(uint8_t *buffer, size_t len)override;

private:
    enum IOViewIPCommands:uint8_t
    {
        /*INOUT_Auslesen*/
        ReadPortWidths = 0xAB,
        ReadInput = 0xAA,
        WriteOutput = 0xBB,
        Reset = 0xee,
        Escape = 0x55
    };
    wxSocketClient *client;
    enum {
        SOCKET_ID = 10,
    };
    IOViewProtocolObserver *protocolObserver;
    unsigned int NumberOfOutputs;
    unsigned int NumberOfInputs;

    virtual void Notify();

};


#endif // IOVIEWPROTOCOLI_H_INCLUDED
