/***************************************************************
 * Name:      IOViewMain.cpp
 * Purpose:   Code for Application Frame
 * Author:     ()
 * Created:   2016-04-12
 * Copyright:  ()
 * License:
 **************************************************************/

#ifdef WX_PRECOMP
#include "wx_pch.h"
#endif

#ifdef __BORLANDC__
#pragma hdrstop
#endif //__BORLANDC__

#include "IOViewMain.h"
#include "IOViewPanel.h"
#include "IOViewProtocol.h"

namespace{
    int idMenuQuit = wxNewId();
    int idMenuAbout = wxNewId();
    int idMenuConnect = wxNewId();
    int idMenuDisconnect = wxNewId();
}

BEGIN_EVENT_TABLE(IOViewFrame, wxFrame)
    EVT_CLOSE(IOViewFrame::OnClose)
    EVT_MENU(idMenuQuit, IOViewFrame::OnQuit)
    EVT_MENU(idMenuAbout, IOViewFrame::OnAbout)
    EVT_MENU(idMenuConnect, IOViewFrame::OnConnect)
    EVT_UPDATE_UI(idMenuConnect, IOViewFrame::OnUpdateConnect)
    EVT_MENU(idMenuDisconnect, IOViewFrame::OnDisconnect)
    EVT_UPDATE_UI(idMenuDisconnect, IOViewFrame::OnUpdateDisconnect)
END_EVENT_TABLE()


IOViewFrame::IOViewFrame(wxFrame *frame, const wxString& title)
    : wxFrame(frame, -1, title)
{
    // create a menu bar
    wxMenuBar* mbar = new wxMenuBar();
    wxMenu* fileMenu = new wxMenu(_T(""));
    fileMenu->Append(idMenuQuit, _("&Quit\tAlt-F4"), _("Quit the application"));
    mbar->Append(fileMenu, _("&File"));

    wxMenu* ioviewMenu = new wxMenu(_T(""));
    ioviewMenu->Append(idMenuConnect, _("Connect"), _(""));
    ioviewMenu->Append(idMenuDisconnect, _("Disconnect"), _(""));
    mbar->Append(ioviewMenu, "IoView-IP");

    wxMenu* helpMenu = new wxMenu(_T(""));
    helpMenu->Append(idMenuAbout, _("&About\tF1"), _("Show info about this application"));
    mbar->Append(helpMenu, _("&Help"));

    SetMenuBar(mbar);
    // create a status bar with some information about the used wxWidgets version
    CreateStatusBar(2);
    SetStatusText(_("Hello to I/O-View"),0);
    SetStatusText(_("Disconnected"), 1);

    protocol = new IOViewProtocol(this);

    mainPanel = new IOViewPanel(this, this);

	wxBoxSizer* bSizer;
	bSizer = new wxBoxSizer( wxVERTICAL );

	bSizer->Add( mainPanel, 1, wxEXPAND, 5 );

	this->SetSizer( bSizer );
	this->Layout();
}

IOViewFrame::~IOViewFrame()
{
}

void IOViewFrame::OnClose(wxCloseEvent &event)
{
    Destroy();
}

void IOViewFrame::OnQuit(wxCommandEvent &event)
{
    Destroy();
}

void IOViewFrame::OnAbout(wxCommandEvent &event)
{
    wxMessageBox(_("I/O-View"), _("Welcome to..."));
}

void IOViewFrame::visualizeInputs(uint8_t *buffer, size_t len)
{
    mainPanel->setLeds(buffer, len);
}

void IOViewFrame::setPortWidths(unsigned int inputs, unsigned int outputs)
{
    mainPanel->setInputs(inputs);
    mainPanel->setOutputs(outputs);
}

void IOViewFrame::setOutput(uint8_t *buffer, size_t len)
{
    protocol->setOutput(buffer, len);
}

void IOViewFrame::OnConnect(wxCommandEvent &event)
{
    if(!protocol->isOpen())
    {
        protocol->open();
    }
}

void IOViewFrame::OnUpdateConnect(wxUpdateUIEvent &event)
{
    event.Enable(!protocol->isOpen());
}

void IOViewFrame::OnDisconnect(wxCommandEvent &event)
{
    if(protocol->isOpen())
    {
        protocol->close();
    }
}

void IOViewFrame::OnUpdateDisconnect(wxUpdateUIEvent &event)
{
    event.Enable(protocol->isOpen());
}
