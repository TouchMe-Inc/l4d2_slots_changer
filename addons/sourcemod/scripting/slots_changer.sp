#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <nativevotes_rework>
#include <colors>


public Plugin myinfo = {
    name        = "SlotsChanger",
    author      = "TouchMe",
    description = "The plugin allows you to configure the initial number of slots and vote for increasing/decreasing slots",
    version     = "build_0002",
    url         = "https://github.com/TouchMe-Inc/l4d2_slots_changer"
}


#define TEAM_SPECTATE           1

#define VOTE_TIME               15


ConVar
    g_cvStartSlots = null,
    g_cvMaxSlots = null,
    g_cvMaxPlayers = null,
    g_cvSurvivorLimit = null,
    g_cvMaxPlayerZombies = null
;

bool g_bSlotChanged = false;

int g_iSlots = 4;


/**
 *
 */
public void OnPluginStart()
{
    LoadTranslations("slots_changer.phrases");

    RegConsoleCmd("sm_slots", Cmd_SlotsChange);

    g_cvStartSlots = CreateConVar("sm_start_slots", "18");
    g_cvMaxSlots = CreateConVar("sm_max_slots", "24");

    g_cvMaxPlayers = FindConVar("sv_maxplayers");
    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_cvMaxPlayerZombies = FindConVar("z_max_player_zombies");

    g_bSlotChanged = false;
}

/**
 * Called when the plugin is unloaded.
 *
 * Updates the maximum player slots based on required values.
 */
public void OnPluginEnd() {
    SetConVarInt(g_cvMaxPlayers, GetRequiredSlots());
}

/**
 * Called after configuration files have been executed.
 *
 * Ensures the initial player slot settings are applied if they haven't been changed.
 */
public void OnConfigsExecuted()
{
    if (!g_bSlotChanged)
    {
        SetConVarInt(g_cvMaxPlayers, GetConVarInt(g_cvStartSlots));
        g_bSlotChanged = true;
    }
}

/**
 *
 */
Action Cmd_SlotsChange(int iClient, int iArgs)
{
    if (!iClient) {
        return Plugin_Handled;
    }

    if (IsClientSpectator(iClient))
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "INVALID_TEAM", iClient);
        return Plugin_Handled;
    }

    if (iArgs != 1)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "INVALID_ARGS", iClient);
        return Plugin_Handled;
    }

    char szSlots[16]; GetCmdArg(1, szSlots, sizeof(szSlots));

    int iSlots = StringToInt(szSlots);

    int iMaxSlots = GetConVarInt(g_cvMaxSlots);

    if (iSlots > iMaxSlots)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "SLOT_OUT_OF_BOUND", iClient, iMaxSlots);
        return Plugin_Handled;
    }

    int iRequiredSlots = GetRequiredSlots();

    if (iSlots < iRequiredSlots)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "SLOT_LESS_THAN_NECESSARY", iClient, iRequiredSlots);
        return Plugin_Handled;
    }

    RunChangeSlotVote(iClient, iSlots);

    return Plugin_Handled;
}

/**
 *
 */
void RunChangeSlotVote(int iClient, int iSlots)
{
    if (!NativeVotes_IsNewVoteAllowed())
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "VOTE_COULDOWN", iClient, NativeVotes_CheckVoteDelay());
        return;
    }

    int iTotalPlayers;
    int[] iPlayers = new int[MaxClients];

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer) || IsClientSpectator(iPlayer)) {
            continue;
        }

        iPlayers[iTotalPlayers ++] = iPlayer;
    }

    g_iSlots = iSlots;

    NativeVote hVote = new NativeVote(HandlerVote, NativeVotesType_Custom_YesNo);
    hVote.Initiator = iClient;

    hVote.DisplayVote(iPlayers, iTotalPlayers, VOTE_TIME);
}

/**
 * Called when a vote action is completed.
 *
 * @param hVote             The vote being acted upon.
 * @param tAction           The action of the vote.
 * @param iParam1           First action parameter.
 * @param iParam2           Second action parameter.
 */
Action HandlerVote(NativeVote hVote, VoteAction tAction, int iParam1, int iParam2)
{
    switch (tAction)
    {
        case VoteAction_Display:
        {
            char sVoteDisplayMessage[128];
            FormatEx(sVoteDisplayMessage, sizeof(sVoteDisplayMessage), "%T", "VOTE_TITLE", iParam1, g_iSlots);

            hVote.SetDetails(sVoteDisplayMessage);

            return Plugin_Changed;
        }

        case VoteAction_Cancel: hVote.DisplayFail();

        case VoteAction_Finish:
        {
            if (iParam1 == NATIVEVOTES_VOTE_NO)
            {
                hVote.DisplayFail();

                return Plugin_Continue;
            }

            SetConVarInt(g_cvMaxPlayers, g_iSlots);

            hVote.DisplayPass();
        }

        case VoteAction_End: hVote.Close();
    }

    return Plugin_Continue;
}

/**
 * Checks if the client is a spectator.
 *
 * @param iClient           The client identifier.
 * @return                  true if the client is in the spectator team, otherwise false.
 */
bool IsClientSpectator(int iClient) {
    return (GetClientTeam(iClient) == TEAM_SPECTATE);
}

/**
 * Retrieves the required number of player slots.
 *
 * @return                  The sum of the g_cvSurvivorLimit and g_cvMaxPlayerZombies convars.
 */
int GetRequiredSlots() {
    return (GetConVarInt(g_cvSurvivorLimit) + GetConVarInt(g_cvMaxPlayerZombies));
}
