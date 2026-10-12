// SPDX-FileCopyrightText: The IPDBG authors
// SPDX-License-Identifier: MPL-2.0

#include "IOViewApp.h"
#include "IOViewMain.h"

IMPLEMENT_APP(IOViewApp);

bool IOViewApp::OnInit()
{
#if wxCHECK_VERSION(3, 3, 0)
    // light or dark like the system: Windows needs this before any window is
    // created, the other platforms follow the system anyway
    SetAppearance(Appearance::System);
#endif
    IOViewFrame* frame = new IOViewFrame(0L, _("I/O-View"));
#ifdef __WXMSW__
    // from resource.rc; on Linux the desktop finds the icon through the
    // desktop file ipdbg-ioview.desktop
    frame->SetIcon(wxICON(aaaa));
#endif
    frame->Show();

    return true;
}
