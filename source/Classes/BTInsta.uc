/*
	BTPlusPlus Tournament is an improved version of BTPlusPlus 0.994
	Flaws have been corrected and extra features have been added
	BT++ Tournament Edition is created by OwYeaW

	BTPlusPlus 0.994
	Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

	This program is free software; you can redistribute and/or modify
	it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTInsta expands Mutator;

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	if ( Other.IsA('enforcer') )
		return false;

	return Super.CheckReplacement( Other, bSuperRelevant );
}