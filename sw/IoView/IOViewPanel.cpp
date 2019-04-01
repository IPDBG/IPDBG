#include <wx/msgdlg.h>
#include <string>

#include "IOViewPanel.h"
#include "led.h"



BEGIN_EVENT_TABLE(IOViewPanel, wxPanel)
    EVT_CHECKBOX(wxID_ANY, IOViewPanel::onCheckBox)
END_EVENT_TABLE()


IOViewPanel::IOViewPanel( wxWindow* parent, IOViewPanelObserver *obs ):
    wxPanel( parent, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL ),
    numberOfInputs_(0),
    numberOfOutputs_(0),
    observer_(obs),
    inputText_(nullptr)
{
    mainSizer_ = new wxBoxSizer( wxVERTICAL );

    wxStaticBoxSizer *sbInputsSizer = new wxStaticBoxSizer( wxVERTICAL, this, "Inputs" );
    mainSizer_->Add( sbInputsSizer, 1, wxEXPAND, 5 );

    bInputLedsSizer_ = new wxBoxSizer( wxHORIZONTAL );
    sbInputsSizer->Add( bInputLedsSizer_, 1, wxEXPAND, 5 );

    bInputTextSizer_ = new wxBoxSizer( wxHORIZONTAL );
    sbInputsSizer->Add( bInputTextSizer_, 1, wxEXPAND, 5 );

    sbOutputsSizer_ = new wxStaticBoxSizer( wxHORIZONTAL, this, "Outputs" );
    mainSizer_->Add( sbOutputsSizer_, 1, wxEXPAND, 5 );

    this->SetSizer( mainSizer_ );
    this->Layout();
}

IOViewPanel::~IOViewPanel()
{
}

void IOViewPanel::onCheckBox(wxCommandEvent& event)
{
    const size_t numberOfOutputBytes = (numberOfOutputs_+7)/8;
    uint8_t *buffer = new uint8_t[numberOfOutputBytes];

    for(size_t idx = 0 ; idx < numberOfOutputBytes ; ++idx)
        buffer[idx] = 0;

    for (size_t idx = 0 ; idx < numberOfOutputs_ ; ++idx)
        if(outputCheckBoxes_[numberOfOutputs_-1-idx]->IsChecked())
            buffer[idx >> 3] |= (0x01 << (idx & 0x07));

    if(observer_)
        observer_->setOutput(buffer, numberOfOutputBytes);

    delete[] buffer;
}

void IOViewPanel::setLeds(uint8_t *buffer, size_t len)
{
    assert(numberOfInputs_ <= len*8);

    for (size_t idx = 0 ; idx < numberOfInputs_ ; ++idx)
    {
        if (buffer[idx >> 3] & (0x01 << (idx & 0x07)))
            inputLeds_[numberOfInputs_-1-idx]->SetState(awxLED_ON);
        else
            inputLeds_[numberOfInputs_-1-idx]->SetState(awxLED_OFF);
    }

    static std::string oldText("");
    std::string text;

    for(size_t idx=0; idx<len; idx++)
    {
        char hexString[3];
        uint8_t validMask=0xff;
        // If numberOfInputs is not a multiple of 8 -> supress surplus bits
        if((idx == 0) && ((numberOfInputs_ % 8) != 0))
            validMask = static_cast<uint8_t>(round(pow(2.0, static_cast<double>(numberOfInputs_ % 8)))) - 1;
        sprintf(hexString, "%02x", buffer[len-1-idx]&validMask);
        text.append(hexString);
    }
    if(text.compare(oldText) != 0)
    {
        // Update value only if it has changed. This prevents from flicker.
        inputText_->Clear();
        *inputText_ << "0x";
        *inputText_ << text;
        oldText.assign(text);
    }
}

void IOViewPanel::initOutputs(unsigned int numberOfOutputs)
{
    for(size_t i = 0 ; i < outputCheckBoxes_.size() ; ++i)
        delete outputCheckBoxes_[i];
    outputCheckBoxes_.clear();

    numberOfOutputs_ = numberOfOutputs;

    for(uint32_t i = 0 ; i < numberOfOutputs_ ; ++i)
    {
        wxString str = wxString::Format(_T("P%d"), numberOfOutputs_-1-i);
        wxCheckBox *checkBox = new wxCheckBox( this, wxID_ANY, str, wxDefaultPosition, wxDefaultSize, 0 );
        sbOutputsSizer_->Add( checkBox, 0, wxALL, 5 );
        outputCheckBoxes_.push_back(checkBox);
    }

    this->SetSizer( mainSizer_ );
    this->Layout();
}

void IOViewPanel::initInputs(unsigned int numberOfInputs)
{
    for(size_t i = 0 ; i < inputLeds_.size() ; ++i)
        delete inputLeds_[i];
    inputLeds_.clear();

    if(inputText_)
    {
        delete inputText_;
        inputText_ = nullptr;
    }

    numberOfInputs_ = numberOfInputs;

    for(size_t i = 0 ; i < numberOfInputs_ ; ++i)
    {
        awxLed *led = new awxLed(this, wxID_ANY);
        bInputLedsSizer_->Add( led, 0, wxALL, 5 );
        led->SetColour(awxLED_RED);
        inputLeds_.push_back(led);
    }

    if(numberOfInputs > 0)
    {
        wxTextCtrl *text = new wxTextCtrl(this, wxID_ANY);
        bInputTextSizer_->Add(text, 0, wxALL, 5);
        inputText_ = text;
    }

    this->SetSizer( mainSizer_ );
    this->Layout();
}
