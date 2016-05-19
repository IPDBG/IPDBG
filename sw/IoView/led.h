/////////////////////////////////////////////////////////////////////////////
// Name:        led.h
// Purpose:
// Author:      Joachim Buermann
// Id:          $Id$
// Copyright:   (c) 2001 Joachim Buermann
/////////////////////////////////////////////////////////////////////////////

#ifndef __LED_H
#define __LED_H

#include <wx/icon.h>
#include <wx/dcclient.h>
#include <wx/bitmap.h>
#include <wx/timer.h>
#include <wx/window.h>

enum wxLedState {
    wxLED_OFF = 0,
    wxLED_ON,
    wxLED_BLINK
};

enum wxLedColour {
    wxLED_LUCID = 0,
    wxLED_RED,
    wxLED_GREEN,
    wxLED_YELLOW
};


class wxLed : public wxWindow
{
protected:
    // bitmap for double buffering
    wxBitmap* m_bitmap;
    wxIcon* m_icons[2];
    wxLedState m_state;
    int m_blink;
    int m_x;
    int m_y;
protected:
    // protected member functions
    void DrawOnBitmap();
public:
    wxLed(wxWindow* parent,
		wxWindowID id= wxID_ANY,
		const wxPoint& pos = wxPoint(0,0),
		const wxSize& size = wxSize(16,16),
		// red LED is default
        wxLedColour color = wxLED_RED);
    ~wxLed();
    void Blink();
    void OnErase(wxEraseEvent& WXUNUSED(erase)) {
	   Redraw();
    };
    void OnPaint(wxPaintEvent& WXUNUSED(event)) {
	   wxPaintDC dc(this);
	   dc.DrawBitmap(*m_bitmap,0,0,false);
    };
    void OnSizeEvent(wxSizeEvent& event) {
	   wxSize size = event.GetSize();
	   m_x = (size.GetX() - m_icons[0]->GetWidth()) >> 1;
	   m_y = (size.GetY() - m_icons[0]->GetHeight()) >> 1;
	   if(m_x < 0) m_x = 0;
	   if(m_y < 0) m_y = 0;
	   DrawOnBitmap();
    };
    void Redraw() {
	   wxClientDC dc(this);
	   DrawOnBitmap();
	   dc.DrawBitmap(*m_bitmap,0,0,false);
    };
    void SetColour(wxLedColour color);
    void SetState(wxLedState state);
    DECLARE_EVENT_TABLE()
};


#endif
