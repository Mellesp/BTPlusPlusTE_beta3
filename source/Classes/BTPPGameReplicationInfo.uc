/*
	BTPlusPlus Tournament is an improved version of BTPlusPlus 0.994
	Flaws have been corrected and extra features have been added
	BT++ Tournament Edition is created by OwYeaW

	BTPlusPlus 0.994
	Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

	This program is free software; you can redistribute and/or modify
	it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTPPGameReplicationInfo expands ReplicationInfo;
/* class holding global information needed by the class'BTPPHUDMutator' and class'BTScoreboard' */

// variables needed by either BTScoreboard or BTPPHUDMutator, set by class'BTPlusPlus'
var string	CountryFlagsPackage;
var string	MapBestPlayer;
var string	MapBestTime;
var string	MapBestAge;
var string	BestTimeStr;
var string	BoardLabel;
var string	EndStatsText;
var string	WinnerText;
var string 	GameBestTime;
var string 	GameBestPlayerName;
var byte 	GameBestPlayerTeam;
var int 	GameBestTimeInt;
var int 	CapLimit;
var int		TimeLimit;
var int		RemainingTime;
var int		ElapsedTime;
var int		MaxPlayers;
var bool	bTournament;
var bool	bGameEnded;
var bool	bGameStarted;

replication
{
	reliable if (ROLE == ROLE_Authority)
		MapBestTime,
		MapBestPlayer,
		MapBestAge,
		CountryFlagsPackage,
		GameBestTime,
		GameBestPlayerName,
		GameBestPlayerTeam,
		BestTimeStr,
		CapLimit,
		TimeLimit,
		RemainingTime,
		ElapsedTime,
		MaxPlayers,
		bTournament,
		bGameEnded,
		BoardLabel,
		bGameStarted,
		EndStatsText,
		WinnerText;
}

defaultproperties
{
	MapBestTime="-:--"
	MapBestPlayer="N/A"
	BestTimeStr="-:--"
	MapBestAge="0"
	CountryFlagsPackage="CountryFlags3"
	NetPriority=9.000000
	bGameEnded=False
}