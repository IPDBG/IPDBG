/***************************************************************
 * Name:      IOViewApp.cpp
 * Purpose:   Code for Application Class
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

#include "IOViewApp.h"
#include "IOViewMain.h"

IMPLEMENT_APP(IOViewApp);

bool IOViewApp::OnInit()
{
    IOViewFrame* frame = new IOViewFrame(0L, _("I/O-View"));
    //frame->SetIcon(wxICON(aaaa)); // To Set App Icon
    frame->Show();

    return true;
}
