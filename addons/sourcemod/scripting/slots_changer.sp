#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <nativevotes_rework>
#include <left4dhooks>
#include <colors>


public Plugin myinfo =
{
	name = "SlotsChanger",
	author = "TouchMe",
	description = "N/a",
	version = "build0000",
	url = "https://github.com/TouchMe-Inc/l4d2_slots_changer"
}


#define TEAM_SPECTATE           1

#define VOTE_TIME               15

ConVar
	g_cvMaxSlots = null,
	g_cvSurvivorLimit = null,
	g_cvMaxPlayerZombies = null
;

int g_iSlots = 0;
int g_iNotConfirmSlots[MAXPLAYERS + 1] = {0, ...};


public void OnPluginStart()
{
	LoadTranslations("slots_changer.phrases");

	RegConsoleCmd("sm_slots", Cmd_SlotsChange);

	g_cvMaxSlots = CreateConVar("sm_max_slots", "24");
	g_cvSurvivorLimit = FindConVar("survivor_limit");
	g_cvMaxPlayerZombies = FindConVar("z_max_player_zombies");
}

public Action Cmd_SlotsChange(int iClient, int iArgs)
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

	char sSlots[16]; GetCmdArg(1, sSlots, sizeof(sSlots));

	int iSlots = StringToInt(sSlots);

	int iMaxSlots = GetConVarInt(g_cvMaxSlots);

	if (iSlots > iMaxSlots)
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "SLOT_OUT_OF_BOUND", iClient, iMaxSlots);
		return Plugin_Handled;
	}

	int iRequiredSlots = GetConVarInt(g_cvSurvivorLimit) + GetConVarInt(g_cvMaxPlayerZombies);

	if (iSlots < iRequiredSlots)
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "SLOT_LESS_THAN_NECESSARY", iClient, iRequiredSlots);
		return Plugin_Handled;
	}

	if (L4D_LobbyIsReserved()) {
		ShowConfirmMenu(iClient, iSlots);
	} else {
		RunVote(iClient, iSlots);
	}

	return Plugin_Handled;
}

/**
 *
 */
void ShowConfirmMenu(int iClient, int iSlots)
{
	Menu hMenu = CreateMenu(HandlerConfirmMenu, MenuAction_Select|MenuAction_End);

	SetMenuTitle(hMenu, "%T", "MENU_TITLE", iClient, iSlots);

	char sName[64];

	FormatEx(sName, sizeof(sName), "%T", "MENU_ITEM_YES", iClient);
	AddMenuItem(hMenu, "yes", sName);

	FormatEx(sName, sizeof(sName), "%T", "MENU_ITEM_NO", iClient);
	AddMenuItem(hMenu, "no", sName);

	g_iNotConfirmSlots[iClient] = iSlots;

	DisplayMenu(hMenu, iClient, -1);
}

/**
 *
 */
int HandlerConfirmMenu(Menu hMenu, MenuAction hAction, int iClient, int iItem)
{
	switch(hAction)
	{
		case MenuAction_End: CloseHandle(hMenu);

		case MenuAction_Select:
		{
			char sAnswer[4]; GetMenuItem(hMenu, iItem, sAnswer, sizeof(sAnswer));

			if (sAnswer[0] == 'n') {
				return 0;
			}

			if (!L4D_LobbyIsReserved())
			{
				CPrintToChat(iClient, "%T%T", "TAG", iClient, "ALREADY_UNRESERVE", iClient);
				return 0;
			}

			RunVote(iClient, g_iNotConfirmSlots[iClient]);
		}
	}

	return 0;
}

void RunVote(int iClient, int iSlots)
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

		iPlayers[iTotalPlayers++] = iPlayer;
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

			if (L4D_LobbyIsReserved()) {
				FormatEx(sVoteDisplayMessage, sizeof(sVoteDisplayMessage), "%T", "VOTE_TITLE_UNRESERVE", iParam1, g_iSlots);
			} else {
				FormatEx(sVoteDisplayMessage, sizeof(sVoteDisplayMessage), "%T", "VOTE_TITLE", iParam1, g_iSlots);
			}

			hVote.SetDetails(sVoteDisplayMessage);

			return Plugin_Changed;
		}

		case VoteAction_Cancel: {
			hVote.DisplayFail();
		}

		case VoteAction_Finish:
		{
			if (iParam1 == NATIVEVOTES_VOTE_NO)
			{
				hVote.DisplayFail();

				return Plugin_Continue;
			}

			if (L4D_LobbyIsReserved()) {
				L4D_LobbyUnreserve();
			}

			SetConVarInt(FindConVar("sv_maxplayers"), g_iSlots);

			hVote.DisplayPass();
		}

		case VoteAction_End: hVote.Close();
	}

	return Plugin_Continue;
}

/**
 *
 */
bool IsClientSpectator(int iClient) {
	return (GetClientTeam(iClient) == TEAM_SPECTATE);
}

