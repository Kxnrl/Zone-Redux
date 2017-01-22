#include <zones>
#include <zombiereloaded>
#include <maoling>

#pragma newdecls required

#define PLUGIN_PREFIX "[\x0CCG\x01] \x04补给站\x0C>>>  \x01"

int g_iLastEntry[MAXPLAYERS+1];
int g_iLastLeave[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "Zones - Supply station",
	author = "maoling( xQy )",
	description = "",
	version = "1.0",
	url = "http://steamcommunity.com/id/_xQy_/"
};

public void OnPluginStart() 
{
	LoadTranslations("ze.phrases");
}

public void Zone_OnZoneFreshed()
{
	for(int client = 1; client <= MaxClients; ++client)
	{
		g_iLastEntry[client] = -1;
		g_iLastLeave[client] = -1;
	}
}

public void Zone_OnClientEntry(int client, int zone, const char[] name)
{
	if(!ZR_IsClientHuman(client))
		return;
	
	if(StrContains(name, "freeze", false) == -1 && StrContains(name, "push", false) == -1)
		return;
	
	if(zone == g_iLastEntry[client])
		return;
	
	g_iLastEntry[client] = zone;

	int weapons = GetPlayerWeaponSlot(client, 0);
	char weapon_string[32];

	if(IsValidEntity(weapons))
	{
		GetEdictClassname(weapons, weapon_string, 32);
		if(GetEntProp(weapons, Prop_Send, "m_iItemDefinitionIndex") == 60)
			strcopy(weapon_string, 32, "weapon_m4a1_silencer");
		RemovePlayerItem(client, weapons);
		AcceptEntityInput(weapons, "Kill");
	}

	GivePlayerItem(client, weapon_string);
	PrintToChat(client, "%s  %t", PLUGIN_PREFIX, "supply ammo received");
}

public void Zone_OnClientLeave(int client, int zone, const char[] name)
{
	if(!ZR_IsClientHuman(client))
		return;

	if(zone == g_iLastLeave[client])
		return;

	g_iLastLeave[client] = zone;

	if(StrContains(name, "freeze", false) != -1) SupplyFreezeWhenLeave(client);
	if(StrContains(name, "push", false) != -1) SupplyPushWhenLeave(client);
}


void SupplyFreezeWhenLeave(int client)
{
	GivePlayerItem(client, "weapon_hegrenade");
	GivePlayerItem(client, "weapon_hegrenade");
	GivePlayerItem(client, "weapon_decoy");
	PrintToChat(client, "%s  %t", PLUGIN_PREFIX, "supply freeze received");
}

void SupplyPushWhenLeave(int client)
{
	GivePlayerItem(client, "weapon_hegrenade");
	GivePlayerItem(client, "weapon_hegrenade");
	GivePlayerItem(client, "weapon_decoy");
	GivePlayerItem(client, "weapon_molotov");
	GivePlayerItem(client, "weapon_flashbang");
	
	if(GetEntProp(client, Prop_Send, "m_ArmorValue") < 100)
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", 100, 1);
		if(GetEntProp(client, Prop_Send, "m_bHasHeavyArmor"))
			SetEntProp(client, Prop_Send, "m_ArmorValue", 50, 1);
	}

	PrintToChat(client, "%s  %t", PLUGIN_PREFIX, "supply push received");
}