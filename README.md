# Dying Light Randomiser Mod 2.0

A randomiser for **Dying Light 1** (PC, Steam). It covers enemy spawns, enemy AI, street crowds, loot, shops, Quartermaster stock, weapon rarity, item amounts, quest rewards, interface and world colours, dialogue and subtitles, in Harran and The Following. You set it up in a small mod menu.

This repository holds the complete source. The mod is plain-text scripts; there are no compiled programs, executables or DLLs. Every file can be opened and read in Notepad.

| File | What it is |
|---|---|
| `Randomiser Menu.bat` | A one-line launcher. It opens `Randomiser Menu.ps1` in Windows PowerShell with the console window hidden. |
| `Randomiser Menu.ps1` | The mod menu, a Windows Forms window. It saves your choices and runs `build.ps1`. |
| `build.ps1` | Reads the game's own script files from its `.pak` archives, randomises them and writes the mod pak. |
| `Play (new roll).bat` | Optional. Re-rolls with your saved choices and a new seed, then starts the game through Steam. |
| `README.txt` | The player guide included in the download. |
| `CHANGELOG.txt` | What changed in each version. |

Everything runs on PowerShell 5.1 and .NET Framework, which come with Windows 10 and 11. Nothing else is installed or downloaded.

## What the scripts do (and don't do)

**Network:** none. There are no web requests, downloads or uploads. The only URL is `steam://rungameid/239140`, which asks Steam to start Dying Light.

**Reads:**
- Steam's install path, from the registry (`HKCU\Software\Valve\Steam`, plus the HKLM equivalents).
- `steamapps\libraryfolders.vdf`, to find which Steam library holds Dying Light.
- `steamapps\appmanifest_239140.acf`, for the game's language (used by the subtitle and dialogue options).
- Game archives, opened as zip files:
  - `DW\Data0.pak`, `DW\Data2.pak` and the language pak (e.g. `DW\DataEn.pak`)
  - `DW_DLC17\DataDLC17_0.pak` and `DW_DLC17\DataDLC17_2.pak` (The Following)
  - `DW_DLC49\DataDLC49_0.pak` (Hellraid)
  - the other DLC folders' `.pak` files, only to find their maps' start files
- The `.rpack` archives are never opened; the script only checks that they exist.

**Writes:**
- `Dying Light\DW\Data3.pak`, always. This is the empty slot the game ships for mods. "Remove mod" puts back the game's original 132-byte placeholder, byte for byte.
- Only when the option that needs it is ticked, because these files outrank `Data3.pak` and can't be overridden from it. Each one is first copied to `<file>.randomiser-backup`. A modded `.pak` also gets a `randomiser_subtitles.txt` marker entry:

  | Option | File edited in place |
  |---|---|
  | Shuffle subtitles | The language pak, e.g. `DW\DataEn.pak` |
  | Shuffle subtitles | The Following's loose subtitle files, `DW_DLC17\Data<language>\Data\Maps\*.bin` |
  | Dialogue, in The Following | `DW_DLC17\DataDLC17_0.pak` |
  | Hellraid enemies in The Following too | `DW_DLC17\DataDLC17_2.pak` (one line added to The Following's map start file) |

  Installing with the option off, or pressing "Remove mod", copies the backup back and deletes it. If Steam has replaced a `.pak` since, which shows as the marker being gone, the backup is just deleted.
- `Dying Light\DW_DLC17\DataDLC17_1.pak`. This is only reset to the game's original placeholder if an old test build had changed it.
- In the mod's own folder:
  - `menu-settings.json` (your choices).
  - `last-launch.log` (the output of the last re-roll).
  - `Data3.pak`, a copy of the last pak it built. It is built here first, then copied into the game.

**Other actions:**
- Copies the optional Steam launch option text to the clipboard, when you press that button.
- Starts Dying Light, but only from "Play (new roll).bat" or the optional Steam launch option.

**Why `-ExecutionPolicy Bypass`:** Windows blocks unsigned PowerShell scripts by default. This flag lets the menu run only for that one PowerShell process, and it changes no system setting.

**Never touched:** saves, game executables, other mods, system settings.

## How it works

Dying Light 1 loads loose script files from its `.pak` archives (these are zip files), and `Data3.pak` takes priority over the base game's `Data0.pak`. `build.ps1` does the following:

1. It extracts the relevant game scripts from your own install. These are spawn presets and pools, enemy presets, street crowds, loot tables, shop stock, item sets, quest rewards, interface and sky colour files, dialogue and subtitles.
2. It rewrites them with the options you chose:
   - It replaces the enemy lists that spawn points pick from with randomised lists.
   - It shuffles loot, shops, rewards, colours, dialogue and enemy AI, using a seed.
   - For DLC enemies used outside their own maps (Hellraid, The Following's Freaks, the Mother, the ghost, the big military viral), it adds the DLC's archive to the maps' start files with the game's own `CrossLevelPack` line, and copies in the DLC's preset and AI files.
3. It writes the changed copies into `Data3.pak`, plus a `randomiser_settings.txt` that records the settings and seed used.

**Precompiled AI data.** Harran only reads enemy AI presets in a precompiled binary form (`.dat`). For The Following's enemies that have no Harran `.dat`, `build.ps1` contains small precompiled files made from the game's own `.scr` scripts. For the Freaks of Nature it holds a text table of differences, applied at install to the base game's own `.dat` files. For the Mother and the human ghost it holds complete `.dat` files as base64 text. All of them contain only AI parameters and animation names.

No game files are included in this repository or the download. Everything is generated from the player's own installation when they press Install.

## Install (players)

1. Download and unzip anywhere. Close Dying Light.
2. Double-click `Randomiser Menu.bat`.
3. Check that the game folder is right (it's detected from Steam). Tick your options, then press **Install**.
4. To uninstall, press **Remove mod (vanilla)**, or verify the game files in Steam.

See `README.txt` for the full guide and the list of options.

## Notes

- With Hellraid enemies or the "in Harran" Following options on, the Prison map and the Be the Zombie tutorial crash.
- Street crowds made of special infected can glitch or crash. The confirmed stable crowds are vanilla Biters, Virals and Left 4 Dead runners.
- Options marked (Experimental) are the least tested.
- Only tested in single player.
