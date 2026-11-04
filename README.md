# Dying Light Randomiser Mod 1.0

A randomiser for **Dying Light 1** (PC, Steam). It covers enemy spawns, street crowds, loot, shops, Quartermaster stock, weapon rarity and item amounts, in Harran and The Following. You set it up in a small mod menu.

This repository holds the complete source. The mod is plain-text scripts; there are no compiled programs, executables or DLLs. Every file can be opened and read in Notepad.

| File | What it is |
|---|---|
| `Randomiser Menu.bat` | A one-line launcher. It opens `Randomiser Menu.ps1` in Windows PowerShell with the console window hidden. |
| `Randomiser Menu.ps1` | The mod menu, a Windows Forms window. It saves your choices and runs `build.ps1`. |
| `build.ps1` | Reads the game's own script files from its `.pak` archives, randomises them and writes the mod pak. |
| `Play (new roll).bat` | Optional. Re-rolls with your saved choices and a new seed, then starts the game through Steam. |
| `README.txt` | The player guide included in the download. |

Everything runs on PowerShell 5.1 and .NET Framework, which come with Windows 10 and 11. Nothing else is installed or downloaded.

## What the scripts do (and don't do)

**Network:** none. There are no web requests, downloads or uploads. The only URL is `steam://rungameid/239140`, which asks Steam to start Dying Light.

**Reads:**
- Steam's install path, from the registry (`HKCU\Software\Valve\Steam`, plus the HKLM equivalents).
- `steamapps\libraryfolders.vdf`, to find which Steam library holds Dying Light.
- These game archives, opened as zip files and never modified:
  - `DW\Data0.pak`
  - `DW_DLC17\DataDLC17_0.pak`
  - `DW_DLC17\DataDLC17_2.pak`

**Writes:**
- `Dying Light\DW\Data3.pak`. This is the empty slot the game ships for mods, and the mod's only output. "Remove mod" puts it back to its original one-file placeholder.
- `Dying Light\DW_DLC17\DataDLC17_1.pak`. This is only restored to its original placeholder if an old test build had changed it.
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

1. It extracts the relevant game scripts from your own install. These are spawn presets and pools, street crowds, loot tables, shop stock and item sets.
2. It rewrites them with the options you chose:
   - It replaces the enemy lists that spawn points pick from with randomised lists.
   - It shuffles the loot tables and shop items, using a seed.
3. It writes the changed copies into `Data3.pak`. It also writes a `randomiser_settings.txt` that records the settings and seed used.

No game files are included in this repository or the download. Everything is generated from the player's own installation when they press Install.

## Install (players)

1. Download and unzip anywhere. Close Dying Light.
2. Double-click `Randomiser Menu.bat`.
3. Check that the game folder is right (it's detected from Steam). Tick your options, then press **Install**.
4. To uninstall, press **Remove mod (vanilla)**, or verify the game files in Steam.

See `README.txt` for the full guide and the list of options.

## Notes

- Street crowds made of special infected can glitch or crash. The confirmed stable crowds are vanilla Biters, Virals and Left 4 Dead runners.
- Only tested in single player.
