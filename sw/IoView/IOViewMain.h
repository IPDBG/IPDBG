#ifndef IOVIEWMAIN_H
#define IOVIEWMAIN_H

#ifndef WX_PRECOMP
    #include <wx/wx.h>
#endif

#include "IOViewApp.h"
#include "IOViewObserver.h"
#include "IOViewProtocolI.h"

class IOViewPanel;
class IOViewProtocol;

class IOViewFrame: public wxFrame, public IOViewPanelObserver, public IOViewProtocolObserver
{
public:
    IOViewFrame(wxFrame *frame, const wxString& title);
    ~IOViewFrame();

    virtual void visualizeInputs(uint8_t *buffer, size_t len);
    virtual void setPortWidths(unsigned int inputs, unsigned int outputs);
    virtual void setOutput(uint8_t *buffer, size_t len);

private:


    void OnClose(wxCloseEvent &event);
    void OnQuit(wxCommandEvent &event);
    void OnAbout(wxCommandEvent &event);
    void OnConnect(wxCommandEvent &event);
    void OnUpdateConnect(wxUpdateUIEvent &event);
    void OnDisconnect(wxCommandEvent &event);
    void OnUpdateDisconnect(wxUpdateUIEvent &event);

    IOViewPanel *mainPanel;
    IOViewProtocol *protocol;

    DECLARE_EVENT_TABLE()
};


#endif
