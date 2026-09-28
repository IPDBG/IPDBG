// SPDX-FileCopyrightText: The IPDBG authors
// SPDX-License-Identifier: MPL-2.0

#ifndef IOVIEWPROTOCOLI_H_INCLUDED
#define IOVIEWPROTOCOLI_H_INCLUDED

#include <cstddef>
#include <cstdint>
#include <wx/string.h>

class IOViewProtocolObserver
{
public:
    virtual void visualizeInputs(uint8_t *buffer, size_t len)=0;
    virtual void setPortWidths(unsigned int inputs, unsigned int outputs)=0;
    virtual void setConnectionStatus(const wxString &text)=0;
};

class IOViewProtocolI
{
public:
    virtual void open()=0;
    virtual void close()=0;
    virtual bool isOpen()=0;
    virtual void setOutput(uint8_t *buffer, size_t len)=0;
};


#endif
