#include <sourcemod>
#include <menu-stocks>
#include <clientprefs>
#include <shop>
#include <emitsoundany>

#pragma semicolon 1;
#pragma newdecls required;

#define ACCEPT "#accept"
#define REJECT "#reject"
#define DISABLED "#disabled"

#define CHAT_PREFIX "* \x04[Dices]\x01 -"

#define WINNER_SOUND "ui/coin_pickup_01.wav"
#define LOSER_SOUND "ui/xp_rankdown_02.wav"
#define NOBODY_SOUND "ui/weapon_cant_buy.wav"

ConVar cv_EnablePlugin;
ConVar cv_MinBetValue;
ConVar cv_MaxBetValue;
//ConVar cv_ShowMessages;

Handle Dices_Cookie;

bool AreDicesEnabled[MAXPLAYERS + 1];
bool IsAlreadyPlaying[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Store/Shop: Dices",
	author = "xSLOW",
	description = "Gamble your credits.",
	version = "1.2",
	url = "https://steamcommunity.com/profiles/76561193897443537"
};


public void OnPluginStart()
{
    LoadTranslations("common.phrases");

    cv_EnablePlugin = CreateConVar("sm_dices_enableplugin", "1", "Enable plugin? 1 = true / 0 = false");
    cv_MinBetValue = CreateConVar("sm_dices_minbetvalue", "100", "Min bet value");
    cv_MaxBetValue = CreateConVar("sm_dices_maxbetvalue", "1000000", "Max bet value");
//   cv_ShowMessages = CreateConVar("sm_dices_showmessages", "3", "0 = No messages, 1= Chat Messages, 2= Hint Messages, 3= Chat + Hint messages");

    Dices_Cookie = RegClientCookie("Dices On/Off", "Dices On/Off", CookieAccess_Protected);

    AutoExecConfig(true, "dices");

    if(cv_EnablePlugin.BoolValue)
    {
        RegConsoleCmd("sm_dices", Command_Dices);
        RegConsoleCmd("sm_barbut", Command_Dices);          // RO version
        RegConsoleCmd("sm_dicesoff", Command_DicesOFF);
        RegConsoleCmd("sm_barbutoff", Command_DicesOFF);    // RO version
        RegConsoleCmd("sm_diceson", Command_DicesON);
        RegConsoleCmd("sm_barbuton", Command_DicesON);      // RO Version
    }
}


public void OnMapStart() {

    if(FileExists(WINNER_SOUND))
    {
        AddFileToDownloadsTable(WINNER_SOUND);
    }

    if(FileExists(LOSER_SOUND))
    {
        AddFileToDownloadsTable(LOSER_SOUND);
    }

    if(FileExists(NOBODY_SOUND))
    {
        AddFileToDownloadsTable(LOSER_SOUND);
    }
	
    PrecacheSound(WINNER_SOUND);
    PrecacheSound(LOSER_SOUND);
    PrecacheSound(NOBODY_SOUND);
}

public void OnClientPutInServer(int client)
{
    AreDicesEnabled[client] = true;
    char buffer[2];
    GetClientCookie(client, Dices_Cookie, buffer, sizeof(buffer));
    if(StrEqual(buffer,"0"))
        AreDicesEnabled[client] = false;
}

public Action Command_DicesOFF(int client, int args) 
{
	PrintToChat(client, "%s \x02Dices requests are now disabled.", CHAT_PREFIX);
	AreDicesEnabled[client] = false;
	SetClientCookie(client, Dices_Cookie, "0");
}

public Action Command_DicesON(int client, int args) 
{
	PrintToChat(client, "%s \x04Dices requests are now enabled.", CHAT_PREFIX);
	AreDicesEnabled[client] = true;
	SetClientCookie(client, Dices_Cookie, "1");
}

public Action Command_Dices(int client, int args)
{
    if(args < 2)
    {
		ReplyToCommand(client, "%s \x03Usage sm_dices <#player> <credits>", CHAT_PREFIX);
		return Plugin_Handled;
    }

    char iTarget[32], iBetValue[16];

    GetCmdArg(1, iTarget, sizeof(iTarget));
    int Target = FindTarget(client, iTarget, false, false);

    GetCmdArg(2, iBetValue, sizeof(iBetValue));
    int BetValue = StringToInt(iBetValue);

    if (Target == 0 || Target == -1) 
        return Plugin_Handled;  

    if(client == Target)
    {
		ReplyToCommand(client, "%s \x07You cant challenge yourself!", CHAT_PREFIX);
		return Plugin_Handled;
    }

    if(BetValue > cv_MaxBetValue.IntValue || BetValue < cv_MinBetValue.IntValue)
    {
		ReplyToCommand(client, "%s \x07Credits bet value range: MIN: %d credits - MAX: %d credits", CHAT_PREFIX, cv_MinBetValue.IntValue, cv_MaxBetValue.IntValue);
		return Plugin_Handled; 
    }

    if(BetValue > Shop_GetClientCredits(client) || BetValue > Shop_GetClientCredits(Target))
    {
		ReplyToCommand(client, "%s \x07You/Your opponent dont have enough credits", CHAT_PREFIX);
		return Plugin_Handled;
    }

    if(IsAlreadyPlaying[client] == true || IsAlreadyPlaying[Target] == true)
    {
		ReplyToCommand(client, "%s \x07You/Your opponent already playing", CHAT_PREFIX);
		return Plugin_Handled;
    }

    if(AreDicesEnabled[client] == false || AreDicesEnabled[Target] == false) 
	{
		PrintToChat(client, "%s \x07You/Your opponent disabled dices.", CHAT_PREFIX);
		return Plugin_Handled;
	}


    if(IsClientValid(Target))
    {
        PrintToChat(client, "%s You have sent an invite to \x04%N (\x03%d \x01credits).", CHAT_PREFIX, Target, BetValue);
        AskTarget(client, Target, BetValue);
    }

    return Plugin_Handled;
}


public void AskTarget(int client, int target, int BetValue)
{
    IsAlreadyPlaying[client] = true;
    IsAlreadyPlaying[target] = true;

    Menu DicesMenu = new Menu(AskTargetHandler, MENU_ACTIONS_DEFAULT);
    char MenuTitle[50];
    FormatEx(MenuTitle, sizeof(MenuTitle), "Dices: (%N) [%i Credits]", client, BetValue);
    DicesMenu.SetTitle(MenuTitle);
    DicesMenu.AddItem(DISABLED, "Be careful which button do you choose..", ITEMDRAW_DISABLED);
    DicesMenu.AddItem(DISABLED, "...you risk to lose all your credits...", ITEMDRAW_DISABLED);
    DicesMenu.AddItem(DISABLED, "... by pressing random buttons.", ITEMDRAW_DISABLED);
    DicesMenu.AddItem(DISABLED, "", ITEMDRAW_SPACER);
    DicesMenu.AddItem(ACCEPT, "Accept");
    DicesMenu.AddItem(REJECT, "Reject");
	
    PushMenuCell(DicesMenu, "Client", client);
    PushMenuCell(DicesMenu, "Target", target);
    PushMenuCell(DicesMenu, "Credits", BetValue);

    DicesMenu.ExitButton = false;
    DicesMenu.Display(target, 15);
}


public int AskTargetHandler(Menu DicesMenu, MenuAction action, int param1, int param2)
{
    int client = GetMenuCell(DicesMenu, "Client");
    int target = GetMenuCell(DicesMenu, "Target");

    switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			DicesMenu.GetItem(param2, info, sizeof(info));
			if(StrEqual(info, ACCEPT))
			{
				PrintToChat(GetMenuCell(DicesMenu, "Client"), "%s \x0D%N\x01 \x06accepted\x01 your challenge for \x10%i credits.", CHAT_PREFIX, param1, GetMenuCell(DicesMenu, "Credits"));
				RollTheDices(GetMenuCell(DicesMenu, "Client"), param1, GetMenuCell(DicesMenu, "Credits"));
			}
			else
            {
                PrintToChat(GetMenuCell(DicesMenu, "Client"), "%s \x0D%N\x01 \x07rejected\x01 your challenge for \x10%i credits.", CHAT_PREFIX, param1, GetMenuCell(DicesMenu, "Credits"));
                IsAlreadyPlaying[client] = false;
                IsAlreadyPlaying[target] = false;
            }
		}
		
		case MenuAction_Cancel:
        {
            PrintToChat(GetMenuCell(DicesMenu, "Client"), "%s Challenge to \x0D%N\x01 was cancelled.", CHAT_PREFIX, param1);
            IsAlreadyPlaying[client] = false;
            IsAlreadyPlaying[target] = false;
        }
	}
}


public void RollTheDices(int client, int target, int BetValue)
{
    Shop_SetClientCredits(target, Shop_GetClientCredits(target) - BetValue);
    Shop_SetClientCredits(client, Shop_GetClientCredits(client) - BetValue);

    int ClientFirstDice = GetRandomInt(1,6);
    int ClientSecondDice = GetRandomInt(1,6);
    int ClientSumDices = ClientFirstDice + ClientSecondDice;

    int TargetFirstDice = GetRandomInt(1,6);
    int TargetSecondDice = GetRandomInt(1,6);
    int TargetSumDices = TargetFirstDice + TargetSecondDice;

    if(ClientSumDices > TargetSumDices)
    {
        Shop_SetClientCredits(client, Shop_GetClientCredits(client) + BetValue*2);

        PrintToChat(client, "%s \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 and you \x04won \x10%d credits.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintToChat(target, "%s \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 and you \x02lost \x10%d credits.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);

        PrintCenterText(client, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> and you <font color='#2FDE0C'>won</font> %d credits.</center>", ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintCenterText(target, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> and you <font color='#F61B01'>lost</font> %d credits.</center>", TargetFirstDice, TargetSecondDice, client, ClientFirstDice, ClientSecondDice, BetValue);

        EmitSoundToClient(client, WINNER_SOUND);
        EmitSoundToClient(target, LOSER_SOUND);
    }
    else if(ClientSumDices < TargetSumDices)
    {

        Shop_SetClientCredits(target, Shop_GetClientCredits(target) + BetValue*2);

        PrintToChat(client, "%s \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 and you \x02lost \x10%d credits.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintToChat(target, "%s \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 and you \x04won \x10%d credits.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);

        PrintCenterText(client, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> and you <font color='#F61B01'>lost</font> %d credits.</center>", ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintCenterText(target, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> and you <font color='#2FDE0C'>won</font> %d credits.</center>", TargetFirstDice, TargetSecondDice, client, ClientFirstDice, ClientSecondDice, BetValue);

        EmitSoundToClient(target, WINNER_SOUND);
        EmitSoundToClient(client, LOSER_SOUND);
    }
    else
    {
        Shop_SetClientCredits(target, Shop_GetClientCredits(target) + BetValue);
        Shop_SetClientCredits(client, Shop_GetClientCredits(client) + BetValue);
        
        PrintToChat(client, "%s \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 but \x02nobody won.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice);
        PrintToChat(target, "%s \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 but \x02nobody won.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice);

        PrintCenterText(client, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> <font color='#F61B01'>but nobody won.</font></center>", ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintCenterText(target, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> <font color='#F61B01'>but nobody won.</font></center>", TargetFirstDice, TargetSecondDice, client, ClientFirstDice, ClientSecondDice, BetValue);

        EmitSoundToClient(target, NOBODY_SOUND);
        EmitSoundToClient(client, NOBODY_SOUND);
    }

    IsAlreadyPlaying[client] = false;
    IsAlreadyPlaying[target] = false;
}

bool IsClientValid(int client)
{
    return (0 < client <= MaxClients) && IsClientInGame(client) && !IsFakeClient(client);
}