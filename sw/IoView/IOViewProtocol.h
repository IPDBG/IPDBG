// SPDX-FileCopyrightText: The IPDBG authors
// SPDX-License-Identifier: MPL-2.0

#ifndef IOVIEWPROTOCOL_H_INCLUDED
#define IOVIEWPROTOCOL_H_INCLUDED

#include <wx/timer.h>
#include <wx/config.h>
#include <vector>
#include "IOViewObserver.h"
#include "IOViewProtocolI.h"

struct IpdbgBusAccessHandle;

// Connection to an IoProbe core through libBusAccess (sw/BusAccess):
// inputs = read data, outputs = write data, polled 50 ms after the previous read.
// All accesses are synchronous: if the core does not answer, the GUI waits
// for the timeout of the library (5 s), then the connection is closed.
class IOViewProtocol: public wxTimer, public IOViewProtocolI
{
public:
    IOViewProtocol(IOViewProtocolObserver *obs);
    virtual ~IOViewProtocol();

    virtual void open()override;
    virtual void close()override;
    virtual bool isOpen()override;
    virtual void setOutput(uint8_t *buffer, size_t len)override;

private:
    void Notify()override; // from the timer: read the inputs

    wxString lastError();
    void failNow(const wxString &message); // close the connection, then show the message
    // same, but later: the failed access may run in an event handler of a
    // control that closing the connection deletes
    void fail(const wxString &message);

    IOViewProtocolObserver *protocolObserver;
    struct IpdbgBusAccessHandle *handle;
    unsigned int numberOfInputs;
    unsigned int numberOfOutputs;
    std::vector<uint8_t> inputBuffer;
    bool failing; // fail() called, connection not yet closed

    wxConfig config;
};


#endif
