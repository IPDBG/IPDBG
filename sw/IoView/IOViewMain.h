/***************************************************************
 * Name:      IOViewMain.h
 * Purpose:   Defines Application Frame
 * Author:     ()
 * Created:   2016-04-12
 * Copyright:  ()
 * License:
 **************************************************************/

#ifndef IOVIEWMAIN_H
#define IOVIEWMAIN_H

#ifndef WX_PRECOMP
    #include <wx/wx.h>
#endif

#include "IOViewApp.h"

class IOViewFrame: public wxFrame
{
    public:
        IOViewFrame(wxFrame *frame, const wxString& title);
        ~IOViewFrame();
    private:
        enum
        {
            idMenuQuit = 1000,
            idMenuAbout
        };
        void OnClose(wxCloseEvent& event);
        void OnQuit(wxCommandEvent& event);
        void OnAbout(wxCommandEvent& event);
        DECLARE_EVENT_TABLE()
};


#endif // IOVIEWMAIN_H
