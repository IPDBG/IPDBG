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
