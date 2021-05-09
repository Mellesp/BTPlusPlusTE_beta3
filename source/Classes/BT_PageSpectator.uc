//=============================================================================
// BT_PageSpectator made by OwYeaW
//=============================================================================
class BT_PageSpectator expands UWindowPageWindow;
//-----------------------------------------------------------------------------
#exec texture IMPORT NAME=BT_GreyBackground FILE=Textures\BT_GreyBackground.BMP	MIPS=OFF
//-----------------------------------------------------------------------------
var		BTClientSettings			BTCS;
//-----------------------------------------------------------------------------
var		bool						bInitialized;
var		Color						Basecolor;
//-----------------------------------------------------------------------------
//	Objects
//-----------------------------------------------------------------------------
var		BT_Checkbox					BehindviewAutoFollowCheck;
var		UMenuLabelControl			BehindviewToggleLabel;
var		UMenuRaisedButton			BehindviewToggleButton;
var 	UWindowSmallButton 			ResetBehindviewToggleButton;
var		UWindowLabelControl			BehindviewSmoothingLabel;
var		BT_SliderControl			BehindviewSmoothingSlider;
var		UWindowLabelControl			BehindviewDistanceLabel;
var		BT_SliderControl			BehindviewDistanceSlider;
var		UWindowLabelControl			SpectatorSpeedLabel;
var		BT_SliderControl			SpectatorSpeedSlider;
var		BT_Checkbox					HideArmorCheck;
var		BT_Checkbox					GhostSpectatorCheck;
var		UMenuLabelControl			OpenSettingsLabel;
var		UMenuRaisedButton			OpenSettingsButton;
var 	UWindowSmallButton 			ResetOpenSettingsButton;
//-----------------------------------------------------------------------------
//	HotKey stuff
//-----------------------------------------------------------------------------
var 	bool 						bPolling;
var 	UMenuRaisedButton 			SelectedButton;
var 	string 						RealKeyName[255];
//-----------------------------------------------------------------------------
var float ControlOffset, ControlOffsetSpace;
//-----------------------------------------------------------------------------
function Created()
{
	local int ButtonWidth, ButtonLeft, ResetLeft;
	local int ControlWidth, ControlLeft, ControlRight;
	local int LabelWidth, calc;
	local int CenterWidth, CenterPos;

	Super.Created();

	ControlWidth = WinWidth/2.5;
	ControlLeft = (WinWidth/2 - ControlWidth)/2;
	ControlRight = WinWidth/2 + ControlLeft;

	CenterWidth = (WinWidth/4)*3;
	CenterPos = (WinWidth - CenterWidth)/2;

	calc =  WinWidth - CenterPos*2;
	LabelWidth = calc * 0.575;
	ButtonWidth = calc * 0.2;
	ButtonLeft =  CenterPos + LabelWidth;
	ResetLeft = ButtonLeft + ButtonWidth + 8;

	//	1	==========================================
	BehindviewAutoFollowCheck = BT_Checkbox(CreateControl(class'BT_Checkbox', CenterPos, ControlOffset, CenterWidth, 1));
	BehindviewAutoFollowCheck.SetText("Behindview auto follow viewrotation");
	BehindviewAutoFollowCheck.SetTextColor(Basecolor);
	BehindviewAutoFollowCheck.SetFont(F_Normal);
	BehindviewAutoFollowCheck.Align = TA_Left;
	//	2	==========================================
	ControlOffset += ControlOffsetSpace;

	BehindviewToggleLabel = UMenuLabelControl(CreateControl(class'UMenuLabelControl', CenterPos, ControlOffset, LabelWidth, 1));
	BehindviewToggleLabel.SetText("Toggle auto behindview on/off");
	BehindviewToggleLabel.SetTextColor(Basecolor);
	BehindviewToggleLabel.SetFont(F_Normal);

	BehindviewToggleButton = UMenuRaisedButton(CreateControl(class'UMenuRaisedButton', ButtonLeft, ControlOffset-3, ButtonWidth, 1));
	BehindviewToggleButton.bAcceptsFocus = False;
	BehindviewToggleButton.bIgnoreLDoubleClick = True;
	BehindviewToggleButton.bIgnoreMDoubleClick = True;
	BehindviewToggleButton.bIgnoreRDoubleClick = True;

	ResetBehindviewToggleButton = UWindowSmallButton(CreateControl(class'UWindowSmallButton', ResetLeft, ControlOffset-2, ButtonWidth, 20));
	ResetBehindviewToggleButton.DownSound = Sound'Botpack.Click';
	ResetBehindviewToggleButton.Text = "Remove";
//	3	==========================================
	ControlOffset += ControlOffsetSpace;

	BehindviewSmoothingLabel = UWindowLabelControl(CreateControl(class'UWindowLabelControl', CenterPos, ControlOffset+2, CenterWidth, 1));
	BehindviewSmoothingLabel.SetText("Smoothing");
	BehindviewSmoothingLabel.SetFont(F_Normal);
	BehindviewSmoothingLabel.SetTextColor(Basecolor);

	BehindviewSmoothingSlider = BT_SliderControl(CreateControl(class'BT_SliderControl', CenterPos, ControlOffset+2, CenterWidth, 1));
	BehindviewSmoothingSlider.SetRange(1, 500, 1);
	BehindviewSmoothingSlider.SetTextColor(Basecolor);
	BehindviewSmoothingSlider.SetFont(F_Normal);
	BehindviewSmoothingSlider.Align = TA_Right;
//	4	==========================================
	ControlOffset += ControlOffsetSpace;

	BehindviewDistanceLabel = UWindowLabelControl(CreateControl(class'UWindowLabelControl', CenterPos, ControlOffset+2, CenterWidth, 1));
	BehindviewDistanceLabel.SetText("Distance");
	BehindviewDistanceLabel.SetFont(F_Normal);
	BehindviewDistanceLabel.SetTextColor(Basecolor);

	BehindviewDistanceSlider = BT_SliderControl(CreateControl(class'BT_SliderControl', CenterPos, ControlOffset+2, CenterWidth, 1));
	BehindviewDistanceSlider.SetRange(0, 1800, 1);
	BehindviewDistanceSlider.SetTextColor(Basecolor);
	BehindviewDistanceSlider.SetFont(F_Normal);
	BehindviewDistanceSlider.Align = TA_Right;
//	5	==========================================
	ControlOffset += ControlOffsetSpace;

	SpectatorSpeedLabel = UWindowLabelControl(CreateControl(class'UWindowLabelControl', CenterPos, ControlOffset+2, CenterWidth, 1));
	SpectatorSpeedLabel.SetText("Fly Speed");
	SpectatorSpeedLabel.SetFont(F_Normal);
	SpectatorSpeedLabel.SetTextColor(Basecolor);

	SpectatorSpeedSlider = BT_SliderControl(CreateControl(class'BT_SliderControl', CenterPos, ControlOffset+2, CenterWidth, 1));
	SpectatorSpeedSlider.SetRange(0, 6000, 1);
	SpectatorSpeedSlider.SetTextColor(Basecolor);
	SpectatorSpeedSlider.SetFont(F_Normal);
	SpectatorSpeedSlider.Align = TA_Right;
//	6	==========================================
	ControlOffset += ControlOffsetSpace;

	HideArmorCheck = BT_Checkbox(CreateControl(class'BT_Checkbox', CenterPos, ControlOffset, CenterWidth, 1));
	HideArmorCheck.SetText("Hide armor from HUD");
	HideArmorCheck.SetTextColor(Basecolor);
	HideArmorCheck.SetFont(F_Normal);
	HideArmorCheck.Align = TA_Left;
//	7	==========================================
	ControlOffset += ControlOffsetSpace;

	GhostSpectatorCheck = BT_Checkbox(CreateControl(class'BT_Checkbox', CenterPos, ControlOffset, CenterWidth, 1));
	GhostSpectatorCheck.SetText("Ghost Spectator");
	GhostSpectatorCheck.SetTextColor(Basecolor);
	GhostSpectatorCheck.SetFont(F_Normal);
	GhostSpectatorCheck.Align = TA_Left;
//	8	==========================================
	ControlOffset += ControlOffsetSpace;

	OpenSettingsLabel = UMenuLabelControl(CreateControl(class'UMenuLabelControl', CenterPos, ControlOffset, LabelWidth, 1));
	OpenSettingsLabel.SetText("Open Spectator Settings Window");
	OpenSettingsLabel.SetTextColor(Basecolor);
	OpenSettingsLabel.SetFont(F_Normal);

	OpenSettingsButton = UMenuRaisedButton(CreateControl(class'UMenuRaisedButton', ButtonLeft, ControlOffset-3, ButtonWidth, 1));
	OpenSettingsButton.bAcceptsFocus = False;
	OpenSettingsButton.bIgnoreLDoubleClick = True;
	OpenSettingsButton.bIgnoreMDoubleClick = True;
	OpenSettingsButton.bIgnoreRDoubleClick = True;

	ResetOpenSettingsButton = UWindowSmallButton(CreateControl(class'UWindowSmallButton', ResetLeft, ControlOffset-2, ButtonWidth, 20));
	ResetOpenSettingsButton.DownSound = Sound'Botpack.Click';
	ResetOpenSettingsButton.Text = "Remove";

	LoadExistingKeys();
}

function LoadExistingKeys()
{
	local int i;
	local string KeyName, Alias;

	for(i = 0; i < 255; i++)
	{
		KeyName = GetPlayerOwner().ConsoleCommand("KEYNAME " $ i);
		RealKeyName[i] = KeyName;

		if(KeyName != "")
		{
			Alias = Caps(GetPlayerOwner().ConsoleCommand("KEYBINDING " $ KeyName));

			switch(Alias)
			{
				case "MUTATE AUTOBEHINDVIEW":
					BehindviewToggleButton.SetText(KeyName);
				break;

				case "MUTATE BTE":
					OpenSettingsButton.SetText(KeyName);
				break;
			}
		}
	}
}

function LoadSettings()
{
	local float S;

	bInitialized = false;

	BehindviewAutoFollowCheck.bChecked = BTCS.bBehindviewFollow;
	HideArmorCheck.bChecked = BTCS.bHideArmor;
	GhostSpectatorCheck.bChecked = BTCS.bGhostSpectator;

	BehindviewSmoothingSlider.SetValue(BTCS.BehindviewSmoothing);
	BehindviewSmoothingSlider.SetText("[" $ int(BehindviewSmoothingSlider.Value) $ "]");

	BehindviewDistanceSlider.SetValue(BTCS.BehindviewDistance);
	S = (BehindviewDistanceSlider.Value / 180) * 100;
	BehindviewDistanceSlider.SetText("[" $ int(S) $ "%]");

	SpectatorSpeedSlider.SetValue(BTCS.SpectatorFlySpeed);
	S = (SpectatorSpeedSlider.Value / 300) * 100;
	SpectatorSpeedSlider.SetText("[" $ int(S) $ "%]");

	bInitialized = true;
}

function KeyDown(int Key, float X, float Y)
{
	if(bPolling)
	{
		ProcessMenuKey(Key, RealKeyName[Key]);
		bPolling = False;
		SelectedButton.bDisabled = False;
	}
}

function ProcessMenuKey(int KeyNo, string KeyName)
{
	if ( (KeyName == "") || (KeyName == "Escape")  
		|| ((KeyNo >= 0x70 ) && (KeyNo <= 0x79)) // function keys
		|| ((KeyNo >= 0x30 ) && (KeyNo <= 0x39))) // number keys
		return;

	if(BehindviewToggleButton.bDisabled)
	{
		GetPlayerOwner().ConsoleCommand("SET INPUT " $ BehindviewToggleButton.Text);
		GetPlayerOwner().ConsoleCommand("SET INPUT " $ KeyName $ " MUTATE AUTOBEHINDVIEW");
		SelectedButton.SetText(KeyName);
	}
	else if(OpenSettingsButton.bDisabled)
	{
		GetPlayerOwner().ConsoleCommand("SET INPUT " $ OpenSettingsButton.Text);
		GetPlayerOwner().ConsoleCommand("SET INPUT " $ KeyName $ " MUTATE BTE");
		SelectedButton.SetText(KeyName);
	}
}

function Notify(UWindowDialogControl C, byte E)
{
	Super.Notify(C, E);

	if(bInitialized)
	{
		switch(E)
		{
			case DE_RClick:
				if(bPolling)
				{
					if(C == SelectedButton)
					{
						ProcessMenuKey(2, "RightMouse");
						bPolling = False;
						SelectedButton.bDisabled = False;
						return;
					}
				}
			break;

			case DE_MClick:
				if(bPolling)
				{
					if(C == SelectedButton)
					{
						ProcessMenuKey(4, "MiddleMouse");
						bPolling = False;
						SelectedButton.bDisabled = False;
						return;
					}
				}
			break;

			case DE_Click:
				if(bPolling)
				{
					if(C == SelectedButton)
					{
						ProcessMenuKey(1, "LeftMouse");
						bPolling = False;
						SelectedButton.bDisabled = False;
						return;
					}
				}
			    switch(C)
        	    {
					case ResetBehindviewToggleButton:
						GetPlayerOwner().ConsoleCommand("SET INPUT " $ BehindviewToggleButton.Text);
						BehindviewToggleButton.SetText("");
						LoadExistingKeys();
					break;
					case ResetOpenSettingsButton:
						GetPlayerOwner().ConsoleCommand("SET INPUT " $ OpenSettingsButton.Text);
						OpenSettingsButton.SetText("");
						LoadExistingKeys();
					break;

					case BehindviewToggleButton:
					case OpenSettingsButton:
						GetPlayerOwner().ClientMessage("CLICK");
						if(UMenuRaisedButton(C) != None)
						{
							SelectedButton = UMenuRaisedButton(C);
							bPolling = True;
							SelectedButton.bDisabled = True;
						}
					break;
				}
			break;

			case DE_Change:
				switch(C)
				{
					case BehindviewAutoFollowCheck:
						BehindviewAutoFollowChanged();
					break;

					case HideArmorCheck:
						HideArmorChanged();
					break;

					case BehindviewSmoothingSlider:
						BehindviewSmoothingChanged();
					break;

					case BehindviewDistanceSlider:
						BehindviewDistanceChanged();
					break;

					case SpectatorSpeedSlider:
						SpectatorSpeedChanged();
					break;

					case GhostSpectatorCheck:
						GhostSpectatorChanged();
					break;
				}
			break;
		}
	}
}

function GhostSpectatorChanged()
{
	local BTSpectator BTSpec;

	BTSpec = BTSpectator(GetPlayerOwner());
	if(BTSpec != None)
	{
		BTSpec.bCollideWorld = !GhostSpectatorCheck.bChecked;
		BTSpec.bGhostSpectator = GhostSpectatorCheck.bChecked;
	}
	BTCS.SwitchBool("bGhostSpectator");
}

function BehindviewAutoFollowChanged()
{
	BTCS.SwitchBool("bBehindviewFollow");
}

function HideArmorChanged()
{
	BTCS.SwitchBool("bHideArmor");
}

function BehindviewSmoothingChanged()
{
	local float S;
	BTCS.IntSetting("BehindviewSmoothing", BehindviewSmoothingSlider.Value);

	if(BTSpectator(GetPlayerOwner()) != None)
		BTSpectator(GetPlayerOwner()).BehindviewSmoothing = BehindviewSmoothingSlider.Value;

	BehindviewSmoothingSlider.SetText("[" $ int(BehindviewSmoothingSlider.Value) $ "]");
}

function BehindviewDistanceChanged()
{
	local float S;
	BTCS.IntSetting("BehindViewDistance", BehindviewDistanceSlider.Value);

	if(BTSpectator(GetPlayerOwner()) != None)
		BTSpectator(GetPlayerOwner()).BehindViewDistance = BehindviewDistanceSlider.Value;

	S = (BehindviewDistanceSlider.Value / 180) * 100;
	BehindviewDistanceSlider.SetText("[" $ int(S) $ "%]");
}

function SpectatorSpeedChanged()
{
	local float S;
	BTCS.IntSetting("SpectatorFlySpeed", SpectatorSpeedSlider.Value);

	if(BTSpectator(GetPlayerOwner()) != None)
		BTSpectator(GetPlayerOwner()).SpectatorFlySpeed = SpectatorSpeedSlider.Value;

	S = (SpectatorSpeedSlider.Value / 300) * 100;
	SpectatorSpeedSlider.SetText("[" $ int(S) $ "%]");
}

defaultproperties
{
	ControlOffset=8
	ControlOffsetSpace=22
	Basecolor=(R=0,G=0,B=0)
}