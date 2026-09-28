// SPDX-FileCopyrightText: The IPDBG authors
// SPDX-License-Identifier: MPL-2.0

#ifndef IOVIEWOBSERVER_H_INCLUDED
#define IOVIEWOBSERVER_H_INCLUDED


#include <cstdint>

class IOViewPanelObserver
{
public:
    virtual void setOutput(uint8_t *buffer, size_t len) = 0;
};


#endif
