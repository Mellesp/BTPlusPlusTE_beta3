/*
	BTPlusPlus Tournament is an improved version of BTPlusPlus 0.994
	Flaws have been corrected and extra features have been added
	BT++ Tournament Edition is created by OwYeaW

	BTPlusPlus 0.994
	Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

	This program is free software; you can redistribute and/or modify
	it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTPlusPlus extends Mutator config(BTPlusPlusTE);

var const int		MAX_CAPTIME;

var config bool		bSuddenDeath;
var config bool 	bCarcasses;
var config bool 	bSaveRecords;
var config string	CountryFlagsPackage;
var config bool		bEnableCheckpointsInPracticeMode;
var config bool		bShowNewRecordsInTournamentMode;
var config string	BoardLabel;

var int		CurrentID;
var bool	TimerBugTriggered;
var bool	bStandalone;				//backup and others only needed for network-games
var bool	Initialized;
var bool	Initialized2;
var int		lastTimestamp;				//save the latest timestamp generated
var int		BestTeam;
var int		SuddenDeathTimer;
var string	BTStatsTimer;
var bool	bCPEnabled;

var string	LevelName;					// current level name
var Actor	focusOn;
var color	OrangeColor;

struct PS_Teamz
{
	var PlayerStart PS[32];
};
var PS_Teamz PS_Team[2];

struct Sides
{
	var PlayerStart	myStart;
};

struct PlayerInfo
{
	var 		PlayerPawn Player;
	var int		PlayerID;
	var			BTPPReplicationInfo RI;
	var			ClientData Config;
	var bool	bStartedFirstRun;
	var byte	myTeam;
	var int		backupLink;				//which index in the backups-array this player is assigned to
	var float	StartTime;
	var int		BoostOther;
	var int		GotBoosted;
	var int		AmountCaps;
	var int		AmountRuns;
	var BTEPRI	EPRI;
	var			BTClientSettings BTCS;
	var Sides	side[2];
	var PlayerStart lastStart;
	var MyStart_Indicator MI;
};
var PlayerInfo PI[32];

struct SpecInfo
{
	var	PlayerPawn			Spec;
	var BTPPReplicationInfo	RI;
	var ClientData			Config;
	var BTClientSettings	BTCS;
};
var SpecInfo SI[32];

struct BU_DATA							//backup BT++ data for restore if a player reconnects to the same game
{
	var int 	BU_Runs;				//BTPPRI->Runs
	var int		BU_Caps;				//BTPPRI->Caps
	var int		BU_Deaths;				//PRI->Deaths
	var int		BU_Frags;				//PRI->Score
	var int		BU_BestTime;			//BTPPRI->BestTime
	var string	BU_BestTimeStr;			//BTPPRI->BestTimeStr
	var float	BU_JoinTime;			//BTPPRI->JoinTime
	var string	BU_PlayerName;			//PRI->PlayerName 
	var string	BU_IP;					//IP + playername matching -> perform restore
};
var BU_DATA backups[64];				//backup data of the first 64 players in a game
var int backupIndex;

var int		CapOfMatchPlayer;
var int		MapBestTime;
var string	MapBestPlayer;

// BTPlusPlus other objects
var ServerRecords SR;
var Mutator Insta;
var BTCheckPoints BTCheckPoints;
var BTPPGameReplicationInfo GRI;

var Actor IpToCountry;					// IpToCountry external actor for resolving country names
var bool bNoIpToCountry;				// will be true if CountryFlags texture is not in the serverpackages

// actors to which the custom events will be send
var Actor EventHandlers[10];
var int EventHandlersCount;

//	BTStats data
var int TotalAmountRuns, TotalAmountCaps, TotalAmountDead, TotalBoostOther, TotalGotBoosted;
//====================================
// CheckDisableNeed - Check whether to run and if to use IpToCountry module
// Triggered in: PreBeginPlay
//====================================
function int CheckDisableNeed()
{
	local string packages;
	local BTPlusPlus temp;

	packages = ConsoleCommand("get ini:Engine.Engine.GameEngine ServerPackages");

	if(InStr(Caps(packages), Caps(CountryFlagsPackage)) == -1)
		bNoIpToCountry=True;
	if(!ClassIsChildOf(Level.Game.class, class'BunnyTrackGame')) // check the gametype
		return 1;
	foreach AllActors(class'BTPlusPlus', temp) // check if there isn't another instance running
		if(temp != self)
			return 2;
	return 0;
}
//====================================
// PreBeginPlay - Mutator registration, Auto loading instagib, Spawning classes, Setting scoreboard
//====================================
function PreBeginPlay()
{
	local DeathMatchPlus dmp;

	if(!Initialized)
	{
		Initialized = !Initialized;
		bStandalone = (Level.NetMode == NM_Standalone);

		CurTimeStamp();//make first timestamp (for possible reuse: calculate record-ages)

		if(Role == ROLE_Authority)
		{
			Tag = 'BTPlusPlus';

			log("+-----------------", tag);
			log("| BTPlusPlus Tournament Edition", tag);

			//force this:
			Log("| forcing Hardcore mode / 100% Gamespeed / 35% AirControl", tag);
			dmp = DeathMatchPlus(Level.Game);
			if(dmp != None)
			{
				dmp.bHardcoreMode = True;
				dmp.AirControl = dmp.Default.AirControl;
				dmp.MinPlayers = 0;
			}
			if(Level.Game.GameSpeed != 1)
				Level.Game.SetGameSpeed(1);

			switch (CheckDisableNeed())
			{
				case 1:
					log("| Status: Disabled", tag);
					log("| Reason: Gametype is not BunnyTrackGame!", tag);
					log("+-----------------", tag);
					Destroy();
					break;
				return;
				case 2:
					log("| Status: Disabled", tag);
					log("| Reason Another instance of BTPlusPlus detected!", tag);
					log("+-----------------", tag);
					Destroy();
				return;
				case 0:
					log("| Status: Running", tag);
					log("+-----------------", tag);
			}

			Level.Game.BaseMutator.AddMutator(Self);
			Level.Game.RegisterDamageMutator(Self);
			Level.Game.RegisterMessageMutator(Self);

			GRI = spawn(class'BTPPGameReplicationInfo');
			GRI.CountryFlagsPackage = CountryFlagsPackage;

			//	INSTAGIB MUTATOR
			Insta = level.spawn(class'BTInsta');
			Insta.DefaultWeapon = class'SuperShockRifle';
			Level.Game.BaseMutator.AddMutator(Insta);

			BunnyTrackGame(level.game).Controller = Self;
		}

		if(!DeathMatchPlus(Level.Game).bTournament && bEnableCheckpointsInPracticeMode)
		{
			BTCheckPoints = spawn(class'BTCheckPoints');
			bCPEnabled = true;
		}

		initPlayerStarts();
	}
	Super.PreBeginPlay();
}
//====================================
// PreBeginPlay - initializing ServerRecords, Binding IpToCountry, Retrieving saved records, Setting timer to spawn custom flags, Setting movers to kill, Setting killing block
//====================================
function PostBeginPlay()
{
	local int i;

	if (!Initialized2)
	{
		Initialized2 = !Initialized2;
		LevelName = GetLevelName();
		SR = spawn(class'ServerRecords');

		if(!bNoIpToCountry)
		{
			foreach AllActors(class'Actor', IpToCountry)
			{
				if(string(IpToCountry.class) == "IpToCountry.LinkActor")
					break;
				else
					IpToCountry = None;
			}
		}
		//get index
		if(bSaveRecords)
		{
			i = SR.CheckRecord(LevelName);

			if(i != -1 && SR.getCaptime(i) != 0)
			{
				//get server record ready for usage
				MapBestTime = SR.getCaptime(i);
				MapBestPlayer = SR.getPlayerName(i);
				GRI.MapBestAge = string((lastTimestamp - SR.getTimestamp(i))/86400);//age in whole days
				GRI.MapBestTime = FormatCentiseconds(MapBestTime, False);
				GRI.MapBestPlayer = MapBestPlayer;
			}
		}

		//Create ini if doesn't exist.
		SaveConfig();

		SendEvent("btpp_started");
		SetSettings();
	}
	Super.PostBeginPlay();
}
//====================================
// Tick - New player detection, runtime measurements
// Inherited from class'Actor'
//====================================
function tick(float DeltaTime)
{
	Super.tick(DeltaTime);
	CheckForNewPlayer();

	GRI.ElapsedTime		= DeathMatchPlus(Level.Game).ElapsedTime;
	GRI.RemainingTime	= Level.Game.GameReplicationInfo.RemainingTime;

	if(GRI.bGameEnded)
		SetViewTargetz();
}
//====================================
function initPlayerStarts()
{
	local NavigationPoint N;
	local PlayerStart PS;
	local int r, b;

	for(N = Level.NavigationPointList; N != None; N = N.nextNavigationPoint)
	{
		PS = PlayerStart(N);
		if(PS != None && PS.bEnabled)
		{
			if(PS.TeamNumber == 0 || PS.TeamNumber == 1)
			{
				if(PS.TeamNumber == 0)
				{
					PS_Team[PS.TeamNumber].PS[r] = PS;
					r++;
				}
				else if(PS.TeamNumber == 1)
				{
					PS_Team[PS.TeamNumber].PS[b] = PS;
					b++;
				}
			}
		}
	}
}
//====================================
function SetSettings()
{
	GRI.bTournament		= DeathMatchPlus(Level.Game).bTournament;
	GRI.MaxPlayers		= DeathMatchPlus(Level.Game).MaxPlayers;
	GRI.CapLimit		= CTFGame(Level.Game).GoalTeamScore;
	GRI.TimeLimit		= CTFGame(Level.Game).TimeLimit;
	GRI.BoardLabel		= BoardLabel;
}
//#########################################################################
//### PLAYER AND RECORD MANAGMENT FUNCTIONS
//#########################################################################
//====================================
// CheckForNewPlayer - Check for new player
// Triggered in: Tick, ModifyPlayer
//====================================
function CheckForNewPlayer()
{
	local Pawn Other;
	local PlayerPawn PP;

	if(Level.Game.CurrentID > CurrentID) // At least one new player has joined - sometimes this happens faster than tick
	{
		for( Other=Level.PawnList; Other!=None; Other=Other.NextPawn )
			if(Other.PlayerReplicationInfo.PlayerID == CurrentID)
				break;
		CurrentID++;

		// Make sure it is a player.
		PP = PlayerPawn(Other);
		if(PP == none || !Other.bIsPlayer)
			return;
		if(Other.PlayerReplicationInfo.bIsSpectator && !Other.PlayerReplicationInfo.bWaitingPlayer)
			InitNewSpec(PP);
		else
			InitNewPlayer(PP);
	}
}
//====================================
// InitNewPlayer - Check for new player
// Triggered in: CheckForNewPlayer
//====================================
function InitNewPlayer(PlayerPawn PP)
{
	local int i, k;

	i = FindFreePISlot();

	PI[i].Player = PP;
	PI[i].EPRI = Spawn(class'BTEPRI', PP);
	PI[i].EPRI.PlayerID = PP.PlayerReplicationInfo.PlayerID;
	PI[i].EPRI.PP = PP;
	PI[i].EPRI.bCPEnabled = bCPEnabled;

	PI[i].PlayerID = PP.PlayerReplicationInfo.PlayerID;

	PI[i].Config = spawn(class'BTPPUser.ClientData', PP);
	PI[i].BTCS = spawn(class'BTClientSettings', PP);
	PI[i].BTCS.Controller = Self;

	if(PI[i].RI != None)
	{
		PI[i].RI.Destroy();
		PI[i].RI = None;
	}
	PI[i].RI = spawn(class'BTPPReplicationInfo', PP);
	PI[i].RI.IpToCountry	= IpToCountry;
	PI[i].RI.PlayerID		= PP.PlayerReplicationInfo.PlayerID;
	PI[i].RI.JoinTime		= Level.TimeSeconds;
	PI[i].bStartedFirstRun	= False;

	//clear mystart data of potential previous player
	PI[i].side[0].myStart = None;
	PI[i].side[1].myStart = None;
	PI[i].lastStart = None;

	//send runtimes to this player (and all others too)
	for(k = 0;k<32;k++)
	{
		if(i != k && PI[k].RI != None && !PI[k].RI.bNeedsRespawn)
			PI[k].RI.runtime_offset = MeasureTime(k, Level.TimeSeconds);
	}

	if(!bStandalone)//Level.NetMode != NM_Standalone)//online
	{
		//try to restore data for reconnectors
		PI[i].backupLink = RestoreData(PP.PlayerReplicationInfo.PlayerName, i);

		//Player already did first run? -> preparation for ModifyPlayer needed
		if(PP.PlayerReplicationInfo.Deaths != 0 || PI[i].RI.Runs != 0)
		{
			PI[i].bStartedFirstRun = True;//ok not needed

			//prepare for regular reset in ModifyPlayer
			PI[i].RI.bNeedsRespawn = True;
			PP.AttitudeToPlayer = ATTITUDE_Follow;
		}
	}
	if(!bCarcasses)
		PI[i].Player.CarcassType = None;
}
//====================================
// InitNewSpec - Check for new spectator
// Triggered in: Tick
//====================================
function InitNewSpec(PlayerPawn PP)
{
	local int i;

	i = FindFreeSISlot();
	SI[i].Spec = PP;
	SI[i].Config = spawn(class'BTPPUser.ClientData', PP);
	SI[i].BTCS = spawn(class'BTClientSettings', PP);
	BTSpectator(PP).BTCS = SI[i].BTCS;
}
//====================================
// FindFreePISlot - Find a free place in a PlayerInfo struct
// Triggered in: InitNewPlayer
//====================================
function int FindFreePISlot()
{
	local int i;

	for(i=0;i<32;i++)
	{
		if(PI[i].Player == none)
			return i;
		else if(PI[i].Player.Player == none)
				return i;
	}
}
//====================================
// FindFreeSISlot - Find a free place in a SpecInfo struct
// Triggered in: InitNewPlayer
//====================================
function int FindFreeSISlot()
{
	local int i;

	for(i=0;i<32;i++)
	{
		if(SI[i].Spec == none)
			return i;
		else if(SI[i].Spec.Player == none)
			return i;
	}
}
//====================================
// FindPlayer - Find a player in the PlayerInfo struct by a Pawn object
// Triggered in: Almost everywhere :P
//====================================
function int FindPlayer(Pawn P)
{
	local int i;

	for(i=0;i<32;i++)
		if(PI[i].Player == P)
			return i;
	return -1;
}
//====================================
// FindSpec - Find a PlayerPawn in the SpecInfo struct
//====================================
function int FindSpec(PlayerPawn PP)
{
	local int i;

	for(i = 0; i < 32; i++)
		if(SI[i].Spec == PP)
			return i;
	return -1;
}
//====================================
// RestoreData - Looks for the PlayerName in the BU-array and returns matching index; -1 if not refound and no capacity left; if an entry matches PlayerName data is restored
// Triggered in: InitNewPlayer
//====================================
function int RestoreData(string PlayerName, int ID)
{
	local int i;

	for(i = 0;i<backupIndex;i++)
	{
		if(backups[i].BU_PlayerName == PlayerName && 
			InStr(PI[ID].Player.GetPlayerNetworkAddress(), backups[i].BU_IP) != -1)//refound
		{
			//restore data as it was backed up
			PI[ID].RI.Runs = backups[i].BU_Runs;
			PI[ID].RI.Caps = backups[i].BU_Caps;
			PI[ID].Player.PlayerReplicationInfo.Deaths = backups[i].BU_Deaths;
			PI[ID].Player.PlayerReplicationInfo.Score = backups[i].BU_Frags;
			PI[ID].RI.BestTime = backups[i].BU_BestTime;
			PI[ID].RI.BestTimeStr = backups[i].BU_BestTimeStr;
			PI[ID].RI.JoinTime = backups[i].BU_JoinTime;

			//fix the time on the SB
			PI[ID].RI.SetTimeDelta(Level.TimeSeconds - backups[i].BU_JoinTime);
			//reference i 
			return i;
		}
	}
	if(backupIndex < 64) //player gets a new entry
	{
		//new Join -> backup JoinTime
		backups[backupIndex].BU_JoinTime = Level.TimeSeconds;//BU_JoinTime = first time the player entered this game
		backups[backupIndex].BU_PlayerName = PI[ID].Player.PlayerReplicationInfo.PlayerName;
		backups[backupIndex].BU_IP = SelElem(PI[ID].Player.GetPlayerNetworkAddress(), 1);

		return backupIndex++;
	}
	else //none left
		return -1;
}
//====================================
// FindPlayer - Find a player in the PlayerInfo struct by a PlayerID
// Triggered in: GetItemName
//====================================
function int FindPlayerByID(coerce int ID)
{
	local int i;
	for(i=0;i<32;i++)
		if(PI[i].PlayerID == ID)
			return i;
}
//====================================
// GetBestTimeClient, GetBestTimeServer, GetSTFU, CheckIfBoosted - used to access structs data from FlagDisposer, trying to acces it normally would result in "too complex variable error"
// Triggered in: class'FlagDisposer'.Touch()
//====================================
function int GetBestTimeClient(int ID) { return PI[ID].Config.BestTime; }
function string GetBestTimeClientStr(int ID) { return PI[ID].Config.BestTimeStr; }
function int GetTimeStampClient(int ID){ return PI[ID].Config.TimeStamp; }
function int GetBestTimeServer(int ID) { return PI[ID].RI.BestTime; }
function bool GetSTFU(int ID) { return PI[ID].Config.bSTFU; }
//====================================
// SetBestTime - Saves a new record, in clientside if needed, in serverside. It also informs other players about new record.
// Triggered in: class'FlagDisposer'.Touch()
//====================================
function SetBestTime(int Time, int TimeStamp, int i, string ctf)
{
	local int j;
	local string Nick;

	//replicate the captime
	PI[i].RI.lastCap = MAX_CAPTIME - Time;

	if(Time > PI[i].Config.BestTime)
	{
		// save the time clientside
		PI[i].Config.AddRecord(LevelName, Time, TimeStamp);
		//update on the serverside
		PI[i].Config.BestTime = Time;
		PI[i].Config.BestTimeStr = ctf;//FormatCentiseconds(Time, False);
		PI[i].Config.Timestamp = Timestamp;
	}

	if(Time > PI[i].RI.BestTime)
	{
		PI[i].RI.BestTime = Time;
		PI[i].RI.BestTimeStr = ctf;

		//try backup
		if(!bStandalone && PI[i].backupLink != -1)
		{
			backups[PI[i].backupLink].BU_BestTime = PI[i].RI.BestTime;
			backups[PI[i].backupLink].BU_BestTimeStr = PI[i].RI.BestTimeStr;
			//name got updated in PlayerCapped()
		}
	}

	//Cap of the game
	if(GRI.GameBestTimeInt < Time)//new best cap in this game
	{
		GRI.GameBestTimeInt = Time;
		GRI.GameBestTime = ctf;
		GRI.GameBestPlayerName = PI[i].Player.PlayerReplicationInfo.PlayerName;
		GRI.GameBestPlayerTeam = PI[i].Player.PlayerReplicationInfo.Team;
		CapOfMatchPlayer = PI[i].PlayerID;
	}

	//is this a new server record?
	if(Time > MapBestTime)
	{
		MapBestTime = Time;
		MapBestPlayer = PI[i].Player.PlayerReplicationInfo.PlayerName;

		if(bSaveRecords)
		{
			SR.AddRecord(LevelName, MapBestTime, CleanName(MapBestPlayer), TimeStamp);
			SendEvent("server_record", PI[i].PlayerID, MapBestTime);
		}
		GRI.MapBestTime = ctf;
		GRI.MapBestPlayer = MapBestPlayer;
		GRI.MapBestAge = "0";//this one is all new

		//tell other players & spectators
		if(bSaveRecords && (bShowNewRecordsInTournamentMode || !DeathMatchPlus(Level.Game).bTournament)) //no spam if records don't persist
		{
			BroadcastAdd("New server record by " $ MapBestPlayer);
		}
	}
}
//====================================
// PlayerCapped - Event on cap, increases some variables.
// Triggered in: class'FlagDisposer'.Touch()
//====================================
function PlayerCapped(int ID)
{
	PI[ID].RI.bNeedsRespawn = True;//no caps before respawn
	PI[ID].RI.Caps++;
	PI[ID].RI.Runs++;
	
	//try backup
	if(!bStandalone && PI[ID].backupLink != -1)
	{
		backups[PI[ID].backupLink].BU_Caps = PI[ID].RI.Caps;
		backups[PI[ID].backupLink].BU_Runs = PI[ID].RI.Runs;
		backups[PI[ID].backupLink].BU_Frags = PI[ID].Player.PlayerReplicationInfo.Score;//just updated +7
		//latest name
		backups[PI[ID].backupLink].BU_PlayerName = PI[ID].Player.PlayerReplicationInfo.PlayerName;
	}
}
//====================================
// MeasureTime - Calculates the current runtime and returns floored CENTISECONDS
//====================================
function int MeasureTime(int ID, float TimeSeconds)
{
	return 90.909090909*(TimeSeconds - PI[ID].StartTime);
}
//### END OF PLAYER AND RECORD MANAGMENT FUNCTIONS
//#########################################################################
//### TEXT FUNCTIONS - used all over the place :)
//#########################################################################
//====================================
// CleanName - needed to remove "\? out of playernames
//====================================
static function string CleanName(string playername)
{
	local int i;

	i = InStr(playername, Chr(34));
	while(i != -1)
	{
		playername = Left(playername, i) $ Mid(playername, i + 1);
		i = InStr(playername, Chr(34));
	}

	i = InStr(playername, "?");
	while(i != -1)
	{
		playername = Left(playername, i) $ Mid(playername, i + 1);
		i = InStr(playername, "?");
	}

	i = InStr(playername, "\\");
	while(i != -1)
	{
		playername = Left(playername, i) $ Mid(playername, i + 1);
		i = InStr(playername, "\\");
	}
	return playername;

}
//====================================
// ElementsNum - Counts a specified character in a string(and thus elements) and returns the countresult-1;
//====================================
static final function int ElementsNum(string Str, optional string Char)
{
	local int count, pos;

	if(Char == "")
		Char = ","; // this is a default separator for config lists
	while(true)
	{
		pos = InStr(Str, Char);
		if(pos == -1)
			break;
		Str = Mid(Str, pos+1);
		count++;
	}
	return count+1;
}
//====================================
// SelElem - Selects an element from a string where elements are separated by a "Char"
//====================================
static final function string SelElem(string Str, int Elem, optional string Char)
{
	local int pos, count;
	if(Char == "")
		Char = ":"; // this is a default separator

	while( (Elem--) >1)
	{
		pos = InStr(Str, Char);
		if(pos != -1)
			Str = Mid(Str, pos+1);
		else
			return "";
	}
	pos = InStr(Str, Char);
	if(pos != -1)
		return Left(Str, pos);
	else
		return Str;
}
//====================================
// SepLeft - Separates a left part of a string with a certain character as a separator
//====================================
static final function string SepLeft(string Input, optional string Char)
{
	local int pos;
	if(Char == "")
		Char = ":"; // this is a default separator

	pos = InStr(Input, Char);
	if(pos != -1)
		return Left(Input, pos);
	else
		return "";
}
//====================================
// SepLeft - Separates a right part of a string with a certain character as a separator
//====================================
static final function string SepRight(string Input, optional string Char)
{
	local int pos;
	if(Char == "")
		Char = ":"; // this is a default separator

	pos = InStr(Input, Char);
	if(pos != -1)
		return Mid(Input, pos+1);
	else
		return "";
}
//====================================
// DelSpaces - Deletes spaces from an end of a string
//====================================
static final function string DelSpaces(string Input)
{
	local int pos;
	pos = InStr(Input, " ");
	if(pos != -1)
		return Left(Input, pos);
	else
		return Input;
}
//====================================
// FormatCentiseconds - formats Score to m:ss.cc
// Triggered in: ?
//====================================
static final function string FormatCentiseconds(coerce int Centis, bool plain)
{
	if(Centis <= 0 || Centis >= Default.MAX_CAPTIME)
		return "-:--";

	if(!plain)
		Centis = Default.MAX_CAPTIME - Centis;

	if(Centis / 100 < 60)//less than 1 minute -> no formatting needed
	{
		if(Centis % 100 < 10)
			return (Centis / 100) $ ".0" $ int(Centis % 100);
		else
			return (Centis / 100) $ "." $ int(Centis % 100);
	}
	else
	{
		if(Centis % 100 < 10)
			return FormatScore(Centis / 100) $ ".0" $ int(Centis % 100);
		else
			return FormatScore(Centis / 100) $ "." $ int(Centis % 100);
	}
}
//====================================
// FormatScore - format seconds to mm:ss
// Triggered in: PostBeginPlay, SetBestTime
//====================================
static final function string FormatScore(coerce int Score)
{
	local int secs;
	local string sec;

	secs = int(Score % 60);
	if ( secs < 10 )
		sec = "0" $string(secs);
	else
		sec = "" $string(secs);

	return string(Score / 60) $":"$sec;
}
//====================================
// GetLevelName - Returns a level name(file name) in a readable format
// Triggered in: PostBeginPlay
//====================================
function string GetLevelName()
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
//### END OF TEXT FUNCTIONS
//#########################################################################
//### MUTATOR FUNCTIONS - inherited from class'Mutator'
//#########################################################################
//====================================
// AddMutator = Little security against initializing this script twice.
//====================================
function AddMutator(Mutator M)
{
	if ( M.Class != Class )
		Super.AddMutator(M);
	else if ( M != Self )
		M.Destroy();
}
//====================================
// MutatorTakeDamage - checks for instagib rays trying to boost a player or to kill someone, it prevents or allows it
// Inherited from class'Mutator'
//====================================
function MutatorTakeDamage( out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType)
{
	local int VictimID;
	local int BoosterID;

	//new condition allowing self-boosting with normal weapons
	if(InstigatedBy != None && PlayerPawn(InstigatedBy) != None && Victim != InstigatedBy && PlayerPawn(Victim) != None)
	{
		VictimID = FindPlayer(Victim);
		BoosterID = FindPlayer(InstigatedBy);

		if((InstigatedBy.PlayerReplicationInfo.Team != Victim.PlayerReplicationInfo.Team)
		|| (!DeathMatchPlus(Level.Game).bTournament && PI[VictimID].Config.bAntiBoost))
		{
			Momentum = Vect(0,0,0);
		}
		else if(InstigatedBy.PlayerReplicationInfo.Team == Victim.PlayerReplicationInfo.Team)
		{
			PI[BoosterID].BoostOther += 1;
			PI[VictimID].GotBoosted += 1;
		}
	}

	if ( NextDamageMutator != None )
		NextDamageMutator.MutatorTakeDamage( ActualDamage, Victim, InstigatedBy, HitLocation, Momentum, DamageType );
}
//====================================
// ScoreKill - Decreases points increased by a standard function, updates number of runs and sets start times for the timer
//====================================
function ScoreKill(Pawn Killer, Pawn Other)
{
	local int ID;

	if ( NextMutator != None )
		NextMutator.ScoreKill(Killer, Other);

	if(PlayerPawn(Killer) != None && PlayerPawn(Other) != None)//@todo no decrement killing animals
		Killer.PlayerReplicationInfo.Score -= 1.0;

	ID = FindPlayer(Other);

	if(ID != -1)
	{
		PI[ID].RI.Runs ++;
		PI[ID].RI.bNeedsRespawn = True;
		Other.AttitudeToPlayer = ATTITUDE_Follow;

		//try backup
		if(!bStandalone && PI[ID].backupLink != -1)
		{
			backups[PI[ID].backupLink].BU_Runs = PI[ID].RI.Runs;
			backups[PI[ID].backupLink].BU_Deaths = Other.PlayerReplicationInfo.Deaths;
			backups[PI[ID].backupLink].BU_Frags = Other.PlayerReplicationInfo.Score;
			//latest name
			backups[PI[ID].backupLink].BU_PlayerName = Other.PlayerReplicationInfo.PlayerName;
		}
	}
	//stop the player; as no carcass will be spawned
	if(!bCarcasses)
		Other.SetPhysics(PHYS_None);
}
//====================================
// PreventDeath - catch deaths through !bIsPlayer - like Pupae / ~ same as ScoreKill
//====================================
function bool PreventDeath(Pawn Killed, Pawn Killer, name damageType, vector HitLocation)
{
	local int ID;
	local TournamentPlayer Player;

	if(Killer != None && !Killer.bIsPlayer)
	{
		ID = FindPlayer(Killed);

		if(ID != -1)
		{
			PI[ID].RI.Runs ++;
			PI[ID].RI.bNeedsRespawn = True;
			Killed.AttitudeToPlayer = ATTITUDE_Follow;

			//try backup
			if(!bStandalone && PI[ID].backupLink != -1)
			{
				backups[PI[ID].backupLink].BU_Runs = PI[ID].RI.Runs;
				backups[PI[ID].backupLink].BU_Deaths = Killed.PlayerReplicationInfo.Deaths;
				backups[PI[ID].backupLink].BU_Frags = Killed.PlayerReplicationInfo.Score;
				//latest name
				backups[PI[ID].backupLink].BU_PlayerName = Killed.PlayerReplicationInfo.PlayerName;
			}
		}
		if(!bCarcasses && Killed.bIsPlayer)
			Killed.SetPhysics(PHYS_None);
	}

	if(Killed.bIsPlayer && Killed.PlayerReplicationInfo.bIsSpectator)
	{
		Super.PreventDeath(Killed, Killer, damageType, HitLocation);
		return True;
	}
	if ( NextMutator != None )
		return NextMutator.PreventDeath(Killed,Killer, damageType,HitLocation);
	return false;
}
//====================================
function WinnerName()
{
	local TournamentPlayer BestPlayer;

	if (BestTeam == 1337)
	{
		if (DeathMatchPlus(Level.Game).MaxPlayers == 2)
			GRI.WinnerText = "Players are Tied";
		else
			GRI.WinnerText = "Teams are Tied";
	}
	else
	{
		if (DeathMatchPlus(Level.Game).MaxPlayers == 2)
		{
			ForEach AllActors(class'TournamentPlayer', BestPlayer)
				if (BestPlayer.PlayerReplicationInfo.Team == BestTeam)
					break;

			GRI.WinnerText = BestPlayer.PlayerReplicationInfo.PlayerName $ " wins the Match!";
		}
		else
		{
			if (BestTeam == 0)
				GRI.WinnerText = "Red team wins the Match!";
			else
				GRI.WinnerText = "Blue team wins the Match!";
		}
	}
}
//====================================
function GameEndTimeMessage()
{
	local TournamentGameReplicationInfo TGRI;
	local int GameDuration, gdr, gdr2, C;
	local string ed1, ed2;

	if (Level.Game.GameReplicationInfo != None)
		TGRI = TournamentGameReplicationInfo(Level.Game.GameReplicationInfo);

	if (GRI.TimeLimit > 0)
	{
		GameDuration = (GRI.TimeLimit * 60) - GRI.RemainingTime;
		if (SuddenDeathTimer != 0)
			GameDuration += Level.TimeSeconds - SuddenDeathTimer;
		gdr = GameDuration/60;
		gdr2 = GameDuration - (60 * gdr);
	}
	else
	{
		GameDuration = GRI.ElapsedTime;
		gdr = GameDuration/60;
		gdr2 = GameDuration - (60 * gdr);
	}

	if (gdr == 0)
		ed1 = "00";
	if (gdr > 0 && gdr < 10)
		ed1 = "0" $ gdr;
	if (gdr > 9 && gdr < 60)
		ed1 = "" $ gdr;

	if (gdr2 < 0)
		ed2 = "" $ GameDuration;
	if (gdr2 >= 0 && gdr2 < 10)
		ed2 = "0" $ gdr2;
	if (gdr2 >= 10 && gdr2 <= 60)
		ed2 = "" $ gdr2;

	if (BestTeam == 1337)
		C = 1337;
	else
		C = 0;

	if (TGRI.Teams[BestTeam - C].Score == 1)
		GRI.EndStatsText = "1 Capture in " $ ed1 $ ":" $ ed2;
	else
		GRI.EndStatsText = int(TGRI.Teams[BestTeam - C].Score) $ " Captures in " $ ed1 $ ":" $ ed2;
	
	BTStatsTimer = ed1 $ ":" $ ed2;
}
//====================================
//HandleEndGame - focus on the player with the best BT score ( CAPS > BESTCAPTIME > DEATHS )
function bool HandleEndGame()
{
	local TournamentGameReplicationInfo TGRI;
	local int i, bestTime, bestCaps, bestRuns;
	local Pawn				P;
	local TournamentPlayer	tp;
	local PlayerPawn		Player;
	local TeamInfo			Best;
	local FlagBase			BestBase;
	local CTFFlag			BestFlag;

	DeathMatchPlus(Level.Game).bDontRestart = True;

	TGRI = TournamentGameReplicationInfo(Level.Game.GameReplicationInfo);
	if ( (TGRI != None) && (TGRI.Teams[0].Score == TGRI.Teams[1].Score) )
	{
		if ( bSuddenDeath )
		{
			if (DeathMatchPlus(Level.Game).bTournament)
				BroadcastMessage("~ Sudden Death ~", false, 'CriticalEvent');
			SuddenDeathTimer = Level.TimeSeconds;
			return false;
		}
	}

	Level.Game.bGameEnded = true;
	GRI.bGameEnded = true;

	//	find winning team
	if (TGRI.Teams[0].Score > TGRI.Teams[1].Score)
		BestTeam = 0;
	else if (TGRI.Teams[0].Score < TGRI.Teams[1].Score)
		BestTeam = 1;
	else if (TGRI.Teams[0].Score == TGRI.Teams[1].Score)
		BestTeam = 1337;

	if (TGRI != None)
	{
		//	look for player with the most amount of caps
		bestCaps = 0;
		for (i = 0; i < 32; i++)
			if ((PI[i].RI != None) && (PI[i].RI.Caps > bestCaps))
				bestCaps = PI[i].RI.Caps;
		//	look for player with the best captime
		bestTime = 0;
		for (i = 0; i < 32; i++)
			if ((PI[i].RI != None) && (PI[i].RI.Caps == bestCaps) && (PI[i].RI.BestTime > bestTime))
				bestTime = PI[i].RI.BestTime;
		//	look for player with the least amount of runs
		bestRuns = 999999999;
		for (i = 0; i < 32; i++)
			if ((PI[i].RI != None) && (PI[i].RI.Caps == bestCaps) && (PI[i].RI.BestTime == bestTime) && (PI[i].RI.Runs - PI[i].RI.Caps < bestRuns))
				bestRuns = PI[i].RI.Runs - PI[i].RI.Caps;
		//	look for the chosen one
		for (i = 0; i < 32; i++)
			if ((PI[i].RI != None) && (PI[i].RI.Caps == bestCaps) && (PI[i].RI.BestTime == bestTime) && (PI[i].RI.Runs - PI[i].RI.Caps == bestRuns))
				focusOn = PI[i].RI.owner;

		//	know the best remaining player now?
		if (focusOn != None)
		{
			//	show to everyone
			for (P = Level.PawnList; P != None; P = P.NextPawn )
			{
				Player = PlayerPawn(P);
				if (Player != None)
				{
					Player.ClientGameEnded();
					Player.GotoState('GameEnded');
					Player.bBehindView = True;
					if (Player == focusOn)
						Player.ViewTarget = None;
					else
						Player.ViewTarget = focusOn;
					if (DeathMatchPlus(Level.Game).bTournament)
					{
						//	winner/loser sound
						tp = TournamentPlayer(Player);
						if(tp != None)
						{
							if (tp.PlayerReplicationInfo.Team == BestTeam || BestTeam == 1337)
								tp.PlayWinMessage(True);
							else
								tp.PlayWinMessage(False);
						}
					}
				}
				//	remove velocity and freeze player
				P.Velocity = vect(0,0,0);
				P.Acceleration = vect(0,0,0);
				P.SetPhysics(PHYS_None);
				P.SetLocation(P.Location);
			}
		}
	}
	WinnerName();
	GameEndTimeMessage();
	BTStats(TGRI.Teams[0].Score, TGRI.Teams[1].Score);
	return false;
}
//====================================
function SetViewTargetz()
{
	local Pawn P;
	local PlayerPawn Player;
	
	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		Player = PlayerPawn(P);
		if (Player != None)
		{
			Player.bBehindView = True;
			if (Player == focusOn)
				Player.ViewTarget = None;
			else
				Player.ViewTarget = focusOn;
		}
	}
}
//====================================
function BTStats(int TeamScore0, int TeamScore1)
{
	local int i;
	local Pawn P;
	local PlayerPawn Player;
	local bool Tie;
	local int winningteam;

	if (TeamScore0 == TeamScore1)
		Tie = true;
	else
	{
		if (TeamScore0 > TeamScore1)
			winningteam = 0;
		else
			winningteam = 1;
	}

	if (DeathMatchPlus(Level.Game).bTournament)
	{
		SendEvent("BTgame", "GameInfo", "MatchMode", "1");
		SendEvent("BTgame", "GameInfo", "PlayerVS", string(DeathMatchPlus(Level.Game).MaxPlayers/2));
		SendEvent("BTgame", "GameInfo", "TimeLimit", GRI.TimeLimit);
		SendEvent("BTgame", "GameInfo", "CapLimit", GRI.CapLimit);

		for (i = 0; i < 32; i++)
		{
			if (PI[i].RI != None)
			{
				SendEvent("BTplay", "AmountRuns", PI[i].PlayerID, PI[i].AmountRuns);
				SendEvent("BTplay", "AmountCaps", PI[i].PlayerID, PI[i].AmountCaps);
				SendEvent("BTplay", "AmountDead", PI[i].PlayerID, PI[i].RI.Runs - PI[i].RI.Caps);
				SendEvent("BTplay", "BoostOther", PI[i].PlayerID, PI[i].BoostOther);
				SendEvent("BTplay", "GotBoosted", PI[i].PlayerID, PI[i].GotBoosted);
				SendEvent("BTplay", "MatchPlus1", PI[i].PlayerID, "1");

				TotalAmountRuns += PI[i].AmountRuns;
				TotalAmountCaps += PI[i].AmountCaps;
				TotalAmountDead += PI[i].RI.Runs - PI[i].RI.Caps;
				TotalBoostOther += PI[i].BoostOther;
				TotalGotBoosted += PI[i].GotBoosted;

				if (PI[i].AmountCaps > 0)
					SendEvent("BTplay", "FastestCap", PI[i].PlayerID, PI[i].RI.BestTimeStr);
				else
					SendEvent("BTplay", "FastestCap", PI[i].PlayerID, "None");

				if (Tie)
				{
					SendEvent("BTplay", "Winneryes", PI[i].PlayerID, "0");
					SendEvent("BTplay", "loseryes", PI[i].PlayerID, "0");
				}
				else
				{
					if (PI[i].myTeam == winningteam)
					{
						SendEvent("BTplay", "Winneryes", PI[i].PlayerID, "1");
						SendEvent("BTplay", "loseryes", PI[i].PlayerID, "0");
					}
					else
					{
						SendEvent("BTplay", "Winneryes", PI[i].PlayerID, "0");
						SendEvent("BTplay", "loseryes", PI[i].PlayerID, "1");
					}
				}
				if (PI[i].PlayerID == CapOfMatchPlayer)
					SendEvent("BTplay", "CotMplayer", PI[i].PlayerID, "1");
				else
					SendEvent("BTplay", "CotMplayer", PI[i].PlayerID, "0");
			}
		}

		for (P = Level.PawnList; P != None; P = P.NextPawn)
		{
			Player = PlayerPawn(P);
			if (Player != None)
			{
				if (Player.PlayerReplicationInfo.bIsSpectator && Player.PlayerReplicationInfo.PlayerName != "Player")
					SendEvent("BTspec", "Spectator", Player.PlayerReplicationInfo.PlayerName);
			}
		}

		SendEvent("BTgame", "GameStats", "MatchTime", BTStatsTimer);
		SendEvent("BTgame", "GameStats", "TotalRuns", TotalAmountRuns);
		SendEvent("BTgame", "GameStats", "TotalCaps", TotalAmountCaps);
		SendEvent("BTgame", "GameStats", "TotalDead", TotalAmountDead);
		SendEvent("BTgame", "GameStats", "TotalBoosts", TotalBoostOther);

		if (TeamScore0 > 0 || TeamScore1 > 0)
		{
			SendEvent("BTgame", "GameStats", "CotMname", GRI.GameBestPlayerName);
			SendEvent("BTgame", "GameStats", "CotMtime", GRI.GameBestTime);
		}
		else
		{
			SendEvent("BTgame", "GameStats", "CotMname", "None");
			SendEvent("BTgame", "GameStats", "CotMtime", "None");
		}
	}
	else
		SendEvent("BTgame", "GameInfo", "MatchMode", "0");
}
//====================================
function BTCapture(Pawn Capper)
{
	local TournamentPlayer	aTPawn;
	local int 				ID, BestTime, BestTimeClient, TimeStampClient, NewTime, TimeStamp;
	local string 			BestTimeClientStr, ctf;
	local float				Stamp;

	aTPawn = TournamentPlayer(Capper);
	if(aTPawn != None)
	{
		Stamp = Level.TimeSeconds;
		ID = FindPlayer(aTPawn);
		PlayerCapped(ID);
		NewTime = MAX_CAPTIME - MeasureTime(ID, Stamp);

		//keep old trick for polycap - protection
		aTPawn.AttitudeToPlayer = ATTITUDE_Follow;

		if(NewTime != MAX_CAPTIME)							// > 0 seconds; else no cap
		{
			TimeStamp = CurTimestamp();						//make the timestamp
			BestTime = GetBestTimeServer(ID);				// on the current map
			BestTimeClient = GetBestTimeClient(ID);			// set in client's user.ini
			BestTimeClientStr = GetBestTimeClientStr(ID);
			TimestampClient = GetTimeStampClient(ID);

			PI[ID].AmountCaps += 1;
			SendEvent("btcap", aTPawn.PlayerReplicationInfo.PlayerID, NewTime, TimeStamp);
			if(newTime > 0)	// IF CAPTIME < 100 MINUTES
			{
				ctf = FormatCentiseconds(NewTime, False);

				if(Capper.PlayerReplicationInfo.Team == 0)
					BroadcastAdd(aTPawn.PlayerReplicationInfo.PlayerName $ " captured the blue flag in " $ ctf);
				else if(Capper.PlayerReplicationInfo.Team == 1)
					BroadcastAdd(aTPawn.PlayerReplicationInfo.PlayerName $ " captured the red flag in " $ ctf);

				if(!GetSTFU(ID))
				{
					aTPawn.ClearProgressMessages();
					aTPawn.SetProgressTime(5);
					aTPawn.SetProgressColor(OrangeColor, 0);
					aTPawn.SetProgressMessage("Cap Time: "$ctf, 0);
				}
				SetBestTime(NewTime, TimeStamp, ID, ctf);
			}
		}
	}
}
//====================================
function ModifyLogin(out class<playerpawn> SpawnClass, out string Portal, out string Options)
{
	if (SpawnClass == class'CHSpectator')
		SpawnClass = class'BTSpectator';

	Portal = "";

	if ( NextMutator != None )
		NextMutator.ModifyLogin(SpawnClass, Portal, Options);
}
//====================================
// ModifyPlayer - Checks for new player and sets some variables
//====================================
function ModifyPlayer(Pawn Other)
{
	local int ID;
	
	if(!GRI.bGameStarted)
		GRI.bGameStarted = true;

	CheckForNewPlayer(); // sometimes modifyplayer is being called faster than a tick where usual new player detection is done thus we have to search for new players also here

	ID = FindPlayer(Other);

	//No bots & ignore waiting players: on gamestart we get another call
	if(ID == -1 || !Other.IsA('TournamentPlayer') || Other.PlayerReplicationInfo.bWaitingPlayer)
	{
		if ( NextMutator != None )
			NextMutator.ModifyPlayer(Other);
		return;
	}

	//allow grab/cap again
	if(PI[ID].RI.bNeedsRespawn)
	{
		Other.PlayerReplicationInfo.HasFlag = None;
		Other.AttitudeToPlayer = ATTITUDE_Hate;

		PI[ID].RI.bNeedsRespawn = False;//new run -> ready to take the enemy's flag
		PI[ID].RI.lastCap = 0;//get normal timer back on scoreboard/HUD

		Other.SetCollision(Other.Default.bCollideActors);
		Other.bBlockPlayers = True;

		//protected: only once after cap/death
		PI[ID].StartTime = Level.TimeSeconds;//TIME MEASUREMENT STARTS HERE
		PI[ID].RI.runtime_offset = 0;

		Other.bHidden = False; // hidden was set after the cap in class'FlagDisposer' in order to prevent some bugs in showing the player @todo -> is reset @ restartplayer?
		PI[ID].myTeam = Other.PlayerReplicationInfo.Team;
	}
	else if(Other.PlayerReplicationInfo.Deaths == 0 && PI[ID].RI.Runs == 0)
	{
		if(!PI[ID].bStartedFirstRun)
		{
			PI[ID].bStartedFirstRun = True;
			PI[ID].StartTime = Level.TimeSeconds;//TIME MEASUREMENT STARTS HERE
			PI[ID].myTeam = Other.PlayerReplicationInfo.Team;
			PI[ID].RI.runtime_offset = 0;
		}
		else if(!TimerBugTriggered)//debug: current try should show this message but prevent the bug
		{
			TimerBugTriggered = True;
			Warn("TimerBug triggered [1]");
		}
	}
	else if(!TimerBugTriggered)//debug: current try should show this message but prevent the bug
	{
		TimerBugTriggered = True;
		Warn("TimerBug triggered [2]");
	}

	PI[ID].AmountRuns += 1;	// BTstats

	//like btcp: do & pass on after that
	if ( NextMutator != None )
		NextMutator.ModifyPlayer(Other);
}
//====================================
function string ParseDelimited(string Text, string Delimiter, int Count, optional bool bToEndOfLine)
{
	local string Result;
	local int Found, i;
	local string s;

	Result = "";
	Found = 1;

	for(i=0;i<Len(Text);i++)
	{
		s = Mid(Text, i, 1);
		if(InStr(Delimiter, s) != -1)
		{
			if(Found == Count)
			{
				if(bToEndOfLine)
					return Result$Mid(Text, i);
				else
					return Result;
			}
			Found++;
		}
		else
		{
			if(Found >= Count)
				Result = Result $ s;
		}
	}
	return Result;
}
//====================================
// MutatorTeamMessage - Allows changing antiboost status also with normal say messages
//====================================
function bool MutatorTeamMessage(Actor Sender, Pawn Receiver, PlayerReplicationInfo PRI, coerce string S, name Type, optional bool bBeep)
{
	local int ID;

	if(Sender == Receiver)
	{
		if(ParseDelimited(S, " ", 1) ~= "!help")
			HelpMessage(PlayerPawn(Receiver));

		if(S ~= "!BT")
		{
			if(BTSpectator(Sender) != None)
				OpenSettingsWindow(PlayerPawn(Sender));
			else
				PlayerPawn(Sender).ClientMessage("This command is for Spectators only");
		}
		else if(Sender.IsA('TournamentPlayer'))
		{
			ID = FindPlayer(PlayerPawn(Sender));

			if(PI[ID].Config.bAntiBoost && S ~= "BOOST")
				SetAntiBoostOff(PlayerPawn(Sender), ID);
			else if(!PI[ID].Config.bAntiBoost && S ~= "NOBOOST")
				SetAntiBoostOn(PlayerPawn(Sender), ID);
			else if(S ~= "!nextstart" || S ~= "!nextspawn" || S ~= "nextspawn" || S ~= "nextstart")
				nextStart(PlayerPawn(Sender), ID);
			else if(S ~= "!prevstart" || S ~= "!prevspawn" || S ~= "prevspawn" || S ~= "prevstart")
				prevStart(PlayerPawn(Sender), ID);
			else if(S ~= "!mystart" || S ~= "mystart")
				newMyStart(PlayerPawn(Sender), ID);
			else if(S ~= "!clearstart" || S ~= "clearstart")
				clearMyStart(PlayerPawn(Sender), ID);
		}
	}

	if(NextMessageMutator != None)
		return NextMessageMutator.MutatorTeamMessage( Sender, Receiver, PRI, S, Type, bBeep );
	else
		return true;
}
function bool MutatorBroadcastMessage(Actor Sender, Pawn Receiver, out coerce string Msg, optional bool bBeep, out optional name Type)
{
	if(Sender == Receiver)
	{
		if(Right(Msg, 3) ~= "!BT")
		{
			if(BTSpectator(Sender) != None)
				OpenSettingsWindow(PlayerPawn(Sender));
			else
				PlayerPawn(Sender).ClientMessage("This command is for Spectators only");
		}
	}

	if(NextMessageMutator != None)
		return NextMessageMutator.MutatorBroadcastMessage(Sender, Receiver, Msg, bBeep, Type);
	else
		return true;
}
//====================================
// OpenSettingsWindow
//====================================
function OpenSettingsWindow(PlayerPawn Sender)
{
	local BT_WRI BTWRI;
	local BT_WRI A;

	foreach AllActors(class'BT_WRI', A)
		if(Sender == A.Owner)
			return;

	BTWRI = Spawn(class'BT_WRI', Sender, , Sender.Location);

	if(BTWRI == None)
	{
		Log("#### -- PostLogin :: Fail:: Could not spawn WRI");
		return;
	}

	BTWRI.BTCS = SI[FindSpec(Sender)].BTCS;
}
function HelpMessage(PlayerPawn Sender)
{
	Sender.ClientMessage("*************************************************");
	Sender.ClientMessage(" - !Cp");
	Sender.ClientMessage("Set a CheckPoint at your current location");
	Sender.ClientMessage(" - !Nocp");
	Sender.ClientMessage("Delete your CheckPoint");
	Sender.ClientMessage(" - !Moveto <PlayerName>");
	Sender.ClientMessage("Set a CheckPoint at a Player's location");
	Sender.ClientMessage("*************************************************");
}
//====================================
// Mutate - Shows help, allows to change the settings and provides an interface to searching the record database
//====================================
function Mutate(string MutateString, PlayerPawn Sender)
{
	local string CommandString;
	local string ValueString;
	local string TempString;
	local int i, j, ID, k, index;
	local bool notDone;
	local float x;

	if ( NextMutator != None )
		NextMutator.Mutate(MutateString, Sender);

	if(!Sender.PlayerReplicationInfo.bIsSpectator)
	{
		ID = FindPlayer(Sender);
		if(ID == -1)
		{
			Log("can't find player ");
			return;
		}
		switch(Caps(MutateString))
		{
			case "nextspawn":
			case "nextstart":
				nextStart(Sender, ID);
			break;

			case "prevspawn":
			case "prevstart":
				prevStart(Sender, ID);
			break;

			case "mystart":
				newMyStart(Sender, ID);
			break;

			case "clearstart":
				clearMyStart(Sender, ID);
			break;

			case "TRANSPARENTSELF":
				TransparentSelf(TournamentPlayer(Sender));
			break;

			case "BOOST":
				if(PI[ID].Config.bAntiBoost)
					SetAntiBoostOff(Sender, ID);
			break;

			case "NOBOOST":
				if(!PI[ID].Config.bAntiBoost)
					SetAntiBoostOn(Sender, ID);
			break;

			case "NOBTHUD":
				PI[ID].Config.SetBTHud(False);
			break;
			case "BTHUD":
				PI[ID].Config.SetBTHud(True);
			break;

			case "BTSTFU":
				if(PI[ID].Config.bSTFU)
				{
					Sender.ClientMessage("Already set.");
				}
				else
					Sender.ClientMessage("So be it! BTPlusPlus won't say a word to you. 'mutate btnostfu' would make me speak again.");
				PI[ID].Config.SetSTFU(True);
			break;

			case "BTNOSTFU":
				if(!PI[ID].Config.bSTFU)
				{
					Sender.ClientMessage("Already set.");
				}
				else
					Sender.ClientMessage("Yeah, you allowed me to speak again.");
				PI[ID].Config.SetSTFU(False);
			break;

			case "MYRECS"://show ALL personal records
				PI[ID].Config.FindAll(lastTimestamp);
			break;

			case "DELETETHISREC":
				if(PI[ID].Config.BestTime != class'ClientData'.Default.BestTime)
				{
					//serverside
					PI[ID].Config.BestTime = class'ClientData'.Default.BestTime;
					PI[ID].Config.BestTimeStr = class'ClientData'.Default.BestTimeStr;
					PI[ID].Config.Timestamp = class'ClientData'.Default.Timestamp;
					//clientside
					PI[ID].Config.DeleteRecord();
					//also the game-best time
					PI[ID].RI.BestTime = 0;
					PI[ID].RI.BestTimeStr = "";

					//backup -> delete game-best-time
					if(!bStandalone && PI[ID].backupLink != -1)
					{
						backups[PI[ID].backupLink].BU_BestTime = 0;
						backups[PI[ID].backupLink].BU_BestTimeStr = "";
						//latest name
						backups[PI[ID].backupLink].BU_PlayerName = PI[ID].Player.PlayerReplicationInfo.PlayerName;
					}
					Sender.ClientMessage("Your record on this map is deleted");
				}
			break;

			default:
				notDone = True;
			break;
		}

		if(!notDone)
			return;//done -> don't go on

		//search own records by mapname
		if(Left(MutateString, 7) ~= "MYRECS ")
		{
			CommandString = Mid(MutateString, 7);
			if(Len(CommandString) > 0)
				PI[ID].Config.FindByMap(CommandString, lastTimestamp);
			else
				Sender.ClientMessage("No empty space after myrecs or append a substring of a mapname");
			return;
		}
		else if(Left(MutateString, 10) ~= "MYOLDRECS ")
		{
			i = int(Mid(MutateString, 10));
			if(i > 0)
				PI[ID].Config.FindByAge(i, lastTimestamp);
			return;
		}
	}
	else
	{
		if(Caps(MutateString) == "AUTOBEHINDVIEW")
			ToggleAutoBehindview(Sender);
		if(Caps(MutateString) == "BTE")
			OpenSettingsWindow(Sender);
	}

	notDone = False;
	//simple info queries (spectators too)
	switch(Caps(MutateString))
	{
		case "BTSETTINGS":
			Sender.ClientMessage("BTPlusPlus Settings:");
			SendSettings(Sender);
		break;
		case "BTHELP":
		case "BT++HELP":
		case "BTPPHELP":
			Sender.ClientMessage("BTPlusPlus Client Commands (type directly in console or bind to key):");
			Sender.ClientMessage("Mutate +");
			if(bSaveRecords)
				Sender.ClientMessage("- records map/records player ... (Search for time records on current server)");
			Sender.ClientMessage("- myRecs (show all your records)");
			Sender.ClientMessage("- myRecs ... (your records matching the mapname filter ...)");
			Sender.ClientMessage("- myOldRecs X (show all your records that are at least X day(s) old)");
			Sender.ClientMessage("- deleteThisRec (delete your record on this map - only on your side. Server records are not affected)");
			Sender.ClientMessage("- bthud (Display BT HUD)");
			Sender.ClientMessage("- nobthud (Hide BT HUD)");
			Sender.ClientMessage("- btstfu (Mute BTPlusPlus messages)");
			Sender.ClientMessage("- btnostfu (Unmute BTPlusPlus messages)");
			Sender.ClientMessage("- btsettings (Reveal BTPlusPlus configuration)");
			Sender.ClientMessage("- bthelp (Show this help)");
			Sender.ClientMessage("For admins:");
			Sender.ClientMessage("- BTPP (BTPlusPlus settings)");
			HelpMessage(Sender);
		break;
		default:
			notDone = True;
		break;
	}

	if(!notDone)
		return;//done -> don't go on

	//admin stuff
	if(Left(MutateString, 4) ~= "BTPP" && !Sender.bAdmin )
		Sender.ClientMessage("You cannot set BTPlusPlus until you're a serveradmin.");
	else if(Left(MutateString, 4) ~= "BTPP" && Sender.bAdmin)
	{
		if(Left(MutateString, 4) ~= "BTPP" && Len(MutateString)==4)
		{
			Sender.ClientMessage("BTPlusPlus Tournament - Configuration menu:");
			Sender.ClientMessage("Settings:");
			SendSettings(Sender);
			Sender.ClientMessage("To set something type 'mutate btpp <option> <value>'.");
			Sender.ClientMessage("Turn BTPlusPlus On/Off: 'mutate btpp enabled/disabled'.");
		}
		else if(Left(MutateString, 5) ~= "BTPP ")
		{
			CommandString = Mid(MutateString, 5);

			if(Left(CommandString, 10) ~= "DELETEREC ")
			{
				TempString = Mid(CommandString, 10);
				if(SR.DeleteRecord(TempString))//in file
				{
					Sender.ClientMessage("Record gone.");
					//so record of the current map is gone?
					if(TempString ~= LevelName)
					{
						//in current game
						MapBestTime = Default.MapBestTime;
						MapBestPlayer = Default.MapBestPlayer;
						//show that now there is no record
						GRI.MapBestAge = class'BTPPGameReplicationInfo'.Default.MapBestAge;
						GRI.MapBestTime = class'BTPPGameReplicationInfo'.Default.MapBestTime;
						GRI.MapBestPlayer = class'BTPPGameReplicationInfo'.Default.MapBestPlayer;
						//also reset the cap-of-the-game
						GRI.GameBestTimeInt = class'BTPPGameReplicationInfo'.Default.GameBestTimeInt;
						GRI.GameBestTime = class'BTPPGameReplicationInfo'.Default.GameBestTime;
						GRI.GameBestPlayerName = class'BTPPGameReplicationInfo'.Default.GameBestPlayerName;
					}
				}
				else
					Sender.ClientMessage("No record found - give full mapname - browse with 'mutate records map'");
			}
			else if(Left(CommandString, 8) ~="EDITREC ")
			{
				ValueString = Mid(CommandString, 8);
				//replace in BTPlusPlus.ini
				SR.AddRecord(ValueString, -1, "", CurTimestamp());
				//it's the current map -> edit current vars too; read from the ini
				if(Left(ValueString, Len(LevelName)) ~= LevelName)
				{
					//get index
					i = SR.CheckRecord(LevelName);

					if(i != -1 && SR.getCaptime(i) != 0)
					{
						//get server record ready for usage
						MapBestTime = SR.getCaptime(i);
						MapBestPlayer = SR.getPlayerName(i);

						GRI.MapBestAge = string((lastTimestamp - SR.getTimestamp(i))/86400);//age in whole days(roughly)
						GRI.MapBestTime = FormatCentiseconds(MapBestTime, False);
						GRI.MapBestPlayer = MapBestPlayer;
					}
				}
				Sender.ClientMessage("changed record");
			}
			SaveConfig();
		}
		return;
	}
	if(Left(MutateString, 8) ~= "RECORDS " && bSaveRecords)
	{
		CommandString = Mid(MutateString, 8);
		if(Left(CommandString, 4) ~= "MAP ")
		{
			ValueString = Mid(CommandString, 4);
			if(Len(ValueString) > 1)
				SR.FindByMap(Sender, ValueString, lastTimestamp);//probably not the current timestamp but well enough 
			else
				Sender.ClientMessage("Sorry, the specified string is too short.");
		}
		else if(Left(CommandString, 3) ~= "MAP")
		{
			Sender.ClientMessage("Searches database for map records by map name.");
			Sender.ClientMessage("Use command 'mutate records map <mapname>'");
			Sender.ClientMessage("   Note: It will find all records containing the specified string.");
		}
		else if(Left(CommandString, 7) ~= "PLAYER ")
		{
			ValueString = CleanName(Mid(CommandString, 7));
			if(Len(ValueString) > 1)
				SR.FindByPlayer(Sender, ValueString, lastTimestamp);
			else
				Sender.ClientMessage("Sorry, the specified string is too short.");
		}
		else if(Left(CommandString, 6) ~= "PLAYER")
		{
			Sender.ClientMessage("Searches database for map records by player name.");
			Sender.ClientMessage("Use command 'mutate records map <player>'");
			Sender.ClientMessage("   Note: It will find all records made by players containing the specified string in the name.");
		}
		else
		{
			Sender.ClientMessage("You can do database searches for map records here.");
			Sender.ClientMessage("It can be done in two ways:");
			Sender.ClientMessage("A) By Map - command 'mutate records map <mapname>'");
			Sender.ClientMessage("B) By Player - command 'mutate records player <player>'");
			Sender.ClientMessage("   Note: It will find all records containing the specified string.");
		}
	}
	else if(Left(MutateString, 7) ~= "RECORDS" && bSaveRecords)
	{
		Sender.ClientMessage("You can do database searches for map records here.");
		Sender.ClientMessage("It can be done in two ways:");
		Sender.ClientMessage("A) By Map - command 'mutate records map <mapname>'");
		Sender.ClientMessage("B) By Player - command 'mutate records player <player>'");
		Sender.ClientMessage("   Note: It will find all records containing the specified string.");
	}
}
//====================================
// SetAntiBoostOn - Enables AntiBoost for a specified Pawn
// Triggered in: MutatorTeamMessage, Mutate
//====================================
function SetAntiBoostOn(Pawn P, int ID)
{
	if(DeathMatchPlus(Level.Game).bTournament)
	{
		P.ClientMessage("This command is not allowed in Tournament mode!");
	}
	else
	{
		P.ClientMessage("You can't be boosted from now on!");
		PI[ID].Config.SetAntiBoost(True);
	}
}
//====================================
// SetAntiBoostOff - Disables AntiBoost for a specified Pawn
// Triggered in: MutatorTeamMessage, Mutate
//====================================
function SetAntiBoostOff(Pawn P, int ID)
{
	if(DeathMatchPlus(Level.Game).bTournament)
	{
		P.ClientMessage("This command is not allowed in Tournament mode!");
	}
	else
	{
		P.ClientMessage("You can now be boosted !");
		PI[ID].Config.SetAntiBoost(False);
	}
}
//====================================
// SendSettings - Sends current server settings - helper for Mutate
// Triggered in: Mutate
//====================================
function SendSettings(Pawn Sender)
{
	Sender.ClientMessage("	bSuddenDeath="$string(bSuddenDeath));
	Sender.ClientMessage("	bCarcasses="$string(bCarcasses));
	Sender.ClientMessage("	bSaveRecords="$string(bSaveRecords));
	Sender.ClientMessage("	CountryFlagsPackage="$CountryFlagsPackage);
	Sender.ClientMessage("	bEnableCheckpointsInPracticeMode="$string(bEnableCheckpointsInPracticeMode));
	Sender.ClientMessage("	bShowNewRecordsInTournamentMode="$string(bShowNewRecordsInTournamentMode));
}
//====================================
function PlayerSpawned(Pawn P, PlayerStart PS)
{
	local int i;

	i = FindPlayer(P);
	if(i == -1)
		return;
	PI[i].lastStart = PS;
}
//====================================
function PlayerStart getMyStart(Pawn P)
{
	local int i;

	i = FindPlayer(P);
	if(i == -1)
		return(None);
	return(PI[i].side[PlayerPawn(P).PlayerReplicationInfo.Team].myStart);
}
//====================================
function extractMystart(string info, PlayerPawn PP)
{
	local int i, red, blue;

	i = FindPlayer(PP);
	if(i == -1)
		return;

	red = getPlayerStartNumber(0, info);
	blue = getPlayerStartNumber(1, info);

	if(red >= 0 && red < 32)
		PI[i].side[0].myStart = PS_Team[0].PS[red];
	else
		PI[i].side[0].myStart = None;

	if(blue >= 0 && blue < 32)
		PI[i].side[1].myStart = PS_Team[1].PS[blue];
	else
		PI[i].side[1].myStart = None;

	manageMyStartIndicator(PP);
}
//====================================
function int getPlayerStartNumber(int team, string info)
{
	local int pos;

	pos = InStr(info, ":");
	if(pos == -1)
		return(-1);
	else if(team == 0)
		return(int(Left(info, pos)));
	else if(team == 1)
		return(int(Right(info, Len(info) - pos - 1)));
	else return(-1);
}
//====================================
function nextStart(PlayerPawn PP, int i)
{
	local int team, idx;
	local PlayerStart newPS;

	team = PP.PlayerReplicationInfo.Team;

	if(PI[i].side[team].myStart == None)
		newPS = PS_Team[team].PS[0];
	else
	{
		for(idx = 0; idx < 32; idx++)
			if(PS_Team[team].PS[idx] == PI[i].side[team].myStart)
				break;

		idx++;
		if(idx >= 32 || PS_Team[team].PS[idx] == None)
			idx = 0;

		newPS = PS_Team[team].PS[idx];
	}

	PI[i].side[team].myStart = newPS;
	newMyStartMessage(PP, newPS);
	saveMyStart(PP, i);
}
//====================================
function prevStart(PlayerPawn PP, int i)
{
	local int team, idx, z;
	local PlayerStart newPS;

	team = PP.PlayerReplicationInfo.Team;

	if(PI[i].side[team].myStart == None)
		newPS = PS_Team[team].PS[0];
	else
	{
		for(idx = 0; idx < 32; idx++)
			if(PS_Team[team].PS[idx] == PI[i].side[team].myStart)
				break;

		idx--;
		if(idx < 0 || PS_Team[team].PS[idx] == None)
		{
			for(z = 31; z >= 0; z--)
				if(PS_Team[Team].PS[z] != None)
					break;
			idx = z;
		}

		newPS = PS_Team[team].PS[idx];
	}

	PI[i].side[team].myStart = newPS;
	newMyStartMessage(PP, newPS);
	saveMyStart(PP, i);
}
//====================================
function newMyStart(PlayerPawn PP, int i)
{
	local int team;

	team = PP.PlayerReplicationInfo.Team;

	if(PI[i].lastStart == None || PI[i].lastStart.TeamNumber != team)
	{
		PP.ClientMessage("Please respawn first");
		return;
	}

	PI[i].side[team].myStart = PI[i].lastStart;
	newMyStartMessage(PP, PI[i].lastStart);
	saveMyStart(PP, i);
}
//====================================
function saveMyStart(PlayerPawn PP, int i)
{
	local string text;
	local int idx, red, blue;

	red = -1;
	blue = -1;

	for(idx = 0; idx < 32; idx++)
	{
		if(PS_Team[0].PS[idx] != None && PS_Team[0].PS[idx] == PI[i].side[0].myStart)
			red = idx;
		if(PS_Team[1].PS[idx] != None && PS_Team[1].PS[idx] == PI[i].side[1].myStart)
			blue = idx;
	}

	text = red $ ":" $ blue;
	PI[i].BTCS.saveMyStart(text);
	manageMyStartIndicator(PP);
}
//====================================
function clearMyStart(PlayerPawn PP, int i)
{
	PI[i].side[PP.PlayerReplicationInfo.Team].myStart = None;
	removeMyStartMessage(PP);
	saveMyStart(PP, i);
}
//====================================
function removeMyStartMessage(PlayerPawn PP)
{
	local string team;

	if(PP.PlayerReplicationInfo.Team == 0)
		team = "Red";
	else
		team = "Blue";

	PP.ClientMessage(team $ " mystart removed");
}
//====================================
function newMyStartMessage(PlayerPawn PP, PlayerStart PS)
{
	local string team, name;
	local int pos;

	if(PP.PlayerReplicationInfo.Team == 0)
		team = "Red";
	else
		team = "Blue";

	pos = InStr(PS, ".");
	name = Right(PS, len(PS) - pos - 1);

	PP.ClientMessage("New mystart on " $ team $ ": " $ name);
}
//====================================
function manageMyStartIndicator(PlayerPawn PP)
{
	local int i, team;
	local PlayerStart mystart;

	i = FindPlayer(PP);
	if(i == -1)
		return;

	team = PP.PlayerReplicationInfo.Team;
	mystart = PI[i].side[team].myStart;

	if(PI[i].MI != None)
	{
		PI[i].MI.Destroy();
		if(mystart != None)
			PI[i].MI = spawn(class'MyStart_Indicator', PP,, mystart.Location, mystart.Rotation);
	}
	else if(mystart != None)
	{
		PI[i].MI = spawn(class'MyStart_Indicator', PP,, mystart.Location, mystart.Rotation);
	}
}
function ToggleAutoBehindview(PlayerPawn PP)
{
	local int i;

	i = FindSpec(PP);
	if(i == -1)
		return;

	SI[i].BTCS.SwitchBool("bBehindviewFollow");
}
function TransparentSelf(TournamentPlayer TP)
{
	local int i;

	i = FindPlayer(TP);
	if(i == -1)
		return;

	PI[i].BTCS.TransparentSelf(TP);
}
//#########################################################################
//### OTHER FUNCTIONS - couldn't find a place for them(yet)
//#########################################################################
//====================================
// CurTimestamp - returns current timestamp/unixtime
//====================================
function int CurTimestamp()
{
	lastTimestamp = timestamp(Level.Year, Level.Month, Level.Day, Level.Hour, Level.Minute, Level.Second);
	return lastTimestamp;
}
//====================================
// timestamp - returns timestamp/unixdate for a specified date
//====================================
static final function int timestamp(int year, int mon, int day, int hour, int min, int sec)
{
	//	Origin of the algorithm below:
	//		Linux Kernel <time.h>
	mon -= 2;
	if (mon <= 0) {	/* 1..12 -> 11,12,1..10 */
		mon += 12;	/* Puts Feb last since it has leap day */
		year -= 1;
	}
	return ((((year/4 - year/100 + year/400 + 367*mon/12 + day) + year*365 - 719499
		)*24 + hour	/* now have hours */
		)*60 + min	/* now have minutes */
		)*60 + sec;	/* finally seconds */
}
//====================================
// timestamp - just in case of destuction, it's better to clean up the stuff and unlink self
// Inherited from class'Actor'
//====================================
function Destroyed()
{
	local Mutator M;
	
	if ( Level.Game != None )
	{
		if ( Level.Game.BaseMutator == Self )
			Level.Game.BaseMutator = NextMutator;
		if ( Level.Game.DamageMutator == Self )
			Level.Game.DamageMutator = NextDamageMutator;
		if ( Level.Game.MessageMutator == Self )
			Level.Game.MessageMutator = NextMessageMutator;
	}
	ForEach AllActors(Class'Engine.Mutator', M)
	{
		if ( M.NextMutator == Self )
			M.NextMutator = NextMutator;
		if ( M.NextDamageMutator == Self )
			M.NextDamageMutator = NextDamageMutator;
		if ( M.NextMessageMutator == Self )
			M.NextMessageMutator = NextMessageMutator;
	}
}
//====================================
// GetItemName - provides various information to actors not linked with BT++ directly
// Triggered in: class'SuperShockRifleBT'.ProcessTraceHit and any other actor talking with BT++
// Inherited from class'Actor'
//====================================
function string GetItemName(string Input)
{
	local int temp, PlayerID;
	local string retstr;

	if(Left(Input, 4) ~= "get ")
	{
		Input = Mid(Input, 4);
		PlayerID = int(SelElem(Input, 2, " "));
		switch(SelElem(Caps(Input), 1, " "))
		{
			case "CAPS":
				return string(PI[FindPlayerByID(PlayerID)].RI.Caps);
			case "RUNS":
				return string(PI[FindPlayerByID(PlayerID)].RI.Runs);
			case "EFF":
				temp = FindPlayerByID(PlayerID);
				if(PI[temp].RI.Runs > 0)
					return string(int(float(PI[temp].RI.Caps)/float(PI[temp].RI.Runs)*100.0));
				else
					return "0";
			default:
				return "error";
		}
	}
}
//====================================
event Touch(Actor A)
{
	local int i;

	if(EventHandlersCount == 10)
		A.GetItemName("-1,event handlers number exceeded");

	for(i=0;i<EventHandlersCount+1;i++)
	{
		if(EventHandlers[i] == None)
		{
			EventHandlers[i] = A;
			A.GetItemName("0,registration successful");
			EventHandlersCount++;
		}
	}
}
//====================================
// SendEvent - Sends custom events to all registered actors
//====================================
function SendEvent(string EventName, optional coerce string Arg1, optional coerce string Arg2, optional coerce string Arg3, optional coerce string Arg4)
{
	local int i;
	local string Event;

	if (Level.Game.LocalLog != None)
		Level.Game.LocalLog.LogSpecialEvent(EventName, Arg1, Arg2, Arg3, Arg4);

	Event = EventName;
	if(Arg1 != "")
		Event = Event$chr(9)$Arg1;
	if(Arg2 != "")
		Event = Event$chr(9)$Arg2;
	if(Arg3 != "")
		Event = Event$chr(9)$Arg3;
	if(Arg4 != "")
		Event = Event$chr(9)$Arg4;

	for(i=0;i<EventHandlersCount+1;i++)
		if(EventHandlers[i] != None)
			EventHandlers[i].GetItemName(Event);
}
//====================================
event BroadcastAdd(coerce string Msg, optional bool bBeep, optional name Type)
{
	local Pawn P;

	if (Type == '')
		Type = 'Event';

	for( P=Level.PawnList; P!=None; P=P.nextPawn )
		if (P.IsA('PlayerPawn'))
			P.ClientMessage( Msg, Type, bBeep );
}
//====================================
defaultproperties
{
	MAX_CAPTIME=600000
	MapBestPlayer="N/A"
	OrangeColor=(R=255,G=88)
	bSuddenDeath=True
	bCarcasses=True
	bSaveRecords=True
	CountryFlagsPackage="CountryFlags3"
	bEnableCheckpointsInPracticeMode=True
	bShowNewRecordsInTournamentMode=False
	BoardLabel="BunnyTrack Server"
}