//=============================================================================
// BTClientSettings made by OwYeaW
//=============================================================================
class BTClientSettings expands Info config(BTPlusPlusTE);
//=============================================================================
// Config Variables
//=============================================================================
var config bool		bBehindviewFollow;
var config int		BehindviewSmoothing;
var config int		BehindviewDistance;
var config int		SpectatorFlySpeed;
var config bool		bHideArmor;
var config bool		bGhostSpectator;
var config bool		bTransparentSelf;
var config string	mystart[4096];
//=============================================================================
// Server Variables
//=============================================================================
var bool	Server_bBehindviewFollow;
var int		Server_BehindviewSmoothing;
var int		Server_BehindviewDistance;
var int		Server_SpectatorFlySpeed;
var bool	Server_bHideArmor;
var bool	Server_bGhostSpectator;
var string	Server_MyStart;
//=============================================================================
// Other Variables
//=============================================================================
var string Client_MyStart;
var BTPlusPlus Controller;
//=============================================================================
// Replication and Tick
//=============================================================================
replication
{
	reliable if (Role < ROLE_Authority)
		SetServerVars;

	reliable if(Role == ROLE_Authority)
		GetClientVars, saveMyStart, SwitchBool, TransparentSelf;
}
function Tick(float DeltaTime)
{
	if(Owner == None)
		Destroy();
}
//=============================================================================
// Initialize
//=============================================================================
event Spawned()
{
	GetClientVars();
}
simulated function GetClientVars()
{
	Client_MyStart = getMystart();
	SetServerVars(bBehindviewFollow, BehindviewSmoothing, BehindviewDistance, SpectatorFlySpeed, bHideArmor, bGhostSpectator, Client_MyStart);

	if(bTransparentSelf)
	{
		TournamentPlayer(Owner).Style = STY_Translucent;
		if(TournamentPlayer(Owner).Weapon != None)
			TournamentPlayer(Owner).Weapon.Style = STY_Translucent;
	}
}
function SetServerVars(bool BF, int BIS, int BVD, int SFS, bool HA, bool GS, string MS)
{
	Server_bBehindviewFollow	= BF;
	Server_BehindviewSmoothing	= BIS;
	Server_BehindviewDistance	= BVD;
	Server_SpectatorFlySpeed	= SFS;
	Server_bHideArmor			= HA;
	Server_bHideArmor			= HA;
	Server_bGhostSpectator		= GS;
	Server_MyStart				= MS;

	if(BTSpectator(Owner) != None)
		BTSpectator(Owner).Grab();
	else
		Controller.extractMystart(Server_MyStart, PlayerPawn(Owner));
}
//=============================================================================
// Mystart stuff
//=============================================================================
simulated function string getMystart()
{
	local int i, l;
	local string mapname;

	mapname = GetLevelName();
	l = Len(mapname);

	for(i = 0; i < 2048; i++)
		if(Left(mystart[i], l) == mapname)
			return(Right(mystart[i], len(mystart[i]) - l - 1));
	return("X");
}
simulated function string GetLevelName()
{
	local string Str;
	local int Pos;

	Str = string(Level);
	Pos = InStr(Str, ".");
	if(Pos != -1)
		return Left(Str, Pos);
	else
		return Str;
}
//=============================================================================
// Settings Stuff
//=============================================================================
simulated function SwitchBool(string BoolName)
{
	switch(BoolName)
	{
		case "bBehindviewFollow": bBehindviewFollow = !bBehindviewFollow; break;
		case "bHideArmor": bHideArmor = !bHideArmor; break;
		case "bGhostSpectator": bGhostSpectator = !bGhostSpectator; break;
	}
	SetServerVars(bBehindviewFollow, BehindviewSmoothing, BehindviewDistance, SpectatorFlySpeed, bHideArmor, bGhostSpectator, Client_MyStart);
	SaveConfig();
}
simulated function IntSetting(string Setting, int Number)
{
	switch(Setting)
	{
		case "BehindviewSmoothing": BehindviewSmoothing = Number; break;
		case "BehindviewDistance": BehindviewDistance = Number; break;
		case "SpectatorFlySpeed": SpectatorFlySpeed = Number; break;
	}
	SetServerVars(bBehindviewFollow, BehindviewSmoothing, BehindviewDistance, SpectatorFlySpeed, bHideArmor, bGhostSpectator, Client_MyStart);
	SaveConfig();
}
simulated function saveMyStart(string text)
{
	local int i, l, x;
	local string mapname;
	local bool bFound;

	mapname = GetLevelName();
	l = Len(mapname);

	for(i = 0; i < 2048; i++)
	{
		if(mystart[i] != "")
			x = i + 1;

		if(Left(mystart[i], l) == mapname)
		{
			bFound = true;
			break;
		}
	}

	if(bFound)
		mystart[i] = mapname $ "," $ text;
	else if(x >= 2048)
		PlayerPawn(Owner).ClientMessage("Your mystart list is full, check your BTPlusPlusTE ini...");
	else
		mystart[x] = mapname $ "," $ text;

	SaveConfig();
}
simulated function TransparentSelf(TournamentPlayer TP)
{
	bTransparentSelf = !bTransparentSelf;

	if(bTransparentSelf)
	{
		TP.ClientMessage("You are now Transparent");
		TP.Style = STY_Translucent;
		if(TP.Weapon != None)
			TP.Weapon.Style = STY_Translucent;
	}
	else
	{

		TP.ClientMessage("Transparency removed");
		TP.Style = STY_Normal;
		if(TP.Weapon != None)
			TP.Weapon.Style = STY_Normal;
	}
}
//=============================================================================
// Default Properties
//=============================================================================
defaultproperties
{
	bBehindviewFollow=false
	BehindviewSmoothing=100
	BehindviewDistance=180
	SpectatorFlySpeed=450
	bHideArmor=false
	bGhostSpectator=false
	bTransparentSelf=false
	mystart(0)=""
}