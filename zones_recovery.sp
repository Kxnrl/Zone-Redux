#include <zones>
#include <zombiereloaded>
#include <cstrike>
#include <maoling>

#pragma newdecls required

#define PLUGIN_PREFIX "[\x0CCG\x01] \x10恢复站\x05>>>  \x01"
#define MAXSTATION 10

int g_iProtect[MAXPLAYERS+1];
int g_iLeft[MAXZONES];

public Plugin myinfo =
{
	name = "Zones - Recovery Station",
	author = "maoling( xQy )",
	description = "",
	version = "1.2",
	url = "http://steamcommunity.com/id/_xQy_/"
};

public void OnPluginStart()
{
	LoadTranslations("ze.phrases");
}

public void Zone_OnZoneFreshed()
{
	for(int client = 1; client <= MaxClients; ++client)
		g_iProtect[client] = 0;
	
	for(int zone; zone < MAXZONES; ++zone)
		g_iLeft[zone] = 10;
}

public void Zone_OnClientEntry(int client, int zone, const char[] name)
{
	if(StrContains(name, "recovery", false) == -1)
		return;

	if(ZR_IsClientHuman(client))
	{
		int maxhp = GetEntProp(client, Prop_Data, "m_iMaxHealth", 4, 0);
		if(GetClientHealth(client) < maxhp)
			SetEntityHealth(client, maxhp);
	}

	if(!ZR_IsClientZombie(client))
		return;

	if(g_iLeft[zone] > 0)
	{
		if(AllowZombieRecovery())
		{
			g_iLeft[zone]--;
			RecoveryClient(client);
		}
		else
			PrintToChat(client, "%s  %t", PLUGIN_PREFIX, "no enough zombies");
	}
	else
		PrintToChat(client, "%s  %t", PLUGIN_PREFIX, "goddess left");
}

bool AllowZombieRecovery()
{
	int zombies, players;
	for(int client = 1; client <= MaxClients; ++client)
		if(IsClientInGame(client))
		{
			if(GetClientTeam(client) > 1)
				players++;
			if(IsPlayerAlive(client) && ZR_IsClientZombie(client))
				zombies++;
		}
		
	if(zombies <= 1)
		return false;

	if(players/(zombies-1) >= 5)
		return true;

	return false;
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
	if(!IsValidClient(attacker))
		return Plugin_Continue;

	if(g_iProtect[client] > 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

void RecoveryClient(int client)
{
	float fPos[3], fAng[3];
	GetClientAbsOrigin(client, fPos);
	GetClientAbsAngles(client, fAng);
	CS_SwitchTeam(client, 3);
	CS_RespawnPlayer(client);
	ResetPlayerItem(client);
	TeleportEntity(client, fPos, fAng, NULL_VECTOR);

	g_iProtect[client] = 10;
	CreateTimer(1.0, Timer_Protect, client, TIMER_REPEAT);
	
	PrintToChatAll("%s  %t", PLUGIN_PREFIX, "turn back to human", client);
}

public Action Timer_Protect(Handle timer, int client)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || g_iProtect[client] <= 0 || ZR_IsClientZombie(client))
	{
		g_iProtect[client] = 0;
		return Plugin_Stop;
	}

	g_iProtect[client]--;
	PrintToChat(client, "%s  %t", PLUGIN_PREFIX, "immune infect coutdown", g_iProtect[client]);
	
	return Plugin_Continue;
}

void ResetPlayerItem(int client)
{
	RemoveAllWeapon(client);
	GivePlayerItem(client, "weapon_p90");
	GivePlayerItem(client, "weapon_p250");
	GivePlayerItem(client, "weapon_knife");
}

stock void RemoveAllWeapon(int client)
{
	RemoveWeaponBySlot(client, 0);
	RemoveWeaponBySlot(client, 1);
	RemoveWeaponBySlot(client, 2);
	while(RemoveWeaponBySlot(client, 3)){}
	while(RemoveWeaponBySlot(client, 4)){}
	
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, 14);
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, 15);
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, 16);
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, 18);
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, 17);
}

stock bool RemoveWeaponBySlot(int client, int slot)
{
	int iWeapon = GetPlayerWeaponSlot(client, slot);

	if(IsValidEdict(iWeapon))
	{
		RemovePlayerItem(client, iWeapon);
		AcceptEntityInput(iWeapon, "Kill");
		return true;
	}

	return false;
}