///////////////////////////////////////////////////////////////////////////
// C++ code generated with wxFormBuilder (version Jun 17 2015)
// http://www.wxformbuilder.org/
//
// PLEASE DO "NOT" EDIT THIS FILE!
///////////////////////////////////////////////////////////////////////////
#include <wx/msgdlg.h>

#include "IOViewPanel.h"
#include "led.h"

///////////////////////////////////////////////////////////////////////////

#define IPDBG_IOVIEW_VALID_MASK 0xA00


BEGIN_EVENT_TABLE(IOViewPanel, wxPanel)
    EVT_CHECKBOX(wxID_ANY, IOViewPanel::onCheckBox)
END_EVENT_TABLE()


IOViewPanel::IOViewPanel( wxWindow* parent, IOViewPanelObserver *obs ):
    wxPanel( parent, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL ),
    NumberOfInputs(0),
    NumberOfOutputs(0),
    observer(obs)
{
    mainSizer = new wxBoxSizer( wxVERTICAL );

    sbLedsSizer = new wxStaticBoxSizer( new wxStaticBox( this, wxID_ANY, wxT("Inputs") ), wxHORIZONTAL );
    mainSizer->Add( sbLedsSizer, 1, wxEXPAND, 5 );

    sbCBoxesSizer = new wxStaticBoxSizer( new wxStaticBox( this, wxID_ANY, wxT("Outputs") ), wxHORIZONTAL );
    mainSizer->Add( sbCBoxesSizer, 1, wxEXPAND, 5 );

    this->SetSizer( mainSizer );
    this->Layout();
}
//////////////////////////////////////////////////////////////////////////////????????????????????????????????????
IOViewPanel::~IOViewPanel()
{
}


void IOViewPanel::onCheckBox(wxCommandEvent& event)
{
    const size_t NumberOfOutputBytes = (NumberOfOutputs+7)/8;
    uint8_t *buffer = new uint8_t[NumberOfOutputBytes];

    for(size_t idx = 0 ; idx < NumberOfOutputBytes ; ++idx)
        buffer[idx] = 0;

    for (size_t idx = 0 ; idx < NumberOfOutputs ; ++idx)
        if(checkBoxes[NumberOfOutputs-1-idx]->IsChecked())
            buffer[idx >> 3] |= (0x01 << (idx & 0x07));

    if(observer)
        observer->setOutput(buffer, NumberOfOutputBytes);

    delete[] buffer;
}

void IOViewPanel::setLeds(uint8_t *buffer, size_t len)
{
    assert(NumberOfInputs <= len*8);

    for (size_t idx = 0 ; idx < NumberOfInputs ; ++idx)
    {
        if (buffer[idx >> 3] & (0x01 << (idx & 0x07)))
            leds[NumberOfInputs-1-idx]->SetState(awxLED_ON);
        else
            leds[NumberOfInputs-1-idx]->SetState(awxLED_OFF);
    }
}

void IOViewPanel::setOutputs(unsigned int outputs)
{
    for(size_t i = 0 ; i < checkBoxes.size() ; ++i)
        delete checkBoxes[i];
    checkBoxes.clear();

    NumberOfOutputs = outputs;

    for(uint32_t i = 0 ; i < NumberOfOutputs ; ++i)
    {
        wxString str = wxString::Format(_T("P%d"), NumberOfOutputs-1-i);
        wxCheckBox *checkBox = new wxCheckBox( this, wxID_ANY, str, wxDefaultPosition, wxDefaultSize, 0 );
        sbCBoxesSizer->Add( checkBox, 0, wxALL, 5 );
        checkBoxes.push_back(checkBox);
    }

    this->SetSizer( mainSizer );
    this->Layout();
}

void IOViewPanel::setInputs(unsigned int inputs)
{
    for(size_t i = 0 ; i < leds.size() ; ++i)
        delete leds[i];
    leds.clear();

    NumberOfInputs = inputs;

    for(size_t i = 0 ; i < NumberOfInputs ; ++i)
    {
        awxLed *led = new awxLed(this, wxID_ANY);
        sbLedsSizer->Add( led, 0, wxALL, 5 );
        led->SetColour(awxLED_RED);
        leds.push_back(led);
    }

    this->SetSizer( mainSizer );
    this->Layout();
}


