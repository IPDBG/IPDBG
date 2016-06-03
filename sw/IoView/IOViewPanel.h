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

#include <cstdint>
///////////////////////////////////////////////////////////////////////////
#include <vector>

///////////////////////////////////////////////////////////////////////////////
/// Class IOViewPanel
///////////////////////////////////////////////////////////////////////////////

class wxLed;
struct URJ_CHAIN;

class IOViewPanel : public wxPanel
{
	private:
	    void onCheckBox(wxCommandEvent& event);
	    void onTimer(wxTimerEvent& event);

	     wxTimer timer;
    private:
        URJ_CHAIN *chain;

        enum IOViewIPCommands:uint8_t
        {
            INOUT_Auslesen = 0xAB,
            ReadInput = 0xAA,
            WriteOutput = 0xBB,
            Reset = 0xee,
            Escape = 0x55
        };
        unsigned int NumberOfInputs;
        unsigned int NumberOfOutputs;

        wxSocketClient *client_;
        enum {
            SOCKET_ID = 10,
        };


	protected:
		std::vector<wxCheckBox*> checkBoxes;
		std::vector<wxLed*> leds;


	public:

		IOViewPanel( wxWindow* parent, wxWindowID id = wxID_ANY, const wxPoint& pos = wxDefaultPosition, const wxSize& size = wxDefaultSize, long style = wxTAB_TRAVERSAL );
		~IOViewPanel();

        DECLARE_EVENT_TABLE()

};

#endif //__NONAME_H__
