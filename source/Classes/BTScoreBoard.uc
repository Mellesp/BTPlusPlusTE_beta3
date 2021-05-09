/*
	BTPlusPlus Tournament is an improved version of BTPlusPlus 0.994
	Flaws have been corrected and extra features have been added
	BT++ Tournament Edition is created by OwYeaW

	BTPlusPlus 0.994
	Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

	This program is free software; you can redistribute and/or modify
	it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTScoreBoard extends UnrealCTFScoreBoard;

struct PlayerInfo
{
	var PlayerReplicationInfo PRI;
	var BTPPReplicationInfo RI;
};
var PlayerInfo PI[32];

struct FlagData
{
	var string Prefix;
	var texture Tex;
};
var FlagData FD[32];	// there can be max 32 (players?) so max 32 different flags
var int saveindex;		// new loaded flags will be saved in FD[index]

var string 		Spectators[32];
var PlayerPawn	PlayerOwner;

var int		tempCaps[32];
var int		tempDeaths[32];
var float	tempTime[32];

var BTPPGameReplicationInfo	GRI;
var ClientData	Config;

var const int	MAX_CAPTIME;
var int			Index;

var Color BlackColor;
//====================================
var int MaxCaps, MaxDeaths;
var byte ColorChangeSpeed, RowColState;
var string MoreText;
var int LastCalcTime, MaxMeterWidth;
var float StartY, StatLineHeight, StatBlockSpacing, StatIndent;
var Color White, Gray, DarkGray, Yellow, RedTeamColor, BlueTeamColor, RedHeaderColor, BlueHeaderColor, StatsColor, HeaderColor, TinyInfoColor, HeaderTinyInfoColor;
var float StatsTextWidth, StatHeight, MeterHeight, NameHeight, ColumnHeight, StatBlockHeight;
var float RedStartX, BlueStartX, ColumnWidth, StatWidth, StatsHorSpacing, ShadingSpacingX, HeaderShadingSpacingY, ColumnShadingSpacingY;
var Font StatFont, CapFont, FooterFont, PlayerNameFont, TinyInfoFont;
//====================================
simulated event PostBeginPlay()
{
	Super.PostBeginPlay();
	PlayerOwner = PlayerPawn(Owner);
	OwnerInfo = PlayerOwner.PlayerReplicationInfo;
	OwnerGame = TournamentGameReplicationInfo(PlayerOwner.GameReplicationInfo);
	LastCalcTime = -100;

	foreach allactors(class'clientdata', config)
		break;

	foreach AllActors(class'BTPPGameReplicationInfo', GRI)
		break;

	SetTimer(1.0, true);
}
//====================================
// 	REFRESHES SPECTATORS LIST
function Timer()
{
	local PlayerReplicationInfo PRI;
	local int i, k;

	for(k = 0;k < 32;k++)
	{
		PRI = PlayerOwner.GameReplicationInfo.PRIArray[k];
		if(PRI == None)
			break;
		if(PRI.bIsSpectator && !PRI.bWaitingPlayer && PRI.PlayerName != "Player")
			Spectators[i++] = PRI.PlayerName;
	}
	while(i<32)
		Spectators[i++] = "";
}
//====================================
//	DrawTrailer - custom version
function DrawTrailer( canvas Canvas )
{
	local int Hours, Minutes, Seconds;
	local float XL, YL, W, H, SW, XW, YW, ZW, XYZ, XLL, YLL, BW, AW;

	// 	ELAPSED & REMAINING TIME	
	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
	Canvas.bCenter = true;
	if(Canvas.ClipX < 1024)
		Canvas.Font = MyFonts.GetMediumFont( Canvas.ClipX );
	else
		Canvas.Font = MyFonts.GetHugeFont( Canvas.ClipX );
	Canvas.StrLen("Test", XL, YL);
	Canvas.SetPos(0, Canvas.ClipY - YL);

	if (GRI.bTournament)
	{
		if (!GRI.bGameEnded)
		{
			if (GRI.bGameStarted)
			{
				if (bTimeDown || GRI.RemainingTime > 0)
				{
					bTimeDown = true;
					if (GRI.RemainingTime <= 0)
						DrawShadowText(Canvas, "~ Sudden Death ~", true);
					else
					{
						Minutes = GRI.RemainingTime / 60;
						Seconds = GRI.RemainingTime % 60;
						Canvas.SetPos(0, Canvas.ClipY - YL + 4);
						DrawShadowText(Canvas, TwoDigitString(Minutes)$":"$TwoDigitString(Seconds), true);
					}
				}
				else
				{
					Seconds	= GRI.ElapsedTime;
					Minutes	= Seconds / 60;
					Hours	= Minutes / 60;
					Seconds	= Seconds - (Minutes * 60);
					Minutes	= Minutes - (Hours * 60);
					DrawShadowText(Canvas, TwoDigitString(Hours)$":"$TwoDigitString(Minutes)$":"$TwoDigitString(Seconds), true);
				}
			}
			else
				DrawShadowText(Canvas, "~ Waiting for Players ~", true);
		}
		else
			DrawShadowText(Canvas, "~ Match Ended ~", true);
	}
	else
		DrawShadowText(Canvas, "~ Practice Mode ~", true);

	//	ENDGAME TEXT
	if (GRI.bGameEnded && GRI.bTournament)
	{
		Canvas.DrawColor = WhiteColor;
		Canvas.Font = MyFonts.GetMediumFont( Canvas.ClipX );
		Canvas.StrLen("Test", XLL, YLL);

		if(GRI.GameBestTime != "")
		{
			Canvas.SetPos(0, Canvas.ClipY - YL - YLL*2);
			DrawShadowText(Canvas, "Cap of the Match: "$GRI.GameBestTime $" by " $ GRI.GameBestPlayerName, true);
		}

		Canvas.SetPos(0, Canvas.ClipY - YL - YLL*4);
		DrawShadowText(Canvas, GRI.EndStatsText, true);

		Canvas.DrawColor = GoldColor;
		Canvas.Font = MyFonts.GetHugeFont( Canvas.ClipX );
		Canvas.StrLen("Test", XL, YL);
		Canvas.SetPos(0, Canvas.ClipY - YL - YLL*4 - YL);
		DrawShadowText(Canvas, GRI.WinnerText, true);
	}
	else if (PlayerOwner != None && PlayerOwner.Health <= 0)
	{
		Canvas.StrLen("Test", XL, YL);
		Canvas.SetPos(0, Canvas.ClipY - YL - YLL -48);
		Canvas.DrawColor = GreenColor;
		DrawShadowText(Canvas, "Hit [Fire] to Respawn!", true);
	}

	// 	SERVER RECORD
	Canvas.bCenter = false;
	if(Canvas.ClipX < 1024)
	{
		Canvas.Font = Canvas.SmallFont;
		Canvas.StrLen("Test", XL, XYZ);
	}
	else
	{
		Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
		Canvas.StrLen("Test", XL, XYZ);
	}
	if(GRI.MapBestTime != "-:--")
	{
		Canvas.SetPos(5, Canvas.ClipY - XYZ);
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
		DrawShadowText(Canvas, "The Server Record is ", True, true);
		Canvas.TextSize("The Server Record is ", W, H);

		Canvas.SetPos(5+W, Canvas.ClipY - XYZ);
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).GreenColor;
		DrawShadowText(Canvas, GRI.MapBestTime, False, true);
		Canvas.TextSize(GRI.MapBestTime, ZW, H);

		Canvas.SetPos(5+W+ZW, Canvas.ClipY - XYZ);
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
		DrawShadowText(Canvas, " set by ", False, true);
		Canvas.TextSize(" set by ", SW, H);

		Canvas.SetPos(5+W+ZW+SW, Canvas.ClipY - XYZ);
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).GoldColor;
		DrawShadowText(Canvas, GRI.MapBestPlayer, False, true);
		Canvas.TextSize(GRI.MapBestPlayer$" ", XW, H);

		if(GRI.MapBestAge == "0")
		{
			Canvas.SetPos(5+W+ZW+SW+XW, Canvas.ClipY - XYZ);
			Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
			DrawShadowText(Canvas, "today", False, True);
		}
		if(GRI.MapBestAge == "1")
		{
			Canvas.SetPos(5+W+ZW+SW+XW, Canvas.ClipY - XYZ);
			Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
			DrawShadowText(Canvas, GRI.MapBestAge, False, true);
			Canvas.TextSize(GRI.MapBestAge, YW, H);

			Canvas.SetPos(5+W+ZW+SW+XW+YW, Canvas.ClipY - XYZ);
			Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
			DrawShadowText(Canvas, " day ago", False, true);
		}
		if((GRI.MapBestAge != "0") && (GRI.MapBestAge != "1"))
		{
			Canvas.SetPos(5+W+ZW+SW+XW, Canvas.ClipY - XYZ);
			Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
			DrawShadowText(Canvas, GRI.MapBestAge, False, true);
			Canvas.TextSize(GRI.MapBestAge, YW, H);

			Canvas.SetPos(5+W+ZW+SW+XW+YW, Canvas.ClipY - XYZ);
			Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
			DrawShadowText(Canvas, " days ago", False, true);
		}
	}
	else
	{
		Canvas.SetPos(5, Canvas.ClipY - XYZ);
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
		DrawShadowText(Canvas, "There is no Server Record yet", True, true);
	}

	// 	PERSONAL RECORD
	if (Config != None)
	{
		if((Config.BestTimeStr != "-:--") && (Config.BestTimeStr != ""))
		{
			Canvas.TextSize(Config.BestTimeStr, AW, H);
			Canvas.SetPos(Canvas.ClipX - AW -5, Canvas.ClipY - XYZ);
			Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).GreenColor;
			DrawShadowText(Canvas, Config.BestTimeStr, False, true);
	
			Canvas.TextSize("Your Personal Record is ", BW, H);		
			Canvas.SetPos(Canvas.ClipX - AW - BW -5, Canvas.ClipY - XYZ);
			Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
			DrawShadowText(Canvas, "Your Personal Record is ", False, true);
		}
	}
}
//====================================
function int GetFlagIndex(string Prefix)
{
	local int i;
	for(i=0;i<32;i++)
		if(FD[i].Prefix == Prefix)
			return i;
	FD[saveindex].Prefix = Prefix;
	FD[saveindex].Tex = texture(DynamicLoadObject(GRI.CountryFlagsPackage$"."$Prefix, class'Texture'));
	i = saveindex;
	saveindex = (saveindex+1) % 256;
	return i;
}
//====================================
function ShowScores( canvas Canvas )
{
	local PlayerReplicationInfo PRI;
	local BTPPReplicationInfo BT_PRI;
	local int PlayerCount, i;
	
	for ( i=0; i<32; i++ )
	{
		PRI = PlayerOwner.GameReplicationInfo.PRIArray[i];
		if(PRI == None) continue;
		else if(!PRI.bIsSpectator || PRI.bWaitingPlayer)
		{
			Ordered[PlayerCount] = PRI;

			BT_PRI = FindInfo(PRI);
			if(BT_PRI == None)
			{
				tempCaps[PlayerCount] = 0;
				tempDeaths[PlayerCount] = 999999999;
				tempTime[PlayerCount] = MAX_CAPTIME;
			}
			else
			{
				tempCaps[PlayerCount] = BT_PRI.Caps;
				tempDeaths[PlayerCount] = BT_PRI.Runs - BT_PRI.Caps;
				if (BT_PRI.BestTime != 0)
					tempTime[PlayerCount] = BT_PRI.BestTime;
				else
					tempTime[PlayerCount] = MAX_CAPTIME;
			}
			PlayerCount++;
		}
	}

	DrawVictoryConditions(Canvas);
	SortScores(PlayerCount);
	DrawSmartBTScores(Canvas, PlayerCount);
	DrawSpectators(Canvas);
	DrawTrailer(Canvas);
}
//====================================
function InitStatBoardConstPos( Canvas C )
{
	local float Nil, LeftSpacingPercent, MidSpacingPercent, RightSpacingPercent;

	CapFont			= Font'LEDFont2';
	FooterFont		= MyFonts.GetSmallestFont( C.ClipX );
	PlayerNameFont	= MyFonts.GetBigFont( C.ClipX );
	TinyInfoFont	= C.SmallFont;

	C.Font = PlayerNameFont;
	C.StrLen( "Player", Nil, NameHeight );

	StartY = ( 180.0 / 1024.0 ) * C.ClipY;
	ColorChangeSpeed = 100; // Influences how 'fast' the color changes from white to green. Higher = faster.

	LeftSpacingPercent = 0.1;
	MidSpacingPercent = 0.2;
	RightSpacingPercent = 0.1;
	RedStartX = LeftSpacingPercent * C.ClipX;
	ColumnWidth = ( ( 1 - LeftSpacingPercent - MidSpacingPercent - RightSpacingPercent ) / 2 * C.ClipX );
	BlueStartX = RedStartX + ColumnWidth + ( MidSpacingPercent * C.ClipX );
	ShadingSpacingX = ( 10.0 / 1024.0 ) * C.ClipX;
	HeaderShadingSpacingY = ( 32 - NameHeight ) / 2 + ( ( 4.0 / 1024.0 ) * C.ClipX );
	ColumnShadingSpacingY = ( 10.0 / 1024.0 ) * C.ClipX;

	StatsHorSpacing = ( 5.0 / 1024.0 ) * C.ClipX;
	StatIndent = ( 32 + StatsHorSpacing ); // For face + flag icons

	InitStatBoardDynamicPos( C );
}
//====================================
function InitStatBoardDynamicPos( Canvas C , optional int Rows , optional int Cols , optional Font NewStatFont , optional float LineSpacing , optional float BlockSpacing )
{
	if( Rows == 0 ) Rows = 3;
	if( Cols == 0 ) Cols = 2;
	if( LineSpacing == 0 ) LineSpacing = 0.9;
	if( BlockSpacing == 0 ) BlockSpacing = 1;

	if( Rows == 2 && Cols == 3 ) RowColState = 1;
	else RowColState = 0;

	StatWidth = ( ( ColumnWidth - StatIndent ) / Cols ) - ( StatsHorSpacing * ( Cols - 1 ) );

	if( NewStatFont == None ) StatFont = MyFonts.GetSmallestFont( C.ClipX );
	else StatFont = NewStatFont;
	C.Font = StatFont;
	C.StrLen( "FlagKls: 00", StatsTextWidth, StatHeight );

	MaxMeterWidth = StatWidth*2 - StatsTextWidth - StatsHorSpacing;
	StatLineHeight = StatHeight * LineSpacing;
	MeterHeight = Max( 1, StatLineHeight * 0.3 );
	StatBlockSpacing = StatLineHeight * BlockSpacing;

	StatBlockHeight = Rows * StatLineHeight;

	if( OwnerGame.Teams[0].Size > OwnerGame.Teams[1].Size )
		ColumnHeight = OwnerGame.Teams[0].Size * ( NameHeight + StatBlockHeight + StatBlockSpacing ) - StatBlockSpacing;
	else
		ColumnHeight = OwnerGame.Teams[1].Size * ( NameHeight + StatBlockHeight + StatBlockSpacing ) - StatBlockSpacing;
}
//====================================
function CompressStatBoard( Canvas C , optional int Level )
{
	local float EndY, Nil, DummyY;

	C.Font = FooterFont;
	C.StrLen( "Test", Nil, DummyY );

	EndY = StartY + ColumnHeight + ( ColumnShadingSpacingY * 2 ) + NameHeight + HeaderShadingSpacingY;
	if( EndY > C.ClipY - DummyY * 5 )
	{
		if( Level == 0 )
		{
			InitStatBoardDynamicPos( C, , , , 0.8 );
		}
		else if( Level == 1 )
		{
			InitStatBoardDynamicPos( C, 2, 3 );
		}
		else if( Level == 2 )
		{
			InitStatBoardDynamicPos( C, 2, 3, Font( DynamicLoadObject( "UWindowFonts.Tahoma10", class'Font' ) ) , 1.0 , 1.0 );
		}
		else
		{
			// We did all the compression we can do. Draw 'More' labels later.
			// First find the columnheight for the amount of players that fit on it.
			ColumnHeight = int( ( C.ClipY - ( EndY - ColumnHeight ) - DummyY * 5 + StatBlockSpacing ) / ( NameHeight + StatBlockHeight + StatBlockSpacing ) )
			* ( NameHeight + StatBlockHeight + StatBlockSpacing ) - StatBlockSpacing;
			return;
		}
		// Did some compression, see if we need more.
		CompressStatBoard( C , Level + 1 );
	}
	// No compression at all or no more compression needed.
	return;
}
//====================================
function DrawSmartBTScores( Canvas C , int PlayerCount)
{
	local int ID, i, j, Time, AvgPing, AvgPL;
	local int RedY, BlueY, X, Y;
	local float Nil, DummyX, DummyY, DummyY2, SizeX, SizeY, Buffer, Size;
	local byte LabelDrawn[2], Rendered[2];
	local Color TeamColor;
	local string TempStr, team_name;

	local BTPPReplicationInfo RI;
	local int FlagShift; /* shifting elements to fit a flag */

	if( Level.TimeSeconds - LastCalcTime > 0.5 )
	{
		RecountNumbers();
		InitStatBoardConstPos( C );
		CompressStatBoard( C );
		LastCalcTime = Level.TimeSeconds;
	}

	Y = int( StartY );
	RedY = Y;
	BlueY = Y;

	C.Style = ERenderStyle.STY_Normal;

	// FOR EACH PLAYER DRAW INFO
	for( i = 0; i < PlayerCount; i++ )
	{
		if(Ordered[i] == None) break;
		RI = FindInfo(Ordered[i]);
		if(RI == None) continue;

		// Get the ID of the ith player
		ID = Ordered[i].PlayerID;

		// set the pos depending on Team
		if( Ordered[i].Team == 0 )
		{
			X = RedStartX;
			Y = RedY;
			TeamColor = RedTeamColor;
		}
		else
		{
			X = BlueStartX;
			Y = BlueY;
			TeamColor = BlueTeamColor;
		}
		C.DrawColor = TeamColor;

		if( LabelDrawn[Ordered[i].Team] == 0 )
		{
			// DRAW THE Team SCORES with the cool Flag icons (masked because of black borders)
			C.bNoSmooth = False;
			C.Font = PlayerNameFont;
			C.Style = ERenderStyle.STY_Translucent;
			if( Ordered[i].Team == 0 ) C.DrawColor = RedHeaderColor;
			else C.DrawColor = BlueHeaderColor;
			C.StrLen( "TEST", SizeX, SizeY );
			C.Style = ERenderStyle.STY_Modulated;
			C.SetPos( X - ShadingSpacingX, Y - HeaderShadingSpacingY );
			C.DrawRect( texture'shade', ColumnWidth + ( ShadingSpacingX * 2 ) , SizeY + ( HeaderShadingSpacingY * 2 ) );
			C.Style = ERenderStyle.STY_Translucent;
			C.SetPos( X - ShadingSpacingX, Y - HeaderShadingSpacingY );
			if( Ordered[i].Team == 0 ) C.DrawPattern( texture'redskin2', ColumnWidth + ( ShadingSpacingX * 2 ) , SizeY + ( HeaderShadingSpacingY * 2 ) , 1 );
			else C.DrawPattern( texture'blueskin2', ColumnWidth + ( ShadingSpacingX * 2 ) , SizeY + ( HeaderShadingSpacingY * 2 ) , 1 );

			C.Style = ERenderStyle.STY_Modulated;
			C.SetPos( X - ShadingSpacingX, Y + SizeY + HeaderShadingSpacingY );
			C.DrawRect( texture'shade', ColumnWidth + ( ShadingSpacingX * 2 ) , ColumnHeight + ( ColumnShadingSpacingY * 2 ) );

			C.Style = ERenderStyle.STY_Translucent;
			C.DrawColor = TeamColor;
			C.SetPos( X, Y - ( ( 32 - SizeY ) / 2 ) ); // Y - 4
			if( Ordered[i].Team == 0 ) C.DrawIcon( texture'I_TeamR', 0.5 );
			else C.DrawIcon( texture'I_TeamB', 0.5 );

			C.Font = CapFont;
			C.StrLen( int(OwnerGame.Teams[Ordered[i].Team].Score), DummyX, DummyY );
			C.Style = ERenderStyle.STY_Normal;
			C.SetPos( X + StatIndent, Y - ( ( DummyY - SizeY ) / 2 ) );
			C.DrawText( int(OwnerGame.Teams[Ordered[i].Team].Score) );

			C.Font = PlayerNameFont;
			C.StrLen( Ordered[i].TeamName  $ " Team", Buffer, Nil );
			C.SetPos( X + ColumnWidth - Buffer, Y );
			C.DrawText( Ordered[i].TeamName  $ " Team" );

	//		C.Font = PlayerNameFont;
	//		C.SetPos( X + StatIndent + DummyX *2, Y - ( ( DummyY - SizeY ) / 2 ) );
	//		C.DrawText( Ordered[i].TeamName  $ " Team" );

			C.DrawColor = HeaderTinyInfoColor;
			C.Font = TinyInfoFont;
			C.StrLen( "TEST", Nil, DummyY );
			C.SetPos( X + StatIndent + DummyX + 2 * StatsHorSpacing, Y + ( SizeY - DummyY * 2 ) / 2 );
			AvgPing = 0;
			AvgPL = 0;

			for( j = 0; j < 32; j++ )
			{
				if( Ordered[j] == None ) break;
				if( Ordered[j].Team == Ordered[i].Team )
				{
					AvgPing += Ordered[j].Ping;
					AvgPL += Ordered[j].PacketLoss;
				}
			}
			if( OwnerGame.Teams[Ordered[i].Team].Size != 0 )
			{
				AvgPing = AvgPing / OwnerGame.Teams[Ordered[i].Team].Size;
				AvgPL = AvgPL / OwnerGame.Teams[Ordered[i].Team].Size;
			}

			TempStr = "PING:" $ AvgPing;
			C.DrawText( TempStr );
			C.SetPos( X + StatIndent + DummyX + 2 * StatsHorSpacing, Y + ( SizeY - DummyY * 2 ) / 2 + DummyY );
			TempStr = "PL:" $ AvgPL $ "%";
			C.DrawText( TempStr );

			C.bNoSmooth = True;

			Y += SizeY + HeaderShadingSpacingY + ColumnShadingSpacingY;
			LabelDrawn[Ordered[i].Team] = 1;
		}

		C.Font = FooterFont;
		C.StrLen( "Test", Nil, DummyY );
		if( LabelDrawn[Ordered[i].Team] != 2 && ( Y + NameHeight + StatBlockHeight + StatBlockSpacing > C.ClipY - DummyY * 5 ) )
		{
			C.DrawColor = TeamColor;
			C.StrLen( MoreText , Size, DummyY );
			if( Ordered[i].Team == 1 ) C.SetPos( X + ColumnWidth - Size, C.ClipY - DummyY * 5 );
			else C.SetPos( X, C.ClipY - DummyY * 5 );
			C.DrawText( "[" @ OwnerGame.Teams[Ordered[i].Team].Size - Rendered[Ordered[i].Team] @ MoreText @ "]" );
			LabelDrawn[Ordered[i].Team] = 2; // "More" label also drawn
		}
		else if( LabelDrawn[Ordered[i].Team] != 2 )
		{
			// Draw the face
			if( Ordered[i].HasFlag == None )
			{
				C.bNoSmooth = False;
				C.DrawColor = WhiteColor;
				C.Style = ERenderStyle.STY_Translucent;
				C.SetPos( X, Y );
				if(RI.bReadyToPlay && Ordered[i].bWaitingPlayer && !GRI.bGameEnded)
					C.DrawIcon( texture'GreenFlag', 1 );
				else
				{
					if( Ordered[i].TalkTexture != None ) C.DrawIcon( Ordered[i].TalkTexture, 0.5 );
					else C.DrawIcon( texture'faceless', 0.5 );
					C.SetPos( X, Y );
					C.DrawColor = DarkGray;
					C.DrawIcon( texture'IconSelection', 1 );
				}
				C.Style = ERenderStyle.STY_Normal;
				C.bNoSmooth = True;
			}

			// Draw the player name
			C.SetPos( X + StatIndent, Y );

			C.Font = PlayerNameFont;
			if( Ordered[i].bAdmin ) C.DrawColor = WhiteColor;
			else if( Ordered[i].PlayerID == OwnerInfo.PlayerID ) C.DrawColor = Yellow;
			else C.DrawColor = TeamColor;
			C.DrawText( Ordered[i].PlayerName );
			C.StrLen( Ordered[i].PlayerName, Size, Buffer );

			C.DrawColor = TinyInfoColor;
			C.Font = TinyInfoFont;
			C.StrLen( "TEST", Buffer, DummyY );

			// Draw Time, NS
			Time = Max( 1, ( Level.TimeSeconds + OwnerInfo.StartTime - Ordered[i].StartTime ) / 60 );
			C.SetPos( X + StatIndent + Size + StatsHorSpacing, Y + ( NameHeight - DummyY * 2 ) / 2 + DummyY );
			C.DrawText( "TM:" $ Time $ " NS:" $ RI.NetSpeed );

			// Draw the country flag
			if(RI.CountryPrefix != "")
			{
				C.SetPos( X+8, Y + StatIndent);
				C.bNoSmooth = False;
				C.DrawColor = WhiteColor;
				C.DrawIcon(FD[GetFlagIndex(RI.CountryPrefix)].Tex, 1.0);
				FlagShift = 12;
				C.bNoSmooth = True;
			}
			else
				FlagShift = 0;

			// Draw Bot or Ping/PL
			C.SetPos( X, Y + StatIndent + FlagShift);
			if( Ordered[i].bIsABot )
			{
				C.DrawText( "BOT" );
				if( Ordered[i].Team == OwnerInfo.Team )
				{
					C.SetPos( X, Y + StatIndent + DummyY);
					C.DrawText( Left( string( BotReplicationInfo( Ordered[i] ).RealOrders ) , 3 ) );
				}
			}
			else
			{
				C.DrawColor = HeaderTinyInfoColor;
				TempStr = "PI:" $ Ordered[i].Ping;
				if( Len( TempStr ) > 5 ) TempStr = "P:" $ Ordered[i].Ping;
				if( Len( TempStr ) > 5 ) TempStr = string( Ordered[i].Ping );
				C.DrawText( TempStr );
				C.SetPos( X, Y + StatIndent + DummyY + FlagShift);
				TempStr = "PL:" $ Ordered[i].PacketLoss $ "%";
				if( Len( TempStr ) > 5 ) TempStr = "L:" $ Ordered[i].PacketLoss $ "%";
				if( Len( TempStr ) > 5 ) TempStr = "L:" $ Ordered[i].PacketLoss;
				if( Len( TempStr ) > 5 ) TempStr = Ordered[i].PacketLoss $ "%";
				C.DrawText( TempStr );
			}

			// Draw the Flag if he has Flag
			if( Ordered[i].HasFlag != None )
			{
				C.DrawColor = WhiteColor;
				C.SetPos( X, Y );
				if( Ordered[i].HasFlag.IsA( 'GreenFlag' ) ) C.DrawIcon( texture'GreenFlag', 1 );
				else if( Ordered[i].HasFlag.IsA( 'YellowFlag' ) ) C.DrawIcon( texture'YellowFlag', 1 );
				else if( Ordered[i].Team == 0 ) C.DrawIcon( texture'BlueFlag', 1 );
				else C.DrawIcon( texture'RedFlag', 1 );
			}

			C.Font = PlayerNameFont;
			C.DrawColor = GreenColor;

			// Draw Frag/Score
			C.StrLen( RI.BestTimeStr, Size, DummyY );
			C.SetPos( X + ColumnWidth - Size, Y );
			C.DrawText(RI.BestTimeStr);

			Y += NameHeight;

			// Set the Font for the stat drawing
			C.Font = StatFont;

			if( RowColState == 1 )
			{
				PlayerOwner.ClientMessage("You found a bug!");
			}
			else
			{
				DrawCaps(	C, X, Y, 1, 1, RI);
				DrawDeaths(	C, X, Y, 2, 1, Ordered[i]);
				DrawTimer(	C, X, Y, 3, 1, RI, Ordered[i]);

				Y += StatBlockHeight + StatBlockSpacing;
			}

			// Alter the RedY or BlueY and do next player
			if( Ordered[i].Team == 0 ) RedY = Y;
			else BlueY = Y;
			Rendered[Ordered[i].Team]++;
		}
	}
}
//====================================
function DrawLocation( Canvas C, int X, int Y, int Row, int Col, PlayerReplicationInfo PRI )
{
	local string location_string;

	if( OwnerInfo.Team != 255 && PRI.Team != OwnerInfo.Team)
		location_string = "-";
	else if ( PRI.PlayerLocation != None )
		location_string = PRI.PlayerLocation.LocationName;
	else if ( PRI.PlayerZone != None )
		location_string = PRI.PlayerZone.ZoneName;
	else
		location_string = "-";

	X += StatIndent + ( ( StatWidth + StatsHorSpacing ) * ( Col - 1 ) );
	Y += ( StatLineHeight * ( Row - 1 ) );

	C.DrawColor = StatsColor;
	C.SetPos( X, Y );
	C.DrawText( "Location: " $ location_string );
}
//====================================
function DrawTimer( Canvas C, int X, int Y, int Row, int Col, BTPPReplicationInfo BT_RI, PlayerReplicationInfo PRI )
{
	local float Size, DummyY, barProgress;
	local int ColorChange, M, runTime;
	local string time_string;

	X += StatIndent + ( ( StatWidth + StatsHorSpacing ) * ( Col - 1 ) );
	Y += ( StatLineHeight * ( Row - 1 ) );

	C.DrawColor = StatsColor;
	C.SetPos( X, Y );
	C.StrLen( "Timer: ", Size, DummyY );
	C.DrawText( "Timer: " );

	if(BT_RI.bNeedsRespawn || (PlayerOwner != None && PlayerOwner.IsInState('GameEnded')))
	{
		C.DrawColor = SilverColor;
		if(BT_RI.lastCap != 0)
			time_string = FormatCentiseconds(BT_RI.lastCap, True);
		else
			time_string = "  -:--";
	}
	else
	{
		C.DrawColor = SilverColor;
		if(PRI.bIsSpectator && PRI.bWaitingPlayer)
			time_string = "  -:--";
		else
		{
			C.DrawColor = GreenColor;
			runTime = BT_RI.GetRuntime();
			time_string = FormatScore(runTime / 100);
		}
	}

	C.SetPos( X + Size, Y );
	C.DrawText( time_string );

	if( runTime != 0 && BT_RI.BestTime != 0 )
	{
		barProgress = float(runTime) / (MAX_CAPTIME - BT_RI.BestTime);
		ColorChange = Min(barProgress * 255, 255);
		C.DrawColor = StatsColor;
		C.DrawColor.R = StatsColor.R - ColorChange;
		C.DrawColor.B = StatsColor.B - ColorChange;

		M = GetMeterLength( runTime, MAX_CAPTIME - BT_RI.BestTime );
		C.SetPos( X + StatsTextWidth + StatsHorSpacing, Y + ( ( StatHeight - MeterHeight ) / 2 ) );
		C.DrawRect( texture'meter', M, MeterHeight );
	}
}
//====================================
function DrawCaps( Canvas C, int X, int Y, int Row, int Col, BTPPReplicationInfo BT_RI )
{
	local float Size, DummyY, barProgress;
	local int ColorChange, M, Total;

	X += StatIndent + ( ( StatWidth + StatsHorSpacing ) * ( Col - 1 ) );
	Y += ( StatLineHeight * ( Row - 1 ) );

	C.DrawColor = StatsColor;
	C.SetPos( X, Y );
	C.DrawText( "Caps: " );
	C.StrLen( BT_RI.Caps, Size, DummyY );
	C.SetPos( X + StatsTextWidth - Size, Y );
	C.DrawText( BT_RI.Caps );

	if( BT_RI.Caps > 0 )
	{
		if(GRI.bTournament && GRI.CapLimit > 0)
			Total = GRI.CapLimit;
		else
			Total = MaxCaps;

		barProgress = float(BT_RI.Caps) / Total;
		ColorChange = Min(barProgress * 255, 255);
		C.DrawColor.B = StatsColor.B - ColorChange;

		M = GetMeterLength( BT_RI.Caps, Total );
		C.SetPos( X + StatsTextWidth + StatsHorSpacing, Y + ( ( StatHeight - MeterHeight ) / 2 ) );
		C.DrawRect( texture'meter', M, MeterHeight );
	}
}
//====================================
function DrawDeaths( Canvas C, int X, int Y, int Row, int Col, PlayerReplicationInfo PRI )
{
	local float Size, DummyY, barProgress;
	local int ColorChange, M, Total;

	X += StatIndent + ( ( StatWidth + StatsHorSpacing ) * ( Col - 1 ) );
	Y += ( StatLineHeight * ( Row - 1 ) );

	C.DrawColor = StatsColor;
	C.SetPos( X, Y );
	C.DrawText( "Deaths: " );
	C.StrLen( int(PRI.Deaths), Size, DummyY );
	C.SetPos( X + StatsTextWidth - Size, Y );
	C.DrawText( int(PRI.Deaths) );

	if( PRI.Deaths > 0 )
	{
		Total = MaxDeaths;
		barProgress = PRI.Deaths / Total;
		ColorChange = Min(barProgress * 255, 255);
		C.DrawColor.G = StatsColor.B - ColorChange;
		C.DrawColor.B = StatsColor.B - ColorChange;

		M = GetMeterLength( PRI.Deaths, Total );
		C.SetPos( X + StatsTextWidth + StatsHorSpacing, Y + ( ( StatHeight - MeterHeight ) / 2 ) );
		C.DrawRect( texture'meter', M, MeterHeight );
	}
}
//====================================
function DrawStatType( Canvas C, int X, int Y, int Row, int Col, string Label, int Count, int Total )
{
	local float Size, DummyY;
	local int ColorChange, M;

	X += StatIndent + ( ( StatWidth + StatsHorSpacing ) * ( Col - 1 ) );
	Y += ( StatLineHeight * ( Row - 1 ) );

	C.DrawColor = StatsColor;
	C.SetPos( X, Y );
	C.DrawText( Label );
	C.StrLen( Count, Size, DummyY );
	C.SetPos( X + StatsTextWidth - Size, Y );
	C.DrawText( Count ); //text
	if( Count > 0 )
	{
		ColorChange = ColorChangeSpeed * loge( Count );
		if( ColorChange > 255 ) ColorChange = 255;
		C.DrawColor.R = StatsColor.R - ColorChange;
		C.DrawColor.B = StatsColor.B - ColorChange;
	}
	M = GetMeterLength( Count, Total );
	C.SetPos( X + StatsTextWidth + StatsHorSpacing, Y + ( ( StatHeight - MeterHeight ) / 2 ) );
	C.DrawRect( texture'meter', M, MeterHeight );
}
//====================================
function int GetMeterLength( int A, int B )
{
	local int Result;

	if( B == 0 ) return 0;
	Result = ( A * MaxMeterWidth ) / B;

	if( Result > MaxMeterWidth ) return MaxMeterWidth;
	else return Result;
}
//====================================
function DrawSpectators(Canvas Canvas)
{
	local float XL, YL;
	local int i;

	Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
	Canvas.DrawColor = WhiteColor;
	Canvas.StrLen("Spectators", XL, YL);
	Canvas.SetPos(Canvas.ClipX-XL-2, Canvas.ClipY/15);
	DrawShadowText(Canvas, "Spectators", False, true);
	if(Spectators[0] == "")
	{
		Canvas.DrawColor = SilverColor;
		Canvas.StrLen("None", XL, YL);
		Canvas.SetPos(Canvas.ClipX-XL-2, Canvas.CurY);
		DrawShadowText(Canvas, "None", False, true);
	}
	else
	{
		Canvas.DrawColor = GreenColor;
		for(i=0;i<32;i++)
		{
			if(Spectators[i] == "")
				break;
			Canvas.StrLen(Spectators[i], XL, YL);
			Canvas.SetPos(Canvas.ClipX-XL-2, Canvas.CurY);
			DrawShadowText(Canvas, Spectators[i], False, true);
		}
	}
}
//====================================
function DrawVictoryConditions(Canvas Canvas)
{
	local float X, Y, XL, YL, YL2, YL3, YL4, startPosY;

	startPosY = 58.0/768.0 * Canvas.ClipY;

	//	BOARD LABEL
	Canvas.bCenter = True;
	Canvas.DrawColor = WhiteColor;
	Canvas.Font = MyFonts.GetHugeFont(Canvas.ClipX);
	Canvas.SetPos(0, startPosY);
	Canvas.StrLen("Test", X, Y);
	DrawShadowText(Canvas, GRI.BoardLabel, true);

	//	MAPNAME
	Canvas.Font = MyFonts.GetMediumFont(Canvas.ClipX);
	Canvas.StrLen("Test", XL, YL);
	Canvas.SetPos(0, startPosY + Y + YL);
	DrawShadowText(Canvas, Left(string(Level), InStr(string(Level), ".")), true);

	//	GAME SETTINGS
	if(GRI.bTournament)
	{
		if(GRI.TimeLimit > 0)
		{
			Canvas.StrLen("Test", XL, YL2);	
			Canvas.SetPos(0, startPosY + Y + YL*3);
			DrawShadowText(Canvas, TimeLimit@GRI.TimeLimit$":00", true);
		}
		if(GRI.CapLimit > 0)
		{
			Canvas.StrLen("Test", XL, YL3);
			Canvas.SetPos(0, startPosY + Y + YL*3 + YL2);
			DrawShadowText(Canvas, FragGoal@GRI.CapLimit, true);
		}
		Canvas.SetPos(0, startPosY + Y + YL*3 + YL2 + YL3);
		DrawShadowText(Canvas, GRI.MaxPlayers/2 $ " vs " $ GRI.MaxPlayers/2, true);

		//	FILLERS
		if(GRI.TimeLimit == 0)
		{
			Canvas.StrLen("Test", XL, YL4);
			Canvas.SetPos(0, startPosY + Y + YL*3 + YL2 + YL3 + YL);
			DrawShadowText(Canvas, "     ", true);
		}
		if(GRI.CapLimit == 0)
		{
			Canvas.SetPos(0, startPosY + Y + YL*3 + YL2 + YL3 + YL + YL4);
			DrawShadowText(Canvas, "     ", true);
		}
	}
	else
	{
		Canvas.SetPos(0, startPosY + Y + YL*3);
		DrawShadowText(Canvas, "     ", true);

		Canvas.SetPos(0, startPosY + Y + YL*4);
		DrawShadowText(Canvas, "     ", true);

		Canvas.SetPos(0, startPosY + Y + YL*5);
		DrawShadowText(Canvas, "     ", true);
	}
	Canvas.bCenter = False;
}
//====================================
// idea and function from UTPro by AnthraX
function DrawShadowText (Canvas Canvas, coerce string Text, optional bool Param,optional bool bSmall, optional bool bGrayShadow)
{
	local Color OldColor;
	local float XL,YL;
	local float X, Y;

	OldColor = Canvas.DrawColor;

	if (bGrayShadow)
	{
		Canvas.DrawColor.R = 127;
		Canvas.DrawColor.G = 127;
		Canvas.DrawColor.B = 127;
	}
	else
	{
		Canvas.DrawColor.R = 0;
		Canvas.DrawColor.G = 0;
		Canvas.DrawColor.B = 0;
	}
	if (bSmall)
	{
		XL = 1;
		YL = 1;
	}
	else
	{
		XL = 2;
		YL = 2;
	}
	X=Canvas.CurX;
	Y=Canvas.CurY;
	Canvas.SetPos(X+XL,Y+YL);
	Canvas.DrawText(Text, Param);
	Canvas.DrawColor = OldColor;
	Canvas.SetPos(X,Y);
	Canvas.DrawText(Text, Param);
}
//====================================
function SortScores(int N)
{
	local PlayerReplicationInfo TempPRI;
	local int I, J, Max, tempC, tempD;
	local float	tempT;

	for ( I = 0; I < N - 1; I++ )
	{
		Max = I;
		for ( J = I + 1; J < N; J++ )
		{
			if (tempCaps[J] > tempCaps[I])
				Max = J;
			else if (tempCaps[J] == tempCaps[I] && tempTime[J] > tempTime[I])
				Max = J;
			else if (tempCaps[J] == tempCaps[I] && tempTime[J] == tempTime[I] && tempDeaths[J] < tempDeaths[I])
				Max = J;
			else if (tempCaps[J] == tempCaps[I] && tempTime[J] == tempTime[I] && tempDeaths[J] == tempDeaths[I] && Ordered[J].PlayerName < Ordered[Max].PlayerName)
				Max = J;
		}
	
		if(Max != I)
		{
			//move PRI
			TempPRI = Ordered[Max];
			Ordered[Max] = Ordered[I];
			Ordered[I] = TempPRI;
		}
	}
}
//searches for the BTPP RI by the UT PRI given
function BTPPReplicationInfo FindInfo(PlayerReplicationInfo PRI)
{
	local int i;
	local BTPPReplicationInfo RI;
	local bool bFound;

	// See if it's already initialized
	for (i=0;i<Index;i++)
		if (PI[i].PRI == PRI)
			return PI[i].RI;

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
	if (Index < 32)//empty elements in array
	{
		InitInfo(Index, PRI, RI);
		Index++;
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
		return RI;
	}

	return None;
}
//====================================
function InitInfo(int i, PlayerReplicationInfo PRI, BTPPReplicationInfo RI)
{
	PI[i].PRI = PRI;
	PI[i].RI = RI;
}
//====================================
// FormatScore - formats seconds to minutes & seconds
// Triggered in: DrawNameAndPing
//====================================
static final function string FormatScore(int Time)
{
	if(int(Time % 60) < 10)//fill up a leading 0 to single-digit seconds
		return Time/60 $ ":0" $ int(Time%60);
	else
		return Time/60 $ ":" $ int(Time%60);
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
function RecountNumbers()
{
	local byte i;
	local BTPPReplicationInfo BT_RI;

	MaxCaps = 0;
	MaxDeaths = 0;

	for( i = 0; i < 32; i++ )
	{
		if( Ordered[i] == None ) break;
		if( Ordered[i].bIsSpectator && !Ordered[i].bWaitingPlayer ) continue;

		BT_RI = FindInfo( Ordered[i] );
		if( BT_RI != None && BT_RI.Caps > MaxCaps )
			MaxCaps = BT_RI.Caps;
		if( Ordered[i].Deaths > MaxDeaths )
			MaxDeaths = Ordered[i].Deaths;
	}
}
//====================================
defaultproperties
{
	MAX_CAPTIME=600000
	MoreText="More..."
	Gray=(R=128,G=128,B=128,A=0)
	DarkGray=(R=32,G=32,B=32,A=0)
	Yellow=(R=255,G=255,B=0,A=0)
	RedTeamColor=(R=255,G=0,B=0,A=0)
	BlueTeamColor=(R=0,G=128,B=255,A=0)
	RedHeaderColor=(R=64,G=0,B=0,A=0)
	BlueHeaderColor=(R=0,G=32,B=64,A=0)
	StatsColor=(R=255,G=255,B=255,A=0)
	HeaderColor=(R=255,G=255,B=0,A=0)
	TinyInfoColor=(R=128,G=128,B=128,A=0)
	HeaderTinyInfoColor=(R=192,G=192,B=192,A=0)
}