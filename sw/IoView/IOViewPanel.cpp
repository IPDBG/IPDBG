///////////////////////////////////////////////////////////////////////////
// C++ code generated with wxFormBuilder (version Jun 17 2015)
// http://www.wxformbuilder.org/
//
// PLEASE DO "NOT" EDIT THIS FILE!
///////////////////////////////////////////////////////////////////////////
#include <wx/msgdlg.h>

#include "IOViewPanel.h"
#include "led.h"

#include "jtaghost.h"

///////////////////////////////////////////////////////////////////////////

BEGIN_EVENT_TABLE(IOViewPanel, wxPanel)
    EVT_CHECKBOX(wxID_ANY, IOViewPanel::onCheckBox)
    EVT_TIMER(wxID_ANY, IOViewPanel::onTimer)
END_EVENT_TABLE()

IOViewPanel::IOViewPanel( wxWindow* parent, wxWindowID id, const wxPoint& pos, const wxSize& size, long style ):
    wxPanel( parent, id, pos, size, style ),
    timer(this)
{

    chain = ipdbgJtagAllocChain();
    if(!chain)
    {
        wxMessageBox(_T("failed to allocate chain"));
        return;
    }

    if(ipdbgJtagInit(chain) != 0 )
    {
        wxMessageBox(_T("failed to initialize chain"));
        return;
    }

    uint8_t buffer[8];
    buffer[0] = IOViewIPCommands::Reset;
    ipdbgJtagWrite(chain, buffer, 1);
    ipdbgJtagWrite(chain, buffer, 1);


    buffer[0] = IOViewIPCommands::INOUT_Auslesen;
    ipdbgJtagWrite(chain, buffer, 1);

    int readBytes  = 0;
    while(readBytes != 8)
    {
        printf("reading (%d)\n", readBytes);
        readBytes +=  ipdbgJtagRead(chain, &buffer[readBytes], 8-readBytes);
    }


    NumberOfOutputs = buffer[0] |
                      buffer[1] << 8 |
                      buffer[2] << 16 |
                      buffer[3] << 24 ;

    NumberOfInputs =  buffer[4] |
                      buffer[5] << 8 |
                      buffer[6] << 16 |
                      buffer[7] << 24;
    //NumberOfInputs = 8;
    //NumberOfOutputs = 8;

	wxBoxSizer* bSizer;
	bSizer = new wxBoxSizer( wxVERTICAL );

	wxStaticBoxSizer* sbSizer1;
	sbSizer1 = new wxStaticBoxSizer( new wxStaticBox( this, wxID_ANY, wxT("Inputs") ), wxHORIZONTAL );

	for(int i = 0 ; i < NumberOfInputs ; ++i)
    {
        wxLed *led = new wxLed(this);
        sbSizer1->Add( led, 0, wxALL, 5 );
        led->SetColour(wxLED_RED);
        if(i%2)
            led->SetState(wxLED_ON);
        leds.push_back(led);
    }

	bSizer->Add( sbSizer1, 1, wxEXPAND, 5 );

	wxStaticBoxSizer* sbSizer2;
	sbSizer2 = new wxStaticBoxSizer( new wxStaticBox( this, wxID_ANY, wxT("Outputs") ), wxHORIZONTAL );

	for(int i = 0 ; i < NumberOfOutputs ; ++i)
    {
        wxString str = wxString::Format(_T("P%d"), NumberOfOutputs-1-i);
        wxCheckBox *checkBox = new wxCheckBox( this, wxID_ANY, str, wxDefaultPosition, wxDefaultSize, 0 );
        sbSizer2->Add( checkBox, 0, wxALL, 5 );
        checkBoxes.push_back(checkBox);
    }

	bSizer->Add( sbSizer2, 1, wxEXPAND, 5 );

	this->SetSizer( bSizer );
	this->Layout();

	timer.Start(200);
}

IOViewPanel::~IOViewPanel()
{
    if(chain)
        ipdbgJtagClose(chain);
}


void IOViewPanel::onCheckBox(wxCommandEvent& event)
{
    //wxMessageBox(_T("CheckBoxClicked"));
    const size_t NumberOfOutputBytes = (NumberOfOutputs+7)/8;
    uint8_t buffer[NumberOfOutputBytes];

    buffer[0] = IOViewIPCommands::WriteOutput;
    ipdbgJtagWrite(chain, buffer, 1);

    for(size_t idx = 0 ; idx < NumberOfOutputBytes ; ++idx)
        buffer[idx] = 0;

    for (size_t idx = 0 ; idx < NumberOfOutputs ; ++idx)
        if(checkBoxes[NumberOfOutputs-1-idx]->IsChecked())
            buffer[(idx & 0xf8)>>3] |= (0x01 << (idx & 0x07));


    ipdbgJtagWrite(chain, buffer, NumberOfOutputBytes);

}

void IOViewPanel::onTimer(wxTimerEvent& event)
{
    //wxMessageBox(_T("timeout expired"));
    const size_t NumberOfInputBytes = (NumberOfInputs+7)/8;
    uint8_t buffer[NumberOfInputBytes];
    buffer[0] = IOViewIPCommands::ReadInput;
    ipdbgJtagWrite(chain, buffer, 1);

//    int readBytes  = 0;
//    while(readBytes != NumberOfInputBytes)
//    {
//        printf("reading (%d)\n", readBytes);
//        readBytes += ;
//    }
    ipdbgJtagRead(chain, buffer, NumberOfInputBytes);
    //ipdbgJtagRead(chain, buffer, 1);


    for (size_t idx = 0 ; idx < NumberOfInputs ; ++idx)
    {

        printf("buf0: %x\n", buffer[0]);

        if (buffer[idx >> 3] & (0x01 << (idx & 0x07)))
            leds[NumberOfInputs-1-idx]->SetState(wxLED_ON);
        else
            leds[NumberOfInputs-1-idx]->SetState(wxLED_OFF);

    }

}



