public OnPlayerUseItem(playerid, itemid)
{
	if(GetItemType(itemid) == item_Timebomb)
	{
		PlayerDropItem(playerid);
		defer TimeBombExplode(itemid);
		return 1;
	}
    return CallLocalFunction("tbm_OnPlayerUseItem", "dd", playerid, itemid);
}
#if defined _ALS_OnPlayerUseItem
    #undef OnPlayerUseItem
#else
    #define _ALS_OnPlayerUseItem
#endif
#define OnPlayerUseItem tbm_OnPlayerUseItem
forward tbm_OnPlayerUseItem(playerid, itemid);


timer TimeBombExplode[5000](itemid)
{
	new
		Float:x,
		Float:y,
		Float:z;

	GetItemPos(itemid, x, y, z);
	DestroyItem(itemid);
	CreateStructuralExplosion(x, y, z, 1, 8.0);
}
