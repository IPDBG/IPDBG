///////////////////////////////////////////////////////////////////////////
// C++ code generated with wxFormBuilder (version Jun 17 2015)
// http://www.wxformbuilder.org/
//
// PLEASE DO "NOT" EDIT THIS FILE!
///////////////////////////////////////////////////////////////////////////

#ifndef __NONAME_H__
#define __NONAME_H__

#include <wx/artprov.h>
#include <wx/xrc/xmlres.h>
#include <wx/string.h>
#include <wx/sizer.h>
#include <wx/statbox.h>
#include <wx/gdicmn.h>
#include <wx/checkbox.h>
#include <wx/font.h>
#include <wx/colour.h>
#include <wx/settings.h>
#include <wx/panel.h>
#include <wx/socket.h>

#include "IOViewObserver.h"

#include <cstdint>
///////////////////////////////////////////////////////////////////////////
#include <vector>

///////////////////////////////////////////////////////////////////////////////
/// Class IOViewPanel
///////////////////////////////////////////////////////////////////////////////

class awxLed;

class IOViewPanel : public wxPanel
{
public:

    IOViewPanel( wxWindow* parent, IOViewPanelObserver *obs);
    ~IOViewPanel();

    void setLeds(uint8_t *buffer, size_t len);
    void setOutputs(unsigned int outputs);
    void setInputs(unsigned int inputs);

private:
    void onCheckBox(wxCommandEvent& event);

    uint32_t NumberOfInputs;
    uint32_t NumberOfOutputs;
    IOViewPanelObserver *observer;

    wxBoxSizer* mainSizer;
    wxStaticBoxSizer* sbLedsSizer;
    wxStaticBoxSizer* sbCBoxesSizer;

protected:
    std::vector<wxCheckBox*> checkBoxes;
    std::vector<awxLed*> leds;



    DECLARE_EVENT_TABLE()

};

#endif //__NONAME_H__
