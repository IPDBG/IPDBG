// SPDX-FileCopyrightText: The IPDBG authors
// SPDX-License-Identifier: MPL-2.0

#include "IOViewProtocol.h"

#include <wx/app.h>
#include <wx/msgdlg.h>
#include <wx/string.h>
#include <wx/utils.h>
#include "ConnectionDialog.h"
#include "BusAccess.h"

namespace
{
    const char *DefaultHost = "127.0.0.1";
    const char *DefaultPort = "4244";
    const unsigned int PollIntervalMs = 50;
    const uint8_t address = 0; // IoProbe has no address, the library does not send it
}

IOViewProtocol::IOViewProtocol(IOViewProtocolObserver *obs):
    protocolObserver(obs),
    handle(nullptr),
    numberOfInputs(0),
    numberOfOutputs(0),
    failing(false),
    config("IO-View")
{
}

IOViewProtocol::~IOViewProtocol()
{
    wxTimer::Stop();
    if (handle)
        IpdbgBusAccess_delete(handle); // closes the connection
}

wxString IOViewProtocol::lastError()
{
    return wxString(IpdbgBusAccess_getLastError(handle));
}

void IOViewProtocol::failNow(const wxString &message)
{
    close(); // first: no timer event while the message box is open
    wxMessageBox(message, _("I/O-View"), wxOK | wxICON_ERROR);
}

void IOViewProtocol::fail(const wxString &message)
{
    if (failing)
        return;
    failing = true;
    wxTimer::Stop();
    CallAfter([this, message]()
    {
        failing = false;
        failNow(message);
    });
}

void IOViewProtocol::open()
{
    if (handle)
        return;

    wxString host;
    wxString port;
    config.Read("LastIp", &host);
    config.Read("LastPort", &port);
    if (host.IsEmpty())
        host = DefaultHost;
    if (port.IsEmpty())
        port = DefaultPort;

    ConnectionDialog dlg(wxTheApp->GetTopWindow(), &host, &port);
    if (dlg.ShowModal() != wxID_OK)
        return;
    if (host.IsEmpty() || port.IsEmpty())
        return;

    config.Write("LastIp", host);
    config.Write("LastPort", port);

    handle = IpdbgBusAccess_new();
    if (!handle)
    {
        wxMessageBox(_("Unable to allocate memory for the connection"), _("I/O-View"), wxOK | wxICON_ERROR);
        return;
    }

    const wxString where = host + ":" + port;
    {
        wxBusyCursor busy; // up to the timeout if the core does not answer
        if (IpdbgBusAccess_open(handle, host.mb_str(), port.mb_str()) != RET_OK)
        {
            wxString message = wxString::Format(_("Connecting to %s failed:\n%s"), where, lastError());
            // the old IoView core answers the width query with its port widths
            if (lastError().Contains("not a BusAccess core"))
                message += _("\n\nAn IoView core of an older IPDBG version? Replace it with rtl/IoProbe.");
            failNow(message);
            return;
        }
    }

    unsigned int coreType = 0;
    size_t inputs = 0;
    size_t outputs = 0;
    if (IpdbgBusAccess_getCoreType(handle, &coreType) != RET_OK ||
        IpdbgBusAccess_getFieldSize(handle, READ_DATA, &inputs) != RET_OK ||
        IpdbgBusAccess_getFieldSize(handle, WRITE_DATA, &outputs) != RET_OK)
    {
        failNow(wxString::Format(_("Connecting to %s failed:\n%s"), where, lastError()));
        return;
    }

    if (coreType != CORE_TYPE_IOPROBE)
    {
        if (coreType == CORE_TYPE_BUS_MASTER)
            failNow(wxString::Format(_("%s is a BusAccess bus master, not an IoProbe core."), where));
        else
            failNow(wxString::Format(_("%s is a BusAccess core of unknown type %u, not an IoProbe core."), where, coreType));
        return;
    }

    numberOfInputs = static_cast<unsigned int>(inputs);
    numberOfOutputs = static_cast<unsigned int>(outputs);
    inputBuffer.assign((numberOfInputs + 7) / 8, 0);

    if (protocolObserver)
    {
        protocolObserver->setPortWidths(numberOfInputs, numberOfOutputs);
        protocolObserver->setConnectionStatus(wxString::Format(_("Connected to %s, %u inputs, %u outputs"),
                                                               where, numberOfInputs, numberOfOutputs));
    }

    wxTimer::Start(PollIntervalMs, wxTIMER_ONE_SHOT);
}

void IOViewProtocol::close()
{
    wxTimer::Stop();

    if (handle)
        IpdbgBusAccess_delete(handle); // closes the connection
    handle = nullptr;

    numberOfInputs = 0;
    numberOfOutputs = 0;
    inputBuffer.clear();

    if (protocolObserver)
    {
        protocolObserver->setPortWidths(0, 0);
        protocolObserver->setConnectionStatus(_("Disconnected"));
    }
}

bool IOViewProtocol::isOpen()
{
    return handle != nullptr;
}

void IOViewProtocol::setOutput(uint8_t *buffer, size_t len)
{
    if (!handle || failing)
        return;

    if (len != (numberOfOutputs + 7) / 8)
    {
        fail(wxString::Format(_("Internal error: %u bytes for %u outputs"),
                              static_cast<unsigned int>(len), numberOfOutputs));
        return;
    }

    const int ret = IpdbgBusAccess_write(handle, &address, buffer);
    if (ret == RET_NAK)
        fail(_("Setting the outputs failed: the core answered NAK."));
    else if (ret != RET_ACK)
        fail(wxString::Format(_("Setting the outputs failed:\n%s"), lastError()));
}

void IOViewProtocol::Notify()
{
    if (!handle || failing)
        return;

    const int ret = IpdbgBusAccess_read(handle, &address, inputBuffer.data());
    if (ret == RET_ACK)
    {
        if (protocolObserver)
            protocolObserver->visualizeInputs(inputBuffer.data(), inputBuffer.size());
        // one shot, restarted after the read: the GUI gets the full interval
        // for its events even if a read takes longer (e.g. CoSim). A periodic
        // timer would fire again right away and, on GTK, starve the redraws.
        wxTimer::Start(PollIntervalMs, wxTIMER_ONE_SHOT);
    }
    else if (ret == RET_NAK)
        fail(_("Reading the inputs failed: the core answered NAK."));
    else
        fail(wxString::Format(_("Reading the inputs failed:\n%s"), lastError()));
}
