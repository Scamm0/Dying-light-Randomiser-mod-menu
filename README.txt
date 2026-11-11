Dying Light - Randomiser Mod   (version 2.0)
============================================

Randomises Dying Light 1's enemy spawns, enemy AI, street crowds, loot, shops, quest rewards, interface
and world colours, dialogue and subtitles, in Harran and The Following.
Everything is chosen in a small mod menu - no files to copy into the game by hand.

REQUIREMENTS
    - Dying Light 1 on PC (Steam). Works with or without The Following DLC
      (without it, the The Following options are greyed out). The Hellraid options need the Hellraid DLC.
    - Windows 10 or 11 (uses the built-in PowerShell - nothing else to install).

INSTALL
    1. Unzip this folder anywhere (e.g. your Documents). Keep the files together.
    2. Close Dying Light.
    3. Double-click "Randomiser Menu.bat".
    4. Check the Game folder at the top. The menu finds Dying Light in your Steam libraries by itself;
       if the box is empty, press Browse and pick the Dying Light folder (the one with DW inside).
    5. Tick what you want and press Install. That's it - start the game.
       Out of the box, enemy spawns are randomised, street crowds are normal biters and everything
       else is off - switch on whichever you like.

    Updating from 1.0: unzip 2.0 over the old folder (or into a new one), open the menu and press Install.
    Your saved choices carry over; the new enemies and options start switched off.

WHAT INSTALL CHANGES
    Always: Dying Light\DW\Data3.pak (an empty slot the game ships for mods).
    Only when the option that needs it is on (the original is kept next to it as *.randomiser-backup):
        Shuffle subtitles                      your language pak, e.g. DW\DataEn.pak, and The Following's
                                               subtitle files in DW_DLC17\Data<language>\Data\Maps
        Dialogue (in The Following)            DW_DLC17\DataDLC17_0.pak
        Hellraid enemies in The Following too  DW_DLC17\DataDLC17_2.pak
    Installing again with an option off puts that file back. Your choices are saved in
    menu-settings.json next to the menu.

UNINSTALL
    Open the menu and press "Remove mod (vanilla)". It restores every file above byte for byte.
    (Verifying game files in Steam also works.)

SAVES
    The mod changes no save data. Removing it puts everything back to normal; items you already
    picked up stay in your inventory.

WHAT THE MENU DOES
    Hover over the blue "i" next to each section title, or over any option, for an explanation.

    Enemies - what comes out of spawn points (noise, virals, patrols, night biters, enemies that
    appear around you) in Harran and The Following.
        Randomise enemy AI (Experimental): each enemy type keeps its body but gets the behaviour of
            another enemy with the same body shape - a Goon that acts like a biter, a viral that acts
            like a Suicider, a Rais soldier that fights like Tahir. Rolled from the seed.
        "Enemy spawn pool selection..." lets you switch any of the 70 enemies on or off:
            specials, humans (bandits, Rais's men), Tahir, tougher and elemental variants, GRE operatives,
            Bolters, the Iced Bolter, The Following's Freaks of Nature and Ultras (Behemoths), Hellraid's
            skeletons, adepts, Dark Knight and Minotaur, The Following's final boss the Mother (both forms),
            The Following's human ghost, friendly NPCs (survivors, a Tower soldier, a bodyguard, Jade),
            and community event enemies (Rust rifleman, astronaut invaders, Chivalry knight).
            New groups (Hellraid, the Mother, friendly NPCs, event enemies, Iced Bolter) start switched off.
        Options in that window:
            Freaks of Nature in Harran - Freaks and Ultras spawn in Harran with their proper Following
                behaviour, toughness and size.
            The Mother and ghosts in Harran - the Mother and the human ghost spawn in Harran too.
            Big military viral in Harran - the big military viral spawns in Harran with its real look
                (loads a 2.2 GB archive; the human ghost is left out while this is on).
            Hellraid enemies in The Following too (Experimental).
            Freaks in The Following - Off, Freaks, or Freaks + Ultras.
        WARNING: Hellraid enemies and the two "in Harran" options above make every map load an extra DLC
        archive. With any of them on, the Prison map and the Be the Zombie tutorial crash, and maps take
        a little longer to load.
        Night spawns (Volatiles) on The Following's map stay vanilla.

    Street crowds - the biters standing and wandering around the streets. Pick one enemy for the
        whole crowd, or separate ones for male and female biters.
        WARNING: crowds of special infected can make some of them glitch into deformed biter models or
        shrunken versions of themselves, and many crowd combinations are unstable and may crash the
        game. The only confirmed stable crowds are Biters (vanilla), Virals and Left 4 Dead runners.

    UI colours - Accents: every coloured part of the HUD, menus and text moves to a random colour.
        Everything: white and grey text gets random colours too. "Icons too" also tints HUD, radar and
        map icons, map areas and elemental effects.

    World colours - Tinted: sunlight, clouds, glow, water and stars get a random tint for each time of
        day. Wild: the sky's colours are swapped around too.

    Dialogue - Same character: each character says their own lines in the wrong order. Everyone: any
        line from that map can come from anyone. Quests still start the right conversations.
        "Shuffle subtitles" swaps the subtitle text of spoken lines (turn subtitles on in the game).
        Animated cutscenes keep their own lines.

    Loot and shops
        Container / body loot   Shuffle: each container type gets another type's loot.
                                Chaos: each container type gets 8 random loot lists.
        Shop stock              Every shop sells random items of the same kind.
        Quartermaster stock     Tower Quartermaster sells random shop items; The Following's buggy
                                parts, bolts and mines shuffle among themselves.
        Weapon tiers            Shuffles the white/green/blue/violet/orange rarity odds.
        Loot quantity           Random amounts of crafting parts, ammo, consumables, cash...
        Quest rewards           Side quest and encounter rewards swap for others of the same kind;
                                cash ranges from half to double.
        Quest items, the grappling hook, UV flashlight, shield, bow and arrows are never changed.

SEEDS
    Everything rolled at install (loot, shops, quest rewards, colours, dialogue, enemy AI) stays the same
    until you install again. Leave the Seed box blank for a new roll each time, or type a seed to repeat
    a roll. Your current seed is in randomiser_settings.txt inside Dying Light\DW\Data3.pak (open the pak
    with any zip tool, e.g. 7-Zip, or rename a copy to .zip). With enemy AI on, randomiser_ai_swaps.txt
    in the same pak lists which enemy got which AI.

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
    - Crash when loading the Prison or the Be the Zombie tutorial: switch off Hellraid enemies and the
      "in Harran" options in the spawn pool window, then press Install.
    - Other crashes: most likely a street crowd choice. Set crowds to Biter (vanilla), Viral or
      L4D runner and press Install again. Options marked (Experimental) are the next thing to switch off.
    - Only tested in single player.

FILES
    Randomiser Menu.bat     opens the menu
    Randomiser Menu.ps1     the menu
    build.ps1               reads your game files and writes the randomised Data3.pak
    Play (new roll).bat     re-roll + start the game (optional)
    CHANGELOG.txt           what changed in each version
