#include "ConnectionDialog.h"

//(*InternalHeaders(ConnectionDialog)
#include <wx/button.h>
#include <wx/intl.h>
#include <wx/string.h>
//*)

#include <wx/valtext.h>

//(*IdInit(ConnectionDialog)
const long ConnectionDialog::ID_STATICTEXT1 = wxNewId();
const long ConnectionDialog::ID_TEXTCTRL1 = wxNewId();
const long ConnectionDialog::ID_STATICTEXT2 = wxNewId();
const long ConnectionDialog::ID_TEXTCTRL2 = wxNewId();
//*)

BEGIN_EVENT_TABLE(ConnectionDialog,wxDialog)
    //(*EventTable(ConnectionDialog)
    //*)
    END_EVENT_TABLE()

ConnectionDialog::ConnectionDialog(wxWindow* parent, wxString *addr, wxString *port, wxWindowID id, const wxPoint& pos, const wxSize& size)
{
    //(*Initialize(ConnectionDialog)
    wxBoxSizer* BoxSizer1;
    wxBoxSizer* BoxSizer2;
    wxBoxSizer* BoxSizer3;
    wxBoxSizer* BoxSizer4;
    wxStdDialogButtonSizer* StdDialogButtonSizer1;

    Create(parent, id, _("Connect to JtagHost"), wxDefaultPosition, wxDefaultSize, wxDEFAULT_DIALOG_STYLE, _T("id"));
    SetClientSize(wxDefaultSize);
    Move(wxDefaultPosition);
    BoxSizer1 = new wxBoxSizer(wxVERTICAL);
    BoxSizer2 = new wxBoxSizer(wxHORIZONTAL);
    BoxSizer3 = new wxBoxSizer(wxVERTICAL);
    StaticText1 = new wxStaticText(this, ID_STATICTEXT1, _("Host:"), wxDefaultPosition, wxDefaultSize, 0, _T("ID_STATICTEXT1"));
    BoxSizer3->Add(StaticText1, 0, wxALL|wxALIGN_LEFT, 5);
    textCtrlIp = new wxTextCtrl(this, ID_TEXTCTRL1, _("127.0.0.1"), wxDefaultPosition, wxDefaultSize, 0, wxTextValidator(wxFILTER_ASCII, addr), _T("ID_TEXTCTRL1"));
    textCtrlIp->SetToolTip(_("IP address or hostname of JtagHost"));
    BoxSizer3->Add(textCtrlIp, 1, wxALL|wxEXPAND, 5);
    BoxSizer2->Add(BoxSizer3, 3, wxEXPAND, 5);
    BoxSizer4 = new wxBoxSizer(wxVERTICAL);
    StaticText2 = new wxStaticText(this, ID_STATICTEXT2, _("Port:"), wxDefaultPosition, wxDefaultSize, 0, _T("ID_STATICTEXT2"));
    BoxSizer4->Add(StaticText2, 0, wxALL|wxALIGN_LEFT, 5);
    textCtrlPort = new wxTextCtrl(this, ID_TEXTCTRL2, _("4243"), wxDefaultPosition, wxDefaultSize, 0, wxTextValidator(wxFILTER_DIGITS, port), _T("ID_TEXTCTRL2"));
    textCtrlPort->SetToolTip(_("TCP port of JtagHost connected to IO ViewController (default: 4243)"));
    BoxSizer4->Add(textCtrlPort, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    BoxSizer2->Add(BoxSizer4, 1, wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    BoxSizer1->Add(BoxSizer2, 1, wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    StdDialogButtonSizer1 = new wxStdDialogButtonSizer();
    StdDialogButtonSizer1->AddButton(new wxButton(this, wxID_OK, wxEmptyString));
    StdDialogButtonSizer1->AddButton(new wxButton(this, wxID_CANCEL, wxEmptyString));
    StdDialogButtonSizer1->Realize();
    BoxSizer1->Add(StdDialogButtonSizer1, 0, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    SetSizer(BoxSizer1);
    BoxSizer1->Fit(this);
    BoxSizer1->SetSizeHints(this);
    //*)
}

ConnectionDialog::~ConnectionDialog()
{
    //(*Destroy(ConnectionDialog)
    //*)
}

