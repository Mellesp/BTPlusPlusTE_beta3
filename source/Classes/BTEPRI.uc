//=============================================================================
// BTEPRI made by OwYeaW
//=============================================================================
class BTEPRI expands ReplicationInfo;

var PlayerPawn PP;
var int PlayerID;

var int	ArmorAmount, ChestAmount, ThighAmount, BootCharges;
var bool bShieldbelt, bChestArmor, bThighArmor, bJumpBoots, bCPEnabled;

//=============================================================================
// replicating armor + boots from server to clients
//=============================================================================
replication
{
	reliable if (Role == ROLE_Authority)
		PP, PlayerID, ArmorAmount, ChestAmount, ThighAmount, bShieldbelt, bChestArmor, bThighArmor, bJumpBoots, BootCharges, bCPEnabled;
}
event Spawned()
{
	if(Role == ROLE_Authority)
		Enable('Tick');
}
//=============================================================================
// Tick - checks armor and boots in player's inventory + netspeed check
//=============================================================================
function Tick(float d)
{
	Local inventory Inv;
	local int NetSpeed;
	local int i;

	if(Owner == None)
		Destroy();
	else
	{
		BootCharges = 0;
		ArmorAmount = 0;
		ThighAmount = 0;
		ChestAmount = 0;
		bJumpBoots = false;
		bShieldbelt = false;
		bThighArmor = false;
		bChestArmor = false;
		for(Inv = PP.Inventory; Inv != None; Inv = Inv.Inventory)
		{
			if(Inv.bIsAnArmor)
			{
				if( Inv.IsA('UT_Shieldbelt') )
					bShieldbelt = true;
				else if( Inv.IsA('Thighpads') )
				{
					ThighAmount += Inv.Charge;
					bThighArmor = true;
				}
				else
				{
					bChestArmor = true;
					ChestAmount += Inv.Charge;
				}
				ArmorAmount += Inv.Charge;
			}
			else if( Inv.IsA('UT_JumpBoots') )
			{
				bJumpBoots = true;
				BootCharges = Inv.Charge;
			}
			else
			{
				i++;
				if(i > 100)
					break; // can occasionally get temporary loops in netplay
			}
		}
	}
}
//=============================================================================
// Default Properties
//=============================================================================
defaultproperties
{
	RemoteRole=ROLE_SimulatedProxy
	NetPriority=9.000000
}