//=============================================================================
// BT_TabWindow made by OwYeaW
//=============================================================================
class BT_TabWindow expands UWindowDialogClientWindow;
//-----------------------------------------------------------------------------
var 	UWindowPageControl 			Pages;
var 	BT_PageSpectator			SpectatorPage;
//-----------------------------------------------------------------------------
var		UWindowLabelControl			SayLabel;
var 	UWindowSmallButton			SendButton;
var 	UWindowEditControl			txtMessage;
var		UWindowSmallButton			CloseButton;
//-----------------------------------------------------------------------------
function Created()
{  
	local UWindowPageControlPage PageControl;
	local int ButtonWidth, StuffHeight;

	Pages = UWindowPageControl(CreateWindow(class'UWindowPageControl', 0, 0, WinWidth, WinHeight));
	Pages.SetMultiLine(True);

	// Add the Spectator Page
	PageControl = Pages.AddPage("Spectator Settings", class'BT_PageSpectator');
	SpectatorPage = BT_PageSpectator(PageControl.Page);

	Super.Created();

	ButtonWidth = 60;
	StuffHeight = WinHeight - 20;

	SayLabel = UWindowLabelControl(CreateControl(class'UWindowLabelControl',	14,							StuffHeight+2,		48,					16));
	SayLabel.SetText("Say:");
	SayLabel.SetFont(F_Normal);

	txtMessage = UWindowEditControl(CreateControl(class'UWindowEditControl',	-163,						StuffHeight,		422,				16));
	txtMessage.Align = TA_Left;

	SendButton = UWindowSmallButton(CreateControl(class'UWindowSmallButton',	WinWidth-(ButtonWidth*2)-7,	StuffHeight,		ButtonWidth,		16));
	SendButton.DownSound = Sound'Botpack.Click';
	SendButton.Text = "Send";

	CloseButton = UWindowSmallButton(CreateControl(class'UWindowSmallButton',	WinWidth-ButtonWidth-1,		StuffHeight,		ButtonWidth,		16));
	CloseButton.DownSound = Sound'Botpack.Click';
	CloseButton.Text = "Close";
}

function Resized()
{
	Pages.WinWidth = WinWidth;
	Pages.WinHeight = WinHeight - 24;
}

function Paint(Canvas C, float X, float Y)
{
	local Texture T;

	T = GetLookAndFeelTexture();
	DrawUpBevel( C, 0, LookAndFeel.TabUnselectedM.H, WinWidth, WinHeight-LookAndFeel.TabUnselectedM.H, T);
}

function Notify(UWindowDialogControl C, byte E)
{
	Super.Notify(C,E);

	switch(E)
	{
		case DE_Click:
			switch(C)
			{
				case SendButton:
					if(txtMessage.GetValue() != "")
					{
						GetPlayerOwner().ConsoleCommand("SAY "$ txtMessage.GetValue());
						txtMessage.SetValue("");
					}
				break;

				case CloseButton:
					UWindowFramedWindow(GetParent(class'UWindowFramedWindow')).Close();
				break;
			}
		break;

		case DE_EnterPressed:
			switch(C)
			{
				case txtMessage:
					if(txtMessage.GetValue() != "")
					{
						GetPlayerOwner().ConsoleCommand("SAY "$ txtMessage.GetValue());
						txtMessage.SetValue("");
					}
				break;
			}
		break;
	}
}