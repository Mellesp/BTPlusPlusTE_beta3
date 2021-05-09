//=============================================================================
// BT_WRI made by OwYeaW
//=============================================================================
class BT_WRI expands WRI;
//-----------------------------------------------------------------------------
var		BTClientSettings	BTCS;
//-----------------------------------------------------------------------------
replication
{
	reliable if(Role == ROLE_Authority)
		BTCS;
}

simulated function bool SetupWindow()
{
	if(Super.SetupWindow())
		SetTimer(0.01, false);
	else
		log("Super.SetupWindow() = false");
}

simulated event Timer()
{
	BT_Window(TheWindow).TabWindow.SpectatorPage.BTCS = BTCS;
	BT_Window(TheWindow).TabWindow.SpectatorPage.LoadSettings();
}

defaultproperties
{
    WindowClass=Class'BT_Window'
    WinLeft=50
    WinTop=30
    WinWidth=400
    WinHeight=250
}