// ============================================================================
//  ULTIMATE ZM MOD MENU  -  Plutonium T6 (Black Ops II Zombies)  -  v3.1
//  Install: %localappdata%\Plutonium\storage\t6\scripts\zm\zm_modmenu.gsc
//
//  Controls (menu closed):  AIM + MELEE ............ open menu
//  Controls (menu open)  :  Action Slot 1 / 2 ...... scroll up / down
//                           JUMP .................... select
//                           MELEE ................... back / close
//
//  Maps: TranZit / Nuketown / Die Rise / Mob of the Dead / Buried / Origins
//  Every weapon / drop / perk entry is checked against what the current map
//  has loaded, so nothing is given that the map does not know.
// ============================================================================

#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

init()
{
    level.mmFrozen = false;
    level thread MM_OnPlayerConnect();
}

MM_OnPlayerConnect()
{
    level endon("end_game");
    for(;;)
    {
        level waittill("connected", player);
        player thread MM_OnPlayerSpawned();
    }
}

MM_OnPlayerSpawned()
{
    self endon("disconnect");
    level endon("end_game");

    self waittill("spawned_player");

    if(self isHost())
        self.hasMenu = true;

    firstSpawn = true;
    for(;;)
    {
        if(isDefined(self.hasMenu) && self.hasMenu)
        {
            self MM_GrantMenu();
            if(firstSpawn)
            {
                self iprintlnbold("^2ULTIMATE ZM MENU LOADED");
                self iprintln("^7Aim + Melee: open | Slot 1/2: scroll | Jump: select | Melee: back");
                firstSpawn = false;
            }
        }
        self waittill("spawned_player");
    }
}

// ============================================================================
//  MENU ACCESS
// ============================================================================

MM_GrantMenu()
{
    self.hasMenu = true;
    if(isDefined(self.menuSetup) && self.menuSetup)
        return;

    self.menuSetup = true;
    self SetupMenu();
    self thread MenuInput();
}

MM_RevokeMenu()
{
    self.hasMenu = false;
    self.menuSetup = false;
    self.menuOpen = false;
    self notify("stop_menu_input");
    self MM_DestroyMenuHud();
}

// ============================================================================
//  MENU FRAMEWORK
// ============================================================================

SetupMenu()
{
    self MM_DestroyMenuHud();

    self.menuOpts = [];
    self.menuParents = [];
    self.menuCursors = [];
    self.menuOpen = false;
    self.menuCursor = 0;
    self.currentMenu = "main";
    self.selectedPlayer = undefined;
    if(!isDefined(self.mmToggle))
        self.mmToggle = [];

    self BuildMenuStructure();
}

// HUD elements only exist while the menu is open (ZM already uses many HUD
// elements per player, so this avoids hitting the engine limit).
MM_CreateMenuHud()
{
    self MM_DestroyMenuHud();

    self.menuBg = newClientHudElem(self);
    self.menuBg.horzAlign = "left";
    self.menuBg.vertAlign = "top";
    self.menuBg.alignX = "left";
    self.menuBg.alignY = "top";
    self.menuBg.x = 12;
    self.menuBg.y = 80;
    self.menuBg.sort = 1000;
    self.menuBg.foreground = true;
    self.menuBg.hideWhenInMenu = true;
    self.menuBg.alpha = 0.6;
    self.menuBg.color = (0, 0, 0);
    self.menuBg setShader("white", 320, 235);

    self.menuTitle = self MM_NewText(22, 86, 1.3);
    self.menuFooter = self MM_NewText(22, 292, 1.1);

    self.menuRows = [];
    for(i = 0; i < 9; i++)
        self.menuRows[i] = self MM_NewText(22, 112 + (i * 19), 1.25);
}

MM_NewText(px, py, scale)
{
    h = newClientHudElem(self);
    h.horzAlign = "left";
    h.vertAlign = "top";
    h.alignX = "left";
    h.alignY = "top";
    h.x = px;
    h.y = py;
    h.font = "objective";
    h.fontScale = scale;
    h.sort = 1001;
    h.foreground = true;
    h.hideWhenInMenu = true;
    h.alpha = 1;
    h.color = (1, 1, 1);
    return h;
}

MM_DestroyMenuHud()
{
    if(isDefined(self.menuBg))
        self.menuBg destroy();
    if(isDefined(self.menuTitle))
        self.menuTitle destroy();
    if(isDefined(self.menuFooter))
        self.menuFooter destroy();
    if(isDefined(self.menuRows))
    {
        rows = self.menuRows;
        foreach(row in rows)
        {
            if(isDefined(row))
                row destroy();
        }
    }
    self.menuBg = undefined;
    self.menuTitle = undefined;
    self.menuFooter = undefined;
    self.menuRows = undefined;
}

addMenuOpt(menuName, text, func, arg, arg2)
{
    if(!isDefined(self.menuOpts[menuName]))
        self.menuOpts[menuName] = [];

    index = self.menuOpts[menuName].size;
    opt = spawnStruct();
    opt.text = text;
    opt.func = func;
    opt.arg = arg;
    opt.arg2 = arg2;
    opt.key = undefined;
    self.menuOpts[menuName][index] = opt;
}

// Menu entry that opens a sub menu and remembers its parent for "back".
addSubMenu(parent, text, child)
{
    self addMenuOpt(parent, text, ::SwitchMenu, child);
    self.menuParents[child] = parent;
}

// Menu entry that shows an [ON]/[OFF] tag. "key" must match the key used by the toggle function.
addToggleOpt(menuName, text, func, key)
{
    self addMenuOpt(menuName, text, func);
    last = self.menuOpts[menuName].size - 1;
    self.menuOpts[menuName][last].key = key;
}

// Only adds a weapon if the map actually has it registered.
MM_AddWeaponOpt(menuName, text, weap)
{
    if(MM_WeaponKnown(weap))
        self addMenuOpt(menuName, text, ::GiveWeap, weap);
}

MM_AddDropOpt(text, type)
{
    if(isDefined(level.zombie_powerups) && isDefined(level.zombie_powerups[type]))
        self addMenuOpt("lobby", text, ::SpawnDrop, type);
}

SwitchMenu(menuName)
{
    self MM_GoTo(menuName, false);
}

MM_GoTo(menuName, restoreCursor)
{
    self.menuCursors[self.currentMenu] = self.menuCursor;
    self.currentMenu = menuName;

    if(menuName == "players" && self isHost())
        self MM_BuildPlayersList();

    self.menuCursor = 0;
    if(restoreCursor && isDefined(self.menuCursors[menuName]))
        self.menuCursor = self.menuCursors[menuName];

    self MM_ClampCursor();
    self UpdateMenuUI();
}

MM_ClampCursor()
{
    total = 0;
    if(isDefined(self.menuOpts[self.currentMenu]))
        total = self.menuOpts[self.currentMenu].size;

    if(self.menuCursor >= total)
        self.menuCursor = total - 1;
    if(self.menuCursor < 0)
        self.menuCursor = 0;
}

MenuBack()
{
    if(self.currentMenu == "main")
    {
        self MM_CloseMenu();
        return;
    }
    parent = self.menuParents[self.currentMenu];
    if(!isDefined(parent))
        parent = "main";
    self MM_GoTo(parent, true);
}

MM_OpenMenu()
{
    self.menuOpen = true;
    self MM_CreateMenuHud();
    self UpdateMenuUI();
}

MM_CloseMenu()
{
    self.menuOpen = false;
    self MM_DestroyMenuHud();
}

MenuScroll(dir)
{
    total = 0;
    if(isDefined(self.menuOpts[self.currentMenu]))
        total = self.menuOpts[self.currentMenu].size;
    if(total < 1)
        return;

    self.menuCursor += dir;
    if(self.menuCursor < 0)
        self.menuCursor = total - 1;
    if(self.menuCursor >= total)
        self.menuCursor = 0;
    self UpdateMenuUI();
}

MenuSelect()
{
    if(!isDefined(self.menuOpts[self.currentMenu]))
        return;
    opt = self.menuOpts[self.currentMenu][self.menuCursor];
    if(!isDefined(opt))
        return;

    if(isDefined(opt.arg2))
        self thread [[opt.func]](opt.arg, opt.arg2);
    else if(isDefined(opt.arg))
        self thread [[opt.func]](opt.arg);
    else
        self thread [[opt.func]]();

    // Give toggles a moment to flip, then refresh the [ON]/[OFF] tags.
    self thread MM_DelayedRefresh();
}

MM_DelayedRefresh()
{
    self endon("disconnect");
    wait 0.1;
    if(isDefined(self.menuOpen) && self.menuOpen)
        self UpdateMenuUI();
}

MM_WaitRelease()
{
    timeout = 0;
    while((self meleeButtonPressed() || self adsButtonPressed()) && timeout < 40)
    {
        wait 0.05;
        timeout++;
    }
}

MenuInput()
{
    self endon("disconnect");
    self endon("stop_menu_input");

    for(;;)
    {
        wait 0.05;

        if(!self.menuOpen)
        {
            if(self adsButtonPressed() && self meleeButtonPressed())
            {
                if(!(self maps\mp\zombies\_zm_laststand::player_is_in_laststand()))
                {
                    self MM_OpenMenu();
                    self MM_WaitRelease();
                }
            }
            continue;
        }

        // Close the menu if the player goes down.
        if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            self MM_CloseMenu();
            continue;
        }

        if(self meleeButtonPressed())
        {
            self MenuBack();
            self MM_WaitRelease();
        }
        else if(self actionSlotOneButtonPressed())
        {
            self MenuScroll(-1);
            wait 0.15;
        }
        else if(self actionSlotTwoButtonPressed())
        {
            self MenuScroll(1);
            wait 0.15;
        }
        else if(self jumpButtonPressed())
        {
            self MenuSelect();
            wait 0.3;
        }
    }
}

MM_MenuTitle(name)
{
    switch(name)
    {
        case "main":           return "MAIN MENU";
        case "personal":       return "PERSONAL MODS";
        case "weapons":        return "WEAPON MODS";
        case "mapweapons":     return "MAP WEAPONS";
        case "lobby":          return "SPAWNS & LOBBY";
        case "zombies":        return "ZOMBIE MANIPULATION";
        case "vision":         return "AIMBOT & ESP";
        case "players":        return "PLAYERS";
        case "player_actions": return "PLAYER ACTIONS";
    }
    return name;
}

UpdateMenuUI()
{
    if(!isDefined(self.menuOpen) || !self.menuOpen)
        return;
    if(!isDefined(self.menuRows) || !isDefined(self.menuTitle))
        return;

    opts = self.menuOpts[self.currentMenu];
    total = 0;
    if(isDefined(opts))
        total = opts.size;

    maxRows = 9;
    first = 0;
    if(total > maxRows)
    {
        first = self.menuCursor - 4;
        if(first < 0)
            first = 0;
        if(first > total - maxRows)
            first = total - maxRows;
    }

    title = "^2>> ^7" + MM_MenuTitle(self.currentMenu) + " ^2<<";
    if(self.currentMenu == "player_actions" && isDefined(self.selectedPlayer))
        title = "^2>> ^7" + self.selectedPlayer.name + " ^2<<";
    self.menuTitle setText(title);

    for(i = 0; i < maxRows; i++)
    {
        row = self.menuRows[i];
        idx = first + i;

        if(idx >= total)
        {
            row.alpha = 0;
            continue;
        }

        opt = opts[idx];
        label = opt.text;
        if(isDefined(opt.key))
        {
            if(self MM_IsOn(opt.key))
                label = label + " ^2[ON]";
            else
                label = label + " ^1[OFF]";
        }

        row setText(label);
        row.alpha = 1;
        if(idx == self.menuCursor)
            row.color = (0.2, 1, 0.2);
        else
            row.color = (1, 1, 1);
    }

    if(total > 0)
        self.menuFooter setText("^3" + (self.menuCursor + 1) + " / " + total + "   ^7Melee: back");
    else
        self.menuFooter setText("^1(empty)   ^7Melee: back");
}

// ============================================================================
//  MENU CONTENT
// ============================================================================

BuildMenuStructure()
{
    hasMapWeapons = self MM_BuildMapWeapons();

    // --- MAIN ---
    self addSubMenu("main", "Personal Mods", "personal");
    self addSubMenu("main", "Weapon Mods", "weapons");
    if(hasMapWeapons)
        self addSubMenu("main", "Map Weapons (" + MM_MapName() + ")", "mapweapons");
    self addSubMenu("main", "Spawns & Lobby", "lobby");
    self addSubMenu("main", "Zombie Manipulation", "zombies");
    self addSubMenu("main", "Aimbot & ESP", "vision");
    if(self isHost())
        self addSubMenu("main", "Players Menu", "players");

    // --- PERSONAL ---
    self addToggleOpt("personal", "God Mode", ::ToggleGodMode, "god");
    self addToggleOpt("personal", "Noclip", ::ToggleNoclip, "noclip");
    self addToggleOpt("personal", "Jetpack (Hold Jump)", ::ToggleJetpack, "jetpack");
    self addToggleOpt("personal", "Super Jump", ::ToggleSuperJump, "superjump");
    self addToggleOpt("personal", "Auto-Bhop", ::ToggleBhop, "bhop");
    self addToggleOpt("personal", "Vampire Mode (Heal on Points)", ::ToggleVampire, "vampire");
    self addToggleOpt("personal", "Move = Refill Ammo", ::ToggleMovementAmmo, "moveammo");
    self addToggleOpt("personal", "Magic Bullets (Ray Gun)", ::ToggleMagicBullets, "magic");
    self addToggleOpt("personal", "Super Health", ::ToggleHealth, "health");
    self addToggleOpt("personal", "Zombies Ignore Me", ::ToggleIgnoreMe, "ignore");
    self addToggleOpt("personal", "Max Movespeed", ::ToggleSpeed, "speed");
    self addToggleOpt("personal", "Invisibility", ::ToggleInvis, "invis");
    self addToggleOpt("personal", "Third Person", ::ToggleThirdPerson, "thirdp");
    self addMenuOpt("personal", "FOV 120", ::SetFOV, "120");
    self addMenuOpt("personal", "FOV Default (65)", ::SetFOV, "65");
    self addMenuOpt("personal", "+100,000 Points", ::GivePoints);
    self addToggleOpt("personal", "Infinite Points", ::ToggleInfPoints, "infpoints");
    self addMenuOpt("personal", "Save Position", ::SavePosition);
    self addMenuOpt("personal", "Load Position", ::LoadPosition);
    self addMenuOpt("personal", "Teleport To Crosshair", ::TeleportToCrosshair);
    self addMenuOpt("personal", "Suicide", ::DoSuicide);

    // --- WEAPONS ---
    self addToggleOpt("weapons", "Infinite Ammo", ::ToggleInfAmmo, "infammo");
    self addMenuOpt("weapons", "Pack-A-Punch Current", ::PapCurrentWeapon);
    self addMenuOpt("weapons", "Pack-A-Punch ALL Guns", ::PapAllWeapons);
    self addMenuOpt("weapons", "Max Ammo Current", ::FillCurrentAmmo);
    self addMenuOpt("weapons", "Max Ammo ALL", ::FillAllAmmo);
    self MM_AddWeaponOpt("weapons", "Ray Gun Mark II (PaP)", "raygun_mark2_upgraded_zm");
    self MM_AddWeaponOpt("weapons", "Ray Gun (PaP)", "ray_gun_upgraded_zm");
    self MM_AddWeaponOpt("weapons", "RPG (PaP)", "usrpg_upgraded_zm");
    self MM_AddWeaponOpt("weapons", "Galil (PaP)", "galil_upgraded_zm");
    self MM_AddWeaponOpt("weapons", "PDW-57 (PaP)", "pdw57_upgraded_zm");
    self MM_AddWeaponOpt("weapons", "Mustang & Sally / M1911 (PaP)", "m1911_upgraded_zm");
    self MM_AddWeaponOpt("weapons", "Monkey Bombs", "cymbal_monkey_zm");
    self MM_AddWeaponOpt("weapons", "EMP Grenades", "emp_grenade_zm");
    self MM_AddWeaponOpt("weapons", "Zombie Shield", "riotshield_zm");
    self MM_AddWeaponOpt("weapons", "Galvaknuckles", "tazer_knuckles_zm");
    self addMenuOpt("weapons", "Give All Perks", ::GiveAllPerks);
    self addMenuOpt("weapons", "Remove All Perks", ::RemoveAllPerks);
    self addMenuOpt("weapons", "Drop Current Weapon", ::DropWeapon);

    // --- LOBBY ---
    self addMenuOpt("lobby", "Turn On Power", ::TurnOnPower);
    self addMenuOpt("lobby", "Open All Doors", ::OpenAllDoors);
    self MM_AddDropOpt("Spawn Max Ammo", "full_ammo");
    self MM_AddDropOpt("Spawn Insta-Kill", "insta_kill");
    self MM_AddDropOpt("Spawn Double Points", "double_points");
    self MM_AddDropOpt("Spawn Nuke", "nuke");
    self MM_AddDropOpt("Spawn Carpenter", "carpenter");
    self MM_AddDropOpt("Spawn Fire Sale", "fire_sale");
    self MM_AddDropOpt("Spawn Free Perk", "free_perk");
    self MM_AddDropOpt("Spawn Death Machine", "minigun");
    self MM_AddDropOpt("Spawn Zombie Blood", "zombie_blood");
    self addMenuOpt("lobby", "Skip Round (+1)", ::SkipRound);
    self addMenuOpt("lobby", "Jump to Round 10", ::SetRound, 10);
    self addMenuOpt("lobby", "Jump to Round 25", ::SetRound, 25);
    self addMenuOpt("lobby", "Jump to Round 50", ::SetRound, 50);
    self addMenuOpt("lobby", "Jump to Round 100", ::SetRound, 100);
    self addMenuOpt("lobby", "Game Speed: Slomo", ::SetTimeScale, 0.5);
    self addMenuOpt("lobby", "Game Speed: Fast", ::SetTimeScale, 2.0);
    self addMenuOpt("lobby", "Game Speed: Normal", ::SetTimeScale, 1.0);
    // Use unique, zero-argument handlers here. SetGravity is also a native
    // BO2 GSC function name, so using it as a custom callback can collide.
    self addMenuOpt("lobby", "Low Gravity", ::MM_SetLowGravity);
    self addMenuOpt("lobby", "Normal Gravity", ::MM_SetNormalGravity);
    if(self isHost())
    {
        self addMenuOpt("lobby", "Restart Map", ::RestartMap);
        self addMenuOpt("lobby", "End Game", ::EndGame);
    }

    // --- ZOMBIES ---
    self addMenuOpt("zombies", "Kill All Zombies", ::KillAllZombies);
    self addMenuOpt("zombies", "Explode All Zombies", ::ExplodeZombies);
    self addMenuOpt("zombies", "Burn All Zombies", ::BurnZombies);
    self addMenuOpt("zombies", "Teleport All To Me", ::TeleportZombies);
    self addMenuOpt("zombies", "Teleport All To Crosshair", ::TeleportZombiesCrosshair);
    self addToggleOpt("zombies", "Zombie Magnet", ::ToggleZombieMagnet, "magnet");
    self addMenuOpt("zombies", "Send Zombies to Moon", ::ZombiesToMoon);
    self addMenuOpt("zombies", "Launch Zombies Up", ::FlingZombies);
    self addToggleOpt("zombies", "Freeze All Zombies", ::ToggleFreezeZombies, "freeze");
    self addMenuOpt("zombies", "Zombie Speed: Sprint", ::SetZombieSpeed, "sprint");
    self addMenuOpt("zombies", "Zombie Speed: Run", ::SetZombieSpeed, "run");
    self addMenuOpt("zombies", "Zombie Speed: Walk", ::SetZombieSpeed, "walk");
    self addMenuOpt("zombies", "Zombie Speed: Default", ::SetZombieSpeed, "default");
    self addToggleOpt("zombies", "Insta-Kill Aura", ::ToggleKillAura, "killaura");
    self addMenuOpt("zombies", "Delete All Zombies", ::DeleteZombies);
    self addMenuOpt("zombies", "Add 24 Zombies To Round", ::RespawnZombies);

    // --- VISION ---
    self addToggleOpt("vision", "Aimbot", ::ToggleAimbot, "aimbot");
    self addMenuOpt("vision", "Aimbot Target: Head", ::SetAimTarget, "j_head");
    self addMenuOpt("vision", "Aimbot Target: Chest", ::SetAimTarget, "j_spinelower");
    self addToggleOpt("vision", "ESP (Zombie Tags)", ::ToggleESP, "esp");
    self addMenuOpt("vision", "ESP Color: Red", ::SetESPColor, (1, 0, 0));
    self addMenuOpt("vision", "ESP Color: Green", ::SetESPColor, (0, 1, 0));
    self addMenuOpt("vision", "ESP Color: Blue", ::SetESPColor, (0, 0, 1));

    // --- PLAYERS (host only) ---
    if(self isHost())
    {
        self MM_BuildPlayersList();

        self addMenuOpt("player_actions", "[+] Give Mod Menu Access", ::ActionGiveMenu);
        self addMenuOpt("player_actions", "[-] Take Mod Menu Access", ::ActionTakeMenu);
        self addMenuOpt("player_actions", "Toggle God Mode", ::ActionGodMode);
        self addMenuOpt("player_actions", "Give All Perks", ::ActionGivePerks);
        self addMenuOpt("player_actions", "Give +100k Points", ::ActionPoints);
        self addMenuOpt("player_actions", "Revive", ::ActionRevive);
        self addMenuOpt("player_actions", "Teleport To Them", ::ActionTeleportTo);
        self addMenuOpt("player_actions", "Bring Them To Me", ::ActionBring);
        self addMenuOpt("player_actions", "Freeze Player (Troll)", ::ActionFreeze);
        self addMenuOpt("player_actions", "Launch Player (Troll)", ::ActionSendToMoon);
        self.menuParents["player_actions"] = "players";
    }
}

// Builds the weapon folder for the CURRENT map only. Returns true if it has any entries.
// Weapon IDs below were checked against the T6 zombie scripts of each map.
MM_BuildMapWeapons()
{
    m = "mapweapons";
    switch(level.script)
    {
        case "zm_tomb":
            self MM_AddWeaponOpt(m, "Ice Staff (Ull's Arrow)", "staff_water_upgraded_zm");
            self MM_AddWeaponOpt(m, "Fire Staff (Kagutsuchi)", "staff_fire_upgraded_zm");
            self MM_AddWeaponOpt(m, "Wind Staff (Boreas)", "staff_air_upgraded_zm");
            self MM_AddWeaponOpt(m, "Lightning Staff (Kimat)", "staff_lightning_upgraded_zm");
            self MM_AddWeaponOpt(m, "Mauser C96 (PaP)", "c96_upgraded_zm");
            self MM_AddWeaponOpt(m, "MG08/15 (PaP)", "mg08_upgraded_zm");
            self MM_AddWeaponOpt(m, "G-Strike", "beacon_zm");
            break;
        case "zm_prison":
            self MM_AddWeaponOpt(m, "Blundergat", "blundergat_zm");
            self MM_AddWeaponOpt(m, "The Sweeper", "blundergat_upgraded_zm");
            self MM_AddWeaponOpt(m, "Acid Gat", "blundersplat_zm");
            self MM_AddWeaponOpt(m, "Acid Gat (PaP)", "blundersplat_upgraded_zm");
            self MM_AddWeaponOpt(m, "Hell's Retriever", "bouncing_tomahawk_zm");
            self MM_AddWeaponOpt(m, "Hell's Redeemer", "upgraded_tomahawk_zm");
            self MM_AddWeaponOpt(m, "Thompson (PaP)", "thompson_upgraded_zm");
            break;
        case "zm_buried":
            self MM_AddWeaponOpt(m, "Paralyzer", "slowgun_zm");
            self MM_AddWeaponOpt(m, "Petrifier", "slowgun_upgraded_zm");
            self MM_AddWeaponOpt(m, "Remington New Model Army", "rnma_zm");
            self MM_AddWeaponOpt(m, "Remington (PaP)", "rnma_upgraded_zm");
            self MM_AddWeaponOpt(m, "Time Bomb", "time_bomb_zm");
            break;
        case "zm_highrise":
            self MM_AddWeaponOpt(m, "Sliquifier", "slipgun_zm");
            self MM_AddWeaponOpt(m, "Sliquifier (PaP)", "slipgun_upgraded_zm");
            break;
        case "zm_transit":
            self MM_AddWeaponOpt(m, "Jet Gun", "jetgun_zm");
            break;
        default:
            break;
    }

    if(isDefined(self.menuOpts[m]) && self.menuOpts[m].size > 0)
    {
        self.menuParents[m] = "main";
        return true;
    }
    return false;
}

MM_MapName()
{
    switch(level.script)
    {
        case "zm_transit":  return "TranZit";
        case "zm_nuked":    return "Nuketown";
        case "zm_highrise": return "Die Rise";
        case "zm_prison":   return "Mob of the Dead";
        case "zm_buried":   return "Buried";
        case "zm_tomb":     return "Origins";
    }
    return level.script;
}

// ============================================================================
//  HELPERS
// ============================================================================

MM_IsOn(key)
{
    if(key == "freeze")
        return level.mmFrozen;
    if(!isDefined(self.mmToggle))
        return false;
    if(!isDefined(self.mmToggle[key]))
        return false;
    return self.mmToggle[key];
}

// Flips a flag, prints status, returns the NEW state.
MM_Flip(key, label)
{
    if(!isDefined(self.mmToggle))
        self.mmToggle = [];

    on = !(self MM_IsOn(key));
    self.mmToggle[key] = on;

    if(on)
        self iprintln(label + " ^2ON");
    else
        self iprintln(label + " ^1OFF");
    return on;
}

// Flips a flag and starts/stops a looping thread. Loop must "endon" mm_stop_<key>.
MM_Toggle(key, label, loopFunc)
{
    on = self MM_Flip(key, label);
    if(on)
        self thread [[loopFunc]]();
    else
        self notify("mm_stop_" + key);
    return on;
}

MM_Forward(dist)
{
    ang = self getPlayerAngles();
    return self.origin + (anglesToForward((0, ang[1], 0)) * dist);
}

MM_CrosshairPos()
{
    eye = self getEye();
    dir = anglesToForward(self getPlayerAngles());
    trace = bulletTrace(eye, eye + (dir * 10000), false, self);
    return trace["position"];
}

MM_WeaponKnown(weap)
{
    if(!isDefined(weap) || weap == "" || weap == "none")
        return false;
    if(isDefined(level.zombie_weapons) && isDefined(level.zombie_weapons[weap]))
        return true;
    if(isDefined(level.zombie_weapons_upgraded) && isDefined(level.zombie_weapons_upgraded[weap]))
        return true;
    return false;
}

MM_FirstKnownWeapon(a, b)
{
    if(MM_WeaponKnown(a))
        return a;
    if(MM_WeaponKnown(b))
        return b;
    return undefined;
}

MM_DefaultMaxHealth()
{
    if(self hasPerk("specialty_armorvest"))
        return 250;
    return 100;
}

MM_ZombieTeam()
{
    if(isDefined(level.zombie_team))
        return level.zombie_team;
    return "axis";
}

// Every live enemy AI (zombies, dogs, bosses).
MM_AllEnemies()
{
    out = [];
    all = getAiSpeciesArray(MM_ZombieTeam(), "all");

    if(!isDefined(all))
        return out;

    foreach(z in all)
    {
        if(isDefined(z) && isDefined(z.origin) && isAlive(z))
            out[out.size] = z;
    }
    return out;
}

MM_IsBoss(z)
{
    if(isDefined(z.is_brutus) && z.is_brutus)
        return true;
    if(isDefined(z.is_avogadro) && z.is_avogadro)
        return true;
    if(isDefined(z.is_sloth) && z.is_sloth)
        return true;
    if(isDefined(z.is_mechz) && z.is_mechz)
        return true;
    return false;
}

// Live enemies without quest bosses (Brutus, Avogadro, Sloth, Mechz), so that
// delete / teleport / freeze cannot break a map's boss logic.
MM_AliveZombies()
{
    out = [];
    all = MM_AllEnemies();
    foreach(z in all)
    {
        if(MM_IsBoss(z))
            continue;
        out[out.size] = z;
    }
    return out;
}

MM_PlayerStillHere(p)
{
    if(!isDefined(p))
        return false;
    players = get_players();
    foreach(pl in players)
    {
        if(pl == p)
            return true;
    }
    return false;
}

MM_Target()
{
    if(!MM_PlayerStillHere(self.selectedPlayer))
    {
        self iprintln("^1That player is no longer in the game.");
        return undefined;
    }
    return self.selectedPlayer;
}

MM_AddScore(player, amount)
{
    player maps\mp\zombies\_zm_score::add_to_player_score(amount);
}

// ============================================================================
//  PLAYERS MENU (HOST)
// ============================================================================

MM_BuildPlayersList()
{
    self.menuOpts["players"] = [];
    self.menuParents["players"] = "main";

    self addMenuOpt("players", "Refresh Player List", ::PopulatePlayersMenu);
    self addMenuOpt("players", "Revive All Players", ::ReviveAllPlayers);
    self addMenuOpt("players", "Give All Players 100k", ::GiveAllPoints);

    players = get_players();
    foreach(player in players)
    {
        if(player == self)
            continue;

        tag = "";
        if(player is_bot())
            tag = "[BOT] ";
        self addMenuOpt("players", "Manage: " + tag + player.name, ::SelectPlayer, player);
    }
    self.menuParents["player_actions"] = "players";
}

PopulatePlayersMenu()
{
    self MM_BuildPlayersList();
    self MM_ClampCursor();
    self UpdateMenuUI();
    self iprintln("Player list refreshed.");
}

SelectPlayer(player)
{
    self.selectedPlayer = player;
    self SwitchMenu("player_actions");
}

ActionGiveMenu()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;

    if(p is_bot())
    {
        self iprintln("^1Bots can't use the menu.");
        return;
    }

    if(isDefined(p.menuSetup) && p.menuSetup)
    {
        self iprintln(p.name + " already has the menu.");
        return;
    }
    p MM_GrantMenu();
    self iprintln("Gave menu to " + p.name);
    p iprintlnbold("^2You have been given the Mod Menu by the Host!");
}

ActionTakeMenu()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;

    if(!isDefined(p.menuSetup) || !p.menuSetup)
    {
        self iprintln(p.name + " doesn't have the menu.");
        return;
    }
    p MM_RevokeMenu();
    self iprintln("Took menu from " + p.name);
    p iprintlnbold("^1Your Mod Menu access was revoked.");
}

ActionGodMode()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;

    on = p MM_Toggle("god", "God Mode", ::GodLoop);
    if(on)
        self iprintln("God Mode ^2GIVEN ^7to " + p.name);
    else
    {
        p disableInvulnerability();
        self iprintln("God Mode ^1REMOVED ^7from " + p.name);
    }
}

ActionGivePerks()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;
    p MM_GivePerks();
    self iprintln("Perks given to " + p.name);
}

ActionPoints()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;
    MM_AddScore(p, 100000);
    self iprintln("Gave 100k to " + p.name);
}

ActionRevive()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;
    if(p maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        p maps\mp\zombies\_zm_laststand::auto_revive(self);
        self iprintln("Revived " + p.name);
    }
    else
        self iprintln(p.name + " is not downed.");
}

ActionTeleportTo()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;
    self setOrigin(p.origin);
    self iprintln("Teleported to " + p.name);
}

ActionBring()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;
    p setOrigin(self.origin);
    self iprintln("Brought " + p.name);
}

ActionSendToMoon()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;
    p setVelocity((0, 0, 1500));
    self iprintln("Launched " + p.name);
}

ActionFreeze()
{
    p = self MM_Target();
    if(!isDefined(p))
        return;

    if(!isDefined(p.isFrozen) || !p.isFrozen)
    {
        p.isFrozen = true;
        p freezeControls(true);
        self iprintln("Froze " + p.name);
    }
    else
    {
        p.isFrozen = false;
        p freezeControls(false);
        self iprintln("Unfroze " + p.name);
    }
}

ReviveAllPlayers()
{
    players = get_players();
    foreach(player in players)
    {
        if(player maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            player maps\mp\zombies\_zm_laststand::auto_revive(self);
    }
    self iprintln("All downed players revived");
}

GiveAllPoints()
{
    players = get_players();
    foreach(player in players)
        MM_AddScore(player, 100000);
    self iprintln("Gave 100k to everyone");
}

// ============================================================================
//  PERSONAL MODS
// ============================================================================

ToggleGodMode()
{
    if(self MM_Toggle("god", "God Mode", ::GodLoop))
        return;
    self disableInvulnerability();
}

GodLoop()
{
    self endon("disconnect");
    self endon("mm_stop_god");
    for(;;)
    {
        self enableInvulnerability();   // re-applied because revives clear it
        wait 0.5;
    }
}

ToggleNoclip()
{
    if(self MM_Toggle("noclip", "Noclip", ::NoclipLoop))
        return;
    self unlink();
}

NoclipLoop()
{
    self endon("disconnect");
    self endon("mm_stop_noclip");

    obj = spawn("script_origin", self.origin);
    obj.angles = self.angles;
    self playerLinkTo(obj);
    self thread MM_NoclipCleanup(obj);
    self iprintln("Noclip: Attack = forward | Frag = up | Tactical = down");

    for(;;)
    {
        if(self attackButtonPressed())
            obj.origin = obj.origin + (anglesToForward(self getPlayerAngles()) * 40);
        if(self fragButtonPressed())
            obj.origin = obj.origin + (0, 0, 25);
        if(self secondaryOffhandButtonPressed())
            obj.origin = obj.origin - (0, 0, 25);
        wait 0.05;
    }
}

MM_NoclipCleanup(obj)
{
    self waittill_any("disconnect", "mm_stop_noclip");
    if(isDefined(obj))
        obj delete();
}

ToggleJetpack()      { self MM_Toggle("jetpack", "Jetpack", ::JetpackLoop); }
JetpackLoop()
{
    self endon("disconnect");
    self endon("mm_stop_jetpack");
    for(;;)
    {
        if(self jumpButtonPressed() && !self.menuOpen)
        {
            vel = self getVelocity();
            if(vel[2] < 600)
                self setVelocity(vel + (0, 0, 60));
        }
        wait 0.05;
    }
}

ToggleSuperJump()    { self MM_Toggle("superjump", "Super Jump", ::SuperJumpLoop); }
SuperJumpLoop()
{
    self endon("disconnect");
    self endon("mm_stop_superjump");
    for(;;)
    {
        if(self jumpButtonPressed() && self isOnGround() && !self.menuOpen)
        {
            wait 0.1;
            self setVelocity(self getVelocity() + (0, 0, 400));
            wait 0.5;
        }
        wait 0.05;
    }
}

ToggleBhop()         { self MM_Toggle("bhop", "Auto-Bhop", ::BhopLoop); }
BhopLoop()
{
    self endon("disconnect");
    self endon("mm_stop_bhop");
    for(;;)
    {
        if(self jumpButtonPressed() && self isOnGround() && !self.menuOpen)
        {
            ang = self getPlayerAngles();
            vec = anglesToForward((0, ang[1], 0));
            self setVelocity(self getVelocity() + (vec[0] * 250, vec[1] * 250, 150));
            wait 0.1;
        }
        wait 0.05;
    }
}

ToggleVampire()      { self MM_Toggle("vampire", "Vampire Mode", ::VampireLoop); }
VampireLoop()
{
    self endon("disconnect");
    self endon("mm_stop_vampire");
    last = self.score;
    for(;;)
    {
        if(self.score > last)
            self.health = self.maxhealth;
        last = self.score;
        wait 0.1;
    }
}

ToggleMovementAmmo() { self MM_Toggle("moveammo", "Move = Refill Ammo", ::MoveAmmoLoop); }
MoveAmmoLoop()
{
    self endon("disconnect");
    self endon("mm_stop_moveammo");
    for(;;)
    {
        if(length(self getVelocity()) > 10)
            self MM_RefillCurrent();
        wait 0.1;
    }
}

ToggleMagicBullets() { self MM_Toggle("magic", "Magic Bullets", ::MagicBulletsLoop); }
MagicBulletsLoop()
{
    self endon("disconnect");
    self endon("mm_stop_magic");

    weap = MM_FirstKnownWeapon("raygun_mark2_upgraded_zm", "ray_gun_upgraded_zm");
    if(!isDefined(weap))
    {
        self iprintln("^1No Ray Gun on this map.");
        self.mmToggle["magic"] = false;
        return;
    }

    for(;;)
    {
        self waittill("weapon_fired");
        eye = self getEye();
        dir = anglesToForward(self getPlayerAngles());
        magicBullet(weap, eye + (dir * 30), eye + (dir * 9999), self);
    }
}

ToggleHealth()
{
    if(self MM_Flip("health", "Super Health"))
    {
        self setMaxHealth(99999);
        self.health = 99999;
    }
    else
    {
        self setMaxHealth(self MM_DefaultMaxHealth());
        self.health = self.maxhealth;
    }
}

ToggleIgnoreMe()
{
    self.ignoreme = self MM_Flip("ignore", "Zombies Ignore You");
}

ToggleSpeed()
{
    if(self MM_Flip("speed", "Max Speed"))
        self setMoveSpeedScale(2.0);
    else
        self setMoveSpeedScale(1.0);
}

ToggleInvis()
{
    if(self MM_Flip("invis", "Invisibility"))
        self hide();
    else
        self show();
}

ToggleThirdPerson()
{
    if(self MM_Flip("thirdp", "Third Person"))
        self setClientThirdPerson(1);
    else
        self setClientThirdPerson(0);
}

SetFOV(val)
{
    self setClientDvar("cg_fov", val);
    self iprintln("FOV set to " + val);
}

GivePoints()
{
    MM_AddScore(self, 100000);
    self iprintln("Given ^2+100,000 ^7points");
}

ToggleInfPoints()    { self MM_Toggle("infpoints", "Infinite Points", ::InfPointsLoop); }
InfPointsLoop()
{
    self endon("disconnect");
    self endon("mm_stop_infpoints");
    for(;;)
    {
        if(self.score < 500000)
            MM_AddScore(self, 1000000);
        wait 1;
    }
}

SavePosition()
{
    self.mmSavedPos = self.origin;
    self.mmSavedAng = self getPlayerAngles();
    self iprintln("Position ^2saved");
}

LoadPosition()
{
    if(!isDefined(self.mmSavedPos))
    {
        self iprintln("^1No saved position.");
        return;
    }
    self setOrigin(self.mmSavedPos);
    self setPlayerAngles(self.mmSavedAng);
    self iprintln("Position ^2loaded");
}

TeleportToCrosshair()
{
    self setOrigin(self MM_CrosshairPos() + (0, 0, 10));
    self iprintln("Teleported");
}

DoSuicide()
{
    self suicide();
}

// ============================================================================
//  WEAPONS & PERKS
// ============================================================================

ToggleInfAmmo()      { self MM_Toggle("infammo", "Infinite Ammo", ::InfAmmoLoop); }
InfAmmoLoop()
{
    self endon("disconnect");
    self endon("mm_stop_infammo");
    for(;;)
    {
        self MM_RefillCurrent();
        wait 0.1;
    }
}

// Refills clip + reserve of one weapon, including its dual-wield and
// alternate (underbarrel) halves.
MM_RefillWeapon(weap)
{
    if(!isDefined(weap) || weap == "none" || weap == "")
        return;

    self setWeaponAmmoClip(weap, weaponClipSize(weap));

    dw = weaponDualWieldWeaponName(weap);
    if(isDefined(dw) && dw != "none" && dw != "")
        self setWeaponAmmoClip(dw, weaponClipSize(dw));

    alt = weaponAltWeaponName(weap);
    if(isDefined(alt) && alt != "none" && alt != "")
        self setWeaponAmmoClip(alt, weaponClipSize(alt));

    self giveMaxAmmo(weap);
}

MM_RefillCurrent()
{
    self MM_RefillWeapon(self getCurrentWeapon());
}

FillCurrentAmmo()
{
    self MM_RefillCurrent();
    self iprintln("Ammo filled");
}

FillAllAmmo()
{
    prim = self getWeaponsListPrimaries();
    foreach(w in prim)
        self MM_RefillWeapon(w);
    self iprintln("All ammo filled");
}

GiveWeap(weap)
{
    if(!MM_WeaponKnown(weap))
    {
        self iprintln("^1That weapon is not loaded on this map.");
        return;
    }

    // Let the game handle weapon limits, PaP camos, equipment and melee slots.
    self maps\mp\zombies\_zm_weapons::weapon_give(weap, isSubStr(weap, "upgraded"));
    self iprintln("Weapon given");
}

// Returns the Pack-a-Punched version of a weapon, or undefined if it has none.
MM_UpgradeOf(weap)
{
    if(!isDefined(weap) || weap == "none" || weap == "")
        return undefined;

    weap = self maps\mp\zombies\_zm_weapons::switch_from_alt_weapon(weap);
    base = maps\mp\zombies\_zm_weapons::get_base_name(weap);

    if(!MM_WeaponKnown(base))
        return undefined;
    if(isSubStr(base, "upgraded"))
        return undefined;
    if(!maps\mp\zombies\_zm_weapons::can_upgrade_weapon(base))
        return undefined;

    return maps\mp\zombies\_zm_weapons::get_upgrade_weapon(base);
}

PapCurrentWeapon()
{
    weap = self getCurrentWeapon();
    weap = self maps\mp\zombies\_zm_weapons::switch_from_alt_weapon(weap);

    if(isSubStr(weap, "upgraded"))
    {
        self iprintln("Already Pack-a-Punched");
        return;
    }

    upg = self MM_UpgradeOf(weap);
    if(!isDefined(upg))
    {
        self iprintln("^1This weapon can't be upgraded");
        return;
    }

    self takeWeapon(weap);
    self maps\mp\zombies\_zm_weapons::weapon_give(upg, true);
    self giveMaxAmmo(upg);
    self iprintln("Weapon upgraded!");
}

PapAllWeapons()
{
    count = 0;
    current = self getCurrentWeapon();
    current = self maps\mp\zombies\_zm_weapons::switch_from_alt_weapon(current);
    newCurrent = undefined;

    prim = self getWeaponsListPrimaries();
    foreach(w in prim)
    {
        if(isSubStr(w, "upgraded"))
            continue;

        upg = self MM_UpgradeOf(w);
        if(!isDefined(upg))
            continue;

        self takeWeapon(w);
        self maps\mp\zombies\_zm_weapons::weapon_give(upg, true);
        self giveMaxAmmo(upg);
        if(w == current)
            newCurrent = upg;
        count++;
    }

    if(isDefined(newCurrent))
        self switchToWeapon(newCurrent);
    self iprintln("Upgraded " + count + " weapon(s)");
}

DropWeapon()
{
    primaries = self getWeaponsListPrimaries();
    if(primaries.size < 2)
    {
        self iprintln("^1Can't drop your only weapon");
        return;
    }
    weap = self getCurrentWeapon();
    self dropItem(weap);
    self iprintln("Weapon dropped");
}

// Gives every perk that has a machine on the current map.
MM_GivePerks()
{
    machines = getEntArray("zombie_vending", "targetname");
    foreach(m in machines)
    {
        perk = m.script_noteworthy;
        if(!isDefined(perk))
            continue;
        if(self hasPerk(perk))
            continue;
        self maps\mp\zombies\_zm_perks::give_perk(perk, false);
        wait 0.25;
    }
}

GiveAllPerks()
{
    self MM_GivePerks();
    self iprintln("All perks ^2given");
}

RemoveAllPerks()
{
    machines = getEntArray("zombie_vending", "targetname");
    foreach(m in machines)
    {
        perk = m.script_noteworthy;
        if(isDefined(perk) && self hasPerk(perk))
            self notify(perk + "_stop");
    }
    self iprintln("Perks removed");
}

// ============================================================================
//  LOBBY / MAP
// ============================================================================

TurnOnPower()
{
    if(flag("power_on"))
    {
        self iprintln("Power is already on");
        return;
    }

    // Same sequence the Die Rise / Buried power switches run.
    level notify("electric_door");
    level thread maps\mp\zombies\_zm_perks::perk_unpause_all_perks();
    flag_set("power_on");
    level setClientField("zombie_power_on", 1);
    self iprintln("Power turned ^2ON");
}

OpenAllDoors()
{
    if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        self iprintln("^1You can't open doors while downed.");
        return;
    }

    setDvar("zombie_unlock_all", 1);

    doors = getEntArray("zombie_door", "targetname");
    foreach(door in doors)
    {
        if(isDefined(door.has_been_opened) && door.has_been_opened)
            continue;
        door notify("trigger", self, true);
        wait 0.05;
    }

    airlocks = getEntArray("zombie_airlock_buy", "targetname");
    foreach(a in airlocks)
    {
        a notify("trigger", self, true);
        wait 0.05;
    }

    debris = getEntArray("zombie_debris", "targetname");
    foreach(d in debris)
    {
        d notify("trigger", self, true);
        wait 0.05;
    }

    wait 1;
    setDvar("zombie_unlock_all", 0);
    self iprintln("All doors ^2opened");
}

SpawnDrop(type)
{
    level maps\mp\zombies\_zm_powerups::specific_powerup_drop(type, MM_Forward(60) + (0, 0, 30));
    self iprintln("Drop spawned");
}

MM_KillEnemies()
{
    enemies = MM_AllEnemies();
    foreach(z in enemies)
    {
        if(isDefined(z) && isAlive(z))
            z doDamage(z.health + 666, z.origin);
    }
}

SkipRound()
{
    level.zombie_total = 0;
    MM_KillEnemies();
    self iprintln("Skipping round...");
}

SetRound(round)
{
    // round_number is incremented when the current round ends.
    level.round_number = round - 1;
    level.zombie_total = 0;
    MM_KillEnemies();
    self iprintln("Jumping to round " + round + "...");
}

SetTimeScale(val)
{
    setDvar("timescale", val);
    self iprintln("Game speed: " + val);
}

MM_SetLowGravity()
{
    setDvar("g_gravity", 100);
    self iprintln("Gravity: 100");
}

MM_SetNormalGravity()
{
    setDvar("g_gravity", 800);
    self iprintln("Gravity: 800");
}

RestartMap()
{
    map_restart(false);
}

EndGame()
{
    level notify("end_game");
}

// ============================================================================
//  ZOMBIES
// ============================================================================

KillAllZombies()
{
    zombies = MM_AliveZombies();
    foreach(z in zombies)
    {
        if(isDefined(z) && isAlive(z))
            z doDamage(z.health + 666, z.origin);
    }
    self iprintln("All zombies killed");
}

ExplodeZombies()
{
    zombies = MM_AliveZombies();
    foreach(z in zombies)
    {
        if(!isDefined(z) || !isAlive(z))
            continue;
        // Skip the splash for zombies next to you so you don't hurt yourself.
        if(distance(self.origin, z.origin) > 250)
            radiusDamage(z.origin, 150, 1000, 1000, self);
        z doDamage(z.health + 666, z.origin);
    }
    self iprintln("Zombies exploded");
}

BurnZombies()
{
    zombies = MM_AliveZombies();
    foreach(z in zombies)
    {
        if(isDefined(z) && isAlive(z))
            z doDamage(z.health + 666, z.origin, self, self, "none", "MOD_BURNED");
    }
    self iprintln("Zombies burned");
}

TeleportZombies()
{
    pos = MM_Forward(150);
    zombies = MM_AliveZombies();
    foreach(z in zombies)
    {
        if(isDefined(z))
            z forceTeleport(pos);
    }
    self iprintln("Zombies teleported to you");
}

TeleportZombiesCrosshair()
{
    pos = self MM_CrosshairPos();
    zombies = MM_AliveZombies();
    foreach(z in zombies)
    {
        if(isDefined(z))
            z forceTeleport(pos);
    }
    self iprintln("Zombies teleported to crosshair");
}

ToggleZombieMagnet() { self MM_Toggle("magnet", "Zombie Magnet", ::MagnetLoop); }
MagnetLoop()
{
    self endon("disconnect");
    self endon("mm_stop_magnet");
    for(;;)
    {
        pos = MM_Forward(150);
        zombies = MM_AliveZombies();
        foreach(z in zombies)
        {
            if(isDefined(z))
                z forceTeleport(pos);
        }
        wait 0.1;
    }
}

MM_FlingZombie(force)
{
    self endon("death");
    self startRagdoll();
    self launchRagdoll((randomIntRange(-150, 150), randomIntRange(-150, 150), force));
    wait 1.5;
    if(isDefined(self) && isAlive(self))
        self doDamage(self.health + 666, self.origin);
}

FlingZombies()
{
    zombies = MM_AliveZombies();
    foreach(z in zombies)
        z thread MM_FlingZombie(900);
    self iprintln("Zombies launched");
}

ZombiesToMoon()
{
    zombies = MM_AliveZombies();
    foreach(z in zombies)
        z thread MM_FlingZombie(3500);
    self iprintln("Zombies sent to the moon");
}

ToggleFreezeZombies()
{
    level.mmFrozen = !level.mmFrozen;
    if(level.mmFrozen)
    {
        level thread MM_FreezeLoop();
        self iprintln("Zombies Frozen ^2ON");
    }
    else
    {
        level notify("mm_unfreeze");
        zombies = MM_AliveZombies();
        foreach(z in zombies)
        {
            z.ignoreall = false;
            z.animPlaybackRate = 1;
            z.moveplaybackrate = 1;
        }
        self iprintln("Zombies Frozen ^1OFF");
    }
}

MM_FreezeLoop()
{
    level endon("mm_unfreeze");
    level endon("end_game");
    for(;;)
    {
        zombies = MM_AliveZombies();
        foreach(z in zombies)
        {
            z.ignoreall = true;
            z.animPlaybackRate = 0;
            z.moveplaybackrate = 0;
        }
        wait 0.2;
    }
}

SetZombieSpeed(mode)
{
    level notify("mm_speed_stop");

    if(mode == "default")
    {
        level.mmSpeed = undefined;
        self iprintln("Zombie speed: default (applies to new zombies)");
        return;
    }

    level.mmSpeed = mode;
    level thread MM_ZombieSpeedLoop();
    self iprintln("Zombie speed: " + mode);
}

MM_ZombieSpeedLoop()
{
    level endon("mm_speed_stop");
    level endon("end_game");
    for(;;)
    {
        zombies = MM_AliveZombies();
        foreach(z in zombies)
        {
            if(!isDefined(z.animname) || z.animname != "zombie")
                continue;
            if(!isDefined(z.zombie_move_speed) || z.zombie_move_speed != level.mmSpeed)
                z set_zombie_run_cycle(level.mmSpeed);
        }
        wait 0.5;
    }
}

ToggleKillAura()     { self MM_Toggle("killaura", "Insta-Kill Aura", ::KillAuraLoop); }
KillAuraLoop()
{
    self endon("disconnect");
    self endon("mm_stop_killaura");
    for(;;)
    {
        zombies = MM_AliveZombies();
        foreach(z in zombies)
        {
            if(isDefined(z) && isAlive(z) && distance(self.origin, z.origin) < 150)
                z doDamage(z.health + 666, z.origin, self);
        }
        wait 0.2;
    }
}

DeleteZombies()
{
    zombies = MM_AliveZombies();
    foreach(z in zombies)
    {
        if(isDefined(z))
            z delete();
    }
    self iprintln("Zombies deleted");
}

RespawnZombies()
{
    level.zombie_total += 24;
    self iprintln("Added 24 zombies to the round");
}

// ============================================================================
//  AIMBOT / ESP
// ============================================================================

ToggleAimbot()       { self MM_Toggle("aimbot", "Aimbot", ::AimbotLoop); }

SetAimTarget(bone)
{
    self.aimbotBone = bone;
    self iprintln("Aimbot target: " + bone);
}

AimbotLoop()
{
    self endon("disconnect");
    self endon("mm_stop_aimbot");

    if(!isDefined(self.aimbotBone))
        self.aimbotBone = "j_head";

    for(;;)
    {
        wait 0.05;
        if(self.menuOpen)
            continue;
        if(!self adsButtonPressed() && !self attackButtonPressed())
            continue;

        eye = self getEye();
        best = undefined;
        bestDist = 999999;

        zombies = MM_AllEnemies();
        foreach(z in zombies)
        {
            tag = z getTagOrigin(self.aimbotBone);
            if(!isDefined(tag))
                continue;
            if(!bulletTracePassed(eye, tag, false, self))
                continue;
            d = distance(self.origin, z.origin);
            if(d < bestDist)
            {
                bestDist = d;
                best = tag;
            }
        }

        if(isDefined(best))
            self setPlayerAngles(vectorToAngles(best - eye));
    }
}

ToggleESP()          { self MM_Toggle("esp", "ESP", ::ESPLoop); }

SetESPColor(color)
{
    self.espColor = color;
    self iprintln("ESP color changed");
}

// Keeps HUD waypoints alive after the ESP loop ends so they can be destroyed
// cleanly if the player disconnects during a toggle or map transition.
MM_ESPDisconnectCleanup()
{
    self waittill("disconnect");

    if(isDefined(self.mmESPHuds))
    {
        foreach(hud in self.mmESPHuds)
        {
            if(isDefined(hud))
                hud destroy();
        }
    }
}

ESPLoop()
{
    self endon("disconnect");

    // Prevent two waypoint pools from being created if ESP is toggled rapidly.
    if(isDefined(self.mmESPThreadActive) && self.mmESPThreadActive)
        return;

    self.mmESPThreadActive = true;

    if(!isDefined(self.espColor))
        self.espColor = (1, 0, 0);

    // A bounded pool prevents HUD-element overflow while showing the nearest
    // ten live zombies. Coordinates are world-space, following the BO2 HUD API.
    maxMarkers = 10;
    huds = [];

    for(i = 0; i < maxMarkers; i++)
    {
        hud = newClientHudElem(self);
        hud.archived = 1;
        hud setWaypoint(true, "white");
        hud.foreground = false;
        hud.hideWhenInMenu = true;
        hud.sort = 1;
        hud.alpha = 0;
        hud.color = self.espColor;
        hud scaleOverTime(0.1, 14, 14);
        huds[huds.size] = hud;
    }

    self.mmESPHuds = huds;
    self thread MM_ESPDisconnectCleanup();

    for(;;)
    {
        if(!self MM_IsOn("esp"))
            break;

        zombies = MM_AllEnemies();
        selected = [];

        for(slot = 0; slot < maxMarkers; slot++)
        {
            best = undefined;
            bestDistance = 999999999;

            foreach(z in zombies)
            {
                alreadySelected = false;
                foreach(chosen in selected)
                {
                    if(chosen == z)
                    {
                        alreadySelected = true;
                        break;
                    }
                }

                if(alreadySelected)
                    continue;

                distanceNow = distancesquared(self.origin, z.origin);
                if(distanceNow < bestDistance)
                {
                    bestDistance = distanceNow;
                    best = z;
                }
            }

            if(isDefined(best))
            {
                selected[selected.size] = best;
                head = best getTagOrigin("j_head");
                if(!isDefined(head))
                    head = best.origin + (0, 0, 60);

                huds[slot].x = head[0];
                huds[slot].y = head[1];
                huds[slot].z = head[2];
                huds[slot].color = self.espColor;
                huds[slot].alpha = 1;
            }
            else
                huds[slot].alpha = 0;
        }

        wait 0.1;
    }

    foreach(hud in huds)
    {
        if(isDefined(hud))
            hud destroy();
    }

    self.mmESPHuds = [];
    self.mmESPThreadActive = false;
}
