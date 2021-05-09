/*
	BTPlusPlus Tournament is an improved version of BTPlusPlus 0.994
	Flaws have been corrected and extra features have been added
	BT++ Tournament Edition is created by OwYeaW

	BTPlusPlus 0.994
	Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

	This program is free software; you can redistribute and/or modify
	it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTPPReplicationInfo expands ReplicationInfo;

var bool bNeedsRespawn;	//indicates if the player needs a respawn to take flag/also stops the timers on him

var int PlayerID; 	// used to identify the owner

var float JoinTime; 	// works just as the original PlayerReplicationInfo.StartTime, but the original can be messed up by BunnyTruck.u
var float timeDelta; 	// used to restore the Time on the scoreboard of reconnectors
var int Runs;
var int Caps;

var int lastCap;	// Time of the last cap -> show in scoreboard and HUD
//NEW:
var float local_update_stamp;
var int runtime_offset;

//comparison // detect variable replication
var bool bIdle_B;
var int runtime_offset_B;

var int BestTime; 	// in current game
var string BestTimeStr; 	//reuse it on the scoreboard

// IpToCountry stuff
var string CountryPrefix;
var Actor IpToCountry;

var bool bReadyToPlay;
var bool bTournament;

var int		Netspeed;
var bool	CPUsed;

replication
{
	reliable if (Role == ROLE_Authority)
		PlayerID, BestTime, BestTimeStr, JoinTime, Runs, Caps, CountryPrefix, bReadyToPlay, bNeedsRespawn, lastCap, SetNoneFlag, SetTimeDelta, runtime_offset, Netspeed, CPUsed;
}

event Spawned()
{
	if(ROLE == ROLE_Authority)
	{
		SetTimer(0.5, true);
		bTournament = DeathMatchPlus(Level.Game).bTournament;
	}
}

function Timer()
{
	local string temp;
	local PlayerPawn P;

	if(Owner == None)
	{
		Destroy();
		return;
	}

	if ((Owner.IsA('PlayerPawn')) && (PlayerPawn(Owner).player!=None))
		NetSpeed = PlayerPawn(Owner).player.CurrentNetSpeed;
	else
		NetSpeed = 0;

	if(IpToCountry != None)
	{
		if(CountryPrefix == "")
		{
			P = PlayerPawn(Owner);
			if(NetConnection(P.Player) != None)
			{
				temp = P.GetPlayerNetworkAddress();
				temp = Left(temp, InStr(temp, ":"));
				temp = IpToCountry.GetItemName(temp);
				if(temp == "!Disabled") /* after this return, iptocountry won't resolve anything anyway */
					IpToCountry = None;
				else if(Left(temp, 1) != "!") /* good response */
				{
					CountryPrefix = SelElem(temp, 5);
					if(CountryPrefix == "") /* the country is probably unknown(maybe LAN), so as the prefix */
						IpToCountry = None;//??? always disable as resolved? -> else +1 loop
				}
			}
			else
				IpToCountry = None;
		}
		else
			IpToCountry = None;
	}

	if(bTournament && PlayerPawn(Owner).bReadyToPlay != bReadyToPlay)
	{
		bReadyToPlay = PlayerPawn(Owner).bReadyToPlay; // replicate this variable normally being serverside only
	}
}

static final function string SelElem(string Str, int Elem, optional string Char)
{
	local int pos;
	if(Char == "")
		Char = ":";

	while(Elem>1)
	{
		Str = Mid(Str, InStr(Str, Char)+1);
		Elem--;
	}
	pos = InStr(Str, Char);
	if(pos != -1)
    	Str = Left(Str, pos);
    return Str;
}

simulated function SetNoneFlag()
{
	if(PlayerPawn(Owner) != None)
		PlayerPawn(Owner).PlayerReplicationInfo.HasFlag = None;
}

simulated function SetTimeDelta(float delta)
{
	//if(Role == ROLE_Authority)
	timeDelta = delta;
}

//locally calculate the runtime of that player
simulated function int GetRuntime()
{
	return runtime_offset + 90.909090909 * (Level.TimeSeconds - local_update_stamp);
}

simulated function Tick(float d)
{
	if(ROLE == ROLE_Authority && Level.NetMode != NM_Standalone)
		return;

	if(bIdle_B != bNeedsRespawn)
	{
		bIdle_B = bNeedsRespawn;
		//new timestamp as a run started
		if(!bNeedsRespawn)
			local_update_stamp = Level.TimeSeconds;
	}

	if(runtime_offset_B != runtime_offset)
	{
		runtime_offset_B = runtime_offset;
		local_update_stamp = Level.TimeSeconds;
	}
}

defaultproperties
{
	PlayerID=-1
	runtime_offset=-1
	runtime_offset_B=-1
	RemoteRole=ROLE_SimulatedProxy
	NetPriority=9.000000
}