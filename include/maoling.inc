#include <sdktools>

stock bool IsValidClient(int client)
{
	if(client > MaxClients || client < 1)
		return false;

	if(!IsClientInGame(client))
		return false;

	return true;
}