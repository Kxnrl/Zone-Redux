#include <maoling>
#include <zones>

#define BOX_MODEL "models/error.mdl"

#pragma newdecls required

enum data
{
	iColor[4],
	Float:fPos1[3],
	Float:fPos2[3],
	String:szName[64]
}

int g_BeamSprite;
int g_HaloSprite;

int g_iZones;
data g_eZones[MAXZONES][data];

Handle g_fwqOnEntry;
Handle g_fwqOnLeave;
Handle g_fwqOnFresh;

public Plugin myinfo =
{
	name		= "Zones - Core [Redux]",
	author		= "Kyle",  // Base on Franug & Root
	description = "",
	version		= "1.0",
	url			= "http://steamcommunity.com/id/_xQy_"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_fwqOnEntry = CreateGlobalForward("Zone_OnClientEntry", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_fwqOnLeave = CreateGlobalForward("Zone_OnClientLeave", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_fwqOnFresh = CreateGlobalForward("Zone_OnZoneFreshed", ET_Ignore);

	CreateNative("Zone_GetMapZoneCountsAll", Native_GetZoneCountsAll);
	CreateNative("Zone_GetMapZoneCountsByName", Native_GetZoneCountsByName);
	CreateNative("Zone_GetMapZoneIdByName", Native_GetZoneIdByName);

	return APLRes_Success;
}

public int Native_GetZoneCountsAll(Handle plugin, int numParams)
{
	return g_iZones;
}

public int Native_GetZoneCountsByName(Handle plugin, int numParams)
{
	char name[64];
	GetNativeString(1, name, 64);
	int counts;
	for(int i; i < g_iZones; ++i)
		if(StrContains(g_eZones[i][szName], name, false) != -1)
			counts++;
		
	return counts;
}

public int Native_GetZoneIdByName(Handle plugin, int numParams)
{
	char name[64];
	GetNativeString(1, name, 64);
	return GetZoneIdByName(name);
}

public void Event_OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	RefreshZones();
}

public void EntOut_OnStartTouch(const char[] output, int caller, int activator, float delay)
{	
	if(!IsValidClient(activator) ||!IsPlayerAlive(activator))
		return;

	char sTargetName[64];
	GetEntPropString(caller, Prop_Data, "m_iName", sTargetName, 64);
	ReplaceString(sTargetName, 64, "zones_", "");

	Call_StartForward(g_fwqOnEntry);
	Call_PushCell(activator);
	Call_PushCell(GetZoneIdByName(sTargetName));
	Call_PushString(sTargetName);
	Call_Finish();
}

public void EntOut_OnEndTouch(const char[] output, int caller, int activator, float delay)
{
	if(!IsValidClient(activator) ||!IsPlayerAlive(activator))
		return;

	char sTargetName[64];
	GetEntPropString(caller, Prop_Data, "m_iName", sTargetName, 64);
	ReplaceString(sTargetName, 64, "zones_", "");

	Call_StartForward(g_fwqOnLeave);
	Call_PushCell(activator);
	Call_PushCell(GetZoneIdByName(sTargetName));
	Call_PushString(sTargetName);
	Call_Finish();
}

public void OnMapStart()
{
	ReadZones();
	
	PrecacheModel(BOX_MODEL);
	g_BeamSprite = PrecacheModel("sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vmt");
}

public void OnMapEnd()
{
	if(g_iZones > 0) UnhookEvent("round_freeze_end", Event_OnRoundStart, EventHookMode_Post);
}

void ReadZones()
{
	g_iZones = 0;

	char szPath[128];
	GetCurrentMap(szPath, 128);
	BuildPath(Path_SM, szPath, 256, "configs/zones/%s.zones", szPath);
	
	if(!FileExists(szPath))
		return;

	Handle kv = CreateKeyValues("Zones");
	FileToKeyValues(kv, szPath);

	if(!KvGotoFirstSubKey(kv))
		return;

	float fTemp[3];
	do
	{
		KvGetVector(kv, "startloc", fTemp);
		g_eZones[g_iZones][fPos1] = fTemp;
		KvGetVector(kv, "endloc", fTemp);
		g_eZones[g_iZones][fPos2] = fTemp;
		KvGetString(kv, "name", g_eZones[g_iZones][szName], 64);
		switch(KvGetNum(kv, "type", 0))
		{
			case 1: g_eZones[g_iZones][iColor] = {0, 255, 0, 255};
			case 2: g_eZones[g_iZones][iColor] = {255, 0, 0, 255};
			case 3: g_eZones[g_iZones][iColor] = {0, 0, 255, 255};
			case 0: g_eZones[g_iZones][iColor] = {255, 255, 0, 255};
		}
		++g_iZones;
	}
	while(KvGotoNextKey(kv));

	CloseHandle(kv);
	
	CreateTimer(1.0, Timer_BeamBoxAll, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	HookEvent("round_freeze_end", Event_OnRoundStart, EventHookMode_Post);
}

public Action Timer_BeamBoxAll(Handle timer)
{
	for(int i = 0; i < g_iZones; ++i)
		TE_SendBeamBoxToAll(i);
}

stock int CreateZoneEntity(int zone)
{
	float fMins[3], fMaxs[3];
	
	fMins[0] = g_eZones[zone][fPos1][0];
	fMins[1] = g_eZones[zone][fPos1][1];
	fMins[2] = g_eZones[zone][fPos1][2];
	
	fMaxs[0] = g_eZones[zone][fPos2][0];
	fMaxs[1] = g_eZones[zone][fPos2][1];
	fMaxs[2] = g_eZones[zone][fPos2][2];
	
	int iEnt = CreateEntityByName("trigger_multiple");

	char sZoneName[64];
	DispatchKeyValue(iEnt, "spawnflags", "64");
	Format(sZoneName, 64, "zones_%s", g_eZones[zone][szName]);
	DispatchKeyValue(iEnt, "targetname", sZoneName);
	DispatchKeyValue(iEnt, "wait", "0");
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	SetEntProp(iEnt, Prop_Data, "m_spawnflags", 64 );

	float fMiddle[3];
	GetMiddleOfABox(fMins, fMaxs, fMiddle);

	TeleportEntity(iEnt, fMiddle, NULL_VECTOR, NULL_VECTOR);
	SetEntityModel(iEnt, BOX_MODEL);

	fMins[0] = fMins[0] - fMiddle[0];
	fMins[1] = fMins[1] - fMiddle[1];
	fMins[2] = fMins[2] - fMiddle[2];

	if(fMins[0] > 0.0) fMins[0] *= -1.0;
	if(fMins[1] > 0.0) fMins[1] *= -1.0;
	if(fMins[2] > 0.0) fMins[2] *= -1.0;

	fMaxs[0] = fMaxs[0] - fMiddle[0];
	fMaxs[1] = fMaxs[1] - fMiddle[1];
	fMaxs[2] = fMaxs[2] - fMiddle[2];
	
	if(fMaxs[0] < 0.0) fMaxs[0] *= -1.0;
	if(fMaxs[1] < 0.0) fMaxs[1] *= -1.0;
	if(fMaxs[2] < 0.0) fMaxs[2] *= -1.0;

	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2);

	int iEffects = GetEntProp(iEnt, Prop_Send, "m_fEffects");
	iEffects |= 32;
	SetEntProp(iEnt, Prop_Send, "m_fEffects", iEffects);

	HookSingleEntityOutput(iEnt, "OnStartTouch", EntOut_OnStartTouch);
	HookSingleEntityOutput(iEnt, "OnEndTouch", EntOut_OnEndTouch);
	
	return iEnt;
}

stock void TE_SendBeamBoxToAll(int zone)
{
	float uppercorner[3], bottomcorner[3];
	
	uppercorner[0] = g_eZones[zone][fPos1][0];
	uppercorner[1] = g_eZones[zone][fPos1][1];
	uppercorner[2] = g_eZones[zone][fPos1][2];
	
	bottomcorner[0] = g_eZones[zone][fPos2][0];
	bottomcorner[1] = g_eZones[zone][fPos2][1];
	bottomcorner[2] = g_eZones[zone][fPos2][2];

	// Create the additional corners of the box
	float tc1[3];
	AddVectors(tc1, uppercorner, tc1);
	tc1[0] = bottomcorner[0];
	
	float tc2[3];
	AddVectors(tc2, uppercorner, tc2);
	tc2[1] = bottomcorner[1];
	
	float tc3[3];
	AddVectors(tc3, uppercorner, tc3);
	tc3[2] = bottomcorner[2];
	
	float tc4[3];
	AddVectors(tc4, bottomcorner, tc4);
	tc4[0] = uppercorner[0];
	
	float tc5[3];
	AddVectors(tc5, bottomcorner, tc5);
	tc5[1] = uppercorner[1];
	
	float tc6[3];
	AddVectors(tc6, bottomcorner, tc6);
	tc6[2] = uppercorner[2];
	
	int Color[4];
	Color[0] = g_eZones[zone][iColor][0];
	Color[1] = g_eZones[zone][iColor][1];
	Color[2] = g_eZones[zone][iColor][2];
	Color[3] = g_eZones[zone][iColor][3];

	// Draw all the edges
	TE_SetupBeamPoints(uppercorner, tc1, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(uppercorner, tc2, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(uppercorner, tc3, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, tc1, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, tc2, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, bottomcorner, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, bottomcorner, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, bottomcorner, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, tc1, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, tc3, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, tc3, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, tc2, g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, Color, 0);
	TE_SendToAll();
	
}

stock void GetMiddleOfABox(const float start[3], const float end[3], float buffer[3])
{
	float mid[3];
	MakeVectorFromPoints(start, end, mid);
	mid[0] = mid[0] / 2.0;
	mid[1] = mid[1] / 2.0;
	mid[2] = mid[2] / 2.0;
	AddVectors(start, mid, buffer);
}

stock void RefreshZones()
{
	RemoveZones();

	for(int i; i < g_iZones; ++i)
		CreateZoneEntity(i);

	Call_StartForward(g_fwqOnFresh);
	Call_Finish();
}

stock void RemoveZones()
{
	int iEnt = -1;
	char szEntityName[32];
	while((iEnt = FindEntityByClassname(iEnt, "trigger_multiple")) != -1)
	{
		if(!IsValidEdict(iEnt))
			continue;

		GetEntPropString(iEnt, Prop_Data, "m_iName", szEntityName, 32);
		
		if(StrContains(szEntityName, "devzone") == -1)
			continue;

		UnhookSingleEntityOutput(iEnt, "OnStartTouch", EntOut_OnStartTouch);
		UnhookSingleEntityOutput(iEnt, "OnEndTouch", EntOut_OnEndTouch);
		AcceptEntityInput(iEnt, "Kill");
	}
}

stock int GetZoneIdByName(const char[] name)
{
	for(int i; i < g_iZones; ++i)
		if(StrEqual(g_eZones[i][szName], name, false))
			return i;
		
	return -1;
}