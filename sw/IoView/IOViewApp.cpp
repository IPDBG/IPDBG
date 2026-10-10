// SPDX-FileCopyrightText: The IPDBG authors
// SPDX-License-Identifier: MPL-2.0

#include "IOViewApp.h"
#include "IOViewMain.h"

IMPLEMENT_APP(IOViewApp);

bool IOViewApp::OnInit()
{
    IOViewFrame* frame = new IOViewFrame(0L, _("I/O-View"));
#ifdef __WXMSW__
    // from resource.rc; on Linux the desktop finds the icon through the
    // desktop file ipdbg-ioview.desktop
    frame->SetIcon(wxICON(aaaa));
#endif
    frame->Show();

    return true;
}
