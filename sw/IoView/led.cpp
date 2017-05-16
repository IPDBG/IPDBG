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

BEGIN_EVENT_TABLE(awxLed, wxWindow)
    EVT_ERASE_BACKGROUND(awxLed::OnErase)
    EVT_PAINT(awxLed::OnPaint)
    EVT_SIZE(awxLed::OnSizeEvent)
END_EVENT_TABLE()

awxLed::awxLed(wxWindow* parent,
			wxWindowID id,
			const wxPoint& pos,
			const wxSize& size,
			awxLedColour color) :
    wxWindow(parent,id,pos,size,wxNO_FULL_REPAINT_ON_RESIZE)
{
    m_state = awxLED_OFF;
    m_bitmap = new wxBitmap(16,16);
    m_timer = NULL;
    m_blink = 0;
    m_x = m_y = 0;

    m_icons[awxLED_OFF] = new wxIcon(led_off_xpm);
    m_icons[awxLED_ON] = NULL;
    SetColour(color);

    m_timer = new BlinkTimer(this);
};

awxLed::~awxLed()
{
    if(m_timer) {
	   m_timer->Stop();
	   delete m_timer;
    }
    delete m_bitmap;
    delete m_icons[awxLED_OFF];
    delete m_icons[awxLED_ON];
};

void awxLed::Blink()
{
    m_blink ^= 1;
    Redraw();
};

void awxLed::DrawOnBitmap()
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

    if(m_state == awxLED_BLINK) dc.DrawIcon(*m_icons[m_blink],m_x,m_y);
    else dc.DrawIcon(*m_icons[m_state & 1],m_x,m_y);

    dc.SelectObject(wxNullBitmap);
};

void awxLed::SetColour(awxLedColour color)
{
    if(m_icons[awxLED_ON]) delete m_icons[awxLED_ON];
    switch(color) {
    case awxLED_GREEN:
	   m_icons[awxLED_ON] = new wxIcon(led_green_xpm);
	   break;
    case awxLED_YELLOW:
	   m_icons[awxLED_ON] = new wxIcon(led_yellow_xpm);
	   break;
    default:
	   m_icons[awxLED_ON] = new wxIcon(led_red_xpm);
    }
};

void awxLed::SetState(awxLedState state) 
{
    m_state = state;
    if(m_timer->IsRunning()) {
	   m_timer->Stop();
    }
    if(m_state == awxLED_BLINK) {
	   m_timer->Start(500);
    }
    Redraw();
};
