//=============================================================================
// BunnyTrackGame made by OwYeaW
//=============================================================================
class BunnyTrackGame extends CTFGame;

var BTPlusPlus Controller;

function ProcessServerTravel(string URL, bool bItems)
{
	DeathMatchPlus(Level.Game).SaveConfig();
	Super.ProcessServerTravel(URL, bItems);
}

function ScoreFlag(Pawn Scorer, CTFFlag theFlag)
{
	local pawn TeamMate;
	local Actor A;

	if ( Scorer.PlayerReplicationInfo.Team == theFlag.Team || Scorer.Health < 1 || Scorer.AttitudeToPlayer == ATTITUDE_Follow)
		return;

	Controller.BTCapture( Scorer );
	Teams[Scorer.PlayerReplicationInfo.Team].Score += 1.0;

	if ( bRatedGame && Scorer.IsA('PlayerPawn') )
		bFulfilledSpecial = true;

	for ( TeamMate=Level.PawnList; TeamMate!=None; TeamMate=TeamMate.NextPawn )
	{
		if ( TeamMate.IsA('PlayerPawn') )
			PlayerPawn(TeamMate).ClientPlaySound(CaptureSound[Scorer.PlayerReplicationInfo.Team]);
		else if ( TeamMate.IsA('Bot') )
			Bot(TeamMate).SetOrders(BotReplicationInfo(TeamMate.PlayerReplicationInfo).RealOrders, BotReplicationInfo(TeamMate.PlayerReplicationInfo).RealOrderGiver, true);
	}

	if (Level.Game.WorldLog != None)
		Level.Game.WorldLog.LogSpecialEvent("flag_captured", Scorer.PlayerReplicationInfo.PlayerID, Teams[theFlag.Team].TeamIndex);
	if (Level.Game.LocalLog != None)
		Level.Game.LocalLog.LogSpecialEvent("flag_captured", Scorer.PlayerReplicationInfo.PlayerID, Teams[theFlag.Team].TeamIndex);

	EndStatsClass.Default.TotalFlags++;
	BroadcastLocalizedMessage( class'CTFMessage', 0, Scorer.PlayerReplicationInfo, None, TheFlag );
	if ( theFlag.HomeBase.Event != '' )
		foreach allactors(class'Actor', A, theFlag.HomeBase.Event )
			A.Trigger(theFlag.HomeBase,	Scorer);

	if ( (bOverTime || (GoalTeamScore != 0)) && (Teams[Scorer.PlayerReplicationInfo.Team].Score >= GoalTeamScore) )
		EndGame("teamscorelimit");
	else if ( bOverTime )
		EndGame("timelimit");

	Scorer.Velocity = vect(0,0,0);
	Scorer.Acceleration = vect(0,0,0);
	Scorer.SetPhysics(PHYS_None);
	Scorer.SetLocation(Scorer.Location);
	Scorer.bBlockPlayers = False;
	Scorer.SetCollision(False);
	Scorer.Weapon.bCanThrow = false; // just in case someone doesn't play with Insta

	if (!Level.Game.bGameEnded)
	{
		Level.Game.DiscardInventory(Scorer);
		Scorer.bHidden = True;
		Scorer.SoundDampening = 0.5;
		Scorer.GoToState('Dying');
		Spawn(class'UTTeleportEffect',Scorer,, Scorer.Location, Scorer.Rotation);
	}
}

function playerpawn Login(string Portal, string Options, out string Error, class<playerpawn> SpawnClass)
{
	local PlayerPawn newPlayer;
	local NavigationPoint StartSpot;

	newPlayer = Super(DeathMatchPlus).Login(Portal, Options, Error, SpawnClass);
	if ( newPlayer == None)
		return None;

	if ( bSpawnInTeamArea )
	{
		StartSpot = FindPlayerStart(NewPlayer,255, Portal);
		if ( StartSpot != None )
		{
			NewPlayer.SetLocation(StartSpot.Location);
			NewPlayer.SetRotation(StartSpot.Rotation);
			NewPlayer.ViewRotation = StartSpot.Rotation;
			NewPlayer.ClientSetRotation(NewPlayer.Rotation);
			StartSpot.PlayTeleportEffect( NewPlayer, true );
			Controller.PlayerSpawned(NewPlayer, PlayerStart(startSpot));
		}
	}
	PlayerTeamNum = NewPlayer.PlayerReplicationInfo.Team;

	return newPlayer;
}

function bool RestartPlayer(pawn aPlayer)
{
	local NavigationPoint startSpot;
	local bool foundStart;

	if( bRestartLevel && Level.NetMode!=NM_DedicatedServer && Level.NetMode!=NM_ListenServer )
		return true;

	startSpot = Controller.getMyStart(aPlayer);
	if(startSpot == None)
	{
		startSpot = FindPlayerStart(aPlayer, 255);
		if( startSpot == None )
		{
			log(" Player start not found!!!");
			return false;
		}
	}
	foundStart = aPlayer.SetLocation(startSpot.Location);
	if(foundStart)
	{
		startSpot.PlayTeleportEffect(aPlayer, true);
		aPlayer.SetRotation(startSpot.Rotation);
		aPlayer.ViewRotation = aPlayer.Rotation;
		aPlayer.Acceleration = vect(0,0,0);
		aPlayer.Velocity = vect(0,0,0);
		aPlayer.SetPhysics(PHYS_Falling);	// ANTI SPAWNJUMP
		aPlayer.Health = aPlayer.Default.Health;
		aPlayer.SetCollision( true, true, true );
		aPlayer.ClientSetLocation( startSpot.Location, startSpot.Rotation );
		aPlayer.bHidden = false;
		aPlayer.DamageScaling = aPlayer.Default.DamageScaling;
		aPlayer.SoundDampening = aPlayer.Default.SoundDampening;
		AddDefaultInventory(aPlayer);
		Controller.PlayerSpawned(aPlayer, PlayerStart(startSpot));
	}
	else
		log(startspot$" Player start not useable!!!");
	return foundStart;
}

function bool ChangeTeam(Pawn Other, int NewTeam)
{
	local int i, Smallest, DesiredTeam;
	local pawn APlayer, P;
	local teaminfo SmallestTeam;

	if ( bRatedGame && (Other.PlayerReplicationInfo.Team != 255) )
		return false;
	if ( Other.IsA('Spectator') )
	{
		Other.PlayerReplicationInfo.Team = 255;
		if (LocalLog != None)
			LocalLog.LogTeamChange(Other);
		if (WorldLog != None)
			WorldLog.LogTeamChange(Other);
		return true;
	}

	// find smallest team
	Smallest = 0;
	for( i=1; i<MaxTeams; i++ )
		if ( Teams[Smallest].Size > Teams[i].Size )
			Smallest = i;

	if ( (NewTeam == 255) || (NewTeam >= MaxTeams) || (DeathMatchPlus(Level.Game).bTournament && Teams[NewTeam].Size >= DeathMatchPlus(Level.Game).MaxPlayers / 2))
		NewTeam = Smallest;

	if ( bPlayersBalanceTeams && (Level.NetMode != NM_Standalone) )
	{
		if ( Teams[NewTeam].Size > Teams[Smallest].Size )
			NewTeam = Smallest;
		if ( NumBots == 1 )
		{
			// join bot's team if sizes are equal, because he will leave
			for ( P=Level.PawnList; P!=None; P=P.NextPawn )
				if ( P.IsA('Bot') )
					break;

			if ( (P != None) && (P.PlayerReplicationInfo != None) && (P.PlayerReplicationInfo.Team != 255)
				&& (Teams[P.PlayerReplicationInfo.Team].Size == Teams[Smallest].Size) )
				NewTeam = P.PlayerReplicationInfo.Team;
		}
	}

	if ( (Other.PlayerReplicationInfo.Team == NewTeam) && bNoTeamChanges )
		return false;

	if(DeathMatchPlus(Level.Game).bTournament && Teams[NewTeam].Size >= (DeathMatchPlus(Level.Game).MaxPlayers / 2))
		return false;

	if ( Other.IsA('TournamentPlayer') )
		TournamentPlayer(Other).StartSpot = None;

	if ( Other.PlayerReplicationInfo.Team != 255 )
	{
		ClearOrders(Other);
		Teams[Other.PlayerReplicationInfo.Team].Size--;
	}

	if ( Teams[NewTeam].Size < MaxTeamSize )
	{
		AddToTeam(NewTeam, Other);
		Controller.manageMyStartIndicator(PlayerPawn(Other));
		return true;
	}

	if ( Other.PlayerReplicationInfo.Team == 255 )
	{
		AddToTeam(Smallest, Other);
		return true;
	}

	return false;
}

function bool SetEndCams(string Reason)
{
	if (DeathMatchPlus(Level.Game).bTournament)
		CalcEndStats();
	return false;
}

function CalcEndStats()
{
	EndStatsClass.Default.TotalGames++;
	EndStatsClass.Static.StaticSaveConfig();
}

defaultproperties
{
	StartMessage=
	ScoreBoardType=BTScoreboard
	HUDType=BTHUD
	GameName="BunnyTrack"
}