#include "IOViewProtocol.h"

#include <wx/socket.h>
#include <wx/msgdlg.h>
#include <wx/string.h>
#include <string>
#include <wx/textdlg.h>
#include <wx/fileconf.h>
#include <wx/msw/regconf.h>
#include <wx/confbase.h>
#include <wx/config.h>

wxConfig *config = new wxConfig("I/O-View");
wxString LastIp;

IOViewProtocol::IOViewProtocol(IOViewProtocolObserver *obs):
client(nullptr),
protocolObserver(obs)
{

}

void IOViewProtocol::open()
{
    client = new wxSocketClient();

    config->Read("LastIp",&LastIp);
    wxString IpAdress = wxGetTextFromUser(wxT("IP Adresse"),wxT("IP Adress to Connect"),LastIp);
    config->Write("LastIp",IpAdress);

    if(IpAdress.IsEmpty())
    {
        delete client;
        client = nullptr;
        return;
    }


    wxIPV4address address;
    address.Hostname(_(IpAdress));
    address.Service(_("4243"));

    client->SetFlags(wxSOCKET_NOWAIT);
    //client->SetEventHandler(*this, SOCKET_ID);
    //client->SetNotify(wxSOCKET_INPUT_FLAG);
    //client->Notify(true);
    client->Connect(address);

    if(!client->IsConnected())
    {
        wxMessageBox(_("Not able to connect to JtagHost"));
        delete client;
        client = nullptr;
        return;
    }

    uint8_t buffer[8];
    buffer[0] = IOViewIPCommands::Reset;
    client->Write(buffer, 1);
    client->Write(buffer, 1);

    buffer[0] = IOViewIPCommands::ReadPortWidths;
    client->Write(buffer, 1);

    size_t len = 0;
    size_t tries = 0;
    do
    {
        client->Read(&buffer[len], 8-len);
        len += client->LastCount();
    }while(len < 8 /*&& ++tries < 10000*/);
    /*if(tries>=10000)
    {
        wxMessageBox("too many tries to read");
        delete client;
        client = nullptr;
        return;
    }*/

    NumberOfOutputs = buffer[0] |
                      buffer[1] << 8 |
                      buffer[2] << 16 |
                      buffer[3] << 24 ;

    NumberOfInputs =  buffer[4] |
                      buffer[5] << 8 |
                      buffer[6] << 16 |
                      buffer[7] << 24;

    if(NumberOfOutputs == (256*len)&&NumberOfInputs == (256*len))
    {
        NumberOfOutputs = len;
        NumberOfInputs = len;
    }

    wxMessageBox(wxString::Format(_("Detected %d inputs and %d outputs"), NumberOfInputs, NumberOfOutputs));

    if(protocolObserver)
        protocolObserver->setPortWidths(NumberOfInputs, NumberOfOutputs);

    wxTimer::Start(200);
}

void IOViewProtocol::close()
{
    if(protocolObserver)
        protocolObserver->setPortWidths(0, 0);

    wxTimer::Stop();

    if(client)
        client->Close();

    delete client;
    client = nullptr;
    return;
}

bool IOViewProtocol::isOpen()
{
    return client;
}

void IOViewProtocol::setOutput(uint8_t *buffer, size_t len)
{
    if(!client)return;

    const size_t NumberOfOutputBytes = (NumberOfOutputs+7)/8;

    assert(NumberOfOutputBytes == len);

    uint8_t cmd = IOViewIPCommands::WriteOutput;
    client->Write(&cmd, 1);

    client->Write(buffer, NumberOfOutputBytes);
}

void IOViewProtocol::Notify()//from timer
{
    if(!client)return;

    const size_t NumberOfInputBytes = (NumberOfInputs+7)/8;
    uint8_t buffer[NumberOfInputBytes];
    buffer[0] = IOViewIPCommands::ReadInput;
    client->Write(buffer, 1);

    size_t read = 0;

    do
    {
        client->Read(buffer, NumberOfInputBytes-read);
        read += client->LastCount();
    }while(read < NumberOfInputBytes);

    protocolObserver->visualizeInputs(buffer, NumberOfInputBytes);
}

