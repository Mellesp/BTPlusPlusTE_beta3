//=============================================================================
// BT_Checkbox made by OwYeaW
//=============================================================================
class BT_Checkbox expands UWindowCheckbox;
//-----------------------------------------------------------------------------
function KeyDown(int Key, float X, float Y)
{
	Super.KeyDown(Key, X, Y);
	ParentWindow.KeyDown(Key, X, Y);
}