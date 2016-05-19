/////////////////////////////////////////////////////////////////////////////
// Name:        led.cpp
// Purpose:
// Author:      Joachim Buermann
// Id:          $Id$
// Copyright:   (c) 2001 Joachim Buermann
/////////////////////////////////////////////////////////////////////////////

#include "led.h"

#include "leds.xpm"

#include <wx/dcmemory.h>
#include <wx/settings.h>

BEGIN_EVENT_TABLE(wxLed, wxWindow)
    EVT_ERASE_BACKGROUND(wxLed::OnErase)
    EVT_PAINT(wxLed::OnPaint)
    EVT_SIZE(wxLed::OnSizeEvent)
END_EVENT_TABLE()

wxLed::wxLed(wxWindow* parent,
			wxWindowID id,
			const wxPoint& pos,
			const wxSize& size,
			wxLedColour color) :
    wxWindow(parent,id,pos,size,wxNO_FULL_REPAINT_ON_RESIZE)
{
    m_state = wxLED_OFF;
    m_bitmap = new wxBitmap(16,16);
    m_blink = 0;
    m_x = m_y = 0;

    m_icons[wxLED_OFF] = new wxIcon(led_off_xpm);
    m_icons[wxLED_ON] = NULL;
    SetColour(color);

};

wxLed::~wxLed()
{
    delete m_bitmap;
    delete m_icons[wxLED_OFF];
    delete m_icons[wxLED_ON];
};

void wxLed::Blink()
{
    m_blink ^= 1;
    Redraw();
};

void wxLed::DrawOnBitmap()
{
    wxSize s = GetClientSize();
    if((m_bitmap->GetWidth() != s.GetWidth()) ||
	  (m_bitmap->GetHeight() != s.GetHeight())) {
	   m_bitmap->Create(s.x,s.y);
    }
    wxMemoryDC dc;
    dc.SelectObject(*m_bitmap);

    wxBrush brush(wxSystemSettings::GetColour(wxSYS_COLOUR_BTNFACE),
				  wxSOLID);
    dc.SetBackground(brush);
    dc.Clear();

    if(m_state == wxLED_BLINK) dc.DrawIcon(*m_icons[m_blink],m_x,m_y);
    else dc.DrawIcon(*m_icons[m_state & 1],m_x,m_y);

    dc.SelectObject(wxNullBitmap);
};

void wxLed::SetColour(wxLedColour color)
{
    if(m_icons[wxLED_ON]) delete m_icons[wxLED_ON];
    switch(color) {
    case wxLED_GREEN:
	   m_icons[wxLED_ON] = new wxIcon(led_green_xpm);
	   break;
    case wxLED_YELLOW:
	   m_icons[wxLED_ON] = new wxIcon(led_yellow_xpm);
	   break;
    default:
	   m_icons[wxLED_ON] = new wxIcon(led_red_xpm);
    }
};

void wxLed::SetState(wxLedState state)
{
    m_state = state;
    Redraw();
};
