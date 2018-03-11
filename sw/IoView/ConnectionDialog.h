#ifndef CONNECTIONDIALOG_H
#define CONNECTIONDIALOG_H

//(*Headers(ConnectionDialog)
#include <wx/dialog.h>
#include <wx/sizer.h>
#include <wx/stattext.h>
#include <wx/textctrl.h>
//*)

class ConnectionDialog: public wxDialog
{
public:

    ConnectionDialog(wxWindow* parent, wxString *addr, wxString *port, wxWindowID id=wxID_ANY, const wxPoint& pos=wxDefaultPosition, const wxSize& size=wxDefaultSize);
    virtual ~ConnectionDialog();

    //(*Declarations(ConnectionDialog)
    wxStaticText* StaticText1;
    wxStaticText* StaticText2;
    wxTextCtrl* textCtrlIp;
    wxTextCtrl* textCtrlPort;
    //*)

protected:

    //(*Identifiers(ConnectionDialog)
    static const long ID_STATICTEXT1;
    static const long ID_TEXTCTRL1;
    static const long ID_STATICTEXT2;
    static const long ID_TEXTCTRL2;
    //*)

private:

    //(*Handlers(ConnectionDialog)
    //*)

    DECLARE_EVENT_TABLE()
};

#endif
