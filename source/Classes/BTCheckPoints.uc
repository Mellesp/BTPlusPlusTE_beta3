/*
	BTPlusPlus Tournament is an improved version of BTPlusPlus 0.994
	Flaws have been corrected and extra features have been added
	BT++ Tournament Edition is created by OwYeaW

	BTPlusPlus 0.994
	Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

	This program is free software; you can redistribute and/or modify
	it under the terms of the Open Unreal Mod License version 1.1.
*/
/*##################################################################################################
##
##  BTCheckPoints 1.0
##  Copyright (C) 2010 Patrick "Sp0ngeb0b" Peltzer
##
##  This program is free software; you can redistribute and/or modify
##  it under the terms of the Open Unreal Mod License version 1.1.
##
##  Contact: spongebobut@yahoo.com | www.unrealriders.de
##
##
##################################################################################################*/
class BTCheckPoints extends Mutator;

struct BTPlayers						// Structure of our BTPlayers
{
  	var PlayerPawn BTPP;				// The PlayerPawn
    var CheckPoint CP;					// Their Checkpoint (if they have one)
    var int CurrTeam;					// Team number player is currently in
    var bool switchedTeamsThisTick;
};
var BTPlayers BTP[32];

struct PlayerInfo
{
	var PlayerReplicationInfo	PRI;
	var BTPPReplicationInfo		RI;
};
var PlayerInfo PI[32];
/*~~~~~~~~~~~
~ VARIABLES ~
~~~~~~~~~~~~*/
var bool Initialized;					// Whether we initialized
var bool Nexgen;						// Whether the server is running Nexgen
var int	IndexX;
var BTPPReplicationInfo RI;
/*##################################################################################################
##
## replication -> Client replication
##
##################################################################################################*/
replication
{
	reliable if (role == ROLE_Authority) // Replicate structure to client if needed
		BTP;
}
/*##################################################################################################
# #################################################################################################
# #
# # GAME FUNCTIONS
# #
# #################################################################################################
##################################################################################################*/
/*##################################################################################################
##
## PreBeginPlay -> Register mutator and check for coop mutators
##
##################################################################################################*/
function PreBeginPlay()
{
	local string ServerActors;

	if(!Initialized)
	{
		Initialized = !Initialized;

		ServerActors = CAPS(ConsoleCommand("get ini:Engine.Engine.GameEngine ServerActors"));
		if(InStr(ServerActors,"NEXGEN") != -1)
		{
			nexgen = true;
			Log("* Nexgen detected, cooperating mode active");
		}

		// Register mutator
		Level.Game.BaseMutator.AddMutator(self);
		Level.Game.RegisterMessageMutator(Self);
	}
	Super.PreBeginPlay();
}
/*##################################################################################################
##
## Tick -> Checks for left players, team-switchers and is capture preventer.
##
##################################################################################################*/
simulated function Tick(float DeltaTime)
{
	local Pawn P;
	local PlayerPawn PP;
	local int i, z;

	Super.tick(DeltaTime);

	searchForLeftPlayers();

	for(P = Level.PawnList; P != None; P = P.NextPawn )
	{
		if( P.isA('TournamentPlayer') )
		{
			PP = PlayerPawn(P);
			i = GetPlayerIndex(PP);

			// Fix for players beeing stuck after respawning in water
			if(PP.Region.Zone.bWaterZone && PP.Physics != PHYS_Swimming && PP.health > 0 && !PP.PlayerReplicationInfo.bWaitingPlayer && !Level.Game.bGameEnded)
			{
				if (PP.HeadRegion.Zone.bWaterZone)
					PP.PainTime = PP.UnderWaterTime;
				PP.setPhysics(PHYS_Swimming);
				PP.GotoState('PlayerSwimming');
			}
			if(BTP[i].switchedTeamsThisTick)
			{
				BTP[i].CurrTeam = BTP[i].BTPP.PlayerReplicationInfo.Team;
				BTP[i].switchedTeamsThisTick = false;
			}
			else
			{
				if(BTP[i].CurrTeam != BTP[i].BTPP.PlayerReplicationInfo.Team)
					RemoveCheckpoint(PP, true);
				BTP[i].CurrTeam = BTP[i].BTPP.PlayerReplicationInfo.Team;
			}

			// Check whether player has changed his team
			if(BTP[i].CurrTeam != BTP[i].BTPP.PlayerReplicationInfo.Team)
				RemoveCheckpoint(PP, true);
			BTP[i].CurrTeam = BTP[i].BTPP.PlayerReplicationInfo.Team;

			RI = FindInfo(PP.PlayerReplicationInfo, z);
			if(RI.CPUsed)
			{
				PP.AttitudeToPlayer = ATTITUDE_Follow;
				if (PP.PlayerReplicationInfo.HasFlag != none)
				{
					CTFFlag(PP.PlayerReplicationInfo.HasFlag).SendHome();
					PP.PlayerReplicationInfo.HasFlag = None;
					BroadcastMessage(PP.PlayerReplicationInfo.PlayerName $ " has reached the flag with Checkpoints!", true, 'CriticalEvent');
				}
			}
		}
	}
}
/*##################################################################################################
##
## ModifyPlayer -> Handles player respawn
##
##################################################################################################*/
function ModifyPlayer(Pawn Other)
{
	local PlayerPawn PP;
	local int i, z;

	if (!Other.IsA('TournamentPlayer'))
	{
		if (NextMutator != None)
			NextMutator.ModifyPlayer(Other);
		return;
	}

	PP = PlayerPawn(other);
	i = GetPlayerIndex(PP);
	RI = FindInfo(Other.PlayerReplicationInfo, z);

	if (BTP[i].CP != none)
	{
		PP.bBlockPlayers = False;
		RI.CPUsed = true;
		PP.AttitudeToPlayer = ATTITUDE_Follow;

		PP.SetLocation(BTP[i].CP.orgLocation);
		PP.ClientSetRotation(BTP[i].CP.orgRotation);
		PP.viewRotation = BTP[i].CP.orgRotation;
	}
	else
	{
		PP.bBlockPlayers = True;
		RI.CPUsed = false;
		PP.AttitudeToPlayer = ATTITUDE_Hate;
	}

	if (NextMutator != None)
		NextMutator.ModifyPlayer(Other);
}

/*adding */
function ForceRespawn(TournamentPlayer PP)
{
    local int Index;

    Index = GetPlayerIndex(PP);
    PP.Weapon = none;
    Level.Game.PlayTeleportEffect(PP, true, true);
    PP.HidePlayer();
    PP.KilledBy(none);
    PP.bFrozen = false;
    PP.ServerReStartPlayer();
    return;
}

//searches for the BTPP RI by the UT PRI given
function BTPPReplicationInfo FindInfo(PlayerReplicationInfo PRI, out int ident)
{
	local int i;
	local BTPPReplicationInfo RI;
	local bool bFound;

	// See if it's already initialized
	for (i=0;i<IndexX;i++)
	{
		if (PI[i].PRI == PRI)
		{
			ident = i;
			return PI[i].RI;
		}
	}

	// Not initialized, find the RI and init a new slot
	foreach Level.AllActors(class'BTPPReplicationInfo', RI)
	{
		if (RI.PlayerID == PRI.PlayerID)
		{
			bFound = true;
			break;
		}
	}
	// Couldn't find RI, this sucks
	if (!bFound)
		return None;

	// Init the slot - on newly found BTPP-RI
	if (IndexX < 32)//empty elements in array
	{
		InitInfo(IndexX, PRI, RI);
		ident = IndexX;
		IndexX++;
		return RI;
	}
	else //search dead one
	{
		for (i=0;i<32;i++) //chg from ++i in 098
		{
			if (PI[i].RI == None)
				break;//assign here; else return none/-1
		}
		InitInfo(i, PRI, RI);
		ident = i;
		return RI;
	}
	ident = -1;
	return None;
}

function InitInfo(int i, PlayerReplicationInfo PRI, BTPPReplicationInfo RI)
{
	PI[i].PRI = PRI;
	PI[i].RI = RI;
}
/*##################################################################################################
##
## Mutate -> Handles player's mutate command
##
##################################################################################################*/
function Mutate(string MutateString, PlayerPawn Sender)
{
	Super.Mutate(MutateString, Sender);

	switch MutateString
	{
		case "checkpoint":
			SetCheckpoint(Sender);
			break;
		case "nocheckpoint":
			RemoveCheckpoint(Sender, false);
			break;
	}
}
/*##################################################################################################
##
## MutatorTeamMessage -> Handles players say messages
##
##################################################################################################*/
function bool MutatorTeamMessage(Actor Sender, Pawn Receiver, PlayerReplicationInfo PRI, coerce string S, name Type, optional bool bBeep)
{
    local PlayerPawn Target, Traveller;
    local string Name, MoveString, TravellerName, TargetName, CapsS;

	if(Sender.IsA('TournamentPlayer') && Sender == Receiver) 
	{
		if(S ~= "!cp" || S ~= "!checkpoint") 
			SetCheckpoint(PlayerPawn(Sender));
		else if(S ~= "!nocp" || S ~= "!nocheckpoint") 
			RemoveCheckpoint(PlayerPawn(Sender), false);
		else
		{
			CapsS = Caps(S);
			if(InStr(CapsS, "!MOVETO ") != -1)
			{
				Name = Mid(CapsS, InStr(CapsS, "!MOVETO ") + 10);
				Target = GetPlayerPawnByName(Name);
				MovePlayer(PlayerPawn(Sender), Target);
			}
			if(InStr(CapsS, "!MOVE ") != -1)
			{
				if(PlayerPawn(Sender).bAdmin)
				{
					MoveString = Mid(CapsS, InStr(CapsS, "!MOVE ") + 8);
					MoveString = ReplaceText(MoveString, " TO ", " ");
					TargetName = Mid(MoveString, InStr(MoveString, " ") + 1);
					TravellerName = Left(MoveString, InStr(MoveString, " " $ TargetName));
					Target = GetPlayerPawnByName(TargetName);
					Traveller = GetPlayerPawnByName(TravellerName);
					MovePlayer(Traveller, Target);
				}
			}
		}
	}
	// Allow other message mutators to do their job.
	if(nextMessageMutator != none)
		return nextMessageMutator.mutatorTeamMessage(sender, receiver, pri, s, type, bBeep);
	else
		return true;
}

function string ReplaceText(string haystack, string needle, string Replacement)
{
    local int StrLen;
    local string toRight, toLeft;

    StrLen = Len(needle);
    toRight = Mid(haystack, InStr(haystack, needle) + StrLen);
    toLeft = Left(haystack, InStr(haystack, needle));
    haystack = (toLeft $ Replacement) $ toRight;
    if(InStr(haystack, needle) != -1)
        ReplaceText(haystack, needle, Replacement);
    return haystack;
}

function TournamentPlayer GetPlayerPawnByName(string Name)
{
	local TournamentPlayer A;

	foreach AllActors(class'TournamentPlayer', A)
		if(InStr(Caps(A.PlayerReplicationInfo.PlayerName), Caps(Name)) != -1)         
			return A;

	return none;
}
/*##################################################################################################
##
## AddMutator -> Protection against initializing this mutator twice.
##
##################################################################################################*/
function AddMutator(Mutator M)
{
	if(M == none)
		return;
	if (M.Class != Class)
		Super.AddMutator(M);
	else if(M != Self)
		M.Destroy();
}
/*##################################################################################################
# #################################################################################################
# #
# # OWN FUNCTIONS
# #
# #################################################################################################
##################################################################################################*/
/*##################################################################################################
##
## MovePlayer -> MoveTo stuff
##
##################################################################################################*/
function MovePlayer(PlayerPawn PP, PlayerPawn Target)
{
	local int origTeam, i, z;

	if(PP.PlayerReplicationInfo.PlayerName == Target.PlayerReplicationInfo.PlayerName)
	{
		PP.ClientMessage(Message("Incorrect PlayerName", "red"));
		return;
	}

	if(Target != none)
	{
		SetMoveToCheckpoint(PP, Target);

		origTeam = PP.PlayerReplicationInfo.Team;
		if(origTeam != Target.PlayerReplicationInfo.Team)
		{
			Level.Game.ChangeTeam(PP, Target.PlayerReplicationInfo.Team);
			i = GetPlayerIndex(PP);
			BTP[i].switchedTeamsThisTick = true;
			RI = FindInfo(PP.PlayerReplicationInfo, z);
			RI.CPUsed = true;
		}
	}
}
/*##################################################################################################
##
## SetMoveToCheckpoint -> Sets a new checkpoint for a specific Player.
##
##################################################################################################*/
function SetMoveToCheckpoint(PlayerPawn Sender, PlayerPawn Target)
{
	local int i;

	// Make sure we have a real player
	if(!Sender.IsA('TournamentPlayer'))
		return;

	// Check whether the player is allowed to set a checkpoint
	if(Sender.PlayerReplicationInfo.bWaitingPlayer || Level.Game.bGameEnded)
	{
		Sender.ClientMessage(message("You cannot set a Checkpoint at this time", "red"));
		return;
	}

	i = GetPlayerIndex(Sender);
	// Remove old checkpoint
	if(BTP[i].CP != none)
	{
		BTP[i].CP.destroy();
		BTP[i].CP = none;
	}
	// Spawn new checkpoint at Target's location
	BTP[i].CP = spawn(class'CheckPoint', Sender, , Target.Location, Target.Rotation);
	Sender.ClientMessage(message("Checkpoint set at " $ Target.PlayerReplicationInfo.PlayerName $ "'s location", "green"));
}
/*##################################################################################################
##
## SetCheckpoint -> Sets a new checkpoint for a specific Player.
##
##################################################################################################*/
function SetCheckpoint(PlayerPawn Sender)
{
	local int i;

	// Make sure we have a real player
	if(!Sender.IsA('TournamentPlayer'))
		return;

	// Check whether the player is allowed to set a checkpoint
	if(Sender.PlayerReplicationInfo.bWaitingPlayer || Level.Game.bGameEnded)
	{
		Sender.ClientMessage(message("You cannot set a Checkpoint at this time", "red"));
		return;
	}

	if(Sender.health < 1)
	{
		Sender.ClientMessage(message("You need to be alive to set a Checkpoint", "red"));
		return;
	}

	if(Sender.Base == None && !Sender.Region.Zone.bWaterZone)
	{
		Sender.ClientMessage(message("You need to stand on the ground or in water to set a Checkpoint", "red"));
		return;
	}

	i = GetPlayerIndex(Sender);
	// Remove old checkpoint
	if(BTP[i].CP != none)
	{
		BTP[i].CP.destroy();
		BTP[i].CP = none;
	}

	// Spawn new checkpoint at player's location
	BTP[i].CP = spawn(class'CheckPoint', Sender, , Sender.Location, Sender.Rotation);

	Sender.ClientMessage(message("Checkpoint set", "green"));
}
/*##################################################################################################
##
## RemoveCheckpoint -> Removes the checkpoint of a specific Player.
##
##################################################################################################*/
function RemoveCheckpoint(PlayerPawn Sender, bool bForced)
{
	local int i;

	// Make sure we have a real player
	if(!Sender.IsA('TournamentPlayer'))
		return;

	i = GetPlayerIndex(Sender);

	if(BTP[i].CP != none)
	{
		BTP[i].CP.destroy();
		BTP[i].CP = none;

		if(!bforced)
			Sender.ClientMessage(message("Checkpoint deleted", "green"));
		else
			Sender.ClientMessage(message("Checkpoint removed", "red"));
	}
}
/*##################################################################################################
##
## searchForLeftPlayers -> Removes old CPs and clears data
##
##################################################################################################*/
function searchForLeftPlayers()
{
	local int i;

	// Search existing entries
	for (i=0;i<ArrayCount(BTP);i++)
	{
		if (BTP[i].BTPP == none || BTP[i].BTPP.Player == none)
		{
			if(BTP[i].CP != none)
				BTP[i].CP.destroy();
			BTP[i].CP = none;
		}
	}
}
/*##################################################################################################
##
## GetPlayerIndex -> Retrieves the playerpawn's ID in the structure or creates a new entry
##
##################################################################################################*/
simulated function int GetPlayerIndex(PlayerPawn Player)
{
	local int i, FirstEmptySlot, z;

	FirstEmptySlot = -1;

	// Search existing entries
	for (i = 0; i < ArrayCount(BTP); i++)
	{
		if (BTP[i].BTPP == Player)
			break;
		else if (BTP[i].BTPP == None && FirstEmptySlot == -1)
			FirstEmptySlot = i;
	}

	// Not found, create new entry
	if (i == ArrayCount(BTP))
	{
		i = FirstEmptySlot;
		BTP[i].BTPP = Player;
		BTP[i].CP = none;
		RI = FindInfo(Player.PlayerReplicationInfo, z);
		RI.CPused = false;
	}
	return i;
}
/*##################################################################################################
##
## message -> Adds Nexgen message HUD color-strings to the message
##
##################################################################################################*/
function string message(string message, string color)
{
	// Check if Nexgen is avaible
	if(!nexgen)
		return message;

	switch color
	{
		case "red":
			return "<C00>"$message;
			break;
		case "white":
			return "<C04>"$message;
			break;
		case "green":
			return "<C02>"$message;
			break;
		default:
			return message;
	}
}