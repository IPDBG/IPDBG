#include <wx/msgdlg.h>
#include <string>

#include "IOViewPanel.h"
#include "led.h"

BEGIN_EVENT_TABLE(IOViewPanel, wxPanel)
    EVT_CHECKBOX(wxID_ANY, IOViewPanel::onCheckBox)
    EVT_TEXT_ENTER(wxID_ANY, IOViewPanel::OnTextEner)
END_EVENT_TABLE()


IOViewPanel::IOViewPanel( wxWindow* parent, IOViewPanelObserver *obs ):
    wxPanel( parent, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL ),
    numberOfInputs_(0),
    numberOfOutputs_(0),
    observer_(obs),
    inputText_(nullptr),
    outputText_(nullptr)
{
    mainSizer_ = new wxBoxSizer(wxVERTICAL);

    wxStaticBoxSizer *sbInputsSizer = new wxStaticBoxSizer(wxVERTICAL, this, "Inputs");
    mainSizer_->Add(sbInputsSizer, 1, wxEXPAND, 5);

    bInputLedsSizer_ = new wxBoxSizer(wxHORIZONTAL);
    sbInputsSizer->Add(bInputLedsSizer_, 1, wxEXPAND, 5);

    bInputTextSizer_ = new wxBoxSizer(wxHORIZONTAL);
    sbInputsSizer->Add(bInputTextSizer_, 1, wxEXPAND, 5);

    wxStaticBoxSizer *sbOutputsSizer = new wxStaticBoxSizer(wxVERTICAL, this, "Outputs");
    mainSizer_->Add(sbOutputsSizer, 1, wxEXPAND, 5);

    bOutputCheckboxSizer_ = new wxBoxSizer(wxHORIZONTAL);
    sbOutputsSizer->Add(bOutputCheckboxSizer_, 1, wxEXPAND, 5);

    bOutputTextSizer_ = new wxBoxSizer(wxHORIZONTAL);
    sbOutputsSizer->Add(bOutputTextSizer_, 1, wxEXPAND, 5);

    this->SetSizer(mainSizer_);
    this->Layout();
}

void IOViewPanel::onCheckBox(wxCommandEvent &)
{
    const size_t numberOfOutputBytes = (numberOfOutputs_ + 7) / 8;
    uint8_t *buffer = new uint8_t[numberOfOutputBytes];

    for (size_t idx = 0 ; idx < numberOfOutputBytes ; ++idx)
        buffer[idx] = 0;

    for (size_t idx = 0 ; idx < numberOfOutputs_ ; ++idx)
        if (outputCheckBoxes_[numberOfOutputs_ - 1 - idx]->IsChecked())
            buffer[idx >> 3] |= (0x01 << (idx & 0x07));

    wxString str{""};
    for (size_t idx = 0 ; idx < numberOfOutputBytes ; ++idx)
    {
        uint32_t d = buffer[idx];
        str = wxString::Format("%02x", d) + str;
    }
    str = "0x" + str;
    outputText_->SetValue(str);

    if (observer_)
        observer_->setOutput(buffer, numberOfOutputBytes);

    delete[] buffer;
}

void IOViewPanel::OnTextEner(wxCommandEvent &e)
{
    const size_t numberOfOutputBytes = (numberOfOutputs_ + 7) / 8;
    uint8_t *buffer = new uint8_t[numberOfOutputBytes];

    wxString txt = outputText_->GetValue();
    if (txt.StartsWith("0x"))
        txt = txt.substr(2);

    while (txt.length() < 2 * numberOfOutputBytes)
        txt = "0" + txt;

    bool failed = false;
    if (txt.length() > 2 * numberOfOutputBytes)
        failed = true;
    else
        for (size_t idx = 0 ; idx < numberOfOutputBytes ; ++idx)
        {
            buffer[idx] = 0;
            wxString ls = txt.substr(txt.length() - 2);
            long temp = 0;
            if (ls.ToLong(&temp,16))
                buffer[idx] = temp & 0xff;
            else
            {
                failed = true;
                break;
            }
            txt = txt.substr(0, txt.length() - 2);
        }
    if (failed)
    {
        for (size_t idx = 0 ; idx < numberOfOutputBytes ; ++idx)
            buffer[idx] = 0;

        for (size_t idx = 0 ; idx < numberOfOutputs_ ; ++idx)
            if (outputCheckBoxes_[numberOfOutputs_ - 1 - idx]->IsChecked())
                buffer[idx >> 3] |= (0x01 << (idx & 0x07));
    }
    wxString str{""};
    for (size_t idx = 0 ; idx < numberOfOutputBytes ; ++idx)
    {
        uint32_t d = buffer[idx];
        str = wxString::Format("%02x", d) + str;
    }
    str = "0x" + str;
    outputText_->SetValue(str);

    if (!failed)
    {
        for (size_t idx = 0 ; idx < numberOfOutputs_ ; ++idx)
            outputCheckBoxes_[numberOfOutputs_ - 1 - idx]->SetValue(
                buffer[idx >> 3] & (0x01 << (idx & 0x07))
            );
        if (observer_)
            observer_->setOutput(buffer, numberOfOutputBytes);
    }

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

    for (size_t idx=0; idx<len; idx++)
    {
        char hexString[3];
        uint8_t validMask=0xff;
        // If numberOfInputs is not a multiple of 8 -> supress surplus bits
        if((idx == 0) && ((numberOfInputs_ % 8) != 0))
            validMask = static_cast<uint8_t>(round(pow(2.0, static_cast<double>(numberOfInputs_ % 8)))) - 1;
        sprintf(hexString, "%02x", buffer[len-1-idx]&validMask);
        text.append(hexString);
    }
    if (text.compare(oldText) != 0)
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
    for (size_t i = 0 ; i < outputCheckBoxes_.size() ; ++i)
        delete outputCheckBoxes_[i];
    outputCheckBoxes_.clear();

    if (outputText_)
    {
        delete outputText_;
        outputText_ = nullptr;
    }

    numberOfOutputs_ = numberOfOutputs;

    for (uint32_t i = 0 ; i < numberOfOutputs_ ; ++i)
    {
        wxString str = wxString::Format(_T("P%d"), numberOfOutputs_- 1 - i);
        wxCheckBox *checkBox = new wxCheckBox(this, wxID_ANY, str, wxDefaultPosition, wxDefaultSize, 0);
        bOutputCheckboxSizer_->Add(checkBox, 0, wxALL, 5);
        outputCheckBoxes_.push_back(checkBox);
    }

    if (numberOfOutputs > 0)
    {
        wxString str{"0x"};
        for (size_t k = 0 ; k < (numberOfOutputs + 3) / 4 ; ++k)
            str += "0";
        outputText_ = new wxTextCtrl(this, wxID_ANY, str, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
        bOutputTextSizer_->Add(outputText_, 0, wxALL, 5);
    }

    this->SetSizer(mainSizer_);
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
        inputText_ = new wxTextCtrl(this, wxID_ANY);
        inputText_->SetEditable(false);
        bInputTextSizer_->Add(inputText_, 0, wxALL, 5);
    }

    this->SetSizer(mainSizer_);
    this->Layout();
}
