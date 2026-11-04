Dying Light - Randomiser Mod   (version 1.0)
============================================

Randomises Dying Light 1's enemy spawns, street crowds, loot and shops, in Harran and The Following.
Everything is chosen in a small mod menu - no files to copy into the game by hand.

REQUIREMENTS
    - Dying Light 1 on PC (Steam). Works with or without The Following DLC
      (without it, the The Following options are greyed out).
    - Windows 10 or 11 (uses the built-in PowerShell - nothing else to install).

INSTALL
    1. Unzip this folder anywhere (e.g. your Documents). Keep the files together.
    2. Close Dying Light.
    3. Double-click "Randomiser Menu.bat".
    4. Check the Game folder at the top. The menu finds Dying Light in your Steam libraries by itself;
       if the box is empty, press Browse and pick the Dying Light folder (the one with DW inside).
    5. Tick what you want and press Install. That's it - start the game.
       Out of the box, enemy spawns are randomised, street crowds are normal biters and the loot and
       shop options are off - switch on whichever you like.

    Install writes one file: Dying Light\DW\Data3.pak (an empty slot the game ships for mods).
    Your choices are saved in menu-settings.json next to the menu.

UNINSTALL
    Open the menu and press "Remove mod (vanilla)". (Verifying game files in Steam also works.)

SAVES
    The mod changes no save data. Removing it puts everything back to normal; items you already
    picked up stay in your inventory.

WHAT THE MENU DOES
    Hover over the blue "i" next to each section title, or over any option, for an explanation.

    Enemies - what comes out of spawn points (noise, virals, patrols, night biters, enemies that
    appear around you) in Harran and The Following:
        Specials, humans (bandits, Rais's men), Tahir, tougher and elemental variants, GRE operatives,
        Bolters, The Following's Freaks of Nature and Ultras (Behemoths), and community event enemies
        (Rust rifleman "zombie with a gun", low-gravity astronaut invaders, Chivalry knight, Iced Bolter).
        "Pick individual enemies..." lets you switch any of the 49 enemies on or off.
        Night spawns (Volatiles) on The Following's map stay vanilla.

    Street crowds - the biters standing and wandering around the streets. Pick one enemy for the
        whole crowd, or separate ones for male and female biters.
        WARNING: crowds of special infected can make some of them glitch into deformed biter models or
        shrunken versions of themselves, and many crowd combinations are unstable and may crash the
        game. The only confirmed stable crowds are Biters (vanilla), Virals and Left 4 Dead runners.

    Loot and shops
        Container / body loot   Shuffle: each container type gets another type's loot.
                                Chaos: each container type gets 8 random loot lists.
        Shop stock              Every shop sells random items of the same kind.
        Quartermaster stock     Tower Quartermaster sells random shop items; The Following's buggy
                                parts, bolts and mines shuffle among themselves.
        Weapon tiers            Shuffles the white/green/blue/violet/orange rarity odds.
        Loot quantity           Random amounts of crafting parts, ammo, consumables, cash...
        Quest items, the grappling hook, UV flashlight, shield, bow and arrows are never changed.

SEEDS
    Loot and shops are randomised once, when you press Install. They stay the same until you install
    again. Leave the Seed box blank for a new roll each time, or type a seed to repeat a roll.
    Your current seed is in randomiser_settings.txt inside Dying Light\DW\Data3.pak (open the pak
    with any zip tool, e.g. 7-Zip, or rename a copy to .zip).

NEW ROLL EVERY TIME THE GAME STARTS (optional - pick one)
    Steam: in the menu press "Copy Steam launch option", then in Steam right-click Dying Light >
        Properties > General > Launch Options and paste. Every Play re-rolls with your saved choices
        and a new seed (takes a few seconds), then the game starts.
        Don't move this folder afterwards (the launch option points to it). To stop, clear that box.
    Or: double-click "Play (new roll).bat" instead of pressing Play in Steam.
    The last roll's details are written to last-launch.log.

TROUBLESHOOTING
    - Nothing happens when opening the menu: right-click each .bat and .ps1 file > Properties and
      tick "Unblock" if it's there (Windows blocks some downloaded files), then try again.
    - "Close Dying Light first": the game locks its files while running.
    - Game crashes: most likely a street crowd choice. Set crowds to Biter (vanilla), Viral or
      L4D runner and press Install again. Crash logs: Documents\DyingLight\out\logs (newest crash_*.log).
    - Only tested in single player.

FILES
    Randomiser Menu.bat     opens the menu
    Randomiser Menu.ps1     the menu
    build.ps1               reads your game files and writes the randomised Data3.pak
    Play (new roll).bat     re-roll + start the game (optional)
