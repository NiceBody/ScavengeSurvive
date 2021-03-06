#include <YSI\y_hooks>


new
		wep_CurrentWeapon[MAX_PLAYERS],
		wep_ReserveAmmo[MAX_PLAYERS],
		tick_LastReload[MAX_PLAYERS];


forward OnPlayerUseWeaponWithItem(playerid, weapon, itemid);


// Zeroing and Load


hook OnGameModeInit()
{
	new
		size,
		name[32];

	DefineItemType("NULL", 0, ITEM_SIZE_SMALL);

	ShiftItemTypeIndex(ItemType:1, 46);

	for(new i = 1; i < 46; i++)
	{
		GetWeaponName(i, name);

		switch(i)
		{
			case 1, 4, 16, 17, 22..24, 41, 43, 44, 45:
				size = ITEM_SIZE_SMALL;

			case 18, 10..13, 26, 28, 32, 39, 40:
				size = ITEM_SIZE_MEDIUM;

			default: size = ITEM_SIZE_LARGE;
		}

		DefineItemType(name, GetWeaponModel(i), size, .rotx = 90.0);
	}
	print("Loaded weapon item data");
	return 1;
}
hook OnPlayerConnect(playerid)
{
	wep_CurrentWeapon[playerid] = 0;
	wep_ReserveAmmo[playerid] = 0;
}
hook OnPlayerDeath(playerid, killerid, reason)
{
	wep_CurrentWeapon[playerid] = 0;
	wep_ReserveAmmo[playerid] = 0;
}


// Core


SetPlayerWeapon(playerid, weaponid, ammo)
{
	if(!IsPlayerConnected(playerid))
		return 0;

	if(wep_CurrentWeapon[playerid] == 0)
	{
		if(ammo > GetWeaponMagSize(weaponid))
		{
			if(GetWeaponAmmoMax(weaponid) > 0)
				wep_ReserveAmmo[playerid] += ammo - GetWeaponMagSize(weaponid);

			ammo = GetWeaponMagSize(weaponid);
		}

		UpdateWeaponUI(playerid);
	}
	else
	{
		if(weaponid != wep_CurrentWeapon[playerid])
			return 0;

		GivePlayerAmmo(playerid, ammo);
		ammo = 0;
	}

	ResetPlayerWeapons(playerid);
	wep_CurrentWeapon[playerid] = weaponid;
	return GivePlayerWeapon(playerid, weaponid, ammo);
}

GivePlayerAmmo(playerid, amount)
{
	new maxammo = GetWeaponAmmoMax(wep_CurrentWeapon[playerid]) * GetWeaponMagSize(wep_CurrentWeapon[playerid]);

	if(wep_ReserveAmmo[playerid] + amount > maxammo)
	{
		new remainder = wep_ReserveAmmo[playerid] + amount - maxammo;
		wep_ReserveAmmo[playerid] = maxammo;
		UpdateWeaponUI(playerid);
		return remainder;
	}
	else
	{
		wep_ReserveAmmo[playerid] += amount;
		UpdateWeaponUI(playerid);
		return 0;
	}
}

stock GetPlayerCurrentWeapon(playerid)
{
	if(!IsPlayerConnected(playerid))
		return 0;

	return wep_CurrentWeapon[playerid];
}

stock GetPlayerTotalAmmo(playerid)
{
	if(!IsPlayerConnected(playerid))
		return 0;

	return GetPlayerAmmo(playerid) + wep_ReserveAmmo[playerid];
}

stock GetPlayerClipAmmo(playerid)
{
	if(!IsPlayerConnected(playerid))
		return 0;

	return GetPlayerAmmo(playerid);
}

stock GetPlayerReserveAmmo(playerid)
{
	if(!IsPlayerConnected(playerid))
		return 0;

	return wep_ReserveAmmo[playerid];
}

stock RemovePlayerWeapon(playerid)
{
	if(!IsPlayerConnected(playerid))
		return 0;

	ResetPlayerWeapons(playerid);
	wep_CurrentWeapon[playerid] = 0;
	wep_ReserveAmmo[playerid] = 0;

	return 1;
}

stock IsWeaponMelee(weaponid)
{
	switch(weaponid)
	{
		case 1..15:
			return 1;
	}
	return 0;
}

stock IsWeaponThrowable(weaponid)
{
	switch(weaponid)
	{
		case 16..18, 39:
			return 1;
	}
	return 0;
}

stock IsWeaponClipBased(weaponid)
{
	switch(weaponid)
	{
		case 22..38, 41..43:
			return 1;
	}
	return 0;
}

stock IsWeaponOneShot(weaponid)
{
	switch(weaponid)
	{
		case :
			return 1;
	}
	return 0;
}

stock GetAmmunitionRemainder(weaponid, startammo, ammunition)
{
	new remainder = startammo + ammunition - (GetWeaponAmmoMax(weaponid) * GetWeaponMagSize(weaponid));

	if(remainder < 0)
		return 0;

	return remainder;
}


// Hooks and Internal


hook OnPlayerUpdate(playerid)
{
	UpdateWeaponUI(playerid);

	if(wep_CurrentWeapon[playerid] == 0)
		return 1;

	if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
	{
		SetPlayerArmedWeapon(playerid, wep_CurrentWeapon[playerid]);

		new
			id,
			ammo;

		GetPlayerWeaponData(playerid, GetWeaponSlot(wep_CurrentWeapon[playerid]), id, ammo);

		if(ammo == 0 && wep_CurrentWeapon[playerid] == id && id != 0)
		{
			if(ReloadWeapon(playerid) == -1)
			{
				RemovePlayerWeapon(playerid);
			}
		}
	}

	return 1;
}

ReloadWeapon(playerid)
{
	if(tickcount() - tick_LastReload[playerid] < 1000)
		return 0;

	if(!IsWeaponClipBased(wep_CurrentWeapon[playerid]))
		return -1;

	if(GetPlayerAmmo(playerid) == GetWeaponMagSize(wep_CurrentWeapon[playerid]))
		return -2;

	if(wep_CurrentWeapon[playerid] == 0)
		return -3;

	if(wep_ReserveAmmo[playerid] <= 0)
	{
		if(GetPlayerAmmo(playerid) <= 0 && !IsWeaponThrowable(wep_CurrentWeapon[playerid]))
		{
			GiveWorldItemToPlayer(playerid, CreateItem(ItemType:wep_CurrentWeapon[playerid]));
			ResetPlayerWeapons(playerid);
			wep_CurrentWeapon[playerid] = 0;
			wep_ReserveAmmo[playerid] = 0;
		}

		return 0;
	}

	new
		clip = GetPlayerAmmo(playerid),
		ammo;

	if(wep_ReserveAmmo[playerid] + clip > GetWeaponMagSize(wep_CurrentWeapon[playerid]))
	{
		ammo = GetWeaponMagSize(wep_CurrentWeapon[playerid]);
		wep_ReserveAmmo[playerid] -= (GetWeaponMagSize(wep_CurrentWeapon[playerid]) - clip);
	}
	else
	{
		ammo = wep_ReserveAmmo[playerid] + clip;
		wep_ReserveAmmo[playerid] = 0;
	}

	switch(wep_CurrentWeapon[playerid])
	{
		default:
			ApplyAnimation(playerid, "COLT45", "COLT45_RELOAD", 4.1, 0, 1, 1, 0, 0);
	}

	ResetPlayerWeapons(playerid);
	GivePlayerWeapon(playerid, wep_CurrentWeapon[playerid], ammo);
	UpdateWeaponUI(playerid);

	tick_LastReload[playerid] = tickcount();

	return 1;
}

UpdateWeaponUI(playerid)
{
	if(IsWeaponClipBased(wep_CurrentWeapon[playerid]))
	{
		if(GetPlayerAmmo(playerid) > GetWeaponMagSize(wep_CurrentWeapon[playerid]))
			SetPlayerAmmo(playerid, wep_CurrentWeapon[playerid], GetWeaponMagSize(wep_CurrentWeapon[playerid]));

		new str[8];

		if(GetWeaponAmmoMax(wep_CurrentWeapon[playerid]) > 0)
			format(str, 8, "%d/%d", GetPlayerAmmo(playerid), wep_ReserveAmmo[playerid]);

		else
			format(str, 8, "%d", GetPlayerAmmo(playerid));

		PlayerTextDrawSetString(playerid, WeaponAmmo, str);
		PlayerTextDrawShow(playerid, WeaponAmmo);
	}
	else
	{
		PlayerTextDrawHide(playerid, WeaponAmmo);
	}
}

ConvertPlayerItemToWeapon(playerid)
{
	new
		itemid,
		ItemType:itemtype,
		ammo;

	itemid = GetPlayerItem(playerid);
	itemtype = GetItemType(itemid);
	ammo = GetItemExtraData(itemid);

	if(!(1 <= _:itemtype <= 46))
		return 0;

	if(ammo <= 0)
		return 0;

	DestroyItem(itemid);
	SetPlayerWeapon(playerid, _:itemtype, ammo);

	return 1;
}

ConvertPlayerWeaponToItem(playerid)
{
	new
		weaponid,
		ammo,
		itemid;

	weaponid = wep_CurrentWeapon[playerid];
	ammo = GetPlayerAmmo(playerid) + wep_ReserveAmmo[playerid];

	if(weaponid == 0)
		return 0;

	RemovePlayerWeapon(playerid);

	itemid = CreateItem(ItemType:weaponid);
	GiveWorldItemToPlayer(playerid, itemid);
	SetItemExtraData(itemid, ammo);

	wep_CurrentWeapon[playerid] = 0;
	wep_ReserveAmmo[playerid] = 0;

	return 1;
}

public OnPlayerPickUpItem(playerid, itemid)
{
	new ItemType:type = GetItemType(itemid);

	if(0 < _:type < WEAPON_PARACHUTE)
	{
		if(wep_CurrentWeapon[playerid] == 0)
		{
			if(GetItemExtraData(itemid) > 0)
			{
				PlayerPickUpWeapon(playerid, itemid);
				return 1;
			}
		}
		else if(IsWeaponClipBased(wep_CurrentWeapon[playerid]))
		{
			if(wep_CurrentWeapon[playerid] != _:type)
			{
				return 1;
			}
			else
			{
				if(GetItemExtraData(itemid) == 0)
					return 1;

				PlayerPickUpWeapon(playerid, itemid);
				return 1;
			}
		}
		else
		{
			return 1;
		}
	}
	else
	{
		if(GetPlayerWeapon(playerid) != 0)
		{
			CallLocalFunction("OnPlayerUseWeaponWithItem", "ddd", playerid, GetPlayerWeapon(playerid), itemid);

			return 1;
		}
	}

	return CallLocalFunction("wep_OnPlayerPickUpItem", "dd", playerid, itemid);
}
#if defined _ALS_OnPlayerPickUpItem
	#undef OnPlayerPickUpItem
#else
	#define _ALS_OnPlayerPickUpItem
#endif
#define OnPlayerPickUpItem wep_OnPlayerPickUpItem
forward wep_OnPlayerPickUpItem(playerid, itemid);

public OnPlayerUseItemWithItem(playerid, itemid, withitemid)
{
	new
		ItemType:itemtype,
		ItemType:withitemtype;

	itemtype = GetItemType(itemid);
	withitemtype = GetItemType(withitemid);

	if(0 < _:itemtype < WEAPON_PARACHUTE)
	{
		if(itemtype == withitemtype)
		{
			PlayerPickUpWeapon(playerid, withitemid);
			return 1;
		}
	}

	return CallLocalFunction("wep_OnPlayerUseItemWithItem", "ddd", playerid, itemid, withitemid);
}
#if defined _ALS_OnPlayerUseItemWithItem
	#undef OnPlayerUseItemWithItem
#else
	#define _ALS_OnPlayerUseItemWithItem
#endif
#define OnPlayerUseItemWithItem wep_OnPlayerUseItemWithItem
forward wep_OnPlayerUseItemWithItem(playerid, itemid, withitemid);


public OnPlayerRemoveFromInventory(playerid, slotid)
{
	if(!IsValidContainer(GetPlayerCurrentContainer(playerid)))
	{
		new
			itemid,
			ItemType:itemtype;

		itemid = GetInventorySlotItem(playerid, slotid);
		itemtype = GetItemType(itemid);

		if(0 < _:itemtype < WEAPON_PARACHUTE)
		{
			SetPlayerWeapon(playerid, _:itemtype, GetItemExtraData(itemid));
			DestroyItem(itemid);
		}
	}

	return CallLocalFunction("wep_OnPlayerRemoveFromInv", "dd", playerid, slotid);
}
#if defined _ALS_OnPlayerRemoveFromInv
	#undef OnPlayerRemoveFromInventory
#else
	#define _ALS_OnPlayerRemoveFromInv
#endif
#define OnPlayerRemoveFromInventory wep_OnPlayerRemoveFromInv
forward OnPlayerRemoveFromInventory(playerid, slotid);

public OnItemRemoveFromContainer(containerid, slotid, playerid)
{
	if(IsPlayerConnected(playerid))
	{
		new
			itemid,
			ItemType:itemtype;

		itemid = GetContainerSlotItem(containerid, slotid);
		itemtype = GetItemType(itemid);

		if(0 < _:itemtype < 46)
		{
			SetPlayerWeapon(playerid, _:GetItemType(itemid), GetItemExtraData(itemid));
			DestroyItem(itemid);
		}
	}

	return CallLocalFunction("wep_OnItemRemoveFromContainer", "ddd", containerid, slotid, playerid);
}
#if defined _ALS_OnItemRemoveFromContainer
	#undef OnItemRemoveFromContainer
#else
	#define _ALS_OnItemRemoveFromContainer
#endif
#define OnItemRemoveFromContainer wep_OnItemRemoveFromContainer
forward wep_OnItemRemoveFromContainer(containerid, slotid, playerid);

hook OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(bPlayerGameSettings[playerid] & KnockedOut)
		return 1;

	if(IsPlayerInAnyVehicle(playerid))
		return 1;

	if(GetPlayerItem(playerid) != INVALID_ITEM_ID)
		return 1;

	if(newkeys & 1)
	{
		ReloadWeapon(playerid);
	}

	if(newkeys & KEY_NO && !(newkeys & 128))
	{
		if(IsPlayerIdle(playerid) && wep_CurrentWeapon[playerid] != 0)
		{
			foreach(new i : Player)
			{
				if(i == playerid)
					continue;

				if(IsPlayerInDynamicArea(playerid, gPlayerArea[i]))
				{
					if(tickcount() - GetPlayerWeaponSwapTick(i) < 1000)
						continue;

					if(GetPlayerWeapon(i) != 0)
						continue;

					if(GetPlayerItem(playerid) != INVALID_ITEM_ID || GetPlayerItem(i) != INVALID_ITEM_ID)
						continue;

					if(!IsPlayerIdle(i))
						continue;

					if(GetPlayerSpecialAction(i) == SPECIAL_ACTION_CUFFED || bPlayerGameSettings[i] & AdminDuty || bPlayerGameSettings[i] & KnockedOut || GetPlayerAnimationIndex(i) == 1381)
						continue;

					PlayerGiveWeapon(playerid, i);
					return 1;
				}
			}

			PlayerDropWeapon(playerid);
		}
	}
	return 1;
}

PlayerPickUpWeapon(playerid, itemid)
{
	new
		Float:x,
		Float:y,
		Float:z,
		Float:ix,
		Float:iy,
		Float:iz;

	GetPlayerPos(playerid, x, y, z);
	GetItemPos(itemid, ix, iy, iz);
	SetPlayerFacingAngle(playerid, GetAngleToPoint(x, y, ix, iy));

	if((z - iz) < 0.3)
	{
		ApplyAnimation(playerid, "CASINO", "SLOT_PLYR", 4.0, 0, 0, 0, 0, 0);
		defer PickUpWeaponDelay(playerid, itemid, 1);
	}
	else
	{
		ApplyAnimation(playerid, "BOMBER", "BOM_PLANT_IN", 5.0, 0, 0, 0, 0, 450);
		defer PickUpWeaponDelay(playerid, itemid, 0);
	}
}
timer PickUpWeaponDelay[400](playerid, itemid, animtype)
{
	if(animtype == 0)
		ApplyAnimation(playerid, "BOMBER", "BOM_PLANT_2IDLE", 4.0, 0, 0, 0, 0, 0);

	new ItemType:type = GetItemType(itemid);

	if(0 < _:type < WEAPON_PARACHUTE)
	{
		if(wep_CurrentWeapon[playerid] == 0)
		{
			new ammo;

			if(IsWeaponClipBased(_:type))
				ammo = GetItemExtraData(itemid);

			else
				ammo = 1;

			if(ammo > 0)
			{
				new curitem = GetPlayerItem(playerid);

				if(IsValidItem(curitem))
				{
					DestroyItem(curitem);
					SetItemExtraData(itemid, 0);
				}
				else
				{
					DestroyItem(itemid);					
				}

				SetPlayerWeapon(playerid, _:type, ammo);
				wep_CurrentWeapon[playerid] = _:type;
			}
		}
		else if(wep_CurrentWeapon[playerid] == _:type)
		{
			new ammo = GetItemExtraData(itemid);

			if(ammo > 0)
			{
				new remainder = GivePlayerAmmo(playerid, ammo);

				SetItemExtraData(itemid, remainder);
			}
		}
	}
}

PlayerDropWeapon(playerid)
{
	if(wep_CurrentWeapon[playerid] > 0)
	{
		ConvertPlayerWeaponToItem(playerid);
		PlayerDropItem(playerid);
	}
}

PlayerGiveWeapon(playerid, targetid)
{
	if(wep_CurrentWeapon[playerid] > 0 && wep_CurrentWeapon[targetid] == 0)
	{
		ConvertPlayerWeaponToItem(playerid);
		PlayerGiveItem(playerid, targetid);
	}
}

public OnPlayerGivenItem(playerid, targetid, itemid)
{
	if(wep_CurrentWeapon[targetid] != 0)
		return 1;

	new ItemType:type = GetItemType(itemid);

	if(0 < _:type < WEAPON_PARACHUTE)
	{
		ConvertPlayerItemToWeapon(targetid);
	}

	return CallLocalFunction("wep_OnPlayerGivenItem", "ddd", playerid, targetid, itemid);
}
#if defined _ALS_OnPlayerGivenItem
	#undef OnPlayerGivenItem
#else
	#define _ALS_OnPlayerGivenItem
#endif
#define OnPlayerGivenItem wep_OnPlayerGivenItem
forward wep_OnPlayerGivenItem(playerid, targetid, itemid);


IsPlayerIdle(playerid)
{
	new animidx = GetPlayerAnimationIndex(playerid);
	switch(animidx)
	{
		case 320, 1164, 1183, 1188, 1189:return 1;
		default: return 0;
	}
	return 0;
}

public OnItemNameRender(itemid)
{
	new ItemType:itemtype = GetItemType(itemid);

	if(0 <= _:itemtype < WEAPON_PARACHUTE)
	{
		if(GetWeaponMagSize(_:itemtype) > 1)
		{
			new exname[5];
			valstr(exname, GetItemExtraData(itemid));
			SetItemNameExtra(itemid, exname);
		}
	}

	return CallLocalFunction("wep_OnItemNameRender", "d", itemid);
}
#if defined _ALS_OnItemNameRender
	#undef OnItemNameRender
#else
	#define _ALS_OnItemNameRender
#endif
#define OnItemNameRender wep_OnItemNameRender
forward wep_OnItemNameRender(itemid);

stock IsWeaponDriveby(weaponid)
{
	switch(weaponid)
	{
		case 28, 29, 32:
		{
			return 1;
		}
	}
	return 0;
}
