forward void Zone_OnClientEntry(int client, int zones, const char[] name);
forward void Zone_OnClientLeave(int client, int zones, const char[] name);
forward void Zone_OnZoneFreshed();

native int Zone_GetMapZoneCountsAll();
native int Zone_GetMapZoneCountsByName(const char[] name);
native int Zone_GetMapZoneIdByName(const char[] name);

#define MAXZONES 128