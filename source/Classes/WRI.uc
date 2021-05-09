//=============================================================================
// WindowReplicationInfo
//=============================================================================
class WRI expands ReplicationInfo;

// Replicated Server->Client Variables
var() 	class <UWindowWindow> 	WindowClass;     						// ����������� ���� ����
var() 	int 					WinLeft,WinTop,WinWidth,WinHeight; 		// Dims of the window
var() 	bool 					DestroyOnClose;                   		// Whether the WRI should destroy itself when the window closes
var 	UWindowWindow 			TheWindow;                 				// Client Side Variables,Holds a pointer to the window
var 	int 					TicksPassed;                         	// Ticks passed since the creation of the uwindows root (counts up to two)

//-----------------------------------------------------------------------------
replication
{
	// Functions that Server calls on the Client
	reliable if (Role == ROLE_Authority)
		OpenWindow, CloseWindow;

	// Function the Client calls on the Server
	reliable if (Role < ROLE_Authority)
		DestroyWRI;
}

//-----------------------------------------------------------------------------
// Post(Net)BeginPlay - ��� �������������� �������, ������� ���������� �����, and creates a window on the appropriate machine.
// Intended for the user attempting to create the window

// The OpenWindow should only be called from one place: the owner's machine.
// To detect when we are on the owner's machine, we check the playerpawn's Player var, and their console.
// Since these only exist on the machine for which they are used, 
//   their existence ensures we are running on the owner's machine.
// Once that has been validated, we call OpenWindow.

// The reason for BOTH the PostNetBeginPlay and PostBeginPlay is slightly strange.
// PostBeginPlay is called on the client if it is simulated, but it is before the variables have been replicated
//   Thus, Owner is not replicated yet, and the WRI is unable to spawn the window
// PostNetBeginPlay is called after the variables have been replicated, and so is appropriate
//   It is not called on the server machine (NM_Standalone or NM_Listen) because no variables are replicated to that machine
//   And so, PostBeginPlay is needed for those types of servers
//-----------------------------------------------------------------------------
event PostBeginPlay()
{ 
	Super.PostBeginPlay();
	OpenIfNecessary();
}

//-----------------------------------------------------------------------------
simulated event PostNetBeginPlay()
{
	Super.PostBeginPlay();
	OpenIfNecessary();
}

//-----------------------------------------------------------------------------
simulated function OpenIfNecessary()
{
	local PlayerPawn P;

	if (Owner != None)
	{
		P = PlayerPawn(Owner);
		if (P != None && P.Player != None && P.Player.Console !=None)
			OpenWindow();
	}
}

//-----------------------------------------------------------------------------
// OpenWindow - This is a client-side function who's job is to open on the window on the client.
// Intended for the user attempting to create the window

// This first does a lot of checking to make sure the player has a console.
// Then it creates and sets up UWindows if it has not been set up yet.
// This can take a long period of time, but only happens if you join from GameSpy.
//   (eg: connect to a server without using the uwindows stuff to do it)
// Then it sets up bQuickKeyEnable so that the menu/status bar don't show up.
// And finally, says to launch the window two ticks from the call to OpenWindow.
// If the Root could have been created this tick, then it does not contain the height and width
//   vars that are necessary to position the window correctly.
//-----------------------------------------------------------------------------
simulated function bool OpenWindow()
{
	local PlayerPawn P;
	local WindowConsole C;

	P = PlayerPawn(Owner);
	if (P == None)
	{
		log("#### -- Attempted to open a window on something other than a PlayerPawn");
		DestroyWRI();
		return false;
	}

	C = WindowConsole(P.Player.Console);
	if (C == None)
	{
		Log("#### -- No Console");
		DestroyWRI();
		return false;
	}

	// Tell the console to create the root
	if (!C.bCreatedRoot || C.Root == None)
		C.CreateRootWindow(None);

	// Hide the status and menu bars and all other windows, so that our window alone will show
	C.bQuickKeyEnable = true;
	// �������� ���� �� 2 �������
	C.LaunchUWindow();

	// tell tick() to create the window in 2 ticks from now, to allow time to get the uwindow size set up
	TicksPassed = 1;
	return true;
}

//-----------------------------------------------------------------------------
// Tick - Counts down ticks in TickPassed until they hit 0, at which point it really creates the window
// Also destroys the WRI when they close the window if DestroyOnClose == true
// Intended for the user attempting to create the window, or close the window

// See the description for OpenWindow for the reasoning behind this Tick.
// After two ticks, it creates the window in the base Root, and sets it up to work with bQuickKeyEnable.

// This also calls DestroyWRI if the WRI is setup to DestroyOnClose, and the window is closed
//-----------------------------------------------------------------------------
simulated function Tick(float DeltaTime)
{
	if (Owner == None)
		Destroy();

	if (TicksPassed != 0)
	{
		if (TicksPassed++ == 2)
		{
			SetupWindow();
			// Reset TicksPassed to 0
			TicksPassed = 0;
		}
	}

	if (DestroyOnClose && TheWindow != None && !TheWindow.bWindowVisible)
		DestroyWRI();
}

//-----------------------------------------------------------------------------
simulated function bool SetupWindow()
{
	local WindowConsole C;

	C = WindowConsole(PlayerPawn(Owner).Player.Console);

	TheWindow = C.Root.CreateWindow(WindowClass, WinLeft, WinTop, WinWidth, WinHeight);
	if (TheWindow == None)
	{
		Log("#### -- CreateWindow Failed");
		DestroyWRI();
		return false;
	}

	if (C.bShowConsole )
		C.HideConsole();

	// Make it show even when everything else is hidden through bQuickKeyEnable
	TheWindow.bLeaveOnScreen = true;
	// Show the window
	TheWindow.ShowWindow();
	return true;
}

//-----------------------------------------------------------------------------
// CloseWindow -- This is a client side function that can be used to close the window.
// Intended for the user attempting to create the window

// Undoes the bQuickKeyEnable stuff just in case
// Then turns off the Uwindow mode, and closes the window.
//-----------------------------------------------------------------------------
simulated function CloseWindow()
{
	local WindowConsole C;

	// ������� ������
	C = WindowConsole(PlayerPawn(Owner).Player.Console);
	C.bQuickKeyEnable = False;
	C.CloseUWindow();
	if (TheWindow != None)
		TheWindow.Close();
}

// ==========================================================================
// These functions happen on the server side
// ==========================================================================
// DestoryWRI - Gets rid of the WRI and cleans up.
// Intended for the server or authority, which *could* be the user that had the window (in a listen server or standalone game)
// DestoryWRI - izbavliaetsia ot WRI i ochishet pamiat naverno..
// prednaznacheno dlia servera ili avtority, kotorim mog bit polzovatel imeushii okno( listen server ili odinochnaia igra)

// Should be called from the client when the user closes the window.
// Subclasses should override it and do any last minute processing of the data here.
// vizivaetsia klienton pri zakritii okna
// tipa na etoi note oknu pizdec )
//-----------------------------------------------------------------------------
function DestroyWRI()
{
	if (DestroyOnClose)
		Destroy();
}

//-----------------------------------------------------------------------------
// Make sure any changes to the WindowClass get replicated in the first Tick of it's lifetime
// Ahead of everything else (UT uses a max of 3)
// Use SimulatedProxy so that the Tick() calls are executed
//-----------------------------------------------------------------------------

defaultproperties
{
    DestroyOnClose=True
    RemoteRole=ROLE_SimulatedProxy
    WindowClass=Class'BT_Window'
    WinLeft=50
    WinTop=30
    WinWidth=400
    WinHeight=300
}