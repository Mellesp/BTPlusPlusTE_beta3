//=============================================================================
// BT_SliderControl made by OwYeaW
//=============================================================================
class BT_SliderControl expands UWindowHSliderControl;
//-----------------------------------------------------------------------------
function Created()
{
	Super.Created();
	SliderWidth = WinWidth / 1.5;
	TrackWidth = 4;
}

function BeforePaint(Canvas C, float X, float Y)
{
	local float W, H;

	Super.BeforePaint(C, X, Y);

	TextSize(C, Text, W, H);
	WinHeight = H+1;

	switch(Align)
	{
		case TA_Left:
			SliderDrawX = 0 + WinWidth * 0.2;
			SliderWidth = WinWidth - SliderDrawX;
			TextX = 0;
		break;

		case TA_Right:
			SliderDrawX = 0 + WinWidth * 0.2;
			TextX = WinWidth - W;
		break;

		case TA_Center:
			SliderDrawX = (WinWidth - SliderWidth) / 2;
			TextX = (WinWidth - W) / 2;
		break;
	}

	SliderDrawY = (WinHeight - 2) / 2;
	TextY = (WinHeight - H) / 2;

	TrackStart = SliderDrawX + (SliderWidth - TrackWidth) * ((Value - MinValue)/(MaxValue - MinValue));
}

function KeyDown(int Key, float X, float Y)
{
	Super.KeyDown(Key, X, Y);
	ParentWindow.KeyDown(Key, X, Y);
}