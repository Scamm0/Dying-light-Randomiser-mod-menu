# Randomiser mod for Dying Light 1 (2.0)
# Reads the spawn scripts from YOUR install's Data0.pak, swaps every biter
# AIPreset for a random special-infected list, and writes DW\Data3.pak.
#   .\build.ps1                 build + install
#   .\build.ps1 -Uninstall      restore the original Data3.pak
param(
    [string]$Game = "C:\Program Files (x86)\Steam\steamapps\common\Dying Light",   # the menu passes the real folder
    [switch]$DayOnly,           # leave night biters (Night_Walker presets) alone
    [switch]$NoVirals,          # leave virals alone, only replace biters
    [switch]$NoVariants,        # leave out the tougher/elemental variants of the specials
    [switch]$NoGRE,             # leave out the Zombie Hunt "former GRE operatives" (giant Goon + Demolisher)
    [switch]$NoBolters,         # leave out Bolters (day and night)
    # The Following's Freaks of Nature, on The Following's map only (their AI data does not load in Harran): None, Freaks, Ultra
    [ValidateSet("None", "Freaks", "Ultra")][string]$Freaks = "None",
    [switch]$NoTahir,           # leave out Tahir (museum boss fight preset)
    # TEST: also spawn Freaks/Ultras (and the GRE Goon) in Harran by copying their AI data files into
    # Data3.pak at the base-game paths the loader reads. Needs The Following DLC.
    [switch]$FreaksInHarran,
    # Community event enemies (Rust rifleman, low-gravity astronauts, Chivalry knight) in every spawn list.
    [switch]$Events,
    # Leave The Following (DLC map) vanilla: its spawns, crowd and loot
    [switch]$NoFollowing,
    # Winter event's Iced Bolter in every spawn list (separate: like any Bolter it puts a Bolter icon on screen).
    [switch]$IcedBolter,
    # Friendly survivors, a Tower soldier and a bodyguard in every spawn list.
    [switch]$Friendlies,
    # Hellraid DLC enemies in Harran's spawn lists (not The Following's, not crowds). Every Harran map is told to load
    # hellraid_PC.rpack (CrossLevelPack in its .startprop), and Hellraid's presets, animation scripts and AI files are copied in.
    [switch]$Hellraid,
    # EXPERIMENTAL: Hellraid enemies in The Following too. Its map start file (wasteland.startprop) is in DataDLC17_2.pak, which outranks
    # Data3.pak, so that pak is edited in place to load hellraid_PC.rpack (original kept as DataDLC17_2.pak.randomiser-backup).
    [switch]$HellraidFollowing,
    # The Mother (The Following's final boss) in The Following's spawn lists only: her model is only in The Following's archives.
    [switch]$Mother,
    # Also spawn the Mother (with -Mother) in Harran: every Harran map loads The Following's final-boss
    # archive (wasteland_final_PC.rpack, ~430 MB, holds mother.msh) and the Mother's AI data is precompiled for Harran.
    # Also adds The Following's human ghost (in the ghost-follower skin) to Harran's lists.
    [switch]$MotherInHarran,
    # Harran's maps also load The Following's main archive (wasteland_PC.rpack, 2.2 GB): the big military viral spawns in Harran.
    [switch]$FollowingArchive,
    # Enemy AI: each enemy type keeps its body but gets the AI (behaviour, attacks, speed, health, weapon) of another enemy with the same
    # body shape and AI family, rolled from the seed. E.g. a Goon that acts like a biter, a viral that acts like a Suicider.
    [switch]$AISwap,
    # Preset names to leave out of every spawn list (comma-separated), e.g. "Screamer,Volatile_Super".
    # Applied after the group switches above; the crowd "Random special" roll respects it too.
    [string]$Exclude,
    # Street crowds (most biters in a late-game save). List = random pick per zombie;
    # Fixed = each of the 2 crowd slots gets one special, rolled at build time
    # (use if List crashes or crowds vanish); Off = leave crowds alone.
    # Virals = slot 0 male viral, slot 1 female viral (keeps the game's 2 slots).
    # Fixed is the tested mode; List and Many (8 slots) crashed on load in testing.
    # Rais = slot 0 Rais's melee man, slot 1 Rais's rifleman (humans in the crowd system: untested).
    # L4D = the 2020 Left 4 Dead event's runners (biter bodies, night-runner AI, day-active, half health),
    # still defined in humanai.pre but only ever switched on server-side.
    [ValidateSet("Virals", "L4D", "Rais", "Fixed", "List", "Many", "Off", "Custom")][string]$CrowdMode = "L4D",
    # Custom crowds, one enemy per slot (1 = male biter slot, 2 = female): Vanilla, L4D, Viral, Random
    # (a special rolled at build time) or a humanai preset name. Either one sets -CrowdMode Custom.
    [string]$Crowd1,
    [string]$Crowd2,
    [switch]$NoSpawns,          # leave enemy spawns alone (noise/night/Following spawn presets)
    # Containers and bodies (default.loot, wasteland.loot). Shuffle = each container type gets another
    # type's whole loot table, rolled at build time; Chaos = every container type gets 8 random item
    # sets from all of them, rolled at build time. Empty chances and quest items stay as they were.
    [ValidateSet("Off", "Shuffle", "Chaos")][string]$Loot = "Chaos",
    # Shops (shop_item_sets.scr). Random = every stock list gets random items of the same kind
    # (melee, firearm, throwable, blueprint, ...) from the same region, rolled at build time.
    [ValidateSet("Off", "Random")][string]$Shops = "Random",
    # Quartermaster stock (Quatermaster_* item sets). Random = Harran Quartermaster slots roll any Harran
    # shop item; The Following's buggy parts/components/bolts/mines shuffle among themselves. The hook,
    # UV flashlight, shield, bow and arrows stay.
    [ValidateSet("Off", "Random")][string]$Quartermaster = "Random",
    # Weapon tiers (color_sets.loot): each colour set's white/green/blue/violet/orange odds are shuffled
    # between the colours, rolled at build time. Crates = weapon, lockpick, valuables and airdrop crates;
    # All = also bodies and everyday containers.
    [ValidateSet("Off", "Crates", "All")][string]$Tiers = "Crates",
    # Loot quantity (item_sets.loot): min-max counts widened, single stackables (crafting parts, ammo,
    # throwables, consumables, valuables) become 1 to 2-4. Weapons and blueprints stay at one.
    [ValidateSet("Off", "Random")][string]$Quantity = "Random",
    # Interface colours (data/menu/*.xui). Accents = every coloured UI element moves to a random hue, keeping its
    # brightness and transparency; Everything = white and grey text gets random colours too. Black backgrounds stay.
    [ValidateSet("Off", "Accents", "Everything")][string]$UIColours = "Off",
    # Add-on to -UIColours (ignored when that's Off): tints HUD, radar and map icons, and recolours map areas and elemental effects.
    [switch]$UIIcons,
    # Spoken lines swap text with each other (the player's language, from Steam). Dialogue only: menus and item names stay.
    [switch]$Subtitles,
    # Sun, clouds and glow get a random tint for each time of day, water and stars too. Wild also swaps the sky's colours.
    [ValidateSet("Off", "Tinted", "Wild")][string]$WorldColours = "Off",
    # Quest reward items swap for others of the same kind (blueprint, melee, firearm, upgrade) and cash varies from half to double.
    [ValidateSet("Off", "Random")][string]$QuestRewards = "Off",
    # Voiced dialogue (data/dialogs/*.xml). SameCharacter = each character's lines swap among themselves; Everyone = any line in that map.
    [ValidateSet("Off", "SameCharacter", "Everyone")][string]$Dialogue = "Off",    [int]$Seed,                 # same seed + settings = same build-time rolls (0 = new random seed)
    [string]$OutFile,           # write the pak here instead of installing it
    [switch]$Uninstall
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$dw     = Join-Path $Game "DW"
$target = Join-Path $dw "Data3.pak"
# A test build wrote The Following's map files into DataDLC17_1.pak (the DLC's empty patch slot); they were ignored,
# so that slot is put back to its placeholder on every install and uninstall.
$dlcTarget = Join-Path $Game "DW_DLC17\DataDLC17_1.pak"

# The vanilla Data3.pak holds one empty placeholder.file and nothing else. These are Steam's exact bytes (the same 132-byte file as
# DataDLC1_1.pak and DataDLC16_1.pak): a rebuilt zip differs (timestamp, flags), and the game then reports a modified install.
$VanillaPlaceholder = [Convert]::FromBase64String('UEsDBBQAAAAIAAAAIAAAAAAAAgAAAAAAAAAQAAAAcGxhY2Vob2xkZXIuZmlsZQMAUEsBAgAAFAAAAAgAAAAgAAAAAAACAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAHBsYWNlaG9sZGVyLmZpbGVQSwUGAAAAAAEAAQA+AAAAMAAAAAAA')
function Write-VanillaPlaceholder([string]$path) { [IO.File]::WriteAllBytes($path, $VanillaPlaceholder) }
function Write-Pak([string]$path, [hashtable]$files) {
    if (Test-Path $path) { Remove-Item $path }
    $zip = [IO.Compression.ZipFile]::Open($path, "Create")
    foreach ($f in $files.Keys) {
        $d = $zip.CreateEntry($f, "Optimal")
        if ($files[$f] -is [byte[]]) { $s = $d.Open(); $s.Write($files[$f], 0, $files[$f].Length); $s.Close(); continue }
        $w = New-Object IO.StreamWriter($d.Open(), (New-Object Text.UTF8Encoding($false)))
        $w.Write($files[$f]); $w.Close()
    }
    $zip.Dispose()
}

# Language paks (Subtitles). Text in DataEn.pak etc. outranks Data3.pak, so shuffled lines have to go in the language pak
# itself. The vanilla pak is kept as Data<lang>.pak.randomiser-backup, and the modded one carries a marker file, so a pak
# Steam has since replaced is recognised as vanilla.
$langMarker = "randomiser_subtitles.txt"
function Test-LangMarker([string]$path) {
    if (-not (Test-Path $path)) { return $false }
    $z = [IO.Compression.ZipFile]::OpenRead($path); $has = [bool]$z.GetEntry($langMarker); $z.Dispose(); $has
}
function Restore-LangPaks([string[]]$Keep = @()) {
    $bakFiles = @(Get-ChildItem $dw -Filter "Data*.pak.randomiser-backup" -ErrorAction SilentlyContinue)
    $dlc = Join-Path $Game "DW_DLC17"
    if (Test-Path $dlc) {
        $bakFiles += @(Get-ChildItem $dlc -Filter "DataDLC17_*.pak.randomiser-backup" -ErrorAction SilentlyContinue)
        $bakFiles += @(Get-ChildItem $dlc -Recurse -Filter "*.bin.randomiser-backup" -ErrorAction SilentlyContinue)
    }
    foreach ($b in $bakFiles) {
        if ($Keep -contains $b.FullName) { continue }
        $orig = $b.FullName -replace '\.randomiser-backup$', ''
        # a pak without the marker was replaced by Steam since, so it's vanilla already; loose text files have no marker
        if ($orig -like "*.bin" -or (Test-LangMarker $orig)) { Copy-Item $b.FullName $orig -Force; "Restored the vanilla $(Split-Path $orig -Leaf)" }
        Remove-Item $b.FullName
    }
}
# Backs up a vanilla pak once, then rewrites it with the given entries replaced.
function Set-ModdedPak([string]$pak, [hashtable]$bins) {
    $bak = "$pak.randomiser-backup"
    if (-not (Test-LangMarker $pak)) { Copy-Item $pak $bak -Force }
    Write-LangPak $bak "$pak.tmp" $bins
    Move-Item "$pak.tmp" $pak -Force
}
# Copies $source to $dest with the given entries replaced, plus the marker.
function Write-LangPak([string]$source, [string]$dest, [hashtable]$bins) {
    if (Test-Path $dest) { Remove-Item $dest }
    $in = [IO.Compression.ZipFile]::OpenRead($source); $out = [IO.Compression.ZipFile]::Open($dest, "Create")
    foreach ($e in $in.Entries) {
        $s = $out.CreateEntry($e.FullName, "Optimal").Open()
        if ($bins.ContainsKey($e.FullName)) { $s.Write($bins[$e.FullName], 0, $bins[$e.FullName].Length) } else { $r = $e.Open(); $r.CopyTo($s); $r.Close() }
        $s.Close()
    }
    $w = New-Object IO.StreamWriter($out.CreateEntry($langMarker, "Optimal").Open()); $w.Write("Modified by the Dying Light Randomiser mod. Press Remove mod, or verify game files in Steam, to restore."); $w.Close()
    $out.Dispose(); $in.Dispose()
}

if ($Uninstall) {
    Write-VanillaPlaceholder $target
    "Restored the vanilla Data3.pak"
    Restore-LangPaks
    if (Test-Path $dlcTarget) { Write-VanillaPlaceholder $dlcTarget; "Restored the vanilla DataDLC17_1.pak" }
    return
}

if ($Crowd1 -or $Crowd2) {
    $CrowdMode = "Custom"
    if (-not $Crowd1) { $Crowd1 = "L4D" }; if (-not $Crowd2) { $Crowd2 = "L4D" }
}
if (-not $Seed) { $Seed = Get-Random -Minimum 1 -Maximum 999999 }
Get-Random -SetSeed $Seed | Out-Null

# Each AIPreset entry is picked at random per spawn; repeat a name to weight it.
$Specials = @(
    "Goon_Slums",        # Goon
    "Toad_OldTown",      # Toad (spitter)
    "Demolisher",        # Demolisher
    "Bomber",            # Bomber
    "RunningBomber",     # Suicider
    "Screamer",          # Screamer
    "GasTank",           # Gas tank biter
    "Volatile",          # Volatile
    "Enemy_Headhunter_Melee",             # Old Town bandit
    "enc_slums_maskedbandit_lvl02",       # Rais's man, melee
    "enc_slums_maskedbanditrifle_lvl02"   # Rais's man, rifle
)
# Tahir's museum boss fight (tahir.msh in common_meshes, melee_fighter_tahir data loads in Harran)
if (-not $NoTahir) { $Specials += "Quest_Museum_TahirBoss" }

# Base-game variants (all in humanai.pre, AI data in Data0.pak)
$Variants = @(
    "Demolisher_Blister",       # blistered Demolisher
    "DemolisherTough",          # black-masked Demolisher
    "Demolisher_Prison",        # prison Demolisher
    "Demolisher_Wasteland",     # military Demolisher
    "Goon_Hazmat",              # hazmat Goon
    "Goon_Poison",              # fireman Goon
    "Goon_Blisters",            # blistered Goon
    "Goon_OldTown",             # Old Town Goon (big hammer)
    "Goon_OldTown_Gaas",        # Mutated Goon
    "Toad_Poison",              # poison Toad
    "Bomber_Poison",            # poison Bomber
    "GasTankGray",              # grey gas tank biter
    "Volatile_Super",           # blue super Volatile
    "ViralBurn_Man",            # burning viral
    "ViralPoison_Man",          # toxic viral
    "ViralBlister_Man"          # blistered viral
)
# Zombie Hunt event: "'Former' GRE Operatives", giant boss-flagged Demolisher (skin GRE).
# Its Goon (Goon_ZombieHunt) is left out: its AI data (thug_armed_hard_zombie_hunt) is filed under
# infected/ instead of zombie/ and never loads, so spawning it is a likely crash.
$GRE     = @("Demolisher_ZombieHunt")
$Bolters = @("Prime", "PrimeNight")
# The Following (humanai_dlc17.pre). Their AI data (*_wasteland_special/ultra) is only loaded on The
# Following's map: in Harran the game loads base data sets only (seen in a crash log), so a freak there gets
# no data. They go in the wasteland presets only.
$FreaksList = @(
    "Demolisher_WastelandSpecial", "Goon_WastelandSpecial", "Bolter_WastelandSpecial",
    "GasTank_WastelandSpecial", "Biter_WastelandSpecial", "Toad_WastelandSpecial"
)
$UltraList = @("Demolisher_WastelandUltra", "Demolisher_WastelandUltra_H", "Goon_WastelandUltra",
               "Biter_WastelandUltra", "Toad_WastelandUltra")
# Every Harran entry's model must be in common_meshes_PC.rpack: a missing one becomes nomesh.msh with no
# skeleton and crashes on the bone lookup (gamedll+0x622147). The big military viral's survivor_b.msh
# exists only in wasteland_PC.rpack.
$FollowingOnly = @()
if (-not $NoVariants) { $Specials += $Variants; $FollowingOnly += "Viral_Big_Humanity" }
if (-not $NoGRE)      { $Specials += $GRE }
if (-not $NoBolters)  { $Specials += $Bolters }
if ($Freaks -ne "None" -and (Test-Path (Join-Path $Game "DW_DLC17"))) {
    $FollowingOnly += $FreaksList
    if ($Freaks -eq "Ultra") { $FollowingOnly += $UltraList }
}
# The Mother: viral and Volatile fighting forms. mother.msh is in wasteland_PC.rpack (not Harran's archives); all her animation
# clips are in common_anims_PC.rpack and her AI data loads on The Following's map, so she goes in The Following's lists only.
if ($Mother -and (Test-Path (Join-Path $Game "DW_DLC17"))) { $FollowingOnly += "Viral_WL_Final_Fight_Hard", "SIR_Mother_Volatile" }
# -MotherInHarran: Harran's maps also load The Following's final-boss archive (wasteland_final_PC.rpack, ~430 MB), so its enemies fit
# there: the Mother, and The Following's human ghost. That archive has survivor_b.msh with only the Ghost_Follower skin's textures (the
# hallucination's followers), so the human ghost wears that skin as a SIR_ copy; with its own Ghost skin it's invisible.
# The ghosts stay out of The Following's lists, whose map doesn't load that archive.
# -FollowingArchive: Harran's maps also load The Following's main archive (wasteland_PC.rpack, 2.2 GB), which has the big military
# viral's real skin, so Viral_Big_Humanity spawns in Harran too.
$wfPack = Join-Path $Game "DW_DLC17\Data\wasteland_final_PC.rpack"
$fullPack = Join-Path $Game "DW_DLC17\Data\wasteland_PC.rpack"
if (($MotherInHarran -or $FollowingArchive) -and -not ((Test-Path $wfPack) -and (Test-Path $fullPack) -and (Test-Path (Join-Path $Game "DW_DLC17\DataDLC17_0.pak")))) {
    "Following enemies in Harran skipped: The Following isn't installed"; $MotherInHarran = $false; $FollowingArchive = $false
}
$GhostList = @("SIR_Ghost_Human")
$WfHarran = @()
if ($MotherInHarran) {
    if ($Mother) { $WfHarran += "Viral_WL_Final_Fight_Hard", "SIR_Mother_Volatile" }
    # Both archives hold survivor_b.msh and the main one wins (tested both orders): with it loaded the ghost gets the plain survivor look
    if ($FollowingArchive) { "Human ghost left out: it needs the final-boss archive's survivor body, and the big military viral option loads the main one" } else { $WfHarran += $GhostList }
}
if ($FollowingArchive) { $WfHarran += "Viral_Big_Humanity" }
$Specials += $WfHarran
# Harran's AI data loader reads data/ai/<type>/<type>_data_custom_preset_*.scr from the base paks only
# (Data0 + Data3), so -FreaksInHarran ships the freaks' data there. Only freaks whose models are in
# common_meshes_PC.rpack: not the zombie_man_b ones (Biter/GasTank freaks, Goliath) or Beelzebufo.
$HarranFreaks = @(
    "Demolisher_WastelandSpecial", "Goon_WastelandSpecial", "Bolter_WastelandSpecial", "Toad_WastelandSpecial",
    "Demolisher_WastelandUltra", "Demolisher_WastelandUltra_H", "Goon_WastelandUltra"
)
if ($FreaksInHarran -and -not (Test-Path (Join-Path $Game "DW_DLC17"))) {
    "Freaks of Nature in Harran skipped: it needs The Following DLC, which isn't installed"
    $FreaksInHarran = $false
}
if ($FreaksInHarran) {
    $Specials += $HarranFreaks
    if (-not $NoGRE) { $Specials += "Goon_ZombieHunt" }   # GRE Goon: a GRE operative, so -NoGRE drops it too
}

# Community event enemies, all in humanai.pre; their bodies use the event loot tables (special_event.loot).
# Tested in game: these spawn fine. Dropped: rust_scientist_melee (player_12_tpp body T-poses), and
# Viral_m_lvl2_winter (goblin), Volatile_Iced and Biter_m_lv2_liveops_christmas (didn't spawn or crashed).
$EventList = @(
    "rust_scientist_range",          # Rust rifleman: shows as a plain biter with a rifle ("zombie with gun")
    "astronaut_melee",               # low gravity: astronaut invader, melee
    "astronaut_range",               # low gravity: astronaut invader, rifle
    "Medieval_Armored"               # Chivalry: armoured knight with a long sword
)
if ($Events) { $Specials += $EventList }
if ($IcedBolter) { $Specials += "Prime_Winter" }   # winter: Iced Bolter (tested, spawns fine)

# crowd slots stay plain infected (a human or boss in the crowd system is untested)
$CrowdSpecials = @($Specials | Where-Object { $_ -notmatch 'Headhunter|bandit|Wasteland|ZombieHunt|Prime|Viral|Gaas|Tahir|Mother|Ghost' -and $EventList -notcontains $_ })

# Friendly NPCs, added after the crowd list so they never join a street crowd. All use survivor_a.msh and AI data that loads in Harran.
if ($Friendlies) { $Specials += "enc_looting_proplayer", "enc_story_teller_SurvivorEnc01", "enc_story_teller_SurvivorEnc02", "enc_story_teller_SurvivorEnc03", "enc_survivor_escort_Ahmet", "enc_survivor_escort_Babar", "enc_survivor_escort_Faruk", "Brecken_Soldier_001", "Dahlia_Bodyguard", "Jade_Museum" }

# Individually switched-off enemies (menu sub-window)
# Hellraid (tested in Slums: skeletons, fire adept, Dark Knight, Minotaur). The Blinded is left out: zombie-type enemies take
# their animations from AI data that Harran only reads precompiled, and the DLC has none, so it T-poses.
$HellraidList = @("HR_Skeletor_l1", "HR_Skeletor_Order_l2", "HR_Skeletor_l3", "HR_Adept_Fire_lvl0", "HR_Adept_Energy_lvl0", "HR_Adept_Poison_lvl0", "HR_Darkknight", "HR_Minotaur")
$hrPak = Join-Path $Game "DW_DLC49\DataDLC49_0.pak"
if ($Hellraid -and -not ((Test-Path $hrPak) -and (Test-Path (Join-Path $Game "DW_DLC49\Data\hellraid_PC.rpack")))) { "Hellraid enemies skipped: the Hellraid DLC isn't installed"; $Hellraid = $false }
if ($Hellraid) { $Specials += $HellraidList }
$dlc2 = Join-Path $Game "DW_DLC17\DataDLC17_2.pak"
if ($HellraidFollowing -and -not ($Hellraid -and -not $NoFollowing -and (Test-Path $dlc2))) { $HellraidFollowing = $false }
$HrOut = if ($HellraidFollowing) { @() } else { $HellraidList }   # Hellraid names kept out of The Following's lists

$Off = @($Exclude -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Off) {
    $Specials      = @($Specials | Where-Object { $Off -notcontains $_ })
    $FollowingOnly = @($FollowingOnly | Where-Object { $Off -notcontains $_ })
    $kept = @($CrowdSpecials | Where-Object { $Off -notcontains $_ })
    if ($kept) { $CrowdSpecials = $kept }   # all crowd-safe specials off: "Random special" still rolls from the full set
    if (-not $NoSpawns -and -not $Specials) { throw "Every Harran enemy is switched off. Turn at least one back on, or untick 'Randomise noise / viral spawns'." }
    "Left out: " + ($Off -join ", ")
}
$WfUsed = @($WfHarran | Where-Object { $Specials -contains $_ })   # Following enemies left in Harran's lists after -Exclude
$SpecialsFollowing = (@($Specials + $FollowingOnly) | Where-Object { $HrOut -notcontains $_ -and $GhostList -notcontains $_ } | Select-Object -Unique) -join ";"   # The Following can't load Hellraid's archive
$Specials = $Specials -join ";"

# The Following also loads some of Harran's spawn presets (named in its own spawn files, and in the base files
# common_area_pools_and_curves.scr and btz_spawn.scr that it includes). It can't load Hellraid's models, so those
# shared presets get Harran's list without Hellraid. Harran's other presets keep Hellraid.
$SharedPresets = @{}
$SpecialsShared = (@($Specials -split ';' | Where-Object { $_ -and $HrOut -notcontains $_ -and $GhostList -notcontains $_ })) -join ";"
$ghostsOn = @($Specials -split ';' | Where-Object { $GhostList -contains $_ }).Count -gt 0   # the ghosts need the final-boss archive, which The Following's map doesn't load
if ((($Hellraid -and -not $HellraidFollowing) -or $ghostsOn) -and (Test-Path (Join-Path $Game "DW_DLC17\DataDLC17_2.pak"))) {
    $refRx = '(?<![A-Za-z])(Preset|RelativePresets|NoZombiesByPresets)\("([^"]*)"'
    $readAll = { param($pakPath, $filter) $zz = [IO.Compression.ZipFile]::OpenRead($pakPath); $txt = foreach ($e in $zz.Entries) { if (& $filter $e) { $r = New-Object IO.StreamReader($e.Open()); $r.ReadToEnd(); $r.Close() } }; $zz.Dispose(); $txt -join "`n" }
    $folText = & $readAll (Join-Path $Game "DW_DLC17\DataDLC17_2.pak") { param($e) $e.FullName -like "data/maps/wasteland*" -and $e.Name -like "*.scr" }
    $folText += "`n" + (& $readAll (Join-Path $Game "DW\Data0.pak") { param($e) $e.FullName -in "data/scripts/common_area_pools_and_curves.scr", "data/scripts/nightaggression/btz_spawn.scr" })
    $harranText = & $readAll (Join-Path $Game "DW\Data0.pak") { param($e) $e.FullName -in "data/scripts/common_spawn_presets.scr", "data/scripts/nightaggression/night_spawn_presets.scr" }
    # Harran's preset blocks, so presets they point at (RelativePresets etc.) count as shared too
    $blocks = @{}; $parts = [regex]::Split($harranText, '(?=^\s*PresetDef\()', [Text.RegularExpressions.RegexOptions]::Multiline)
    foreach ($b in $parts) { $m = [regex]::Match($b, '^\s*PresetDef\("([^"]+)"\)'); if ($m.Success) { $blocks[$m.Groups[1].Value] = $b } }
    $queue = New-Object Collections.Queue
    foreach ($m in [regex]::Matches($folText, $refRx)) { foreach ($n in ($m.Groups[2].Value -split ';')) { $n = ($n -split ',')[0].Trim(); if ($blocks.ContainsKey($n) -and -not $SharedPresets.ContainsKey($n)) { $SharedPresets[$n] = $true; $queue.Enqueue($n) } } }
    while ($queue.Count) { $n = $queue.Dequeue(); foreach ($m in [regex]::Matches($blocks[$n], $refRx)) { foreach ($x in ($m.Groups[2].Value -split ';')) { $x = ($x -split ',')[0].Trim(); if ($blocks.ContainsKey($x) -and -not $SharedPresets.ContainsKey($x)) { $SharedPresets[$x] = $true; $queue.Enqueue($x) } } } }
    "{0}: kept out of {1} Harran spawn presets that The Following also uses" -f (@(@("Hellraid", "ghosts") | Where-Object { ($_ -eq "Hellraid" -and $Hellraid -and -not $HellraidFollowing) -or ($_ -eq "ghosts" -and $ghostsOn) }) -join " and "), $SharedPresets.Count
}

$Replace = '^(Biter\w*|NightWalker_\w+)$'
# Virals (incl. the ones loud noises call in); HumanToViralTransformation is left alone
if (-not $NoVirals) { $Replace = '^(Biter\w*|NightWalker_\w+|ViralHumanity_\w+|Viral_(Man|Woman))$' }

# Spawn tricks that play biter/viral-only animations (lying dead, eating, climbing
# out of the ground). Special infected have no such anims and stay in T-pose.
$BiterOnlyFields = '^\s*(DiffLvlTableName|SetDeadBody|AttractorToSpawnWithAI|MeshToSpawnWithAI|CanSpawnInAttractor|SarcophagusTime)\('

function Convert-Presets([string]$text, [string]$list = $Specials, [hashtable]$shared = @{}, [string]$sharedList = "") {
    $cur = ""
    $out = New-Object System.Text.StringBuilder
    $inBlock = $false
    foreach ($line in $text -split "\r?\n") {
        if ($line -match '^\s*PresetDef\("([^"]*)"') { $inBlock = $false; $cur = $Matches[1] }
        if ($line -match '^(\s*)AIPreset\("([^"]*)"\)') {
            $indent = $Matches[1]; $was = $Matches[2]
            $names = $was.Split(";") | Where-Object { $_ }
            $use = if ($shared.ContainsKey($cur)) { $sharedList } else { $list }
            # an empty list would make the game pick from nothing (divide by zero crash), so such presets stay vanilla
            if ($use -and $names -and -not ($names | Where-Object { $_ -notmatch $Replace })) {
                $line = "${indent}AIPreset(`"$use`") // was: $was"
                $inBlock = $true
            }
        }
        if ($inBlock -and $line -match $BiterOnlyFields) { $line = "//" + $line }
        [void]$out.Append($line).Append("`r`n")
    }
    Convert-InitSpots ($out.ToString().TrimEnd() + "`r`n")
}

# t_INIT spots play a biter/viral entry anim (crawl out from under a car or bus, window, vent);
# specials have none and T-pose. Replaced presets that want those spots get the plain
# ground-spot rule the vanilla scream/noise viral preset uses instead.
$NoInitSpots = "nav_mesh, -1;__any__, 1;t_INIT, -1;p_ROOF, -1"
function Convert-InitSpots([string]$text) {
    [regex]::Replace($text, '(?s)PresetDef\(.*?(?=PresetDef\(|\z)', {
        param($m)
        $b = $m.Value
        if ($b -notmatch 'AIPreset\("[^"]*"\) // was: ') { return $b }
        [regex]::Replace($b, '(?m)^(\s*)SpawnCondition\("([^"]*\bt_INIT,\s*0*\.?[1-9][^"]*)"\)', {
            param($s) "$($s.Groups[1].Value)SpawnCondition(`"$NoInitSpots`") // was: $($s.Groups[2].Value)"
        })
    })
}

function Convert-Crowd([string]$text) {
    if ($CrowdMode -eq "Many") { return Convert-CrowdMany $text }
    $out = New-Object System.Text.StringBuilder
    $rolls = @(Get-Random -InputObject $CrowdSpecials -Count $CrowdSpecials.Count)   # shuffled, no repeats
    $virals = @("Man", "Woman")   # slot 0 is the male biter, slot 1 the female
    $slot = 0
    foreach ($line in $text -split "\r?\n") {
        if ($line -match '^(\s*)AIPreset\("([^"]*)"\)') {
            $indent = $Matches[1]; $was = $Matches[2]
            $sex = $virals[$slot % 2]
            # per-slot kind: Custom takes the slot's choice, the other modes map onto the same kinds
            $kind = switch ($CrowdMode) {
                "Custom" { @($Crowd1, $Crowd2)[$slot % 2] }
                "Virals" { "Viral" }
                "L4D"    { "L4D" }
                "Rais"   { @("enc_slums_maskedbandit_lvl02", "enc_slums_maskedbanditrifle_lvl02")[$slot % 2] }
                "List"   { $Specials }
                default  { "Random" }
            }
            $pick = switch ($kind) {
                "Vanilla" { $was }
                "L4D"     { "NightWalker_${sex}_L4D" }
                "Viral"   { "ViralHumanity_$sex" }
                "Random"  { $rolls[$slot % $rolls.Count] }
                default   { $kind }
            }
            $slot++
            $line = "${indent}AIPreset(`"$pick`") // was: $was"
        }
        if ($line -match '^(\s*)DiffLevelTab\(') {
            # virals keep their own level tables (as vanilla viral spawns do), L4D runners the night-walker
            # tables their presets are built on, vanilla biters theirs; others use base stats. In The
            # Following's crowd (Biter_*_Wast tables) virals take its Viral_*_Wast tables; there's no night-walker one.
            $ind  = $Matches[1]
            $wast = if ($line.Contains('_Wast"')) { "_Wast" } else { "" }
            $line = switch ($kind) {
                "Vanilla" { $line }
                "Viral"   { "${ind}DiffLevelTab(`"Viral_$sex$wast`")" }
                "L4D"     { "${ind}DiffLevelTab(`"NightWalker_$sex`")" }
                default   { "//" + $line }
            }
        }
        [void]$out.Append($line).Append("`r`n")
    }
    $out.ToString().TrimEnd() + "`r`n"
}

# One crowd slot per special, copied from the vanilla man/woman slots (their distant
# biter meshes and anims stay; the zombie becomes the special up close).
function Convert-CrowdMany([string]$text) {
    $blocks = [regex]::Matches($text, '(?s)CrowdPresetDef\(\d+\)\s*\{.*?\r?\n\}')
    $rest = [regex]::Replace($text, '(?s)CrowdPresetDef\(\d+\)\s*\{.*?\r?\n\}\s*', '')
    $out = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $CrowdSpecials.Count; $i++) {
        $b = $blocks[$i % $blocks.Count].Value
        $b = $b -replace 'CrowdPresetDef\(\d+\)', "CrowdPresetDef($i)"
        $b = $b -replace 'AIPreset\("([^"]*)"\)', "AIPreset(`"$($CrowdSpecials[$i])`") // was: `$1"
        $b = $b -replace '(?m)^(\s*DiffLevelTab\()', '//$1'
        [void]$out.Append($b).Append("`r`n`r`n")
    }
    ($out.ToString() + $rest.Trim()) -replace '\r?\n', "`r`n"
}

# Loot. Containers that keep vanilla loot: events, escorts/challenges, Bozak horde, harvesting and
# gathering spots, buggy parts, and The Following's containers in default.loot (their sets hold
# Following items).
$LootKeep   = 'Liveops|Christmas|Halloween|Bozak|Escort|Challenge|WhiteNoise|Iced|SmashedHead|Harvesting|ToxicPlant|Lichen|Shroom|Underwater|Algae|^"?Fuel|PartsComponents|Parts_Chest|Buggy|Following|Military|_wast|Gaas'
# Sets that are never moved or pooled: empty rolls and quest items stay in their own container
$LootFixed  = '^(Empty|QuestItems_\w+)$'
# Vanilla containers list at most 11 sets; all 61 per container crashed the game at the main menu
$ChaosSets  = 8
$Inv = [Globalization.CultureInfo]::InvariantCulture
function Convert-Loot([string]$text) {
    $rx = '(?s)(LootedObject\(([^)]*)\)\s*\{)(.*?)(\r?\n\s*\})'
    $mine = @([regex]::Matches($text, $rx) | Where-Object { $_.Groups[2].Value -notmatch $LootKeep })
    $lines = { param($body) $body -split "\r?\n" | Where-Object { $_.Trim() } }
    $isFixed = { param($l) $l -match "use (\w+)\(" -and $Matches[1] -match $LootFixed }
    $pool = @($mine | ForEach-Object { [regex]::Matches($_.Groups[3].Value, 'use (\w+)\(') | ForEach-Object { $_.Groups[1].Value } } |
        Where-Object { $_ -notmatch $LootFixed } | Sort-Object -Unique)
    # Shuffle: block i gets donor block order[i]'s ColorSet and non-fixed uses
    $order = @(Get-Random -InputObject (0..($mine.Count - 1)) -Count $mine.Count)
    $new = @{}
    for ($i = 0; $i -lt $mine.Count; $i++) {
        $own = & $lines $mine[$i].Groups[3].Value
        $keep = @($own | Where-Object { & $isFixed $_ })
        if ($Loot -eq "Shuffle") {
            $donor = & $lines $mine[$order[$i]].Groups[3].Value
            $body = @($donor | Where-Object { -not (& $isFixed $_) }) + $keep
        } else {
            $sum = 0.0
            foreach ($l in $own) { if (-not (& $isFixed $l) -and $l -match 'weight\s*=\s*([\d.]+)') { $sum += [double]::Parse($Matches[1], $Inv) } }
            if ($sum -le 0) { continue }
            $picks = @(Get-Random -InputObject $pool -Count ([Math]::Min($ChaosSets, $pool.Count)))
            $w = ($sum / $picks.Count).ToString("0.####", $Inv)
            $body = @($own | Where-Object { $_ -match 'ColorSet\(' }) + $keep + @($picks | ForEach-Object { "use $_(weight = $w);" })
        }
        $new[$mine[$i].Index] = $mine[$i].Groups[1].Value + "`r`n" + (($body | ForEach-Object { "        " + $_.Trim() }) -join "`r`n") + $mine[$i].Groups[4].Value
    }
    $script:LootCount = $new.Count
    [regex]::Replace($text, $rx, { param($m) if ($new.ContainsKey($m.Index)) { $new[$m.Index] } else { $m.Value } })
}

# Shops. Stock lists that keep vanilla items: Quartermaster/progression gear (grappling hook, UV light,
# shield, Following buggy parts), promotions, escorts, legendary/unique tiers, event and DLC items.
$ShopKeep = 'Quatermaster|Quartermaster|SalesPromotion|ItemOf|Highway|SafeZone|Escort|Legendary|Unique|Platinum|Liveops|^Hr_|Gaas|AddOn|unlocker|Valentine|Baseball|Spike|Jewels|Grappling|UVEmitter|Shields|Flashlight|Lockpick|^Bow$|^Arrows'
function Get-ShopKind([string]$name) {
    switch -regex ($name) {
        'Upgrade'                 { "upgrade"; break }
        'Craftplan|Blueprint'     { "blueprint"; break }
        '^Melee|^Mechetes$'       { "melee"; break }
        '^Firearm'                { "firearm"; break }
        '^Throw'                  { "throwable"; break }
        'Ammo'                    { "ammo"; break }
        '^Medkit|Potion'          { "healing"; break }
        '^Craft|Craftparts'       { "crafting"; break }
    }
}
# Quartermaster sets that never change (quest/progression gear; Level_8_other is the grappling hook)
$QMKeep = 'Grappling|UVFlashlight|Shield|_Bow|Arrows|Level_8_other'
function Convert-Shops([string]$text) {
    $rx = '(?s)(ItemSet\("([^"]+)"\)[^{]*\{)(.*?)(\})'
    $pools = @{}; $sets = @()
    $add = { param($key, $body) if (-not $pools[$key]) { $pools[$key] = New-Object System.Collections.Generic.HashSet[string] }
             foreach ($it in [regex]::Matches($body, 'Item\("([^"]+)"')) { [void]$pools[$key].Add($it.Groups[1].Value) } }
    foreach ($m in [regex]::Matches($text, $rx)) {
        $name = $m.Groups[2].Value
        if ($name -match '^Qua') {
            if ($Quartermaster -eq "Off" -or $name -match $QMKeep) { continue }
            $key = if ($name -match 'Components|Screws|Parts|Bolts|Mines') { "qm/Following" } else { "qm/Harran" }
            & $add $key $m.Groups[3].Value; $sets += , @($m.Index, $key); continue
        }
        $kind = Get-ShopKind $name
        if (-not $kind -or $name -match $ShopKeep) { continue }
        $key = $kind + $(if ($name -match 'Wasteland|Following') { "/Following" } else { "/Harran" })
        & $add $key $m.Groups[3].Value
        if ($Shops -eq "Random") { $sets += , @($m.Index, $key) }
    }
    # the Harran Quartermaster can stock anything Harran's shops sell
    if ($pools["qm/Harran"]) { foreach ($k in @($pools.Keys)) { if ($k -like "*/Harran" -and $k -ne "qm/Harran") { $pools["qm/Harran"].UnionWith($pools[$k]) } } }
    $keyAt = @{}; foreach ($s in $sets) { $keyAt[$s[0]] = $s[1] }
    $script:ShopCount = $sets.Count
    [regex]::Replace($text, $rx, {
        param($m)
        if (-not $keyAt.ContainsKey($m.Index)) { return $m.Value }
        $pool = @($pools[$keyAt[$m.Index]])
        $n = ([regex]::Matches($m.Groups[3].Value, 'Item\(')).Count
        $picks = @(Get-Random -InputObject $pool -Count ([Math]::Min($n, $pool.Count)))
        $m.Groups[1].Value + "`r`n" + (($picks | ForEach-Object { "        Item(`"$_`");" }) -join "`r`n") + "`r`n    " + $m.Groups[4].Value
    })
}

# Tiers. Same shuffle for a set in all three difficulty subs. Single-colour, part, prison and event
# sets keep their colours. Platinum odds are never touched.
$TierColors = "White", "Green", "Blue", "Violet", "Orange"
$TierCrates = '^(WeaponChest\w*|Cont_Lockpick|Lockpick\d|ValuableChest|Valuables_Chest|AirDrop|cs_encounter_chest|cs_airrdrop_bundles)$'
$TierKeep   = 'Only|^Tier\d|Parts_|Components|Platinum|Liveops|Prison|Iced|cs_drp|cs_prime'
function Convert-Tiers([string]$text) {
    $perm = @{}
    $rx = 'ColorWeight\(Color_(White|Green|Blue|Violet|Orange),\s*([\d.]+)\)'
    $out = [regex]::Replace($text, '(?s)DefColorSet\(ColorSet_(\w+)\)\s*\{.*?\}', {
        param($m)
        $name = $m.Groups[1].Value
        $ok = if ($Tiers -eq "Crates") { $name -match $TierCrates } else { $name -notmatch $TierKeep -or $name -match $TierCrates }
        $cw = [regex]::Matches($m.Value, $rx)
        if (-not $ok -or $cw.Count -ne 5) { return $m.Value }
        if (-not $perm.ContainsKey($name)) { $perm[$name] = @(Get-Random -InputObject (0..4) -Count 5) }
        $vals = @{}; foreach ($c in $cw) { $vals[$c.Groups[1].Value] = $c.Groups[2].Value }
        $p = $perm[$name]
        [regex]::Replace($m.Value, $rx, { param($c) "ColorWeight(Color_$($c.Groups[1].Value), $($vals[$TierColors[$p[$TierColors.IndexOf($c.Groups[1].Value)]]]))" })
    })
    $script:TierCount = $perm.Count
    $out
}

# Quantity. Only stackable item families get counts; everything else stays a single item.
$Stackable = '^(z+_)?(Craft_|Ammo_|misc_|Cons_|Medkit_|Throwable_|LockpickItem|FuelBottle|Cash_)'
function Convert-Quantity([string]$text) {
    $script:QtyCount = 0
    $text = [regex]::Replace($text, 'ItemCount\("([^"]+)",\s*(\d+),\s*(\d+),\s*([\d.]+)\)', {
        param($m)
        $lo = [Math]::Max(1, [int][Math]::Floor([int]$m.Groups[2].Value / 2))
        $hi = [Math]::Max($lo + 1, [int][Math]::Ceiling([int]$m.Groups[3].Value * (Get-Random -Minimum 1.0 -Maximum 3.0)))
        $script:QtyCount++
        "ItemCount(`"$($m.Groups[1].Value)`", $lo, $hi, $($m.Groups[4].Value))"
    })
    [regex]::Replace($text, '\bItem\("([^"]+)",\s*([\d.]+)\)', {
        param($m)
        if ($m.Groups[1].Value -notmatch $Stackable) { return $m.Value }
        $script:QtyCount++
        "ItemCount(`"$($m.Groups[1].Value)`", 1, $(Get-Random -Minimum 2 -Maximum 5), $($m.Groups[2].Value))"
    })
}

# pak (relative to the game folder) => scripts in it to patch
$sources = [ordered]@{ "DW\Data0.pak" = @(); "DW_DLC17\DataDLC17_2.pak" = @() }
if (-not $NoSpawns) {
    $sources["DW\Data0.pak"] += "data/scripts/common_spawn_presets.scr"
    # The Following: converted here, but delivered through shared base files (Add-FollowingOverrides)
    if (-not $NoFollowing) { $sources["DW_DLC17\DataDLC17_2.pak"] += "data/maps/wasteland/wasteland_presets.scr" }
    if (-not $DayOnly) { $sources["DW\Data0.pak"] += "data/scripts/nightaggression/night_spawn_presets.scr" }
}
if ($CrowdMode -ne "Off") { $sources["DW\Data0.pak"] += "data/scripts/common_crowd.scr" }
if ($Loot -ne "Off")  {
    $sources["DW\Data0.pak"] += "data/scripts/inventory/default.loot"
    if (-not $NoFollowing) { $sources["DW\Data0.pak"] += "data/scripts/inventory/wasteland.loot" }   # The Following's loot
}
if ($Shops -ne "Off" -or $Quartermaster -ne "Off") { $sources["DW\Data0.pak"] += "data/scripts/trading/shop_item_sets.scr" }
if ($Tiers -ne "Off") { $sources["DW\Data0.pak"] += "data/scripts/inventory/color_sets.loot" }
if ($Quantity -ne "Off") { $sources["DW\Data0.pak"] += "data/scripts/inventory/item_sets.loot" }

$patched = @{}
foreach ($pak in $sources.Keys) {
    $pakPath = Join-Path $Game $pak
    if (-not $sources[$pak]) { continue }
    if (-not (Test-Path $pakPath)) { "skipping $pak (not installed)"; continue }
    $src = [IO.Compression.ZipFile]::OpenRead($pakPath)
    foreach ($f in $sources[$pak]) {
        $e = $src.GetEntry($f); if (-not $e) { throw "$f not found in $pak" }
        $r = New-Object IO.StreamReader($e.Open()); $t = $r.ReadToEnd(); $r.Close()
        if ($f -like "*color_sets.loot") { $patched[$f] = Convert-Tiers $t; "{0}: {1} colour sets shuffled ({2})" -f $f, $TierCount, $Tiers; continue }
        if ($f -like "*item_sets.loot") { $patched[$f] = Convert-Quantity $t; "{0}: {1} item counts randomised" -f $f, $QtyCount; continue }
        if ($f -like "*.loot") { $patched[$f] = Convert-Loot $t; "{0}: {1} containers {2}" -f $f, $LootCount, $Loot.ToLower(); continue }
        if ($f -like "*shop_item_sets.scr") { $patched[$f] = Convert-Shops $t; "{0}: {1} stock lists randomised" -f $f, $ShopCount; continue }
        $new = if ($f -like "*common_crowd.scr") { Convert-Crowd $t }
               elseif ($f -like "data/maps/wasteland/*") { Convert-Presets $t $SpecialsFollowing }
               else { Convert-Presets $t $Specials $SharedPresets $SpecialsShared }
        $n = ([regex]::Matches($new, 'AIPreset\("[^"]*"\) // was: ')).Count
        $i = ([regex]::Matches($new, 'SpawnCondition\("[^"]*"\) // was: ')).Count
        "{0}: {1} presets replaced, {2} moved off init spots" -f $f, $n, $i
        $patched[$f] = $new
    }
    $src.Dispose()
}

# The Following. Its map files live in DataDLC17_2.pak, which outranks Data3 and DataDLC17_1 (a patched
# wasteland_presets.scr in either pak left it vanilla). Data3 IS read on its map (the GRE Goon set that only loads
# through our Data3 .scr loads there, 2026-11-04 15:15 log), and wasteland_spawn.scr includes the base
# common_area_pools_and_curves.scr after its pools, curves and crowd - so overrides go at the end of that file.
# - Crowd (works): Harran's randomised CrowdPresetDef(0/1) (zombie_man_a / zombie_woman, which The Following
#   has). Last definition wins; in Harran it's an identical repeat of common_crowd.scr.
# - Spawns: appending the randomised PresetDefs under their own names (after AND before The Following's)
#   and the virals stayed vanilla: pools bind preset names when the pool is declared, to the definition current
#   then (The Following's). So this adds renamed copies (SIR_<name>, randomised, plus every preset they reference)
#   and re-declares The Following's pools that use them, same name and type, pointing at the copies. Curves pick
#   pools by type while they run (PoolType is a step in the curve), and the crowd showed a later same-name
#   definition wins. Harran: no pool/area pool of these names, and no Harran curve asks for these types (night,
#   which both maps use, is left out), so the extra pools never run there.
function Add-FollowingOverrides {
    $wp = $patched["data/maps/wasteland/wasteland_presets.scr"]; $patched.Remove("data/maps/wasteland/wasteland_presets.scr")
    $d0 = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak"))
    $area = "data/scripts/common_area_pools_and_curves.scr"
    $areaText = ReadEntry $d0 $area
    $harranPools = [regex]::Matches((ReadEntry $d0 "data/scripts/common_spawn_pools.scr") + $areaText, '\b(?:Area)?Pool\("([^"]+)"\)') | ForEach-Object { $_.Groups[1].Value }
    $d0.Dispose()
    $add = ""
    if ($wp) {
        $dlc = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW_DLC17\DataDLC17_2.pak"))
        $poolText = ReadEntry $dlc "data/maps/wasteland/wasteland_pools.scr"; $dlc.Dispose()
        $blocks = Get-ScriptBlocks $wp 'PresetDef'
        $pools  = Get-ScriptBlocks $poolText '(?:Area)?Pool'
        # spawn-preset references: Preset("A, 40;B, 60"), RelativePresets("A;B"), NoZombiesByPresets("A, 100;", ..)
        # - not AIPreset("..."), which lists enemies
        $refRx = '(?<![A-Za-z])(Preset|RelativePresets|NoZombiesByPresets)\("([^"]*)"'
        $refs = { param($b) [regex]::Matches($b, $refRx) | ForEach-Object { $_.Groups[2].Value -split ';' } |
                  ForEach-Object { ($_ -split ',')[0].Trim() } | Where-Object { $_ -and $blocks.Contains($_) } }
        $randomised = @($blocks.Keys | Where-Object { $blocks[$_] -match '// was: ' })
        # pools to re-declare: use a randomised preset, aren't night pools, don't share a name with a Harran pool;
        # then any other such pool that refers to the same presets (day_after_pursuit counts pursuit zombies by name)
        $redo = @($pools.Keys | Where-Object { $p = $pools[$_]; $p -notmatch 'Type\("[^"]*night' -and $harranPools -notcontains $_ -and @(& $refs $p | Where-Object { $randomised -contains $_ }).Count })
        $copy = @($redo | ForEach-Object { & $refs $pools[$_] } | Select-Object -Unique)
        $more = @($pools.Keys | Where-Object { $redo -notcontains $_ -and $harranPools -notcontains $_ -and $pools[$_] -notmatch 'Type\("[^"]*night' -and @(& $refs $pools[$_] | Where-Object { $copy -contains $_ }).Count })
        $redo += $more
        for ($i = 0; $i -lt $copy.Count; $i++) { foreach ($n in & $refs $blocks[$copy[$i]]) { if ($copy -notcontains $n) { $copy += $n } } }
        # rename copied presets in PresetDef("x") and in the reference calls above, nowhere else
        $renameList = { param($list) (($list -split ';') | ForEach-Object {
            $parts = $_ -split ',', 2; $n = $parts[0].Trim()
            if ($n -and $copy -contains $n) { $parts[0] = $parts[0].Replace($n, "SIR_$n") }; $parts -join ',' }) -join ';' }
        $rename = { param($t)
            $t = [regex]::Replace($t, '^(\s*PresetDef\(")([^"]+)"', { param($m) $m.Groups[1].Value + $(if ($copy -contains $m.Groups[2].Value) { "SIR_" }) + $m.Groups[2].Value + '"' })
            [regex]::Replace($t, $refRx, { param($m) $m.Groups[1].Value + '("' + (& $renameList $m.Groups[2].Value) + '"' }) }
        $text = "`r`n`r`n// ---- The Following's spawns (Randomiser mod): renamed preset copies + its pools re-declared ----`r`n"
        $text += ($copy | ForEach-Object { & $rename $blocks[$_] }) -join "`r`n"
        $text += "`r`n" + (($redo | ForEach-Object { & $rename $pools[$_] }) -join "`r`n") + "`r`n"
        $add += $text -replace '\r?\n', "`r`n"
        "The Following: {0} pools re-declared ({1}) with {2} renamed presets in common_area_pools_and_curves.scr" -f $redo.Count, ($redo -join ", "), $copy.Count
    }
    if ($patched["data/scripts/common_crowd.scr"]) {
        $crowd = ([regex]::Matches($patched["data/scripts/common_crowd.scr"], '(?s)CrowdPresetDef\(\d+\)\s*\{.*?\r?\n\}') | ForEach-Object { $_.Value }) -join "`r`n`r`n"
        $add += "`r`n`r`n// ---- The Following's crowd = Harran's (Randomiser mod) ----`r`n" + $crowd + "`r`n"
        "The Following: crowd added to common_area_pools_and_curves.scr"
    }
    if ($add) { $patched[$area] = $areaText.TrimEnd() + $add }
}

# name => full text of each top-level `Kind("name") { ... }` block (braces counted, so nested blocks are fine)
function Get-ScriptBlocks([string]$text, [string]$kind) {
    $out = [ordered]@{}
    foreach ($m in [regex]::Matches($text, "(?m)^[ \t]*$kind\(`"([^`"]+)`"\)")) {
        $i = $text.IndexOf("{", $m.Index + $m.Length); if ($i -lt 0) { continue }
        $depth = 0; $j = $i
        for (; $j -lt $text.Length; $j++) { if ($text[$j] -eq '{') { $depth++ } elseif ($text[$j] -eq '}') { if (--$depth -eq 0) { break } } }
        $out[$m.Groups[1].Value] = $text.Substring($m.Index, $j - $m.Index + 1)
    }
    $out
}

function ReadEntry($zip, [string]$name) {
    $e = $zip.GetEntry($name); if (-not $e) { return $null }
    $r = New-Object IO.StreamReader($e.Open()); $t = $r.ReadToEnd(); $r.Close(); $t
}

# Copy every AI file the named presets use (custom data, knowledge base, goal rules, modules) from a DLC pak
# to the same path in Data3.pak, plus the DLC-only files they !include. Used by -FreaksInHarran (DLC17).
# LIMIT: Harran loads custom data presets from precompiled .dat files (Data0 has a
# .dat for each of its 192), and a .scr only counts when Data0 already has its .dat - so these custom data
# copies never load (no wasteland_special/undead set in any Harran log). Knowledge bases, goal rules and
# modules are .scr-only in Data0, so those copies may be read. The enemies run on their type's default data.
function Copy-AiData([string]$dlcPak, [string]$preFile, [string[]]$presets) {
    $d0  = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak"))
    $dlc = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game $dlcPak))
    $inBase = @{}; foreach ($e in $d0.Entries) { $inBase[$e.FullName.ToLower()] = 1 }
    $dlcAi = $dlc.Entries | Where-Object { $_.FullName -match '^data/ai/.+\.scr$' } | ForEach-Object { $_.FullName }
    $pre = ReadEntry $dlc $preFile
    $queue = New-Object System.Collections.Generic.Queue[string]
    foreach ($n in $presets) {
        $i = $pre.IndexOf("Preset(`"$n`")"); if ($i -lt 0) { throw "$n not found in $preFile" }
        $b = $pre.Substring($i, $pre.IndexOf("}", $i) - $i)
        foreach ($k in "m_CustomDataPreset", "m_KnowledgeBasePreset", "m_MainGoalRulesPreset", "m_ModulesPreset") {
            $v = ([regex]::Match($b, "$k`",\s*`"([^`"]+)`"")).Groups[1].Value; if (-not $v) { continue }
            $pat = "^data/ai/[^/]+/[^/]+_(data_custom_preset|knowledge_base|goal_rules|modules_preset)_$([regex]::Escape($v))\.scr$"
            $dlcAi | Where-Object { $_ -match $pat -and -not $inBase[$_.ToLower()] } | ForEach-Object { $queue.Enqueue($_) }
        }
    }
    $copied = @()
    while ($queue.Count) {
        $f = $queue.Dequeue(); if ($patched.ContainsKey($f)) { continue }
        $patched[$f] = ReadEntry $dlc $f; $copied += $f
        foreach ($m in [regex]::Matches($patched[$f], '!include\("([^"]+)"\)')) {
            $inc = (Split-Path $f -Parent).Replace('\', '/') + "/" + $m.Groups[1].Value
            if (-not $inBase[$inc.ToLower()] -and ($dlcAi -contains $inc)) { $queue.Enqueue($inc) }
        }
    }
    $d0.Dispose(); $dlc.Dispose()
    "AI data copied from ${dlcPak}: " + (($copied | ForEach-Object { Split-Path $_ -Leaf } | Sort-Object) -join ", ")
}

if ($FreaksInHarran) {
    Copy-AiData "DW_DLC17\DataDLC17_0.pak" "data/presets/humanai_dlc17.pre" $HarranFreaks    
    # Freaks' real AI data for Harran. Harran reads AI data only in precompiled .dat form, and The Following ships its Freaks'
    # data as text, so in Harran they used default behaviour. Each Freak's data is a base-game preset plus a few changes; the
    # changes below (parameter values by id, added animations, added curves) were compiled from The Following's scripts and
    # are applied to the base preset's .dat from this install. Tested in game (Behemoths now at their proper size).
    $FreakAiDelta = [ordered]@{
        'infected_data_custom_preset_armored_hard_wasteland_special' = @{ Base = 'infected_data_custom_preset_armored'
            Params = '3:2:0000b443;47:2:00002041;53:2:66662640;76:2:0000003f;77:2:0080bb44;113:2:00004040;122:2:00007a44;348:3:00;409:1:06000000;410:1:0a000000;540:3:00;580:2:c3f5a83e;641:2:0000c03f;642:2:0000e03f;643:2:00000040;694:2:3333733f;696:2:3333733f'
            Data = ''
            Curves = '' }
        'infected_data_custom_preset_armored_hard_wasteland_ultra' = @{ Base = 'infected_data_custom_preset_armored'
            Params = '3:2:0000b443;47:2:00002041;53:2:66662640;76:2:00000040;77:2:0080bb44;113:2:0000a040;122:2:00401c46;302:2:0000803f;407:4:14005468726f7761626c655f526f636b5f4865617679;409:1:01000000;540:3:00;580:2:c3f5a83e;641:2:0000c03f;642:2:0000e03f;643:2:00000040;694:2:9a99593f;732:3:01'
            Data = ''
            Curves = '' }
        'zombie_data_custom_preset_thug_armed_hard_wasteland_special' = @{ Base = 'zombie_data_custom_preset_thug_armed_medium'
            Params = '3:2:00002042;113:2:0000c841;120:2:00004040;122:2:00007a44;224:2:0000b443;225:2:0000b443;326:2:00000442;521:2:0000003f;524:2:0000003f;540:3:00;641:2:0000c03f;642:2:0000e03f;643:2:00000040'
            Data = ''
            Curves = '' }
        'zombie_data_custom_preset_thug_armed_hard_wasteland_ultra' = @{ Base = 'zombie_data_custom_preset_thug_armed_medium'
            Params = '3:2:00002042;106:2:0000803f;113:2:0000c842;120:2:0000c040;122:2:0060ea45;224:2:0000b443;225:2:0000b443;326:2:00000442;521:2:0000003f;524:2:cdcc4c3f;540:3:00;641:2:0000c03f;642:2:0000e03f;643:2:00000040;694:2:9a99593f;696:2:9a99593f;732:3:01'
            Data = ''
            Curves = '' }
        'infected_data_custom_preset_spitter_wasteland_special' = @{ Base = 'infected_data_custom_preset_spitter_medium'
            Params = '34:3:00;35:3:00;113:2:0000c841;122:2:00007a44;220:2:00000040;340:2:0000c841;341:2:0000003f;344:2:00007041;348:3:00;382:2:cdcccc3d;383:1:04000000;384:1:08000000'
            Data = '0:24577:-2:-1:1:spitter_spit_attack_x3_01'
            Curves = '30:spitter_health' }
        'infected_data_custom_preset_infected_humanity_wasteland_special' = @{ Base = ''
            Params = '18:2:0000803f;20:2:00000000;21:2:00000000;22:2:00000000;23:2:00000000;24:2:0000803f;25:2:0000803f;26:2:cdcccc3d;27:2:0000803e;29:2:00008040;30:2:cdcccc3d;34:3:00;35:3:00;78:2:cdcc4c3e;113:2:0000c841;116:2:0000803f;117:2:0000803f;118:2:0000803f;119:2:0000003f;120:2:0000803f;122:2:00007a44;134:2:0000803f;137:2:0000003f;225:2:0000f042;352:2:0000803f;353:2:0000803f;354:2:0000003f;355:2:0000803f;356:2:0000803f;400:2:0000803f;411:2:cdcc8c3f;413:2:0000803f;414:2:0000803f;415:2:0000803f;416:2:0000803f;517:2:9a99993e;518:2:0000a041;522:2:cdcccc3d;657:3:00'
            Data = ''
            Curves = '' }
    }
    Add-Type -TypeDefinition @'
    // Decoder/encoder for Dying Light 1 precompiled AI custom data (.dat). Hypothesis-driven; verified by round trip.
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Text;
    
    public class RzDatEntry { public float Dur, Dur2; public int Group; public ushort Weight; public string Anim; public uint Trailer; }
    public class RzDatKey { public ulong Key; public List<RzDatEntry> Entries = new List<RzDatEntry>(); }
    public class RzDatParam { public uint Id; public byte Flag; public uint Type; public byte[] Value; }
    public class RzDatCurve { public uint Id; public string Name; }
    public class RzDatFile {
        public List<List<RzDatKey>> Sections = new List<List<RzDatKey>>();
        public List<RzDatParam> Params = new List<RzDatParam>();
        public List<RzDatCurve> Curves = new List<RzDatCurve>();
        public byte[] Tail;
        public string Error;
    }
    
    public static class RzAiDat {
        public static int DataSections = 26;
        static int ValueSize(uint type, byte[] b, int p) {
            switch (type) {
                case 1: return 4;   // int
                case 2: return 4;   // float
                case 3: return 1;   // bool
                case 6: return 16;  // prob (hypothesis)
                case 5: return 8;   // float range (hypothesis)
                case 4: return 2 + BitConverter.ToUInt16(b, p); // string (hypothesis)
                default: throw new Exception("unknown param type " + type + " at " + p);
            }
        }
        static Encoding L1 = Encoding.GetEncoding(28591);
        public static RzDatFile Read(byte[] b) {
            var f = new RzDatFile(); int p = 0;
            try {
                for (int s = 0; s < DataSections; s++) {
                    var sec = new List<RzDatKey>(); int n = (int)BitConverter.ToUInt32(b, p); p += 4;
                    if (n < 0 || n > 100000) throw new Exception("bad key count " + n + " in section " + s + " at " + (p - 4));
                    for (int k = 0; k < n; k++) {
                        var dk = new RzDatKey(); dk.Key = BitConverter.ToUInt64(b, p); p += 8;
                        int m = (int)BitConverter.ToUInt32(b, p); p += 4;
                        if (m < 0 || m > 10000) throw new Exception("bad entry count " + m + " in section " + s + " at " + (p - 4));
                        for (int e = 0; e < m; e++) {
                            var de = new RzDatEntry();
                            de.Dur = BitConverter.ToSingle(b, p); de.Dur2 = BitConverter.ToSingle(b, p + 4); de.Group = BitConverter.ToInt32(b, p + 8);
                            de.Weight = BitConverter.ToUInt16(b, p + 12); int len = BitConverter.ToUInt16(b, p + 14); p += 16;
                            de.Anim = L1.GetString(b, p, len); p += len;
                            de.Trailer = BitConverter.ToUInt32(b, p); p += 4;
                            dk.Entries.Add(de);
                        }
                        sec.Add(dk);
                    }
                    f.Sections.Add(sec);
                }
                int np = (int)BitConverter.ToUInt32(b, p); p += 4;
                for (int i = 0; i < np; i++) {
                    var dp = new RzDatParam(); dp.Id = BitConverter.ToUInt32(b, p); dp.Flag = b[p + 4]; p += 5;
                    if (dp.Flag == 0) { dp.Value = new byte[0]; f.Params.Add(dp); continue; }   // unset parameter: no type or value
                    dp.Type = BitConverter.ToUInt32(b, p); p += 4;
                    int sz = ValueSize(dp.Type, b, p); dp.Value = new byte[sz]; Array.Copy(b, p, dp.Value, 0, sz); p += sz;
                    f.Params.Add(dp);
                }
                int nc = (int)BitConverter.ToUInt32(b, p); p += 4;
                for (int i = 0; i < nc; i++) {
                    var c = new RzDatCurve(); c.Id = BitConverter.ToUInt32(b, p); int len = BitConverter.ToUInt16(b, p + 4); p += 6;
                    c.Name = L1.GetString(b, p, len); p += len; f.Curves.Add(c);
                }
                f.Tail = new byte[b.Length - p]; Array.Copy(b, p, f.Tail, 0, f.Tail.Length);
            } catch (Exception ex) { f.Error = ex.Message + " (offset " + p + ")"; }
            return f;
        }
        public static byte[] Write(RzDatFile f) {
            var ms = new MemoryStream(); var w = new BinaryWriter(ms);
            foreach (var sec in f.Sections) {
                w.Write((uint)sec.Count);
                foreach (var k in sec) {
                    w.Write(k.Key); w.Write((uint)k.Entries.Count);
                    foreach (var e in k.Entries) {
                        w.Write(e.Dur); w.Write(e.Dur2); w.Write(e.Group); w.Write(e.Weight);
                        var s = L1.GetBytes(e.Anim); w.Write((ushort)s.Length); w.Write(s); w.Write(e.Trailer);
                    }
                }
            }
            w.Write((uint)f.Params.Count);
            foreach (var p in f.Params) { w.Write(p.Id); w.Write(p.Flag); if (p.Flag == 0) continue; w.Write(p.Type); w.Write(p.Value); }
            w.Write((uint)f.Curves.Count);
            foreach (var c in f.Curves) { w.Write(c.Id); var s = L1.GetBytes(c.Name); w.Write((ushort)s.Length); w.Write(s); }
            w.Write(f.Tail); w.Flush(); return ms.ToArray();
        }
    }
    
'@
    $freakDat = 0
    $d0z = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak"))
    foreach ($fn in $FreakAiDelta.Keys) {
        $fd = $FreakAiDelta[$fn]; $type = ($fn -split '_')[0]
        if ($fd.Base) {
            $e = $d0z.GetEntry("data/ai/$type/$($fd.Base).dat"); if (-not $e) { "Freak AI data skipped for $fn (base $($fd.Base).dat not found)"; continue }
            $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $f = [RzAiDat]::Read($ms.ToArray())
            if ($f.Error) { "Freak AI data skipped for $fn ($($f.Error))"; continue }
        } else {
            $f = New-Object RzDatFile; for ($i = 0; $i -lt 26; $i++) { $f.Sections.Add((New-Object 'Collections.Generic.List[RzDatKey]')) }; $f.Tail = [byte[]](0, 0, 0, 0)
        }
        $byId = @{}; foreach ($p in $f.Params) { $byId[[uint32]$p.Id] = $p }
        foreach ($t in ($fd.Params -split ';' | Where-Object { $_ })) {
            $id, $ty, $hex = $t -split ':'; $p = New-Object RzDatParam; $p.Id = [uint32]$id; $p.Flag = 1; $p.Type = [uint32]$ty
            $p.Value = [byte[]](0..($hex.Length / 2 - 1) | ForEach-Object { [Convert]::ToByte($hex.Substring($_ * 2, 2), 16) }); $byId[$p.Id] = $p
        }
        $f.Params.Clear(); foreach ($id in ($byId.Keys | Sort-Object)) { $f.Params.Add($byId[$id]) }
        foreach ($t in ($fd.Data -split ';' | Where-Object { $_ })) {
            $sec, $code, $dur, $grp, $w, $anim = $t -split ':', 6
            $k = $null; foreach ($x in $f.Sections[[int]$sec]) { if ($x.Key -eq [uint64]$code) { $k = $x } }
            if (-not $k) { $k = New-Object RzDatKey; $k.Key = [uint64]$code; $f.Sections[[int]$sec].Add($k) }
            $en = New-Object RzDatEntry; $en.Dur = [single]$dur; $en.Dur2 = [single]$dur; $en.Group = [int]$grp; $en.Weight = [uint16]$w; $en.Anim = $anim; $k.Entries.Add($en)
            $sorted = @($f.Sections[[int]$sec] | Sort-Object Key); $f.Sections[[int]$sec].Clear(); foreach ($x in $sorted) { $f.Sections[[int]$sec].Add($x) }
        }
        foreach ($t in ($fd.Curves -split ';' | Where-Object { $_ })) { $cid, $cname = $t -split ':', 2; $c = New-Object RzDatCurve; $c.Id = [uint32]$cid; $c.Name = $cname; $f.Curves.Add($c) }
        $patched["data/ai/$type/$fn.dat"] = [RzAiDat]::Write($f); $freakDat++
    }
    $d0z.Dispose()
    "Freaks of Nature: real AI data built for $freakDat presets"
    # GRE Goon: its zombie data set sits under infected/ in Data0, where the zombie loader never looks
    $d0 = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak"))
    $zh = "zombie_data_custom_preset_thug_armed_hard_zombie_hunt.scr"
    $patched["data/ai/zombie/$zh"] = ReadEntry $d0 "data/ai/infected/$zh"
    $d0.Dispose()
}

if (-not $NoFollowing -and (Test-Path (Join-Path $Game "DW_DLC17"))) { Add-FollowingOverrides }
else { $patched.Remove("data/maps/wasteland/wasteland_presets.scr") }

# Interface colours. The .xui screens are XML with 0xAARRGGBB values. Similar hues (12 bands of 30 degrees) move
# together, so all the oranges in the UI land on one new colour. Replacements are the same length as the originals.
# Uses its own generator, so turning this on doesn't change a seed's loot and spawn rolls.
if ($UIColours -ne "Off") {
    $uiRng = New-Object Random($Seed)
    $uiHues = @(0..11 | ForEach-Object { $uiRng.NextDouble() * 360 })
    $uiCache = @{}
    function Convert-UiColour([string]$tag, [string]$hex) {
        $key = "$tag$hex".ToLower()
        if ($uiCache.ContainsKey($key)) { return $uiCache[$key] }
        $result = $hex
        $a = [Convert]::ToInt32($hex.Substring(0, 2), 16); $r = [Convert]::ToInt32($hex.Substring(2, 2), 16)
        $g = [Convert]::ToInt32($hex.Substring(4, 2), 16); $b = [Convert]::ToInt32($hex.Substring(6, 2), 16)
        $max = [Math]::Max($r, [Math]::Max($g, $b)); $min = [Math]::Min($r, [Math]::Min($g, $b)); $d = $max - $min
        $v = $max / 255.0; $s = if ($max) { $d / [double]$max } else { 0.0 }
        $newH = -1.0
        if ($a -gt 0 -and $s -ge 0.15 -and $v -ge 0.1) {
            $h = if ($max -eq $r) { 60.0 * ((($g - $b) / [double]$d + 6) % 6) } elseif ($max -eq $g) { 60.0 * (($b - $r) / [double]$d + 2) } else { 60.0 * (($r - $g) / [double]$d + 4) }
            $band = [int][Math]::Floor($h / 30) % 12
            $newH = ($uiHues[$band] + ($h - $band * 30)) % 360
        }
        elseif ($UIColours -eq "Everything" -and $a -gt 0 -and $tag -eq "TextColor" -and $v -ge 0.5) {
            # white and grey text: each brightness step gets its own colour; kept bright enough to read
            $newH = $uiHues[[int][Math]::Min(11, [Math]::Floor($v * 12))]; $s = 0.75; $v = [Math]::Max($v, 0.85)
        }
        if ($newH -ge 0) {
            if ($tag -eq "TextColor" -and $newH -ge 200 -and $newH -le 290) { $s = [Math]::Min($s, 0.6); $v = [Math]::Max($v, 0.85) }   # deep blue text is unreadable on black
            $i = [int][Math]::Floor($newH / 60) % 6; $f = $newH / 60 - [Math]::Floor($newH / 60)
            $p = $v * (1 - $s); $q = $v * (1 - $s * $f); $u = $v * (1 - $s * (1 - $f))
            $rgb = switch ($i) { 0 { $v, $u, $p } 1 { $q, $v, $p } 2 { $p, $v, $u } 3 { $p, $q, $v } 4 { $u, $p, $v } default { $v, $p, $q } }
            $result = "{0:x2}{1:x2}{2:x2}{3:x2}" -f $a, [int][Math]::Round($rgb[0] * 255), [int][Math]::Round($rgb[1] * 255), [int][Math]::Round($rgb[2] * 255)
        }
        $uiCache[$key] = $result
        $result
    }
    $script:UiChanged = 0; $uiFiles = 0
    $uiRx = New-Object Text.RegularExpressions.Regex('<(Color|TextColor|OutlineColor|ShadowColor|DropShadowColor|DefaultFontColor|m_CursorColor)>0x([0-9a-fA-F]{8})<', [Text.RegularExpressions.RegexOptions]::Compiled)
    $uiEval = [Text.RegularExpressions.MatchEvaluator]{ param($m)
        $n = Convert-UiColour $m.Groups[1].Value $m.Groups[2].Value
        if ($n -ine $m.Groups[2].Value) { $script:UiChanged++ }
        "<$($m.Groups[1].Value)>0x$n<"
    }
    # Animations: hover/selection fades are <Timeline>s listing <TimelineProp> names, and each <KeyFrame> holds one <Prop>
    # per name, in the same order. Every 0xAARRGGBB <Prop> in the game's UI belongs to a colour property.
    $uiTimelineRx = New-Object Text.RegularExpressions.Regex('(?s)<Timeline>.*?</Timeline>', [Text.RegularExpressions.RegexOptions]::Compiled)
    $uiKeyRx = New-Object Text.RegularExpressions.Regex('(?s)<KeyFrame>.*?</KeyFrame>', [Text.RegularExpressions.RegexOptions]::Compiled)
    $uiPropRx = New-Object Text.RegularExpressions.Regex('<Prop>([^<]*)</Prop>', [Text.RegularExpressions.RegexOptions]::Compiled)
    $uiPropEval = [Text.RegularExpressions.MatchEvaluator]{ param($p)
        $tag = $script:uiNames[$script:uiIndex]; $script:uiIndex++
        $v = $p.Groups[1].Value
        if ($v -notmatch '^0x[0-9a-fA-F]{8}$') { return $p.Value }
        $n = Convert-UiColour $tag $v.Substring(2)
        if ($n -ine $v.Substring(2)) { $script:UiChanged++ }
        "<Prop>0x$n</Prop>"
    }
    $uiKeyEval = [Text.RegularExpressions.MatchEvaluator]{ param($k) $script:uiIndex = 0; $uiPropRx.Replace($k.Value, $uiPropEval) }
    $uiTimelineEval = [Text.RegularExpressions.MatchEvaluator]{ param($m)
        if (-not $m.Value.Contains("<Prop>0x")) { return $m.Value }
        $script:uiNames = @([regex]::Matches($m.Value, '<TimelineProp>([^<]*)</TimelineProp>') | ForEach-Object { $_.Groups[1].Value })
        $uiKeyRx.Replace($m.Value, $uiKeyEval)
    }
    # Icons (-UIIcons): an image tint multiplies with the icon's own colours, so white icons take any colour but yellow
    # ones go almost black under blue. Tints therefore skip the blue range. Images with their own colour keep the UI colour.
    $script:UiIconCount = 0
    $uiIconRng = New-Object Random($Seed + 1)
    $uiIconHues = @{}
    $uiPropsRx = New-Object Text.RegularExpressions.Regex('(?s)<Properties>.*?</Properties>', [Text.RegularExpressions.RegexOptions]::Compiled)
    $uiIconEval = [Text.RegularExpressions.MatchEvaluator]{ param($m)
        $b = $m.Value
        if (-not $b.Contains("<ImagePath>")) { return $b }
        $img = [regex]::Match($b, '<ImagePath>([^<]*)</ImagePath>').Groups[1].Value
        $id = [regex]::Match($b, '<Id>([^<]*)</Id>').Groups[1].Value
        if ($img -match '(?i)^(white|black)$|mask|matte|stroke|_bg|back') { return $b }
        if ($img -notmatch '(?i)^(map_|obj_|poi_|stat_|elemental|crosshair|coop_|player_|hud_|grenade|fuel|timer|hive|voice|hint_icon|skills_|item_|weapon_|component|star|car_)' -and $id -notmatch 'Icon') { return $b }
        $existing = [regex]::Match($b, '<Color>0x([0-9a-fA-F]{8})</Color>')
        $alpha = "ff"; $level = 1.0
        if ($existing.Success) {
            $hex = $existing.Groups[1].Value; $alpha = $hex.Substring(0, 2)
            $r = [Convert]::ToInt32($hex.Substring(2, 2), 16); $g = [Convert]::ToInt32($hex.Substring(4, 2), 16); $c = [Convert]::ToInt32($hex.Substring(6, 2), 16)
            $hi = [Math]::Max($r, [Math]::Max($g, $c)); $lo = [Math]::Min($r, [Math]::Min($g, $c))
            if ($alpha -eq "00" -or $hi -lt 40 -or ($hi - $lo) / [double]$hi -ge 0.15) { return $b }   # invisible, black, or already coloured
            $level = $hi / 255.0
        }
        if (-not $uiIconHues.ContainsKey($img)) { $x = $uiIconRng.NextDouble() * 280; $uiIconHues[$img] = $(if ($x -lt 200) { $x } else { $x + 80 }) }
        $h = $uiIconHues[$img]; $s = 0.75
        $i = [int][Math]::Floor($h / 60) % 6; $f = $h / 60 - [Math]::Floor($h / 60)
        $p = $level * (1 - $s); $q = $level * (1 - $s * $f); $u = $level * (1 - $s * (1 - $f))
        $rgb = switch ($i) { 0 { $level, $u, $p } 1 { $q, $level, $p } 2 { $p, $level, $u } 3 { $p, $q, $level } 4 { $u, $p, $level } default { $level, $p, $q } }
        $tint = "<Color>0x{0}{1:x2}{2:x2}{3:x2}</Color>" -f $alpha, [int][Math]::Round($rgb[0] * 255), [int][Math]::Round($rgb[1] * 255), [int][Math]::Round($rgb[2] * 255)
        $script:UiIconCount++
        if ($existing.Success) { return $b.Replace($existing.Value, $tint) }
        $b.Replace("</ImagePath>", "</ImagePath>`r`n$tint")
    }
    # Plain-text colour lists: R,G,B as 0-1 or 0-255. Goes through the same hue mapping; neutral colours are left alone.
    function Convert-ScriptColours([string]$text, [string]$pattern, [double]$scale, [string]$format) {
        [regex]::Replace($text, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($m)
            $inv = [Globalization.CultureInfo]::InvariantCulture
            $parts = @(1..3 | ForEach-Object { [double]::Parse($m.Groups[$_ + 1].Value, $inv) })
            $hex = "ff{0:x2}{1:x2}{2:x2}" -f @($parts | ForEach-Object { [int][Math]::Round([Math]::Min(1.0, $_ / $scale) * 255) })
            $n = Convert-UiColour "Color" $hex
            if ($n -ieq $hex) { return $m.Value }
            $script:UiIconCount++
            $vals = @(0..2 | ForEach-Object { ([Convert]::ToInt32($n.Substring(2 + $_ * 2, 2), 16) / 255.0 * $scale).ToString($format, $inv) })
            "$($m.Groups[1].Value)$($vals[0]), $($vals[1]), $($vals[2])$($m.Groups[5].Value)"
        })
    }
    $src = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak"))
    foreach ($e in @($src.Entries | Where-Object { $_.FullName -like "data/menu/*.xui" -and $_.FullName -notmatch "^data/menu/(editor|xuieditor)/" })) {
        $r = New-Object IO.StreamReader($e.Open(), (New-Object Text.UTF8Encoding($false))); $t = $r.ReadToEnd(); $r.Close()
        if ($t.Contains([char]0xFFFD)) { "skipped $($e.FullName) (not UTF-8)"; continue }   # couldn't be written back unchanged
        $new = $uiTimelineRx.Replace($uiRx.Replace($t, $uiEval), $uiTimelineEval)
        if ($UIIcons) { $new = $uiPropsRx.Replace($new, $uiIconEval) }
        if (-not [string]::Equals($new, $t)) { $patched[$e.FullName] = $new; $uiFiles++ }
    }
    if ($UIIcons) {
        $r = New-Object IO.StreamReader($src.GetEntry("data/scripts/locationsconfig.scr").Open()); $t = $r.ReadToEnd(); $r.Close()
        $patched["data/scripts/locationsconfig.scr"] = Convert-ScriptColours $t '(?m)^(\s*\w*AreaColor\(\[\s*)([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(\s*,\s*[\d.]+\s*\]\))' 1.0 "0.000"
        $r = New-Object IO.StreamReader($src.GetEntry("data/scripts/crafting/crafting_elementals.scr").Open()); $t = $r.ReadToEnd(); $r.Close()
        $patched["data/scripts/crafting/crafting_elementals.scr"] = Convert-ScriptColours $t '(?m)^(\s*EffectMenuColor\(\[\s*)([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(\s*\]\))' 255.0 "0.0"
        "Interface icons: {0} tints and colours changed" -f $script:UiIconCount
    }
    $src.Dispose()
    "Interface colours ({0}): {1} colour values changed in {2} screens" -f $UIColours, $script:UiChanged, $uiFiles
}

# Shuffled subtitles. *_texts_all.bin: u32 version, u32 count, then per entry u16 key length + ASCII key, u16 character
# count + UTF-16 text. Only spoken lines move (key has DLG/TLK/CHT/USA/INP + number, or starts CIN_), and never ones holding
# % or & codes. Keys stay put, so nothing that looks a line up can break. Base game lines live in the language pak;
# The Following's are loose files in DW_DLC17\Data<lang>\Data\Maps. Each game shuffles among its own lines.
function Read-TextBin([byte[]]$b, [string]$name, [Collections.Generic.List[string]]$pool) {
    if ($b.Length -lt 8) { return $null }
    $count = [BitConverter]::ToUInt32($b, 4); $p = 8
    $keys = New-Object 'string[]' $count; $vals = New-Object 'string[]' $count; $slots = New-Object Collections.Generic.List[int]; $found = New-Object Collections.Generic.List[string]
    for ($i = 0; $i -lt $count; $i++) {
        $n = [BitConverter]::ToUInt16($b, $p); $p += 2; $keys[$i] = [Text.Encoding]::ASCII.GetString($b, $p, $n); $p += $n
        $n = [BitConverter]::ToUInt16($b, $p); $p += 2; $vals[$i] = [Text.Encoding]::Unicode.GetString($b, $p, $n * 2); $p += $n * 2
        if ($vals[$i] -and $vals[$i] -notmatch '[%&]' -and $keys[$i] -cmatch '^CIN_|(DLG|TLK|CHT|USA|INP)\d') { $slots.Add($i); $found.Add($vals[$i]) }
    }
    if ($p -ne $b.Length -or -not $slots.Count) { return $null }
    $pool.AddRange($found)
    @{ Name = $name; Version = [BitConverter]::ToUInt32($b, 0); Keys = $keys; Vals = $vals; Slots = $slots }
}
function Write-TextBin($sf) {
    $ms = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter($ms)
    $bw.Write([uint32]$sf.Version); $bw.Write([uint32]$sf.Keys.Length)
    for ($i = 0; $i -lt $sf.Keys.Length; $i++) {
        $bw.Write([uint16]$sf.Keys[$i].Length); $bw.Write([Text.Encoding]::ASCII.GetBytes($sf.Keys[$i]))
        $bw.Write([uint16]$sf.Vals[$i].Length); $bw.Write([Text.Encoding]::Unicode.GetBytes($sf.Vals[$i]))
    }
    $bw.Flush(); , $ms.ToArray()
}
function Invoke-LineShuffle($files, [Collections.Generic.List[string]]$pool, $rng) {
    for ($i = $pool.Count - 1; $i -gt 0; $i--) { $j = $rng.Next($i + 1); $swap = $pool[$i]; $pool[$i] = $pool[$j]; $pool[$j] = $swap }
    $next = 0
    foreach ($sf in $files) { foreach ($i in $sf.Slots) { $sf.Vals[$i] = $pool[$next]; $next++ } }
}
$script:SubBins = @{}; $script:SubLoose = @{}
if ($Subtitles) {
    $langMap = @{ english = "En"; german = "De"; french = "Fr"; italian = "It"; spanish = "Es"; polish = "Pl"; russian = "Ru"; brazilian = "Br"; czech = "Cs"; dutch = "Nl"; turkish = "Tr"; japanese = "Jp"; koreana = "Ko"; schinese = "Cn"; tchinese = "Tw"; thai = "Th"; greek = "El" }
    $lang = "En"
    $acf = Join-Path (Split-Path (Split-Path $Game)) "appmanifest_239140.acf"
    if (Test-Path $acf) { $lm = [regex]::Match((Get-Content $acf -Raw), '"language"\s+"(\w+)"'); if ($lm.Success -and $langMap[$lm.Groups[1].Value] -and (Test-Path (Join-Path $Game "DW\Data$($langMap[$lm.Groups[1].Value]).pak"))) { $lang = $langMap[$lm.Groups[1].Value] } }
    $script:SubLangPath = Join-Path $Game "DW\Data$lang.pak"
    $script:SubSource = if ((Test-LangMarker $script:SubLangPath) -and (Test-Path "$($script:SubLangPath).randomiser-backup")) { "$($script:SubLangPath).randomiser-backup" } else { $script:SubLangPath }   # always shuffle from vanilla
    $subRng = New-Object Random($Seed + 2)
    $subFiles = New-Object Collections.ArrayList; $subPool = New-Object Collections.Generic.List[string]
    $langPak = [IO.Compression.ZipFile]::OpenRead($script:SubSource)
    foreach ($e in @($langPak.Entries | Where-Object { $_.Name -like "*_texts_all.bin" -and $_.Name -notlike "testmap_*" })) {
        $ms = New-Object IO.MemoryStream; $st = $e.Open(); $st.CopyTo($ms); $st.Close()
        $sf = Read-TextBin $ms.ToArray() $e.FullName $subPool
        if ($sf) { [void]$subFiles.Add($sf) }
    }
    $langPak.Dispose()
    Invoke-LineShuffle $subFiles $subPool $subRng
    foreach ($sf in $subFiles) { $script:SubBins[$sf.Name] = Write-TextBin $sf }
    "Subtitles: {0} spoken lines shuffled across {1} files ({2})" -f $subPool.Count, $subFiles.Count, $lang
    $wlDir = Join-Path $Game "DW_DLC17\Data$lang\Data\Maps"
    if (-not $NoFollowing -and (Test-Path $wlDir)) {
        $wlFiles = New-Object Collections.ArrayList; $wlPool = New-Object Collections.Generic.List[string]
        foreach ($f in @(Get-ChildItem $wlDir -Filter "*.bin")) {
            $src = if (Test-Path "$($f.FullName).randomiser-backup") { "$($f.FullName).randomiser-backup" } else { $f.FullName }
            $sf = Read-TextBin ([IO.File]::ReadAllBytes($src)) $f.FullName $wlPool
            if ($sf) { [void]$wlFiles.Add($sf) }
        }
        if ($wlFiles.Count) {
            Invoke-LineShuffle $wlFiles $wlPool $subRng
            foreach ($sf in $wlFiles) { $script:SubLoose[$sf.Name] = Write-TextBin $sf }
            "Subtitles (The Following): {0} spoken lines shuffled across {1} files" -f $wlPool.Count, $wlFiles.Count
        }
    }
}

# World colours. Each time of day gets its own tint, scaled so the scene keeps about the same brightness.
if ($WorldColours -ne "Off") {
    $wInv = [Globalization.CultureInfo]::InvariantCulture
    $wRng = New-Object Random($Seed + 4)
    $wSat = if ($WorldColours -eq "Wild") { 0.8 } else { 0.35 }
    $wPerms = @(@(1, 2, 0), @(2, 0, 1), @(0, 2, 1), @(2, 1, 0), @(1, 0, 2))
    $wTint = @{}; $wPerm = @{}
    foreach ($ph in "night", "dawn", "day", "dusk") {
        $h = $wRng.NextDouble() * 360; $i = [int][Math]::Floor($h / 60) % 6; $f = $h / 60 - [Math]::Floor($h / 60)
        $lo = 1 - $wSat; $dn = 1 - $wSat * $f; $up = 1 - $wSat * (1 - $f)
        $c = switch ($i) { 0 { 1.0, $up, $lo } 1 { $dn, 1.0, $lo } 2 { $lo, 1.0, $up } 3 { $lo, $dn, 1.0 } 4 { $up, $lo, 1.0 } default { 1.0, $lo, $dn } }
        $luma = 0.2126 * $c[0] + 0.7152 * $c[1] + 0.0722 * $c[2]
        $scale = [Math]::Min(1 / $luma, 1.8 / [Math]::Max($c[0], [Math]::Max($c[1], $c[2])))
        $wTint[$ph] = @(($c[0] * $scale), ($c[1] * $scale), ($c[2] * $scale))
        $wPerm[$ph] = $wPerms[$wRng.Next($wPerms.Count)]
    }
    function Read-Data0Text([string]$name) { $z = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak")); $r = New-Object IO.StreamReader($z.GetEntry($name).Open()); $t = $r.ReadToEnd(); $r.Close(); $z.Dispose(); $t }
    $script:WorldCount = 0
    $patched["data/scripts/weather/weather.scr"] = [regex]::Replace((Read-Data0Text "data/scripts/weather/weather.scr"),
        '(?m)^(\s*vec3\s+(shading_sun_color|clouds_color|sun_glow_color|scattering_l|scattering_k)_(night|dawn\w*|day|dusk\w*)\s*=\s*\[\s*)([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)(\s*\])',
        [Text.RegularExpressions.MatchEvaluator]{ param($m)
            $ph = [regex]::Match($m.Groups[3].Value, '^(night|dawn|day|dusk)').Value
            $v = @(4..6 | ForEach-Object { [double]::Parse($m.Groups[$_].Value, $wInv) })
            if ($m.Groups[2].Value -like "scattering*") {
                if ($WorldColours -ne "Wild") { return $m.Value }
                $o = $wPerm[$ph]; $v = @($v[$o[0]], $v[$o[1]], $v[$o[2]])
            } else { $t = $wTint[$ph]; $v = @(($v[0] * $t[0]), ($v[1] * $t[1]), ($v[2] * $t[2])) }
            $script:WorldCount++
            "$($m.Groups[1].Value)$($v[0].ToString('0.000000', $wInv)), $($v[1].ToString('0.000000', $wInv)), $($v[2].ToString('0.000000', $wInv))$($m.Groups[7].Value)"
        })
    foreach ($w in @(@("data/scripts/varlist_water.scr", "v_water_color", "day"), @("data/scripts/varlist_stars.scr", "v_stars_color", "night"))) {
        $tint = $wTint[$w[2]]
        $patched[$w[0]] = [regex]::Replace((Read-Data0Text $w[0]), "(`"$($w[1])`",\s*\[\s*)([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)",
            [Text.RegularExpressions.MatchEvaluator]{ param($m)
                $script:WorldCount++
                $m.Groups[1].Value + ((1..3 | ForEach-Object { [Math]::Min(1.0, [double]::Parse($m.Groups[$_ + 1].Value, $wInv) * $tint[$_ - 1]).ToString('0.000000', $wInv) }) -join ", ")
            })
    }
    "World colours ({0}): {1} values changed" -f $WorldColours, $script:WorldCount
}

# Quest rewards. Replacement items come from the same kind of Harran shop stock. Craftplan_ZaidFlare is kept: a quest uses
# it. Paint jobs, bundles and collectables keep their items. XP is never changed, so levelling stays the same.
if ($QuestRewards -ne "Off") {
    $qRng = New-Object Random($Seed + 5)
    $qz = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak"))
    $r = New-Object IO.StreamReader($qz.GetEntry("data/scripts/trading/shop_item_sets.scr").Open()); $shopText = $r.ReadToEnd(); $r.Close()
    $r = New-Object IO.StreamReader($qz.GetEntry("data/scripts/quests_rewards_main.scr").Open()); $rewardText = $r.ReadToEnd(); $r.Close()
    $qz.Dispose()
    $qPools = @{}
    foreach ($m in [regex]::Matches($shopText, '(?s)ItemSet\("([^"]+)"\)[^{]*\{(.*?)\}')) {
        $name = $m.Groups[1].Value; $kind = Get-ShopKind $name
        if (-not $kind -or $name -match $ShopKeep -or $name -match 'Wasteland|Following|^Qua') { continue }
        if (-not $qPools[$kind]) { $qPools[$kind] = New-Object Collections.Generic.SortedSet[string] ([StringComparer]::Ordinal) }
        foreach ($it in [regex]::Matches($m.Groups[2].Value, 'Item\("([^"]+)"')) { [void]$qPools[$kind].Add($it.Groups[1].Value) }
    }
    $script:QuestItems = 0; $script:QuestCash = 0
    $qCash = { param($amount) [Math]::Max(50, [int]([Math]::Round([int]$amount * (0.5 + $qRng.NextDouble() * 1.5) / 50) * 50)) }
    $new = [regex]::Replace($rewardText, 'Item\("([^"]+)"(,\s*\w+,\s*)(\d+)', [Text.RegularExpressions.MatchEvaluator]{ param($m)
        $id = $m.Groups[1].Value
        if ($id -eq "Cash_Cash") { $script:QuestCash++; return "Item(`"Cash_Cash`"$($m.Groups[2].Value)$(& $qCash $m.Groups[3].Value)" }
        $kind = switch -regex ($id) { '^Craftplan_ZaidFlare$' { break } '^Craftplan_' { "blueprint"; break } '^Craft_Upgrade' { "upgrade"; break } '^Melee_' { "melee"; break } '^Firearm_' { "firearm"; break } }
        if (-not $kind -or -not $qPools[$kind]) { return $m.Value }
        $pool = @($qPools[$kind]); $script:QuestItems++
        "Item(`"$($pool[$qRng.Next($pool.Count)])`"$($m.Groups[2].Value)$($m.Groups[3].Value)"
    })
    $new = [regex]::Replace($new, '(?m)^(\s*)Cash\((\d+)\)', [Text.RegularExpressions.MatchEvaluator]{ param($m) $script:QuestCash++; "$($m.Groups[1].Value)Cash($(& $qCash $m.Groups[2].Value))" })
    $patched["data/scripts/quests_rewards_main.scr"] = $new
    "Quest rewards: {0} items swapped, {1} cash amounts changed" -f $script:QuestItems, $script:QuestCash
}

# Voiced dialogue. Only <line id="..."> values move: group names (which quests start conversations by), speakers, gestures
# and pauses stay in place. Lines stay within one file, because each map only loads its own lines. Test maps are skipped.
$script:DlcMaps = @{}   # The Following's map files edited in DataDLC17_2.pak (-HellraidFollowing)
$script:DlcDialogue = @{}   # The Following's dialogue outranks Data3.pak, so it goes into DataDLC17_0.pak
if ($Dialogue -ne "Off") {
    $dRng = New-Object Random($Seed + 6)
    $dIdRx = '(?<=<line\s(?:[^>]*\s)?id=")[^"]+(?=")'
    $dTotal = 0; $dFiles = 0
    $dSources = @(, @("DW\Data0.pak", "data/dialogs/*.xml"))
    if (-not $NoFollowing -and (Test-Path (Join-Path $Game "DW_DLC17\DataDLC17_0.pak"))) { $dSources += , @("DW_DLC17\DataDLC17_0.pak", "data/dialogs/wasteland*.xml") }
    foreach ($ds in $dSources) {
        $dzPath = Join-Path $Game $ds[0]; if ((Test-LangMarker $dzPath) -and (Test-Path "$dzPath.randomiser-backup")) { $dzPath = "$dzPath.randomiser-backup" }   # always shuffle from vanilla
        $dz = [IO.Compression.ZipFile]::OpenRead($dzPath)
        foreach ($e in @($dz.Entries | Where-Object { $_.FullName -like $ds[1] -and $_.Name -notlike "testmap*" })) {
            $r = New-Object IO.StreamReader($e.Open(), [Text.Encoding]::GetEncoding(28591)); $t = $r.ReadToEnd(); $r.Close()
            $pools = @{}
            foreach ($m in [regex]::Matches($t, $dIdRx)) {
                $key = if ($Dialogue -eq "SameCharacter") { ($m.Value -split '_')[0] } else { "all" }
                if (-not $pools[$key]) { $pools[$key] = New-Object Collections.Generic.List[string] }
                $pools[$key].Add($m.Value)
            }
            if (-not $pools.Count) { continue }
            foreach ($k in @($pools.Keys | Sort-Object)) {
                $list = $pools[$k]
                for ($i = $list.Count - 1; $i -gt 0; $i--) { $j = $dRng.Next($i + 1); $tmpId = $list[$i]; $list[$i] = $list[$j]; $list[$j] = $tmpId }
            }
            $used = @{}
            $dNew = [regex]::Replace($t, $dIdRx, [Text.RegularExpressions.MatchEvaluator]{ param($m)
                $key = if ($Dialogue -eq "SameCharacter") { ($m.Value -split '_')[0] } else { "all" }
                $n = [int]$used[$key]; $used[$key] = $n + 1; $script:dCount++
                $pools[$key][$n]
            })
            if ($ds[0] -like 'DW_DLC17*') { $script:DlcDialogue[$e.FullName] = [Text.Encoding]::GetEncoding(28591).GetBytes($dNew) } else { $patched[$e.FullName] = $dNew }
            $dFiles++
        }
        $dz.Dispose()
    }
    "Dialogue ({0}): {1} lines shuffled in {2} files" -f $Dialogue, $script:dCount, $dFiles
}

# Hellraid files. Only the presets that survived -Exclude are added, so nothing unused is defined.
$hrUsed = @($HellraidList | Where-Object { ";$Specials;" -like "*;$_;*" })
if ($Hellraid -and $hrUsed.Count) {
    $l1 = [Text.Encoding]::GetEncoding(28591)
    $hz = [IO.Compression.ZipFile]::OpenRead($hrPak); $bz = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak")); $mz = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data2.pak"))
    $readText = { param($zip, $name) $r = New-Object IO.StreamReader($zip.GetEntry($name).Open(), $l1); $x = $r.ReadToEnd(); $r.Close(); $x }
    $dlcPre = & $readText $hz "data/presets/humanai_dlc49.pre"; $basePre = & $readText $bz "data/presets/humanai.pre"
    $nl = if ($basePre.Contains("`r`n")) { "`r`n" } else { "`n" }
    $blocks = foreach ($n in $hrUsed) { [regex]::Match($dlcPre, "(?s)[ \t]*Preset\(`"$n`"\)\s*\{.*?\n\s*\}").Value -replace "`r?`n", $nl }
    $last = [regex]::Matches($basePre, '(?s)[ \t]*Preset\("[^"]+"\)\s*\{.*?\n\s*\}') | Select-Object -Last 1
    $at = $last.Index + $last.Length
    $pre = $basePre.Substring(0, $at) + $nl + $nl + "        // ---- Hellraid enemies (Dying Light Randomiser mod) ----" + $nl + ($blocks -join ($nl + $nl)) + $basePre.Substring($at)
    $pre = $pre.Replace('import "infected_ai_module_presets.def"', 'import "infected_ai_module_presets.def"' + $nl + 'import "human_ai_hellraid_types.def"')
    $patched["data/presets/humanai.pre"] = $l1.GetBytes($pre)
    # animation scripts, body file and AI files the DLC normally supplies (never replacing a base-game file)
    $hrFiles = 0
    foreach ($e in $hz.Entries) {
        if (-not ($e.FullName -match '^data/(characters|ai)/' -and $e.Length) -or $bz.GetEntry($e.FullName) -or $patched.ContainsKey($e.FullName)) { continue }
        $ms = New-Object IO.MemoryStream; $st = $e.Open(); $st.CopyTo($ms); $st.Close(); $patched[$e.FullName] = $ms.ToArray(); $hrFiles++
    }
    # every Harran map loads the Hellraid archive (kept in memory between maps that list it)
    $maps = 0
    foreach ($e in @($mz.Entries | Where-Object { $_.Name -like "*.startprop" -and $_.Name -ne "menu_lvl_new.startprop" })) {
        $sp = & $readText $mz $e.FullName
        $m = [regex]::Matches($sp, '(?m)^([ \t]*)CrossLevelPack\([^\r\n]*') | Select-Object -Last 1
        if (-not $m) { continue }
        $snl = if ($sp.Contains("`r`n")) { "`r`n" } else { "`n" }
        $patched[$e.FullName] = $l1.GetBytes($sp.Insert($m.Index + $m.Length, $snl + $m.Groups[1].Value + 'CrossLevelPack("hellraid", "")'))
        $maps++
    }
    # DLC side maps (Prison, stadium, challenge maps, BTZ tutorial) use the same spawn lists. Their start files sit in DLC paks
    # that may outrank Data3.pak, in which case these copies are ignored.
    foreach ($dp in @(Get-ChildItem $Game -Directory -Filter "DW_DLC*" | Where-Object { $_.Name -notin "DW_DLC17", "DW_DLC49" } | ForEach-Object { Get-ChildItem $_.FullName -Filter *.pak })) {
        $dz = [IO.Compression.ZipFile]::OpenRead($dp.FullName)
        foreach ($e in @($dz.Entries | Where-Object { $_.Name -like "*.startprop" })) {
            if ($patched.ContainsKey($e.FullName)) { continue }
            $sp = & $readText $dz $e.FullName
            $m = [regex]::Matches($sp, '(?m)^([ \t]*)CrossLevelPack\([^\r\n]*') | Select-Object -Last 1
            if (-not $m) { continue }
            $snl = if ($sp.Contains("`r`n")) { "`r`n" } else { "`n" }
            $patched[$e.FullName] = $l1.GetBytes($sp.Insert($m.Index + $m.Length, $snl + $m.Groups[1].Value + 'CrossLevelPack("hellraid", "")'))
            $maps++
        }
        $dz.Dispose()
    }
    $hz.Dispose(); $bz.Dispose(); $mz.Dispose()
    # The Following's map: its start file is in DataDLC17_2.pak (outranks Data3.pak), so that pak gets the line in place at install
    $script:DlcMaps = @{}
    if ($HellraidFollowing) {
        $src2 = if (Test-Path "$dlc2.randomiser-backup") { "$dlc2.randomiser-backup" } else { $dlc2 }
        $z2 = [IO.Compression.ZipFile]::OpenRead($src2)
        foreach ($mapStart in "data/maps/wasteland/wasteland.startprop") {
            $e2 = $z2.GetEntry($mapStart); if (-not $e2) { continue }
            $sp = & $readText $z2 $mapStart
            $m = [regex]::Matches($sp, '(?m)^([ \t]*)CrossLevelPack\([^\r\n]*') | Select-Object -Last 1
            if (-not $m -or $sp.Contains('CrossLevelPack("hellraid"')) { continue }
            $snl = if ($sp.Contains("`r`n")) { "`r`n" } else { "`n" }
            $script:DlcMaps[$mapStart] = $l1.GetBytes($sp.Insert($m.Index + $m.Length, $snl + $m.Groups[1].Value + 'CrossLevelPack("hellraid", "")'))
        }
        $z2.Dispose()
        "Hellraid in The Following (experimental): its map start file will load the Hellraid archive"
    }
    "Hellraid: {0} enemies added to Harran's spawn lists; {1} DLC files copied; {2} maps load the Hellraid archive" -f $hrUsed.Count, $hrFiles, $maps
}

# The Mother's Volatile form, made for open spawns: her own preset (Volatile_WL_Final) is a night creature that reacts to light,
# which in daylight or torchlight outside her dark boss arena makes her approach, recoil and escape. This copy turns both off.
# The preset goes in the base humanai.pre (loaded on every map); its AI data file includes hers and overrides the light settings.
if ($Mother -and ";$SpecialsFollowing;" -like "*;SIR_Mother_Volatile;*") {
    $l1m = [Text.Encoding]::GetEncoding(28591)
    $mz = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW_DLC17\DataDLC17_0.pak"))
    $r = New-Object IO.StreamReader($mz.GetEntry("data/presets/humanai_dlc17.pre").Open(), $l1m); $dlcPre = $r.ReadToEnd(); $r.Close(); $mz.Dispose()
    $blk = [regex]::Match($dlcPre, '(?s)[ \t]*Preset\("Volatile_WL_Final"\)\s*\{.*?\n\s*\}').Value
    if ($blk) {
        $blk = $blk.Replace('Preset("Volatile_WL_Final")', 'Preset("SIR_Mother_Volatile")').Replace('SetField("m_CustomDataPreset", "volatile_wasteland_final")', 'SetField("m_CustomDataPreset", "volatile_wasteland_final_sir")').Replace('SetField("m_IsNightCreature", "1")', 'SetField("m_IsNightCreature", "0")')
        if ($patched.ContainsKey("data/presets/humanai.pre")) { $pre = $l1m.GetString([byte[]]$patched["data/presets/humanai.pre"]) }
        else { $bz2 = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak")); $r = New-Object IO.StreamReader($bz2.GetEntry("data/presets/humanai.pre").Open(), $l1m); $pre = $r.ReadToEnd(); $r.Close(); $bz2.Dispose() }
        $nl = if ($pre.Contains("`r`n")) { "`r`n" } else { "`n" }
        $last = [regex]::Matches($pre, '(?s)[ \t]*Preset\("[^"]+"\)\s*\{.*?\n\s*\}') | Select-Object -Last 1; $at = $last.Index + $last.Length
        $pre = $pre.Substring(0, $at) + $nl + $nl + "        // ---- The Mother, Volatile form for open spawns (Dying Light Randomiser mod) ----" + $nl + ($blk -replace "`r?`n", $nl) + $pre.Substring($at)
        $patched["data/presets/humanai.pre"] = $l1m.GetBytes($pre)
        $patched["data/ai/infected/infected_data_custom_preset_volatile_wasteland_final_sir.scr"] = "!include(`"ai_data.def`")`r`n!include(`"infected_data_custom_preset_volatile_wasteland_final.scr`")`r`n// Dying Light Randomiser mod: no light reaction, so she fights in daylight and torchlight`r`nParamBool(`"react_on_light`", 0)`r`nParamBool(`"can_react_on_light`", 0)`r`nParamBool(`"can_be_alarmed_by_flashlight`", 0)`r`n"
        "The Mother: Volatile form added as SIR_Mother_Volatile (no light reaction)"
    } else { "The Mother: Volatile_WL_Final not found in The Following's presets; Volatile form skipped" }
}

# The Mother's AI data precompiled for Harran (Harran reads custom-data presets only as .dat). Built by the mod's AI compiler from
# The Following's scripts; 14 settings it has no ID for are left at the game's defaults.
# The Following's human ghost (Ghost_WastelandSpecial) AI data for Harran: melee_fighter_a_hard's .dat plus the ghost script's own lines.
$GhostDat = @{ 'human_data_custom_preset_melee_fighter_a_hard_lvl04_ghost' = 'DQAAANEQAAAAAAAABAAAAAAAAMAAAADA/////wEAIABNX01FTEVFX0ZJR0hURVJfQV9hdHRhY2tfTGVmdF8wMQAAAAAAAADAAAAAwP////8BACAATV9NRUxFRV9GSUdIVEVSX0FfYXR0YWNrX0xlZnRfMDIAAAAAAAAAwAAAAMD/////AQAhAE1fTUVMRUVfRklHSFRFUl9BX2F0dGFja19yaWdodF8wMQAAAAAAAADAAAAAwP////8BACEATV9NRUxFRV9GSUdIVEVSX0FfYXR0YWNrX3JpZ2h0XzAyAAAAANEgAAAAAAAABAAAAAAAAMAAAADA/////wEAIQBNX01FTEVFX0ZJR0hURVJfQV9maWdodGVydGF1bnRfMDEAAAAAAAAAwAAAAMD/////AQAhAE1fTUVMRUVfRklHSFRFUl9BX2ZpZ2h0ZXJ0YXVudF8wMgAAAAAAAADAAAAAwP////8BACEATV9NRUxFRV9GSUdIVEVSX0FfZmlnaHRlcnRhdW50XzAzAAAAAAAAAMAAAADA/////wEAIABNX01FTEVFX0ZJR0hURVJfQV9mYWtlX2F0dGFja18wMQAAAADRVAAAAAAAAAQAAAAAAADAAAAAwP////8BACAATV9NRUxFRV9GSUdIVEVSX0FfYXR0YWNrX2tpY2tfMDEAAAAAAAAAwAAAAMD/////AQAgAE1fTUVMRUVfRklHSFRFUl9BX2F0dGFja19raWNrXzAyAAAAAAAAAMAAAADA/////wEAIABNX01FTEVFX0ZJR0hURVJfQV9hdHRhY2tfa2lja18wNAAAAAAAAADAAAAAwP////8BACAATV9NRUxFRV9GSUdIVEVSX0FfYXR0YWNrX2tpY2tfMDUAAAAA0XQAAAAAAAABAAAAAAAAwAAAAMD/////AQAgAE1fTUVMRUVfRklHSFRFUl9BX2F0dGFja19raWNrXzA0AAAAAAGQAAAAAAAAAwAAAAAAAMAAAADA/////wEAJwBtX21lbGVlX2ZpZ2h0ZXJfYV9hdHRhY2tfdGhyb3dfa25pZmVfMDIAAAAAAAAAwAAAAMD/////AQAnAG1fbWVsZWVfZmlnaHRlcl9hX2F0dGFja190aHJvd19rbmlmZV8wNQAAAAAAAADAAAAAwP////8BACwAbV9tZWxlZV9maWdodGVyX2FfYXR0YWNrX3Rocm93X2tuaWZlXzA1X2Zhc3QAAAAA0YwDAAAAAAACAAAAAAAAwAAAAMD/////AQAlAE1fTUVMRUVfRklHSFRFUl9BX2RvZGdlX2p1bXBfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAlAE1fTUVMRUVfRklHSFRFUl9BX2RvZGdlX2p1bXBfcmlnaHRfMDIAAAAAAagDAAAAAAABAAAAAAAAwAAAAMD/////AQAjAE1fTUVMRUVfRklHSFRFUl9BX0Nyb3VjaGluZ19sZWZ0XzAxAAAAANGMBAAAAAAAAgAAAAAAAMAAAADA/////wEAJABtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZV9qdW1wX2xlZnRfMDEAAAAAAAAAwAAAAMD/////AQAkAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlX2p1bXBfbGVmdF8wMgAAAAABqAQAAAAAAAEAAAAAAADAAAAAwP////8BACQATV9NRUxFRV9GSUdIVEVSX0FfQ3JvdWNoaW5nX3JpZ2h0XzAxAAAAANFMIAAAAAAACgAAAAAAAMAAAADA/////wEAKwBNX01FTEVFX0ZJR0hURVJfQV9hdHRhY2tfbGVmdF8zbV9yZXRyZWF0XzAxAAAAAAAAAMAAAADA/////wEALABNX01FTEVFX0ZJR0hURVJfQV9hdHRhY2tfcmlnaHRfM21fcmV0cmVhdF8wMwAAAAAAAADAAAAAwP////8BACwATV9NRUxFRV9GSUdIVEVSX0FfYmVyc2Vya2VyX3JpZ2h0XzNtXzAxX2hhcmQAAAAAAAAAwAAAAMD/////AQAnAE1fTUVMRUVfRklHSFRFUl9BX2JlcnNlcmtlcl9yaWdodF80bV8wMQAAAAAAAADAAAAAwP////8BACcATV9NRUxFRV9GSUdIVEVSX0FfYmVyc2Vya2VyX3JpZ2h0XzRtXzAyAAAAAAAAAMAAAADA/////wEAIQBNX01FTEVFX0ZJR0hURVJfQV9hdHRhY2tfY29tYm9fMDEAAAAAAAAAwAAAAMD/////AQAhAE1fTUVMRUVfRklHSFRFUl9BX2F0dGFja19jb21ib18wMgAAAAAAAADAAAAAwP////8BACEATV9NRUxFRV9GSUdIVEVSX0FfYXR0YWNrX2NvbWJvXzAzAAAAAAAAAMAAAADA/////wEAIQBNX01FTEVFX0ZJR0hURVJfQV9hdHRhY2tfY29tYm9fMDQAAAAAAAAAwAAAAMD/////AQAhAE1fTUVMRUVfRklHSFRFUl9BX2F0dGFja19jb21ib18wNgAAAADRaCAAAAAAAAQAAAAAAADAAAAAwP////8BACwAbV9tZWxlZV9maWdodGVyX2FfYXR0YWNrX2Zyb21fbW92ZV8zbV8wMV8wMDEAAAAAAAAAwAAAAMD/////AQAoAG1fbWVsZWVfZmlnaHRlcl9hX2F0dGFja19mcm9tX21vdmVfM21fMDIAAAAAAAAAwAAAAMD/////AQAoAG1fbWVsZWVfZmlnaHRlcl9hX2F0dGFja19mcm9tX21vdmVfMm1fMDMAAAAAAAAAwAAAAMD/////AQAuAG1fbWVsZWVfZmlnaHRlcl9hX2F0dGFja19jb21ib19mcm9tX21vdmVfMm1fMDEAAAAA0UwwAAAAAAAJAAAAAAAAwAAAAMD/////AQAnAE1fTUVMRUVfRklHSFRFUl9BX2JlcnNlcmtlcl9yaWdodF8zbV8wMwAAAAAAAADAAAAAwP////8BACYATV9NRUxFRV9GSUdIVEVSX0FfYmVyc2Vya2VyX2xlZnRfM21fMDMAAAAAAAAAwAAAAMD/////AQAnAE1fTUVMRUVfRklHSFRFUl9BX2JlcnNlcmtlcl9yaWdodF8zbV8wMgAAAAAAAADAAAAAwP////8BADQATV9NRUxFRV9GSUdIVEVSX0FfbWVsZWVfZmlnaHRlcmJlcnNlcmtlcl9yaWdodF8zbV8wMQAAAAAAAADAAAAAwP////8BACYATV9NRUxFRV9GSUdIVEVSX0FfYmVyc2Vya2VyX2xlZnRfM21fMDEAAAAAAAAAwAAAAMD/////AQAmAE1fTUVMRUVfRklHSFRFUl9BX2JlcnNlcmtlcl9sZWZ0XzNtXzAyAAAAAAAAAMAAAADA/////wEAJwBNX01FTEVFX0ZJR0hURVJfQV9iZXJzZXJrZXJfcmlnaHRfNG1fMDMAAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX2F0dGFja19mcm9tX3N0YW5kXzRtXzAzAAAAAAAAAMAAAADA/////wEALwBtX21lbGVlX2ZpZ2h0ZXJfYV9hdHRhY2tfY29tYm9fZnJvbV9zdGFuZF80bV8wMQAAAADRaDAAAAAAAAUAAAAAAADAAAAAwP////8BACgAbV9tZWxlZV9maWdodGVyX2FfYXR0YWNrX2Zyb21fbW92ZV80bV8wMwAAAAAAAADAAAAAwP////8BAC4AbV9tZWxlZV9maWdodGVyX2FfYXR0YWNrX2NvbWJvX2Zyb21fbW92ZV80bV8wMQAAAAAAAADAAAAAwP////8BACwAbV9tZWxlZV9maWdodGVyX2FfYXR0YWNrX2Zyb21fbW92ZV80bV8wMV8wMDEAAAAAAAAAwAAAAMD/////AQAtAG1fbWVsZWVfZmlnaHRlcl9hX2F0dGFja19mcm9tX21vdmVfaGFyZF81bV8wMQAAAAAAAADAAAAAwP////8BACgAbV9tZWxlZV9maWdodGVyX2FfYXR0YWNrX2Zyb21fbW92ZV80bV8wMgAAAAAKAAAAAQQAAAAAAAAQAAAAAAAAwAAAAMD/////AQAeAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlZG93bl8wMQAAAAAAAADAAAAAwP////8BAB4AbV9tZWxlZV9maWdodGVyX2FfZG9kZ2Vkb3duXzAyAAAAAAAAAMAAAADA/////wEAHgBtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZWRvd25fMDMAAAAAAAAAwAAAAMD/////AQAgAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlc19kb3duXzAxAAAAAAAAAMAAAADA/////wEAIABtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZXNfZG93bl8wMgAAAAAAAADAAAAAwP////8BACAAbV9tZWxlZV9maWdodGVyX2FfZG9kZ2VzX2Rvd25fMDMAAAAAAAAAwAAAAMD/////AQAgAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlc19kb3duXzA0AAAAAAAAAMAAAADA/////wEAIABtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZXNfZG93bl8wNQAAAAAAAADAAAAAwP////8BACAAbV9tZWxlZV9maWdodGVyX2FfZG9kZ2VzX2Rvd25fMDYAAAAAAAAAwAAAAMD/////AQAgAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlc19kb3duXzA3AAAAAAAAAMAAAADA/////wEAKQBtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZXNfY291bnRlcl9yaWdodF8wMQAAAAAAAADAAAAAwP////8BACkAbV9tZWxlZV9maWdodGVyX2FfZG9kZ2VzX2NvdW50ZXJfcmlnaHRfMDIAAAAAAAAAwAAAAMD/////AQAoAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlc19jb3VudGVyX2xlZnRfMDEAAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlc19jb3VudGVyX3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAKQBtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZXNfY291bnRlcl9yaWdodF8wMgAAAAAAAADAAAAAwP////8BACgAbV9tZWxlZV9maWdodGVyX2FfZG9kZ2VzX2NvdW50ZXJfbGVmdF8wMQAAAAABCAAAAAAAAAcAAAAAAADAAAAAwP////8BAB4AbV9tZWxlZV9maWdodGVyX2FfZG9kZ2Vkb3duXzAxAAAAAAAAAMAAAADA/////wEAHgBtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZWRvd25fMDIAAAAAAAAAwAAAAMD/////AQAeAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlZG93bl8wMwAAAAAAAADAAAAAwP////8BACgAbV9tZWxlZV9maWdodGVyX2FfZG9kZ2VzX2NvdW50ZXJfbGVmdF8wMQAAAAAAAADAAAAAwP////8BACkAbV9tZWxlZV9maWdodGVyX2FfZG9kZ2VzX2NvdW50ZXJfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAoAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlc19jb3VudGVyX2xlZnRfMDEAAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlc19jb3VudGVyX3JpZ2h0XzAxAAAAANEMAAAAAAAADAAAAAAAAMAAAADA/////wEAHABNX01FTEVFX0ZJR0hURVJfQV9ibG9ja19MXzAxAAAAAAAAAMAAAADA/////wEAHABNX01FTEVFX0ZJR0hURVJfQV9ibG9ja19MXzAyAAAAAAAAAMAAAADA/////wEAHABNX01FTEVFX0ZJR0hURVJfQV9ibG9ja19MXzAzAAAAAAAAAMAAAADA/////wEAHABNX01FTEVFX0ZJR0hURVJfQV9ibG9ja19MXzAzAAAAAAAAAMAAAADA/////wEAKABtX21lbGVlX2ZpZ2h0ZXJfYV9ibG9ja19yZWFjdGlvbl9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAKABtX21lbGVlX2ZpZ2h0ZXJfYV9ibG9ja19yZWFjdGlvbl9sZWZ0XzAyAAAAAAAAAMAAAADA/////wEAKABtX21lbGVlX2ZpZ2h0ZXJfYV9ibG9ja19yZWFjdGlvbl9sZWZ0XzAyAAAAAAAAAMAAAADA/////wEAKABtX21lbGVlX2ZpZ2h0ZXJfYV9ibG9ja19yZWFjdGlvbl9sZWZ0XzAzAAAAAAAAAMAAAADA/////wEAKABtX21lbGVlX2ZpZ2h0ZXJfYV9ibG9ja19yZWFjdGlvbl9sZWZ0XzA0AAAAAAAAAMAAAADA/////wEAKABtX21lbGVlX2ZpZ2h0ZXJfYV9ibG9ja19yZWFjdGlvbl9sZWZ0XzA0AAAAAAAAAMAAAADA/////wEAKQBtX21lbGVlX2ZpZ2h0ZXJfYV9ibG9ja19yZWFjdGlvbl9yaWdodF8wNQAAAAAAAADAAAAAwP////8BACgAbV9tZWxlZV9maWdodGVyX2FfZG9kZ2VzX2NvdW50ZXJfbGVmdF8wMwAAAADREAAAAAAAAA0AAAAAAADAAAAAwP////8BABwATV9NRUxFRV9GSUdIVEVSX0FfYmxvY2tfUl8wMQAAAAAAAADAAAAAwP////8BABwATV9NRUxFRV9GSUdIVEVSX0FfYmxvY2tfUl8wMgAAAAAAAADAAAAAwP////8BABwATV9NRUxFRV9GSUdIVEVSX0FfYmxvY2tfUl8wMwAAAAAAAADAAAAAwP////8BACkAbV9tZWxlZV9maWdodGVyX2FfYmxvY2tfcmVhY3Rpb25fcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX2Jsb2NrX3JlYWN0aW9uX3JpZ2h0XzAyAAAAAAAAAMAAAADA/////wEAKQBtX21lbGVlX2ZpZ2h0ZXJfYV9ibG9ja19yZWFjdGlvbl9yaWdodF8wMwAAAAAAAADAAAAAwP////8BACkAbV9tZWxlZV9maWdodGVyX2FfYmxvY2tfcmVhY3Rpb25fcmlnaHRfMDUAAAAAAAAAwAAAAMD/////AQAoAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlc19jb3VudGVyX2xlZnRfMDMAAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX2Jsb2NrX3JlYWN0aW9uX3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAKQBtX21lbGVlX2ZpZ2h0ZXJfYV9ibG9ja19yZWFjdGlvbl9yaWdodF8wMgAAAAAAAADAAAAAwP////8BACkAbV9tZWxlZV9maWdodGVyX2FfYmxvY2tfcmVhY3Rpb25fcmlnaHRfMDMAAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX2Jsb2NrX3JlYWN0aW9uX3JpZ2h0XzA1AAAAAAAAAMAAAADA/////wEAKABtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZXNfY291bnRlcl9sZWZ0XzAzAAAAANEUAAAAAAAAAQAAAAAAAMAAAADA/////wEAHQBNX01FTEVFX0ZJR0hURVJfQV9ibG9ja19VcF8wMQAAAADRGAAAAAAAAAMAAAAAAADAAAAAwP////8BAB8ATV9NRUxFRV9GSUdIVEVSX0FfYmxvY2tfRG93bl8wMQAAAAAAAADAAAAAwP////8BAB8ATV9NRUxFRV9GSUdIVEVSX0FfYmxvY2tfRG93bl8wMgAAAAAAAADAAAAAwP////8BACgAbV9tZWxlZV9maWdodGVyX2FfYmxvY2tfcmVhY3Rpb25fZG93bl8wMQAAAADRHAAAAAAAAAMAAAAAAADAAAAAwP////8BAB8ATV9NRUxFRV9GSUdIVEVSX0FfYmxvY2tfRG93bl8wMQAAAAAAAADAAAAAwP////8BAB8ATV9NRUxFRV9GSUdIVEVSX0FfYmxvY2tfRG93bl8wMgAAAAAAAADAAAAAwP////8BACgAbV9tZWxlZV9maWdodGVyX2FfYmxvY2tfcmVhY3Rpb25fZG93bl8wMQAAAAABIAAAAAAAAAIAAAAAAADAAAAAwP////8BACQATV9NRUxFRV9GSUdIVEVSX0FfZG9kZ2VfanVtcF9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAJABNX01FTEVFX0ZJR0hURVJfQV9kb2RnZV9qdW1wX2JhY2tfMDIAAAAAASQAAAAAAAABAAAAAAAAwAAAAMD/////AQAlAE1fTUVMRUVfRklHSFRFUl9BX2RvZGdlX2p1bXBfcmlnaHRfMDIAAAAAASgAAAAAAAACAAAAAAAAwAAAAMD/////AQAkAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlX2p1bXBfbGVmdF8wMgAAAAAAAADAAAAAwP////8BACQATV9NRUxFRV9GSUdIVEVSX0FfZG9kZ2VfanVtcF9sZWZ0XzAzAAAAAAcAAADBAQAAAAAAAAEAAAAAAADAAAAAwP////8BABwATV9NRUxFRV9GSUdIVEVSX0FfYWxhcm1lZF8wMQAAAADBGgAAAAAAAAEAAAAAAADAAAAAwP////8BABoAbV9tZWxlZV9maWdodGVyX2FfdHVybl80NWwAAAAAwRsAAAAAAAABAAAAAAAAwAAAAMD/////AQAaAG1fbWVsZWVfZmlnaHRlcl9hX3R1cm5fOTBsAAAAAMEdAAAAAAAAAQAAAAAAAMAAAADA/////wEAGwBtX21lbGVlX2ZpZ2h0ZXJfYV90dXJuXzE4MGwAAAAAwSIAAAAAAAABAAAAAAAAwAAAAMD/////AQAaAG1fbWVsZWVfZmlnaHRlcl9hX3R1cm5fNDVSAAAAAMEjAAAAAAAAAQAAAAAAAMAAAADA/////wEAGgBtX21lbGVlX2ZpZ2h0ZXJfYV90dXJuXzkwUgAAAADBJQAAAAAAAAEAAAAAAADAAAAAwP////8BABsAbV9tZWxlZV9maWdodGVyX2FfdHVybl8xODBSAAAAAEMAAAAhAQAAAAAAAAYAAAAAAADAAAAAwP////8BACkAbV9tZWxlZV9maWdodGVyX2FfZG9kZ2VfYmFja19yZWFjdGlvbnNfMDEAAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlX2JhY2tfcmVhY3Rpb25zXzAyAAAAAAAAAMAAAADA/////wEAKQBtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZV9iYWNrX3JlYWN0aW9uc18wMwAAAAAAAADAAAAAwP////8BACkAbV9tZWxlZV9maWdodGVyX2FfZG9kZ2VfYmFja19yZWFjdGlvbnNfMDQAAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX2RvZGdlX2JhY2tfcmVhY3Rpb25zXzA3AAAAAAAAAMAAAADA/////wEAMABtX21lbGVlX2ZpZ2h0ZXJfYV9kb2RnZV9iYWNrX2NvdW50ZXJyZWFjdGlvbnNfMDEAAAAA4QBAAAAAAAABAAAAAAAAwAAAAMD/////AQAxAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2JhY2tfMDEAAAAAEQFAAAAAAAABAAAAAAAAwAAAAMD/////AQAxAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2JhY2tfMDEAAAAA4QCAAAAAAAACAAAAAAAAwAAAAMD/////AQAyAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2Zyb250XzAxAAAAAAAAAMAAAADA/////wEAMgBNX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19mcm9udF8wMwAAAAARAYAAAAAAAAEAAAAAAADAAAAAwP////8BADIATV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fZnJvbnRfMDEAAAAA4QDAAAAAAAABAAAAAAAAwAAAAMD/////AQAxAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2xlZnRfMDEAAAAAEQHAAAAAAAABAAAAAAAAwAAAAMD/////AQAxAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2xlZnRfMDEAAAAA4QAAAQAAAAABAAAAAAAAwAAAAMD/////AQAxAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2JhY2tfMDEAAAAAEQEAAQAAAAABAAAAAAAAwAAAAMD/////AQAxAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2JhY2tfMDEAAAAAEQAAEAAAAAACAAAAAAAAwAAAAMD/////AQAyAG1fbWVsZWVfZmlnaHRlcl9hX2xpZ2h0X2hpdHJlYWN0aW9uX3RvcnNvX2Zyb250XzAxAAAAAAAAAMAAAADA/////wEAMABNX01FTEVFX0ZJR0hURVJfQV9saWdodF9oaXRyZWFjdGlvbl9oZWFkX2JhY2tfMDEAAAAAsQAAEAAAAAABAAAAAAAAwAAAAMD/////AQAxAG1fbWVsZWVfZmlnaHRlcl9hX2xpZ2h0X2hpdHJlYWN0aW9uX3RvcnNvX2JhY2tfMDIAAAAAMQBAEAAAAAABAAAAAAAAwAAAAMD/////AQAuAE1fTUVMRUVfRklHSFRFUl9BX0NvdW50ZXJhdHRhY2tfdG9yc29fcmlnaHRfMDEAAAAAEQCAEAAAAAABAAAAAAAAwAAAAMD/////AQArAE1fTUVMRUVfRklHSFRFUl9BX2hpdHJlYWN0aW9uX2JhY2tfbGlnaHRfMDEAAAAAEQABEgAAAAACAAAAAAAAwAAAAMD/////AQAqAE1fTUVMRUVfRklHSFRFUl9BX3Nob3RfcmVhY3Rpb25fYWJkb21lbl8wMQAAAAAAAADAAAAAwP////8BADIAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fZnJvbnRfMDMAAAAAEQCAEgAAAAACAAAAAAAAwAAAAMD/////AQAyAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2Zyb250XzAxAAAAAAAAAMAAAADA/////wEAMgBNX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19mcm9udF8wMwAAAAARAAEUAAAAAAIAAAAAAADAAAAAwP////8BACoATV9NRUxFRV9GSUdIVEVSX0Ffc2hvdF9yZWFjdGlvbl9hYmRvbWVuXzAxAAAAAAAAAMAAAADA/////wEAMgBtX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19mcm9udF8wMQAAAAARAIAUAAAAAAIAAAAAAADAAAAAwP////8BADIATV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fZnJvbnRfMDEAAAAAAAAAwAAAAMD/////AQAyAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2Zyb250XzAzAAAAABEAgBYAAAAAAQAAAAAAAMAAAADA/////wEAMgBNX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19mcm9udF8wMwAAAAARAAAgAAAAAAEAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfbGlnaHRfaGl0cmVhY3Rpb25faGVhZF9mcm9udF8wMQAAAACxAAAgAAAAAAEAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfbGlnaHRfaGl0cmVhY3Rpb25faGVhZF9mcm9udF8wMQAAAAAxAEAgAAAAAAEAAAAAAADAAAAAwP////8BAC0ATV9NRUxFRV9GSUdIVEVSX0FfQ291bnRlcmF0dGFja190b3Jzb19iYWNrXzAyAAAAABGAUSAAAAAABAAAAAAAAMAAAADA/////wEALABNX01FTEVFX0ZJR0hURVJfQV9oaXRyZWFjdGlvbl9raWNrX21lZGl1bV8wMQAAAAAAAADAAAAAwP////8BACwATV9NRUxFRV9GSUdIVEVSX0FfaGl0cmVhY3Rpb25fa2lja19tZWRpdW1fMDIAAAAAAAAAwAAAAMD/////AQAsAE1fTUVMRUVfRklHSFRFUl9BX2hpdHJlYWN0aW9uX2tpY2tfbWVkaXVtXzAzAAAAAAAAAMAAAADA/////wEALABNX01FTEVFX0ZJR0hURVJfQV9oaXRyZWFjdGlvbl9raWNrX21lZGl1bV8wNQAAAAAxgFEgAAAAAAEAAAAAAADAAAAAwP////8BAC0ATV9NRUxFRV9GSUdIVEVSX0FfQ291bnRlcmF0dGFja190b3Jzb19iYWNrXzAyAAAAABEAACIAAAAAAgAAAAAAAMAAAADA/////wEAMQBNX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19iYWNrXzAxAAAAAAAAAMAAAADA/////wEAMQBtX21lbGVlX2ZpZ2h0ZXJfYV9saWdodF9oaXRyZWFjdGlvbl9oZWFkX2Zyb250XzAxAAAAABEAASIAAAAAAgAAAAAAAMAAAADA/////wEAJwBNX01FTEVFX0ZJR0hURVJfQV9zaG90X3JlYWN0aW9uX2hlYWRfMDEAAAAAAAAAwAAAAMD/////AQAxAG1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2JhY2tfMDEAAAAAEQAAJAAAAAADAAAAAAAAwAAAAMD/////AQAxAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2JhY2tfMDEAAAAAAAAAwAAAAMD/////AQAuAE1fTUVMRUVfRklHSFRFUl9BX2hpdHJlYWN0aW9uX2FiZG9tZW5fbGlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAsAE1fTUVMRUVfRklHSFRFUl9BX2hpdHJlYWN0aW9uX2tpY2tfbWVkaXVtXzAxAAAAABEAASQAAAAAAwAAAAAAAMAAAADA/////wEAKwBNX01FTEVFX0ZJR0hURVJfQV9zaG90X3JlYWN0aW9uX2xlZnRfYXJtXzAxAAAAAAAAAMAAAADA/////wEALABNX01FTEVFX0ZJR0hURVJfQV9zaG90X3JlYWN0aW9uX3JpZ2h0X2FybV8wMQAAAAAAAADAAAAAwP////8BADIAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fcmlnaHRfMDEAAAAAEQAAJgAAAAABAAAAAAAAwAAAAMD/////AQAxAG1fbWVsZWVfZmlnaHRlcl9hX2xpZ2h0X2hpdHJlYWN0aW9uX3RvcnNvX2JhY2tfMDIAAAAAEQAAMAAAAAABAAAAAAAAwAAAAMD/////AQAxAG1fbWVsZWVfZmlnaHRlcl9hX2xpZ2h0X2hpdHJlYWN0aW9uX3RvcnNvX2xlZnRfMDEAAAAAMQAAMAAAAAABAAAAAAAAwAAAAMD/////AQAtAE1fTUVMRUVfRklHSFRFUl9BX0Zyb250X2NvdW50ZXJhdHRhY2tfbGVmdF8wMQAAAACxAAAwAAAAAAEAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfbGlnaHRfaGl0cmVhY3Rpb25fdG9yc29fbGVmdF8wMQAAAAAxAEAwAAAAAAEAAAAAAADAAAAAwP////8BAC0ATV9NRUxFRV9GSUdIVEVSX0FfQ291bnRlcmF0dGFja190b3Jzb19sZWZ0XzAxAAAAABEAADIAAAAAAgAAAAAAAMAAAADA/////wEAMQBNX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19iYWNrXzAxAAAAAAAAAMAAAADA/////wEAMABNX01FTEVFX0ZJR0hURVJfQV9oaXRyZWFjdGlvbl9sZWZ0X2FybV9tZWRpdW1fMDEAAAAAEQAANAAAAAADAAAAAAAAwAAAAMD/////AQAxAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2JhY2tfMDEAAAAAAAAAwAAAAMD/////AQAwAE1fTUVMRUVfRklHSFRFUl9BX2hpdHJlYWN0aW9uX2xlZnRfYXJtX21lZGl1bV8wMQAAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfbGlnaHRfaGl0cmVhY3Rpb25fdG9yc29fbGVmdF8wMQAAAAARAAA2AAAAAAIAAAAAAADAAAAAwP////8BAC8AbV9tZWxlZV9maWdodGVyX2FfbGlnaHRfaGl0cmVhY3Rpb25fbGVnX2xlZnRfMDEAAAAAAAAAwAAAAMD/////AQAwAG1fbWVsZWVfZmlnaHRlcl9hX2xpZ2h0X2hpdHJlYWN0aW9uX2xlZ3NfbGVmdF8wMQAAAAARAABAAAAAAAIAAAAAAADAAAAAwP////8BADIATV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAyAE1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX3JpZ2h0XzAxAAAAALEAAEAAAAAAAQAAAAAAAMAAAADA/////wEAMgBNX01FTEVFX0ZJR0hURVJfQV9saWdodF9oaXRyZWFjdGlvbl90b3Jzb19yaWdodF8wMQAAAAAxAEBAAAAAAAIAAAAAAADAAAAAwP////8BAC4ATV9NRUxFRV9GSUdIVEVSX0FfQ291bnRlcmF0dGFja190b3Jzb19yaWdodF8wMQAAAAAAAADAAAAAwP////8BADcATV9NRUxFRV9GSUdIVEVSX0FfY291bnRlcmF0dGFja19iZXJzZXJrZXJfaGVhZF9yaWdodF8wMQAAAAARAABCAAAAAAMAAAAAAADAAAAAwP////8BADEATV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fbGVmdF8wMQAAAAAAAADAAAAAwP////8BADIATV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAyAE1fTUVMRUVfRklHSFRFUl9BX2xpZ2h0X2hpdHJlYWN0aW9uX3RvcnNvX3JpZ2h0XzAxAAAAABEAwEIAAAAAAQAAAAAAAMAAAADA/////wEAMgBNX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19mcm9udF8wMwAAAAARAABEAAAAAAMAAAAAAADAAAAAwP////8BADEATV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fbGVmdF8wMQAAAAAAAADAAAAAwP////8BADIATV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAyAE1fTUVMRUVfRklHSFRFUl9BX2xpZ2h0X2hpdHJlYWN0aW9uX3RvcnNvX3JpZ2h0XzAxAAAAABEAwEQAAAAAAQAAAAAAAMAAAADA/////wEAMgBNX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19mcm9udF8wMwAAAAARAABGAAAAAAMAAAAAAADAAAAAwP////8BADEATV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fbGVmdF8wMQAAAAAAAADAAAAAwP////8BADAATV9NRUxFRV9GSUdIVEVSX0FfbGlnaHRfaGl0cmVhY3Rpb25fbGVnX3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAMQBtX21lbGVlX2ZpZ2h0ZXJfYV9saWdodF9oaXRyZWFjdGlvbl9sZWdzX3JpZ2h0XzAxAAAAABEAwEYAAAAAAQAAAAAAAMAAAADA/////wEAMgBNX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19mcm9udF8wMwAAAAARAABQAAAAAAEAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfbGlnaHRfaGl0cmVhY3Rpb25faGVhZF9mcm9udF8wMQAAAACxAABQAAAAAAEAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfbGlnaHRfaGl0cmVhY3Rpb25fdG9yc29fYmFja18wMQAAAAAxAEBQAAAAAAEAAAAAAADAAAAAwP////8BAC4ATV9NRUxFRV9GSUdIVEVSX0FfQ291bnRlcmF0dGFja190b3Jzb19yaWdodF8wMQAAAAARAABgAAAAAAEAAAAAAADAAAAAwP////8BADAATV9NRUxFRV9GSUdIVEVSX0FfbGlnaHRfaGl0cmVhY3Rpb25faGVhZF9iYWNrXzAxAAAAALEAAGAAAAAAAQAAAAAAAMAAAADA/////wEAMABNX01FTEVFX0ZJR0hURVJfQV9saWdodF9oaXRyZWFjdGlvbl9oZWFkX2JhY2tfMDEAAAAAMQBAYAAAAAABAAAAAAAAwAAAAMD/////AQAtAE1fTUVMRUVfRklHSFRFUl9BX0NvdW50ZXJhdHRhY2tfdG9yc29fbGVmdF8wMQAAAAARAAFyAAAAAAIAAAAAAADAAAAAwP////8BACoATV9NRUxFRV9GSUdIVEVSX0Ffc2hvdF9yZWFjdGlvbl9hYmRvbWVuXzAxAAAAAAAAAMAAAADA/////wEAMgBtX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19mcm9udF8wMwAAAAARAAF0AAAAAAYAAAAAAADAAAAAwP////8BACsATV9NRUxFRV9GSUdIVEVSX0Ffc2hvdF9yZWFjdGlvbl9sZWZ0X2FybV8wMQAAAAAAAADAAAAAwP////8BACoATV9NRUxFRV9GSUdIVEVSX0Ffc2hvdF9yZWFjdGlvbl9hYmRvbWVuXzAxAAAAAAAAAMAAAADA/////wEAKgBNX01FTEVFX0ZJR0hURVJfQV9zaG90X3JlYWN0aW9uX2FiZG9tZW5fMDEAAAAAAAAAwAAAAMD/////AQAxAG1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2xlZnRfMDMAAAAAAAAAwAAAAMD/////AQAyAG1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX2Zyb250XzAxAAAAAAAAAMAAAADA/////wEAMgBtX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19mcm9udF8wMwAAAAARAAF2AAAAAAIAAAAAAADAAAAAwP////8BADEATV9NRUxFRV9GSUdIVEVSX0FfbGlnaHRfaGl0cmVhY3Rpb25fbGVnc19yaWdodF8wMQAAAAAAAADAAAAAwP////8BADIAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fcmlnaHRfMDEAAAAAEQABggAAAAACAAAAAAAAwAAAAMD/////AQAqAE1fTUVMRUVfRklHSFRFUl9BX3Nob3RfcmVhY3Rpb25fYWJkb21lbl8wMQAAAAAAAADAAAAAwP////8BADIAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fZnJvbnRfMDEAAAAAEQABhAAAAAACAAAAAAAAwAAAAMD/////AQAsAE1fTUVMRUVfRklHSFRFUl9BX3Nob3RfcmVhY3Rpb25fcmlnaHRfYXJtXzAxAAAAAAAAAMAAAADA/////wEAMgBtX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19yaWdodF8wMQAAAAARAAGGAAAAAAIAAAAAAADAAAAAwP////8BADAATV9NRUxFRV9GSUdIVEVSX0FfbGlnaHRfaGl0cmVhY3Rpb25fbGVnc19sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAMQBtX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19sZWZ0XzAzAAAAABEAAZIAAAAABAAAAAAAAMAAAADA/////wEAJwBNX01FTEVFX0ZJR0hURVJfQV9zaG90X3JlYWN0aW9uX2hlYWRfMDEAAAAAAAAAwAAAAMD/////AQAnAE1fTUVMRUVfRklHSFRFUl9BX3Nob3RfcmVhY3Rpb25faGVhZF8wMQAAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fYmFja18wMQAAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fYmFja18wMQAAAAARAAGUAAAAAAMAAAAAAADAAAAAwP////8BACsATV9NRUxFRV9GSUdIVEVSX0Ffc2hvdF9yZWFjdGlvbl9sZWZ0X2FybV8wMQAAAAAAAADAAAAAwP////8BACsATV9NRUxFRV9GSUdIVEVSX0Ffc2hvdF9yZWFjdGlvbl9sZWZ0X2FybV8wMQAAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fbGVmdF8wMwAAAAARAAGWAAAAAAIAAAAAAADAAAAAwP////8BADAATV9NRUxFRV9GSUdIVEVSX0FfbGlnaHRfaGl0cmVhY3Rpb25fbGVnc19sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAMQBtX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19sZWZ0XzAzAAAAABEAAaIAAAAABAAAAAAAAMAAAADA/////wEAJwBNX01FTEVFX0ZJR0hURVJfQV9zaG90X3JlYWN0aW9uX2hlYWRfMDEAAAAAAAAAwAAAAMD/////AQAnAE1fTUVMRUVfRklHSFRFUl9BX3Nob3RfcmVhY3Rpb25faGVhZF8wMQAAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fYmFja18wMQAAAAAAAADAAAAAwP////8BADEAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fYmFja18wMQAAAAARAAGkAAAAAAQAAAAAAADAAAAAwP////8BACwATV9NRUxFRV9GSUdIVEVSX0Ffc2hvdF9yZWFjdGlvbl9yaWdodF9hcm1fMDEAAAAAAAAAwAAAAMD/////AQAsAE1fTUVMRUVfRklHSFRFUl9BX3Nob3RfcmVhY3Rpb25fcmlnaHRfYXJtXzAxAAAAAAAAAMAAAADA/////wEAMgBtX21lbGVlX2ZpZ2h0ZXJfYV9oZWF2eV9oaXRyZWFjdGlvbl90b3Jzb19yaWdodF8wMQAAAAAAAADAAAAAwP////8BADIAbV9tZWxlZV9maWdodGVyX2FfaGVhdnlfaGl0cmVhY3Rpb25fdG9yc29fcmlnaHRfMDEAAAAAEQABpgAAAAACAAAAAAAAwAAAAMD/////AQAxAE1fTUVMRUVfRklHSFRFUl9BX2xpZ2h0X2hpdHJlYWN0aW9uX2xlZ3NfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAyAG1fbWVsZWVfZmlnaHRlcl9hX2hlYXZ5X2hpdHJlYWN0aW9uX3RvcnNvX3JpZ2h0XzAxAAAAABEAgBADAAAAAQAAAAAAAMAAAADA/////wEAKgBNX01FTEVFX0ZJR0hURVJfQV9oaXRyZWFjdGlvbl9iYWNrX2hhcmRfMDIAAAAAEYCREAMAAAABAAAAAAAAwAAAAMD/////AQAqAE1fTUVMRUVfRklHSFRFUl9BX2hpdHJlYWN0aW9uX2JhY2tfaGFyZF8wMQAAAAARgFEgAwAAAAEAAAAAAADAAAAAwP////8BACoATV9NRUxFRV9GSUdIVEVSX0FfaGl0cmVhY3Rpb25fa2lja19oYXJkXzAxAAAAABEAAEIDAAAAAQAAAAAAAMAAAADA/////wEAMQBNX01FTEVFX0ZJR0hURVJfQV9oaXRyZWFjdGlvbl9yaWdodF9hcm1fbWVkaXVtXzAxAAAAABEAAEQDAAAAAQAAAAAAAMAAAADA/////wEAMQBNX01FTEVFX0ZJR0hURVJfQV9oaXRyZWFjdGlvbl9yaWdodF9hcm1fbWVkaXVtXzAxAAAAAAAAAAAWAAAAkQEAAAAAAAACAAAAAAAAwAAAAMD/////AQAYAE1fTUVMRUVfRklHSFRFUl9jbGltYl8wMQAAAAAAAADAAAAAwP////8BABwATV9NRUxFRV9GSUdIVEVSX0FfSnVtcF9vbl8xbQAAAAChAQAAAAAAAAEAAAAAAADAAAAAwP////8BABoATV9NRUxFRV9GSUdIVEVSX0FfSnVtcF9vZmYAAAAA0QEAAAAAAAABAAAAAAAAwAAAAMD/////AQAZAE1fTUVMRUVfRklHSFRFUl9BX0p1bXBfb24AAAAA4QEAAAAAAAABAAAAAAAAwAAAAMD/////AQAaAE1fTUVMRUVfRklHSFRFUl9BX0p1bXBfb2ZmAAAAAPEBAAAAAAAAAQAAAAAAAMAAAADA/////wEAIwBNX01FTEVFX0ZJR0hURVJfQV9KdW1wX292ZXJfaGlnaF8wMQAAAAARAgAAAAAAAAEAAAAAAADAAAAAwP////8BAB4ATV9NRUxFRV9GSUdIVEVSX0FfSnVtcF9vdmVyXzAxAAAAACECAAAAAAAAAQAAAAAAAMAAAADA/////wEAIwBNX01FTEVFX0ZJR0hURVJfQV9KdW1wX292ZXJfaGlnaF8wMQAAAACRCQAAAAAAAAUAAAAAAADAAAAAwP////8BABYAbXppX3Vwc2V0X3NwcmludGp1bXB1cAAAAAAAAADAAAAAwP////8BABsAbXppX3Vwc2V0X3NwcmludGp1bXB1cF9sbGVnAAAAAAAAAMAAAADA/////wEAFgBwcmltZV9jbGltYmluZ191cF8zXzNtAAAAAAAAAMAAAADA/////wEAFgBwcmltZV9jbGltYmluZ191cF82XzZtAAAAAAAAAMAAAADA/////wEAFgBwcmltZV9jbGltYmluZ191cF85XzltAAAAAKEJAAAAAAAABwAAAAAAAMAAAADA/////wEAGABpbmZlY3RlZF9qdW1wX2Rvd25fM21fMDEAAAAAAAAAwAAAAMD/////AQAYAGluZmVjdGVkX2p1bXBfZG93bl8zbV8wMgAAAAAAAADAAAAAwP////8BABgAaW5mZWN0ZWRfanVtcF9kb3duXzNtXzAzAAAAAAAAAMAAAADA/////wEAFgBtemlfdXBzZXRfanVtcF9kb3duXzAxAAAAAAAAAMAAAADA/////wEAGABwcmltZV9jbGltYmluZ19kb3duXzNfM20AAAAAAAAAwAAAAMD/////AQAYAHByaW1lX2NsaW1iaW5nX2Rvd25fNl82bQAAAAAAAADAAAAAwP////8BABgAcHJpbWVfY2xpbWJpbmdfZG93bl85XzltAAAAAAEKAAAAAAAABAAAAAAAAMAAAADA/////wEAIgBwcmltZV9jbGltYmluZ191cF8zXzNtX292ZXJiYXJyaWVyAAAAAAAAAMAAAADA/////wEAIgBwcmltZV9jbGltYmluZ191cF82XzZtX292ZXJiYXJyaWVyAAAAAAAAAMAAAADA/////wEAIgBwcmltZV9jbGltYmluZ191cF85XzltX292ZXJiYXJyaWVyAAAAAAAAAMAAAADA/////wEAHQBtemlfdXBzZXRfc3ByaW50YmFycmllcmp1bXB1cAAAAACBCgAAAAAAAAEAAAAAAADAAAAAwP////8BAA8AcHJpbWVfc3ByaW50XzAyAAAAAJEKAAAAAAAAAQAAAAAAAMAAAADA/////wEADwBwcmltZV9zcHJpbnRfMDIAAAAAYQoaAAAAAAABAAAAAAAAwAAAAMD/////AQAlAG1fbWVsZWVfZmlnaHRlcl9hX3BhdHJvbF93YWxrX2xvb3BfMDEAAAAAcQoaAAAAAAACAAAAAAAAwAAAAMD/////AQAeAG1fbWVsZWVfZmlnaHRlcl9hX3Ryb3RfbG9vcF8wMQAAAAAAAADAAAAAwP////8BAB4AbV9tZWxlZV9maWdodGVyX2FfdHJvdF9sb29wXzAyAAAAAIEKGgAAAAAABAAAAAAAAMAAAADA/////wEAHQBNX01FTEVFX0ZJR0hURVJfQV9SdW5fbG9vcF8wMwAAAAAAAADAAAAAwP////8BAB0ATV9NRUxFRV9GSUdIVEVSX0FfUnVuX2xvb3BfMDEAAAAAAAAAwAAAAMD/////AQAeAG1fbWVsZWVfZmlnaHRlcl9hX3Ryb3RfbG9vcF8wMgAAAAAAAADAAAAAwP////8BAB4AbV9tZWxlZV9maWdodGVyX2FfdHJvdF9sb29wXzAyAAAAAJEKGgAAAAAAAgAAAAAAAMAAAADA/////wEAHQBNX01FTEVFX0ZJR0hURVJfQV9SdW5fbG9vcF8wMQAAAAAAAADAAAAAwP////8BAB0ATV9NRUxFRV9GSUdIVEVSX0FfUnVuX2xvb3BfMDMAAAAAYRIaAAAAAAABAAAAAAAAwAAAAMD/////AQAiAG1fbWVsZWVfZmlnaHRlcl9hX3N0cmFmZV9iYWNrX2xvb3AAAAAAcRIaAAAAAAABAAAAAAAAwAAAAMD/////AQAiAG1fbWVsZWVfZmlnaHRlcl9hX3N0cmFmZV9iYWNrX2xvb3AAAAAAYRoaAAAAAAABAAAAAAAAwAAAAMD/////AQAiAE1fTUVMRUVfRklHSFRFUl9BX3N0cmFmZV9sZWZ0X2xvb3AAAAAAcRoaAAAAAAABAAAAAAAAwAAAAMD/////AQAiAG1fbWVsZWVfZmlnaHRlcl9hX3N0cmFmZV9sZWZ0X2xvb3AAAAAAYSIaAAAAAAABAAAAAAAAwAAAAMD/////AQAjAE1fTUVMRUVfRklHSFRFUl9BX3N0cmFmZV9yaWdodF9sb29wAAAAAHEiGgAAAAAAAQAAAAAAAMAAAADA/////wEAIwBtX21lbGVlX2ZpZ2h0ZXJfYV9zdHJhZmVfcmlnaHRfbG9vcAAAAAAAAAAAEgAAAAEwAgAAAAAAAQAAAAAAAMAAAADA/////wEAIgBNX01FTEVFX0ZJR0hURVJfQV9wcmVwYXJlX1R1cm5fNDVMAAAAABEwAgAAAAAAAQAAAAAAAMAAAADA/////wEAIgBNX01FTEVFX0ZJR0hURVJfQV9wcmVwYXJlX1R1cm5fNDVMAAAAAGE1AgAAAAAAAQAAAAAAAMAAAADA/////wEAHQBtX25wY19hazQ3X2FpbV9yb3RhdGU0NWxfbGxlZwAAAAABQAIAAAAAAAEAAAAAAADAAAAAwP////8BACIATV9NRUxFRV9GSUdIVEVSX0FfcHJlcGFyZV9UdXJuXzQ1UgAAAAARQAIAAAAAAAEAAAAAAADAAAAAwP////8BACIATV9NRUxFRV9GSUdIVEVSX0FfcHJlcGFyZV9UdXJuXzQ1UgAAAABhRQIAAAAAAAEAAAAAAADAAAAAwP////8BAB0AbV9ucGNfYWs0N19haW1fcm90YXRlNDVyX2xsZWcAAAAAATADAAAAAAABAAAAAAAAwAAAAMD/////AQAaAG1fbWVsZWVfZmlnaHRlcl9hX3R1cm5fOTBsAAAAABEwAwAAAAAAAQAAAAAAAMAAAADA/////wEAGgBtX21lbGVlX2ZpZ2h0ZXJfYV90dXJuXzkwbAAAAABhNQMAAAAAAAEAAAAAAADAAAAAwP////8BAB0AbV9ucGNfYWs0N19hbGFybWluZ191cHNldF85MGwAAAAAAUADAAAAAAABAAAAAAAAwAAAAMD/////AQAaAG1fbWVsZWVfZmlnaHRlcl9hX3R1cm5fOTByAAAAABFAAwAAAAAAAQAAAAAAAMAAAADA/////wEAGgBtX21lbGVlX2ZpZ2h0ZXJfYV90dXJuXzkwUgAAAABhRQMAAAAAAAEAAAAAAADAAAAAwP////8BAB0AbV9ucGNfYWs0N19hbGFybWluZ191cHNldF85MHIAAAAAATAFAAAAAAABAAAAAAAAwAAAAMD/////AQAbAG1fbWVsZWVfZmlnaHRlcl9hX3R1cm5fMTgwbAAAAAARMAUAAAAAAAEAAAAAAADAAAAAwP////8BABsAbV9tZWxlZV9maWdodGVyX2FfdHVybl8xODBsAAAAAGE1BQAAAAAAAQAAAAAAAMAAAADA/////wEAHgBtX25wY19hazQ3X2FsYXJtaW5nX3Vwc2V0XzE4MGwAAAAAAUAFAAAAAAABAAAAAAAAwAAAAMD/////AQAbAG1fbWVsZWVfZmlnaHRlcl9hX3R1cm5fMTgwcgAAAAARQAUAAAAAAAEAAAAAAADAAAAAwP////8BABsAbV9tZWxlZV9maWdodGVyX2FfdHVybl8xODByAAAAAGFFBQAAAAAAAQAAAAAAAMAAAADA/////wEAHgBtX25wY19hazQ3X2FsYXJtaW5nX3Vwc2V0XzE4MGwAAAAAEgAAAAFwCgAAAAAAAQAAAAAAAMAAAADA/////wEAHwBtX21lbGVlX2ZpZ2h0ZXJfYV90cm90X3N0YXJ0XzAxAAAAAAGACgAAAAAAAgAAAAAAAMAAAADA/////wEAHwBtX21lbGVlX2ZpZ2h0ZXJfYV90cm90X3N0YXJ0XzAxAAAAAAAAAMAAAADA/////wEAHwBtX21lbGVlX2ZpZ2h0ZXJfYV90cm90X3N0YXJ0XzAyAAAAAAFw2gAAAAAAAQAAAAAAAMAAAADA/////wEAIABtX21lbGVlX2ZpZ2h0ZXJfYV90cm90X3N0YXJ0XzkwbAAAAAABgNoAAAAAAAIAAAAAAADAAAAAwP////8BACIATV9NRUxFRV9GSUdIVEVSX0FfUnVuX1N0YXJ0XzkwTF8wMQAAAAAAAADAAAAAwP////8BACAAbV9tZWxlZV9maWdodGVyX2FfdHJvdF9zdGFydF85MGwAAAAAAXDqAAAAAAABAAAAAAAAwAAAAMD/////AQAhAG1fbWVsZWVfZmlnaHRlcl9hX3Ryb3Rfc3RhcnRfMTgwbAAAAAABgOoAAAAAAAIAAAAAAADAAAAAwP////8BACMAbV9tZWxlZV9maWdodGVyX2FfcnVuX3N0YXJ0XzE4MGxfMDEAAAAAAAAAwAAAAMD/////AQAhAG1fbWVsZWVfZmlnaHRlcl9hX3Ryb3Rfc3RhcnRfMTgwbAAAAAABcBoBAAAAAAEAAAAAAADAAAAAwP////8BACAAbV9tZWxlZV9maWdodGVyX2FfdHJvdF9zdGFydF85MHIAAAAAAYAaAQAAAAACAAAAAAAAwAAAAMD/////AQAiAE1fTUVMRUVfRklHSFRFUl9BX1J1bl9TdGFydF85MFJfMDEAAAAAAAAAwAAAAMD/////AQAgAG1fbWVsZWVfZmlnaHRlcl9hX3Ryb3Rfc3RhcnRfOTByAAAAAAFwKgEAAAAAAQAAAAAAAMAAAADA/////wEAIQBtX21lbGVlX2ZpZ2h0ZXJfYV90cm90X3N0YXJ0XzE4MHIAAAAAAYAqAQAAAAACAAAAAAAAwAAAAMD/////AQAjAG1fbWVsZWVfZmlnaHRlcl9hX3J1bl9zdGFydF8xODByXzAxAAAAAAAAAMAAAADA/////wEAIQBtX21lbGVlX2ZpZ2h0ZXJfYV90cm90X3N0YXJ0XzE4MHIAAAAAAQBABAAAAAABAAAAAAAAwAAAAMD/////AQAnAG1fbWVsZWVfZmlnaHRlcl9hX3N0cmFmZV9mcm9udF9zdGFydF8wMQAAAABBc0IEAAAAAAEAAAAAAADAAAAAwP////8BACcAbV9tZWxlZV9maWdodGVyX2Ffc3RyYWZlX2Zyb250X3N0YXJ0XzAxAAAAAAEAgAQAAAAAAQAAAAAAAMAAAADA/////wEAJgBtX21lbGVlX2ZpZ2h0ZXJfYV9zdHJhZmVfYmFja19zdGFydF8wMQAAAABBc4IEAAAAAAEAAAAAAADAAAAAwP////8BACYAbV9tZWxlZV9maWdodGVyX2Ffc3RyYWZlX2JhY2tfc3RhcnRfMDEAAAAAAQDABAAAAAABAAAAAAAAwAAAAMD/////AQAmAG1fbWVsZWVfZmlnaHRlcl9hX3N0cmFmZV9zdGFydF9sZWZ0XzAxAAAAAEFzwgQAAAAAAQAAAAAAAMAAAADA/////wEAJgBtX21lbGVlX2ZpZ2h0ZXJfYV9zdHJhZmVfc3RhcnRfbGVmdF8wMQAAAAABAAAFAAAAAAEAAAAAAADAAAAAwP////8BACcAbV9tZWxlZV9maWdodGVyX2Ffc3RyYWZlX3N0YXJ0X3JpZ2h0XzAxAAAAAEFzAgUAAAAAAQAAAAAAAMAAAADA/////wEAJwBtX21lbGVlX2ZpZ2h0ZXJfYV9zdHJhZmVfc3RhcnRfcmlnaHRfMDEAAAAAGQAAAEFjCgAAAAAAAgAAAAAAAMAAAADA/////wEAKwBtX21lbGVlX2ZpZ2h0ZXJfYV9wYXRyb2xfd2Fsa19zdG9wX2Zyb250XzAxAAAAAAAAAMAAAADA/////wEAKwBtX21lbGVlX2ZpZ2h0ZXJfYV9wYXRyb2xfd2Fsa19zdG9wX2Zyb250XzAyAAAAAAFwCgAAAAAAAgAAAAAAAMAAAADA/////wEAHgBtX21lbGVlX2ZpZ2h0ZXJfYV90cm90X3N0b3BfMDEAAAAAAAAAwAAAAMD/////AQAeAG1fbWVsZWVfZmlnaHRlcl9hX3Ryb3Rfc3RvcF8wMgAAAAABgAoAAAAAAAMAAAAAAADAAAAAwP////8BAB4AbV9tZWxlZV9maWdodGVyX2FfdHJvdF9zdG9wXzAxAAAAAAAAAMAAAADA/////wEAHgBtX21lbGVlX2ZpZ2h0ZXJfYV90cm90X3N0b3BfMDIAAAAAAAAAwAAAAMD/////AQAdAE1fTUVMRUVfRklHSFRFUl9BX1J1bl9TdG9wXzAxAAAAAAGQCgAAAAAAAQAAAAAAAMAAAADA/////wEAHQBNX01FTEVFX0ZJR0hURVJfQV9SdW5fU3RvcF8wMQAAAABBY9oAAAAAAAEAAAAAAADAAAAAwP////8BACkAbV9tZWxlZV9maWdodGVyX2FfcGF0cm9sX3dhbGtfc3RvcF85MGxfMDEAAAAAAYDaAAAAAAABAAAAAAAAwAAAAMD/////AQAeAE1fTUVMRUVfRklHSFRFUl9BX1J1bl9TdG9wXzkwTAAAAABBY+oAAAAAAAEAAAAAAADAAAAAwP////8BACoAbV9tZWxlZV9maWdodGVyX2FfcGF0cm9sX3dhbGtfc3RvcF8xODBsXzAxAAAAAAGA6gAAAAAAAQAAAAAAAMAAAADA/////wEAIgBtX21lbGVlX2ZpZ2h0ZXJfYV9ydW5fc3RvcF8xODBsXzAxAAAAAEFjGgEAAAAAAQAAAAAAAMAAAADA/////wEAKQBtX21lbGVlX2ZpZ2h0ZXJfYV9wYXRyb2xfd2Fsa19zdG9wXzkwcl8wMQAAAAABgBoBAAAAAAEAAAAAAADAAAAAwP////8BAB4ATV9NRUxFRV9GSUdIVEVSX0FfUnVuX1N0b3BfOTBSAAAAAEFjKgEAAAAAAQAAAAAAAMAAAADA/////wEAKgBtX21lbGVlX2ZpZ2h0ZXJfYV9wYXRyb2xfd2Fsa19zdG9wXzE4MHJfMDEAAAAAAYAqAQAAAAABAAAAAAAAwAAAAMD/////AQAiAG1fbWVsZWVfZmlnaHRlcl9hX3J1bl9zdG9wXzE4MHJfMDEAAAAAQWMKBAAAAAACAAAAAAAAwAAAAMD/////AQArAG1fbWVsZWVfZmlnaHRlcl9hX3BhdHJvbF93YWxrX3N0b3BfZnJvbnRfMDEAAAAAAAAAwAAAAMD/////AQArAG1fbWVsZWVfZmlnaHRlcl9hX3BhdHJvbF93YWxrX3N0b3BfZnJvbnRfMDIAAAAAQWPaBAAAAAABAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX3BhdHJvbF93YWxrX3N0b3BfOTBsXzAxAAAAAEFj6gQAAAAAAQAAAAAAAMAAAADA/////wEAKgBtX21lbGVlX2ZpZ2h0ZXJfYV9wYXRyb2xfd2Fsa19zdG9wXzE4MGxfMDEAAAAAQWMaBQAAAAABAAAAAAAAwAAAAMD/////AQApAG1fbWVsZWVfZmlnaHRlcl9hX3BhdHJvbF93YWxrX3N0b3BfOTByXzAxAAAAAEFjKgUAAAAAAQAAAAAAAMAAAADA/////wEAKgBtX21lbGVlX2ZpZ2h0ZXJfYV9wYXRyb2xfd2Fsa19zdG9wXzE4MHJfMDEAAAAAAQBACAAAAAABAAAAAAAAwAAAAMD/////AQArAG1fbWVsZWVfZmlnaHRlcl9hX3BhdHJvbF93YWxrX3N0b3BfZnJvbnRfMDEAAAAAQXNCCAAAAAABAAAAAAAAwAAAAMD/////AQAmAG1fbWVsZWVfZmlnaHRlcl9hX3N0cmFmZV9mcm9udF9zdG9wXzAxAAAAAAEAgAgAAAAAAQAAAAAAAMAAAADA/////wEAJQBtX21lbGVlX2ZpZ2h0ZXJfYV9zdHJhZmVfYmFja19zdG9wXzAxAAAAAEFzgggAAAAAAQAAAAAAAMAAAADA/////wEAJQBtX21lbGVlX2ZpZ2h0ZXJfYV9zdHJhZmVfYmFja19zdG9wXzAxAAAAAAEAwAgAAAAAAQAAAAAAAMAAAADA/////wEAJQBtX21lbGVlX2ZpZ2h0ZXJfYV9zdHJhZmVfc3RvcF9sZWZ0XzAxAAAAAEFzwggAAAAAAQAAAAAAAMAAAADA/////wEAJQBtX21lbGVlX2ZpZ2h0ZXJfYV9zdHJhZmVfc3RvcF9sZWZ0XzAxAAAAAAEAAAkAAAAAAQAAAAAAAMAAAADA/////wEAJgBtX21lbGVlX2ZpZ2h0ZXJfYV9zdHJhZmVfc3RvcF9yaWdodF8wMQAAAABBcwIJAAAAAAEAAAAAAADAAAAAwP////8BACYAbV9tZWxlZV9maWdodGVyX2Ffc3RyYWZlX3N0b3BfcmlnaHRfMDEAAAAAGAAAAAGA0gAAAAAAAgAAAAAAAMAAAADA/////wEAGwBJbmZlY3RlZF9zcHJpbnRfdHVybl80NUxfMDEAAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzQ1TF8wMgAAAAABkNIAAAAAAAIAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fNDVMXzAxAAAAAAAAAMAAAADA/////wEAGwBJbmZlY3RlZF9zcHJpbnRfdHVybl80NUxfMDIAAAAAAYDaAAAAAAACAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzkwTF8wMQAAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fOTBMXzAyAAAAAAGQ2gAAAAAAAgAAAAAAAMAAAADA/////wEAGwBJbmZlY3RlZF9zcHJpbnRfdHVybl85MExfMDEAAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzkwTF8wMgAAAAABgOoAAAAAAAEAAAAAAADAAAAAwP////8BABsAbXppX3Vwc2V0X3NwcmludF90dXJuXzE4MF9sAAAAAAGQ6gAAAAAAAQAAAAAAAMAAAADA/////wEAGwBtemlfdXBzZXRfc3ByaW50X3R1cm5fMTgwX2wAAAAAAYASAQAAAAABAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzQ1Ul8wMQAAAAABkBIBAAAAAAEAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fNDVSXzAxAAAAAAGAGgEAAAAABAAAAAAAAMAAAADA/////wEAGwBJbmZlY3RlZF9zcHJpbnRfdHVybl85MFJfMDEAAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzkwUl8wMgAAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fOTBSXzAzAAAAAAAAAMAAAADA/////wEAGwBJbmZlY3RlZF9zcHJpbnRfdHVybl85MFJfMDMAAAAAAZAaAQAAAAACAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzkwUl8wMQAAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fOTBSXzAyAAAAAAGAKgEAAAAAAQAAAAAAAMAAAADA/////wEAGwBtemlfdXBzZXRfc3ByaW50X3R1cm5fMTgwX3IAAAAAAZAqAQAAAAABAAAAAAAAwAAAAMD/////AQAbAG16aV91cHNldF9zcHJpbnRfdHVybl8xODBfcgAAAAABgNIEAAAAAAIAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fNDVMXzAxAAAAAAAAAMAAAADA/////wEAIgBJbmZlY3RlZF9zcHJpbnRfdHVybl80NUxfMDJfc3VkZGVuAAAAAAGQ0gQAAAAAAgAAAAAAAMAAAADA/////wEAGwBJbmZlY3RlZF9zcHJpbnRfdHVybl80NUxfMDEAAAAAAAAAwAAAAMD/////AQAiAEluZmVjdGVkX3NwcmludF90dXJuXzQ1TF8wMl9zdWRkZW4AAAAAAYDaBAAAAAACAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzkwTF8wMQAAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fOTBMXzAyAAAAAAGQ2gQAAAAAAgAAAAAAAMAAAADA/////wEAGwBJbmZlY3RlZF9zcHJpbnRfdHVybl85MExfMDEAAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzkwTF8wMgAAAAABgOoEAAAAAAEAAAAAAADAAAAAwP////8BABsAbXppX3Vwc2V0X3NwcmludF90dXJuXzE4MF9sAAAAAAGQ6gQAAAAAAQAAAAAAAMAAAADA/////wEAGwBtemlfdXBzZXRfc3ByaW50X3R1cm5fMTgwX2wAAAAAAYASBQAAAAABAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzQ1Ul8wMQAAAAABkBIFAAAAAAEAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fNDVSXzAxAAAAAAGAGgUAAAAABAAAAAAAAMAAAADA/////wEAGwBJbmZlY3RlZF9zcHJpbnRfdHVybl85MFJfMDEAAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzkwUl8wMgAAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fOTBSXzAzAAAAAAAAAMAAAADA/////wEAGwBJbmZlY3RlZF9zcHJpbnRfdHVybl85MFJfMDMAAAAAAZAaBQAAAAACAAAAAAAAwAAAAMD/////AQAbAEluZmVjdGVkX3NwcmludF90dXJuXzkwUl8wMQAAAAAAAADAAAAAwP////8BABsASW5mZWN0ZWRfc3ByaW50X3R1cm5fOTBSXzAyAAAAAAGAKgUAAAAAAQAAAAAAAMAAAADA/////wEAGwBtemlfdXBzZXRfc3ByaW50X3R1cm5fMTgwX3IAAAAAAZAqBQAAAAABAAAAAAAAwAAAAMD/////AQAbAG16aV91cHNldF9zcHJpbnRfdHVybl8xODBfcgAAAAAGAAAAQQAAAAAAAAABAAAAAAAAwAAAAMD/////AQAZAE1fTUVMRUVfRklHSFRFUl9BX2lkbGVfMDEAAAAAAQIAAAAAAAACAAAAAAAAwAAAAMD/////AQAhAE1fTUVMRUVfRklHSFRFUl9BX2ZpZ2h0ZXJ0YXVudF8wMQAAAAAAAADAAAAAwP////8BACEATV9NRUxFRV9GSUdIVEVSX0FfZmlnaHRlcnRhdW50XzAzAAAAAEEDAAAAAAAAAQAAAAAAAMAAAADA/////wEAGQBNX01FTEVFX0ZJR0hURVJfQV9pZGxlXzAxAAAAAEEKAAAAAAAAAwAAAAAAAMAAAADA/////wEAIABNX01FTEVFX0ZJR0hURVJfQV9maWdodF9vdXRyb18wNAAAAAAAAADAAAAAwP////8BACAATV9NRUxFRV9GSUdIVEVSX0FfZmlnaHRfb3V0cm9fMDUAAAAAAAAAwAAAAMD/////AQAgAE1fTUVMRUVfRklHSFRFUl9BX2ZpZ2h0X291dHJvXzA4AAAAAIEKAAAAAAAABAAAAAAAAMAAAADA/////wEAIABNX01FTEVFX0ZJR0hURVJfQV9maWdodF9vdXRyb18wMQAAAAAAAADAAAAAwP////8BACAATV9NRUxFRV9GSUdIVEVSX0FfZmlnaHRfb3V0cm9fMDIAAAAAAAAAwAAAAMD/////AQAgAG1fbWVsZWVfZmlnaHRlcl9hX2ZpZ2h0X291dHJvXzA5AAAAAAAAAMAAAADA/////wEAIABtX21lbGVlX2ZpZ2h0ZXJfYV9maWdodF9vdXRyb18xMAAAAADB1wAAAAAAAAQAAAAAAADAAAAAwP////8BACMATV9NRUxFRV9GSUdIVEVSX0FfYXR0YWNrX3ByZXBhcmVfMDEAAAAAAAAAwAAAAMD/////AQAjAE1fTUVMRUVfRklHSFRFUl9BX2F0dGFja19wcmVwYXJlXzAyAAAAAAAAAMAAAADA/////wEAIwBNX01FTEVFX0ZJR0hURVJfQV9hdHRhY2tfcHJlcGFyZV8wMwAAAAAAAADAAAAAwP////8BACEATV9NRUxFRV9GSUdIVEVSX0FfZmlnaHRlcnRhdW50XzAyAAAAAA8AAAABAAQAAAAAAAEAAAAAAADAAAAAwP////8BAB4AbV96b21iaWVfZGVhdGhfZGVjYXBpdGF0aW9uXzAxAAAAAAEADAAAAAAAAQAAAAAAAMAAAADA/////wEAJgBtX21lbGVlX2ZpZ2h0ZXJfZGVhdGhfcmVhY3Rpb25fYnVybl8wMQAAAAABABAAAAAAAAIAAAAAAADAAAAAwP////8BAB8AbV96b21iaWVfZGVhdGhfZWxlY3Ryb2N1dGlvbl8wMQAAAAAAAADAAAAAwP////8BAB8AbV96b21iaWVfZGVhdGhfZWxlY3Ryb2N1dGlvbl8wMgAAAAABwBAAAAAAAAEAAAAAAADAAAAAwP////8BAB8AbV96b21iaWVfZGVhdGhfZWxlY3Ryb2N1dGlvbl8wMQAAAAABABEAAAAAAAEAAAAAAADAAAAAwP////8BAB8AbV96b21iaWVfZGVhdGhfZWxlY3Ryb2N1dGlvbl8wMgAAAAABQCgAAAAAAAEAAAAAAADAAAAAwP////8BACgATV9NRUxFRV9GSUdIVEVSX0FfZGVhdGhfcmVhY3Rpb25fYmFja18wMQAAAAABgCgAAAAAAAIAAAAAAADAAAAAwP////8BACsATV9NRUxFRV9GSUdIVEVSX0FfZGVhdGhfcmVhY3Rpb25fYWJkb21lbl8wMQAAAAAAAADAAAAAwP////8BACgATV9NRUxFRV9GSUdIVEVSX0FfZGVhdGhfcmVhY3Rpb25faGVhZF8wMQAAAAABwCgAAAAAAAEAAAAAAADAAAAAwP////8BACkATV9NRUxFRV9GSUdIVEVSX0FfZGVhdGhfcmVhY3Rpb25fcmlnaHRfMDEAAAAAAQApAAAAAAABAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX2RlYXRoX3JlYWN0aW9uX2xlZnRfMDEAAAAAAUApAAAAAAABAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX2RlYXRoX3JlYWN0aW9uX2JhY2tfMDEAAAAAAYApAAAAAAABAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX2RlYXRoX3JlYWN0aW9uX2JhY2tfMDEAAAAAAcApAAAAAAABAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX2RlYXRoX3JlYWN0aW9uX2JhY2tfMDEAAAAAAQAqAAAAAAABAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX2RlYXRoX3JlYWN0aW9uX2JhY2tfMDEAAAAAAUAqAAAAAAACAAAAAAAAwAAAAMD/////AQArAE1fTUVMRUVfRklHSFRFUl9BX2RlYXRoX3JlYWN0aW9uX2FiZG9tZW5fMDEAAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX2RlYXRoX3JlYWN0aW9uX2hlYWRfMDEAAAAAAYAqAAAAAAACAAAAAAAAwAAAAMD/////AQArAE1fTUVMRUVfRklHSFRFUl9BX2RlYXRoX3JlYWN0aW9uX2FiZG9tZW5fMDEAAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX2RlYXRoX3JlYWN0aW9uX2hlYWRfMDEAAAAAAQAAAAEAAAAAAAAABAAAAAAAAMAAAADA/////wEAIgBNX01FTEVFX0ZJR0hURVJfQV9zdGFuZF91cF9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAIwBNX01FTEVFX0ZJR0hURVJfQV9zdGFuZF91cF9mcm9udF8wMQAAAAAAAADAAAAAwP////8BACkATV9NRUxFRV9GSUdIVEVSX0Ffc3RhbmRfdXBfcGFuaWNfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX3N0YW5kX3VwX3BhbmljX2xlZnRfMDEAAAAAAAAAAAAAAAAAAAAAAwAAAEEAAAAAAAAAAwAAAAAAAMAAAADA/////wEAIwBNX01FTEVFX0ZJR0hURVJfQV9SZWFjdGlvbnNfYnVybl8wMQAAAAAAAADAAAAAwP////8BACMATV9NRUxFRV9GSUdIVEVSX0FfUmVhY3Rpb25zX2J1cm5fMDIAAAAAAAAAwAAAAMD/////AQAjAE1fTUVMRUVfRklHSFRFUl9BX1JlYWN0aW9uc19idXJuXzAzAAAAAEIAAAAAAAAAAgAAAAAAAMAAAADA/////wEAKgBNX01FTEVFX0ZJR0hURVJfQV9SZWFjdGlvbnNfZWxlY3RyaWZpZWRfMDEAAAAAAAAAwAAAAMD/////AQAqAE1fTUVMRUVfRklHSFRFUl9BX1JlYWN0aW9uc19lbGVjdHJpZmllZF8wMgAAAABDAAAAAAAAAAIAAAAAAADAAAAAwP////8BACIAbV9tZWxlZV9maWdodGVyX3JlYWN0aW9uc190b3hpY18wMQAAAAAAAADAAAAAwP////8BACIAbV9tZWxlZV9maWdodGVyX3JlYWN0aW9uc190b3hpY18wMgAAAAAAAAAAAAAAABgAAAABNAAAAAAAAAEAAAAAAADAAAAAwP////8BACgATV9NRUxFRV9GSUdIVEVSX0FfbmFnZXdhemFfYmFja18wMV9iZWdpbgAAAAACNAAAAAAAAAEAAAAAAADAAAAAwP////8BACkATV9NRUxFRV9GSUdIVEVSX0FfbmFnZXdhemFfYmFja18wMV9maW5pc2gAAAAAETQAAAAAAAABAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX25hZ2V3YXphX2JhY2tfMDFfYmVnaW4AAAAAEjQAAAAAAAABAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX25hZ2V3YXphX2JhY2tfMDFfYmVnaW4AAAAA0TQAAAAAAAABAAAAAAAAwAAAAMD/////AQApAE1fTUVMRUVfRklHSFRFUl9BX25hZ2V3YXphX2JhY2tfMDFfZmluaXNoAAAAANI0AAAAAAAAAQAAAAAAAMAAAADA/////wEAKQBNX01FTEVFX0ZJR0hURVJfQV9uYWdld2F6YV9iYWNrXzAxX2ZpbmlzaAAAAAABOAAAAAAAAAEAAAAAAADAAAAAwP////8BACgATV9NRUxFRV9GSUdIVEVSX0FfbmFnZXdhemFfYmFja18wMV9iZWdpbgAAAAACOAAAAAAAAAEAAAAAAADAAAAAwP////8BACkATV9NRUxFRV9GSUdIVEVSX0FfbmFnZXdhemFfYmFja18wMV9maW5pc2gAAAAAETgAAAAAAAABAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX25hZ2V3YXphX2JhY2tfMDFfYmVnaW4AAAAAEjgAAAAAAAABAAAAAAAAwAAAAMD/////AQAoAE1fTUVMRUVfRklHSFRFUl9BX25hZ2V3YXphX2JhY2tfMDFfYmVnaW4AAAAA0TgAAAAAAAABAAAAAAAAwAAAAMD/////AQApAE1fTUVMRUVfRklHSFRFUl9BX25hZ2V3YXphX2JhY2tfMDFfZmluaXNoAAAAANI4AAAAAAAAAQAAAAAAAMAAAADA/////wEAKQBNX01FTEVFX0ZJR0hURVJfQV9uYWdld2F6YV9iYWNrXzAxX2ZpbmlzaAAAAAABPAAAAAAAAAEAAAAAAADAAAAAwP////8BACkATV9NRUxFRV9GSUdIVEVSX0FfbmFnZXdhemFfcmlnaHRfMDFfYmVnaW4AAAAAAjwAAAAAAAABAAAAAAAAwAAAAMD/////AQAqAE1fTUVMRUVfRklHSFRFUl9BX25h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' }
$MotherDat = @{
    'infected_data_custom_preset_bossfight_viral_boss_hard' = 'DgAAAAEEAAAAAAAABQAAAAAAAMAAAADA/////wEAIQBJbmZlY3RlZF9jcm91Y2hpbmdfYXR0YWNrX0xlZnRfMDEAAAAAAAAAwAAAAMD/////AQAhAEluZmVjdGVkX2Nyb3VjaGluZ19hdHRhY2tfTGVmdF8wMgAAAAAAAADAAAAAwP////8BACEASW5mZWN0ZWRfY3JvdWNoaW5nX2F0dGFja19MZWZ0XzAzAAAAAAAAAMAAAADA/////wEAIABtb3RoZXJfc3RlcF9mcndfYXR0YWNrX2xlZnRfaGFuZAAAAAAAAADAAAAAwP////8BABUAbW90aGVyX2F0dGFja19sZWZ0XzAxAAAAAAEIAAAAAAAABQAAAAAAAMAAAADA/////wEAIgBJbmZlY3RlZF9jcm91Y2hpbmdfYXR0YWNrX1JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAIgBJbmZlY3RlZF9jcm91Y2hpbmdfYXR0YWNrX1JpZ2h0XzAyAAAAAAAAAMAAAADA/////wEAIgBJbmZlY3RlZF9jcm91Y2hpbmdfYXR0YWNrX1JpZ2h0XzAzAAAAAAAAAMAAAADA/////wEAIQBtb3RoZXJfc3RlcF9mcndfYXR0YWNrX3JpZ2h0X2hhbmQAAAAAAAAAwAAAAMD/////AQAWAG1vdGhlcl9hdHRhY2tfcmlnaHRfMDEAAAAAAaQAAAAAAAABAAAAAAAAwAAAAMD/////AQAmAGluZmVjdGVkX2F0dGFja19mcm9tX3N0YW5kXzAzX2h1bWFuaXR5AAAAAAGMAgAAAAAABgAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAHwBpbmZlY3RlZF9kb2RnZV9iYWNrX3JlYWN0aW9uXzAxAAAAAAAAAMAAAADA/////wEAHwBpbmZlY3RlZF9kb2RnZV9iYWNrX3JlYWN0aW9uXzAyAAAAAAGMAwAAAAAABAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9sZWZ0XzAxAAAAAAGMBAAAAAAABAAAAAAAAMAAAADA/////wEAFwBJbmZlY3RlZF9kb2RnZV9yaWdodF8wMQAAAAAAAADAAAAAwP////8BABcASW5mZWN0ZWRfZG9kZ2VfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAXAEluZmVjdGVkX2RvZGdlX3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAFwBJbmZlY3RlZF9kb2RnZV9yaWdodF8wMQAAAAABTCAAAAAAABEAAAAAAADAAAAAwP////8BAB0AaW5mZWN0ZWRfYXR0YWNrX2Zyb21fc3RhbmRfMDQAAAAAAAAAwAAAAMD/////AQAiAEluZmVjdGVkX2Nyb3VjaGluZ19hdHRhY2tfUmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAiAEluZmVjdGVkX2Nyb3VjaGluZ19hdHRhY2tfUmlnaHRfMDIAAAAAAAAAwAAAAMD/////AQAiAEluZmVjdGVkX2Nyb3VjaGluZ19hdHRhY2tfUmlnaHRfMDMAAAAAAAAAwAAAAMD/////AQAhAEluZmVjdGVkX2Nyb3VjaGluZ19hdHRhY2tfTGVmdF8wMQAAAAAAAADAAAAAwP////8BACEASW5mZWN0ZWRfY3JvdWNoaW5nX2F0dGFja19MZWZ0XzAyAAAAAAAAAMAAAADA/////wEAIQBJbmZlY3RlZF9jcm91Y2hpbmdfYXR0YWNrX0xlZnRfMDMAAAAAAAAAwAAAAMD/////AQAdAGluZmVjdGVkX2F0dGFja19mcm9tX3N0YW5kXzAxAAAAAAAAAMAAAADA/////wEAHQBpbmZlY3RlZF9hdHRhY2tfZnJvbV9zdGFuZF8wMgAAAAAAAADAAAAAwP////8BAB0AaW5mZWN0ZWRfYXR0YWNrX2Zyb21fc3RhbmRfMDMAAAAAAAAAwAAAAMD/////AQAbAG1vdGhlcl9hdHRhY2tfZnJvbV9zdGFuZF8wMQAAAAAAAADAAAAAwP////8BABsAbW90aGVyX2F0dGFja19mcm9tX3N0YW5kXzAzAAAAAAAAAMAAAADA/////wEAIABtb3RoZXJfc3RlcF9mcndfYXR0YWNrX2JvdGhfaGFuZAAAAAAAAADAAAAAwP////8BACEAbW90aGVyX3N0ZXBfZnJ3X2F0dGFja19yaWdodF9oYW5kAAAAAAAAAMAAAADA/////wEAFgBtb3RoZXJfYXR0YWNrX3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAIABtb3RoZXJfc3RlcF9mcndfYXR0YWNrX2xlZnRfaGFuZAAAAAAAAADAAAAAwP////8BABUAbW90aGVyX2F0dGFja19sZWZ0XzAxAAAAAAFoIAAAAAAABAAAAAAAAMAAAADA/////wEAIgBpbmZlY3RlZF9hdHRhY2tfZnJvbV9tb3ZlX1JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAIQBpbmZlY3RlZF9hdHRhY2tfZnJvbV9tb3ZlX0xlZnRfMDEAAAAAAAAAwAAAAMD/////AQAiAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfUmlnaHRfMDIAAAAAAAAAwAAAAMD/////AQAhAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfTGVmdF8wMgAAAAABpCAAAAAAAAQAAAAAAADAAAAAwP////8BACUAaW5mZWN0ZWRfY3JvdWNoaW5nX2F0dGFja18wMV9odW1hbml0eQAAAAAAAADAAAAAwP////8BACoASW5mZWN0ZWRfY3JvdWNoaW5nX2F0dGFja19MZWZ0XzAxX2h1bWFuaXR5AAAAAAAAAMAAAADA/////wEAGwBtb3RoZXJfYXR0YWNrX2Zyb21fc3RhbmRfMDEAAAAAAAAAwAAAAMD/////AQAbAG1vdGhlcl9hdHRhY2tfZnJvbV9zdGFuZF8wMwAAAAAB3CAAAAAAAAcAAAAAAADAAAAAwP////8BABsAbW90aGVyX2F0dGFja19mcm9tX3N0YW5kXzAxAAAAAAAAAMAAAADA/////wEAGwBtb3RoZXJfYXR0YWNrX2Zyb21fc3RhbmRfMDMAAAAAAAAAwAAAAMD/////AQAgAG1vdGhlcl9zdGVwX2Zyd19hdHRhY2tfYm90aF9oYW5kAAAAAAAAAMAAAADA/////wEAIQBtb3RoZXJfc3RlcF9mcndfYXR0YWNrX3JpZ2h0X2hhbmQAAAAAAAAAwAAAAMD/////AQAWAG1vdGhlcl9hdHRhY2tfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAgAG1vdGhlcl9zdGVwX2Zyd19hdHRhY2tfbGVmdF9oYW5kAAAAAAAAAMAAAADA/////wEAFQBtb3RoZXJfYXR0YWNrX2xlZnRfMDEAAAAAAWgwAAAAAAAGAAAAAAAAwAAAAMD/////AQAoAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfUmlnaHRfMDFfc2hvcnQAAAAAAAAAwAAAAMD/////AQAiAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfUmlnaHRfMDIAAAAAAAAAwAAAAMD/////AQAhAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfTGVmdF8wMgAAAAAAAADAAAAAwP////8BACcAaW5mZWN0ZWRfYXR0YWNrX2Zyb21fbW92ZV9MZWZ0XzAzX3Nob3J0AAAAAAAAAMAAAADA/////wEAIgBpbmZlY3RlZF9hdHRhY2tfZnJvbV9tb3ZlX1JpZ2h0XzAzAAAAAAAAAMAAAADA/////wEAIQBpbmZlY3RlZF9hdHRhY2tfZnJvbV9tb3ZlX0xlZnRfMDMAAAAAAdwwAAAAAAADAAAAAAAAwAAAAMD/////AQArAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfUmlnaHRfMDFfaHVtYW5pdHkAAAAAAAAAwAAAAMD/////AQArAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfUmlnaHRfMDJfaHVtYW5pdHkAAAAAAAAAwAAAAMD/////AQArAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfUmlnaHRfMDNfaHVtYW5pdHkAAAAAAWhAAAAAAAABAAAAAAAAwAAAAMD/////AQAiAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfUmlnaHRfMDQAAAAAAdxAAAAAAAABAAAAAAAAwAAAAMD/////AQArAGluZmVjdGVkX2F0dGFja19mcm9tX21vdmVfUmlnaHRfMDRfaHVtYW5pdHkAAAAAAQAAAAEgAAAAAAAAGAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAHABpbmZlY3RlZF9kb2RnZV9zdGFuZF9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAHABpbmZlY3RlZF9kb2RnZV9zdGFuZF9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAHABpbmZlY3RlZF9kb2RnZV9zdGFuZF9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAHABpbmZlY3RlZF9kb2RnZV9zdGFuZF9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAFgBJbmZlY3RlZF9kb2RnZV9iYWNrXzAyAAAAAAAAAMAAAADA/////wEAHABpbmZlY3RlZF9kb2RnZV9zdGFuZF9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAHABpbmZlY3RlZF9kb2RnZV9zdGFuZF9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAHABpbmZlY3RlZF9kb2RnZV9zdGFuZF9iYWNrXzAxAAAAAAAAAMAAAADA/////wEAHABpbmZlY3RlZF9kb2RnZV9zdGFuZF9iYWNrXzAxAAAAAAAAAAAhAAAAEQAAAAAAAAACAAAAAAAAwAAAAMD/////AQAuAEluZmVjdGVkX1N0YW5kX0hpdHJlYWN0aW9uX0hlYWRfQmFja19TdHJvbmdfMDEAAAAAAAAAwAAAAMD/////AQAuAEluZmVjdGVkX1N0YW5kX0hpdHJlYWN0aW9uX0hlYWRfQmFja19TdHJvbmdfMDIAAAAAEQCAAAAAAAABAAAAAAAAwAAAAMD/////AQAmAEluZmVjdGVkX2hpdF9yZWFjdGlvbl9mb3J3YXJkX2hlYXZ5XzAyAAAAABEAABAAAAAABAAAAAAAAMAAAADA/////wEAJgBJbmZlY3RlZF9oaXRfcmVhY3Rpb25fZm9yd2FyZF9oZWF2eV8wMgAAAAAAAADAAAAAwP////8BACwASW5mZWN0ZWRfaGVhdnlfcmVhY3Rpb25fdG9yc29fZnJvbnRfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAsAEluZmVjdGVkX2hlYXZ5X3JlYWN0aW9uX3RvcnNvX2Zyb250X3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEALABJbmZlY3RlZF9oZWF2eV9yZWFjdGlvbl90b3Jzb19mcm9udF9yaWdodF8wMQAAAAARAAASAAAAAAIAAAAAAADAAAAAwP////8BACgAaW5mZWN0ZWRfbWVkaXVtX2hpdHJlYWN0aW9uX2hlYWRfYmFja18wMQAAAAAAAADAAAAAwP////8BACkAaW5mZWN0ZWRfbWVkaXVtX2hpdHJlYWN0aW9uX2hlYWRfZnJvbnRfMDEAAAAAEQCAEgAAAAABAAAAAAAAwAAAAMD/////AQArAGluZmVjdGVkX21lZGl1bV9oaXRyZWFjdGlvbl9oZWFkX2JhY2sxODBfMDEAAAAAEQAAFAAAAAABAAAAAAAAwAAAAMD/////AQApAGluZmVjdGVkX21lZGl1bV9oaXRyZWFjdGlvbl90b3Jzb19iYWNrXzAxAAAAABEAgBQAAAAAAQAAAAAAAMAAAADA/////wEALABpbmZlY3RlZF9tZWRpdW1faGl0cmVhY3Rpb25fdG9yc29fYmFjazE4MF8wMQAAAAARAAAWAAAAAAIAAAAAAADAAAAAwP////8BACgAaW5mZWN0ZWRfbWVkaXVtX2hpdHJlYWN0aW9uX2xlZ3NfbGVmdF8wMQAAAAAAAADAAAAAwP////8BACkAaW5mZWN0ZWRfbWVkaXVtX2hpdHJlYWN0aW9uX2xlZ3NfcmlnaHRfMDEAAAAAMQAAIAAAAAACAAAAAAAAwAAAAMD/////AQAlAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX2JhY2tfMDEAAAAAAAAAwAAAAMD/////AQAlAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX2JhY2tfMDIAAAAAUQAAIAAAAAACAAAAAAAAwAAAAMD/////AQAlAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX2JhY2tfMDEAAAAAAAAAwAAAAMD/////AQAlAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX2JhY2tfMDIAAAAAEQAAIgAAAAADAAAAAAAAwAAAAMD/////AQApAGluZmVjdGVkX21lZGl1bV9oaXRyZWFjdGlvbl9oZWFkX2Zyb250XzAxAAAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAxAAAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAyAAAAADGAUSIAAAAABQAAAAAAAMAAAADA/////wEAJgB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9yaWdodF8wMQAAAAAAAADAAAAAwP////8BACYAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAmAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9iYWNrXzAxAAAAABEAACQAAAAAAwAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAxAAAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAyAAAAAAAAAMAAAADA/////wEAKgBpbmZlY3RlZF9tZWRpdW1faGl0cmVhY3Rpb25fdG9yc29fZnJvbnRfMDEAAAAAMYBRJAAAAAADAAAAAAAAwAAAAMD/////AQAlAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX2xlZnRfMDEAAAAAAAAAwAAAAMD/////AQAlAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX2xlZnRfMDEAAAAAAAAAwAAAAMD/////AQAlAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX2JhY2tfMDEAAAAAEQAAJgAAAAACAAAAAAAAwAAAAMD/////AQAoAGluZmVjdGVkX21lZGl1bV9oaXRyZWFjdGlvbl9sZWdzX2xlZnRfMDEAAAAAAAAAwAAAAMD/////AQApAGluZmVjdGVkX21lZGl1bV9oaXRyZWFjdGlvbl9sZWdzX3JpZ2h0XzAxAAAAABEAADAAAAAAAQAAAAAAAMAAAADA/////wEAIwBJbmZlY3RlZF9oaXRfcmVhY3Rpb25fbGVmdF9oZWF2eV8wMgAAAAAxAAAwAAAAAAEAAAAAAADAAAAAwP////8BACUAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfbGVmdF8wMQAAAABRAAAwAAAAAAEAAAAAAADAAAAAwP////8BACUAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfbGVmdF8wMQAAAAARAAAyAAAAAAMAAAAAAADAAAAAwP////8BACgAaW5mZWN0ZWRfbWVkaXVtX2hpdHJlYWN0aW9uX2hlYWRfbGVmdF8wMQAAAAAAAADAAAAAwP////8BAC4ASW5mZWN0ZWRfU3RhbmRfSGl0cmVhY3Rpb25fSGVhZF9CYWNrX1N0cm9uZ18wMQAAAAAAAADAAAAAwP////8BAC4ASW5mZWN0ZWRfU3RhbmRfSGl0cmVhY3Rpb25fSGVhZF9CYWNrX1N0cm9uZ18wMQAAAAARAAA0AAAAAAEAAAAAAADAAAAAwP////8BACkAaW5mZWN0ZWRfbWVkaXVtX2hpdHJlYWN0aW9uX3RvcnNvX2xlZnRfMDEAAAAAEQAANgAAAAABAAAAAAAAwAAAAMD/////AQAoAGluZmVjdGVkX21lZGl1bV9oaXRyZWFjdGlvbl9sZWdzX2xlZnRfMDEAAAAAEQAAQAAAAAACAAAAAAAAwAAAAMD/////AQAsAEluZmVjdGVkX2hlYXZ5X3JlYWN0aW9uX3RvcnNvX2Zyb250X3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAJABJbmZlY3RlZF9oaXRfcmVhY3Rpb25fcmlnaHRfaGVhdnlfMDEAAAAAMQAAQAAAAAABAAAAAAAAwAAAAMD/////AQAmAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX3JpZ2h0XzAxAAAAAFEAAEAAAAAAAgAAAAAAAMAAAADA/////wEAJgB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9yaWdodF8wMQAAAAAAAADAAAAAwP////8BACYAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfcmlnaHRfMDIAAAAAEQAAQgAAAAADAAAAAAAAwAAAAMD/////AQApAGluZmVjdGVkX21lZGl1bV9oaXRyZWFjdGlvbl9oZWFkX3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAyAAAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAyAAAAABEAAEQAAAAAAQAAAAAAAMAAAADA/////wEAKgBpbmZlY3RlZF9tZWRpdW1faGl0cmVhY3Rpb25fdG9yc29fcmlnaHRfMDEAAAAAEQAARgAAAAABAAAAAAAAwAAAAMD/////AQApAGluZmVjdGVkX21lZGl1bV9oaXRyZWFjdGlvbl9sZWdzX3JpZ2h0XzAxAAAAABEAAFIAAAAAAgAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAxAAAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAxAAAAABEAAFQAAAAAAgAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAxAAAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0JhY2tfU3Ryb25nXzAyAAAAABEAAFYAAAAAAgAAAAAAAMAAAADA/////wEAJwBJbmZlY3RlZF9oaXRfcmVhY3Rpb25fYmFja3dhcmRfaGVhdnlfMDEAAAAAAAAAwAAAAMD/////AQAmAEluZmVjdGVkX2hpdF9yZWFjdGlvbl9mb3J3YXJkX2hlYXZ5XzAxAAAAABEAAGAAAAAAAgAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0Rvd25fTWVkaXVtXzAxAAAAAAAAAMAAAADA/////wEALgBJbmZlY3RlZF9TdGFuZF9IaXRyZWFjdGlvbl9IZWFkX0Rvd25fTWVkaXVtXzAyAAAAABEAAGQAAAAAAgAAAAAAAMAAAADA/////wEAJwBJbmZlY3RlZF9oaXRfcmVhY3Rpb25fYmFja3dhcmRfaGVhdnlfMDEAAAAAAAAAwAAAAMD/////AQAmAEluZmVjdGVkX2hpdF9yZWFjdGlvbl9mb3J3YXJkX2hlYXZ5XzAxAAAAABEAAGYAAAAAAgAAAAAAAMAAAADA/////wEAJwBJbmZlY3RlZF9oaXRfcmVhY3Rpb25fYmFja3dhcmRfaGVhdnlfMDEAAAAAAAAAwAAAAMD/////AQAmAEluZmVjdGVkX2hpdF9yZWFjdGlvbl9mb3J3YXJkX2hlYXZ5XzAxAAAAAAAAAAAhAAAAEQgAAAAAAAACAAAA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AAAAAMAAAADA/////wEAFgBtemlfdXBzZXRfanVtcF9kb3duXzAxAAAAALEJAAAAAAAABgAAAAAAAMAAAADA/////wEAGABpbmZlY3RlZF9qdW1wX2Rvd25fM21fMDEAAAAAAAAAwAAAAMD/////AQAYAGluZmVjdGVkX2p1bXBfZG93bl8zbV8wMgAAAAAAAADAAAAAwP////8BABgAaW5mZWN0ZWRfanVtcF9kb3duXzNtXzAzAAAAAAAAAMAAAADA/////wEAFgBtemlfdXBzZXRfanVtcF9kb3duXzAxAAAAAAAAAMAAAADA/////wEAFgBtemlfdXBzZXRfanVtcF9kb3duXzAxAAAAAAAAAMAAAADA/////wEAFgBtemlfdXBzZXRfanVtcF9kb3duXzAxAAAAAMEJAAAAAAAABAAAAAAAAMAAAADA/////wEAFwBpbmZlY3RlZF9qdW1wX2Rvd25fMm1fUgAAAAAAAADAAAAAwP////8BABcAaW5mZWN0ZWRfanVtcF9kb3duXzJtX0wAAAAAAAAAwAAAAMD/////AQAbAGluZmVjdGVkX2NsaW1iaW5nX2Rvd25fNl82bQAAAAAAAADAAAAAwP////8BABsAaW5mZWN0ZWRfY2xpbWJpbmdfZG93bl85XzltAAAAANEJAAAAAAAAAQAAAAAAAMAAAADA/////wEAEQBtemlfdXBzZXRfanVtcF9vbgAAAADhCQAAAAAAAAEAAAAAAADAAAAAwP////8BABIAbXppX3Vwc2V0X2p1bXBfb2ZmAAAAAPEJAAAAAAAAAwAAAAAAAMAAAADA/////wEAGwBtemlfdXBzZXRfanVtcF9vdmVyX2hpZ2hfMDEAAAAAAAAAwAAAAMD/////AQAbAG16aV91cHNldF9qdW1wX292ZXJfaGlnaF8wMgAAAAAAAADAAAAAwP////8BABUAbXppX3Vwc2V0X3NwcmludGNsaW1iAAAAAAEKAAAAAAAAAQAAAAAAAMAAAADA/////wEAHQBtemlfdXBzZXRfc3ByaW50YmFycmllcmp1bXB1cAAAAAARCgAAAAAAAAIAAAAAAADAAAAAwP////8BABoAbXppX3Vwc2V0X2p1bXBfb3Zlcl9sb3dfMDIAAAAAAAAAwAAAAMD/////AQAfAG16aV91cHNldF9qdW1wX292ZXJfbG93XzAyX2xsZWcAAAAAIQoAAAAAAAABAAAAAAAAwAAAAMD/////AQAfAG16aV91cHNldF9zcHJpbnRiYXJyaWVyanVtcGRvd24AAAAAMQoAAAAAAAABAAAAAAAAwAAAAMD/////AQATAG16aV91cHNldF9qdW1wX2ZhaWwAAAAAQQoAAAAAAAACAAAAAAAAwAAAAMD/////AQAaAG16aV91cHNldF9qdW1wX292ZXJfbG93XzAyAAAAAAAAAMAAAADA/////wEAHwBtemlfdXBzZXRfanVtcF9vdmVyX2xvd18wMl9sbGVnAAAAAFEKAAAAAAAAAgAAAAAAAMAAAADA/////wEAGgBtemlfdXBzZXRfanVtcF90aHJvdWdoX2NhcgAAAAAAAADAAAAAwP////8BAB8AbXppX3Vwc2V0X2p1bXBfdGhyb3VnaF9jYXJfbGxlZwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAADBDAAAAAAAAAUAAAAAAADAAAAAwP////8BABgAbW90aGVyX2luZmVjdGVkX3RhdW50XzAxAAAAAAAAAMAAAADA/////wEAGABtb3RoZXJfaW5mZWN0ZWRfdGF1bnRfMDIAAAAAAAAAwAAAAMD/////AQAYAG1vdGhlcl9pbmZlY3RlZF90YXVudF8wMwAAAAAAAADAAAAAwP////8BABgAbW90aGVyX2luZmVjdGVkX3RhdW50XzA0AAAAAAAAAMAAAADA/////wEAGABtb3RoZXJfSW5mZWN0ZWRfdGF1bnRfMDYAAAAAgQ0AAAAAAAACAAAAAAAAwAAAAMD/////AQASAHZvbGF0aWxlX3NjcmVhbV8wMQAAAAAAAADAAAAAwP////8BABIAdm9sYXRpbGVfc2NyZWFtXzAzAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAFEAAAAAAAAAQAAAAAAAMAAAADA/////wEAHQB2aXJhbF9WZWhpY2xlR3JhYl9mcm9udF9iZWdpbgAAAAARRAAAAAAAAAEAAAAAAADAAAAAwP////8BAB0AdmlyYWxfVmVoaWNsZUdyYWJfZnJvbnRfYmVnaW4AAAAAsUQAAAAAAAAGAAAAAAAAwAAAAMD/////AQAeAHZpcmFsX1ZlaGljbGVHcmFiX2Zyb250X2xvb3BfMQAAAAAAAADAAAAAwP////8BAB4AdmlyYWxfVmVoaWNsZUdyYWJfZnJvbnRfbG9vcF8yAAAAAAAAAMAAAADA/////wEAHgB2aXJhbF9WZWhpY2xlR3JhYl9mcm9udF9sb29wXzMAAAAAAAAAwAAAAMD/////AQAeAHZpcmFsX1ZlaGljbGVHcmFiX2Zyb250X2xvb3BfNAAAAAAAAADAAAAAwP////8BAB4AdmlyYWxfVmVoaWNsZUdyYWJfZnJvbnRfbG9vcF81AAAAAAAAAMAAAADA/////wEAHgB2aXJhbF9WZWhpY2xlR3JhYl9mcm9udF9sb29wXzYAAAAA0UQAAAAAAAABAAAAAAAAwAAAAMD/////AQAhAHZpcmFsX1ZlaGljbGVHcmFiX2Zyb250X2ZpbmlzaHdpbgAAAAAxRQAAAAAAAAEAAAAAAADAAAAAwP////8BACIAdmlyYWxfVmVoaWNsZUdyYWJfZnJvbnRfZmluaXNobG9zZQAAAACxRQAAAAAAAAEAAAAAAADAAAAAwP////8BACEAdmlyYWxfVmVoaWNsZUdyYWJfZnJvbnRfbGVhbl9sZWZ0AAAAANFFAAAAAAAAAQAAAAAAAMAAAADA/////wEAIgB2aXJhbF9WZWhpY2xlR3JhYl9mcm9udF9sZWFuX3JpZ2h0AAAAAPFFAAAAAAAAAQAAAAAAAMAAAADA/////wEAHwB2aXJhbF9WZWhpY2xlR3JhYl9mcm9udF90YXVudF8xAAAAAAFIAAAAAAAAAQAAAAAAAMAAAADA/////wEAHQB2aXJhbF9WZWhpY2xlR3JhYl9yaWdodF9iZWdpbgAAAAARSAAAAAAAAAEAAAAAAADAAAAAwP////8BAB0AdmlyYWxfVmVoaWNsZUdyYWJfcmlnaHRfYmVnaW4AAAAAsUgAAAAAAAAGAAAAAAAAwAAAAMD/////AQAeAHZpcmFsX1ZlaGljbGVHcmFiX3JpZ2h0X2xvb3BfMQAAAAAAAADAAAAAwP////8BAB4AdmlyYWxfVmVoaWNsZUdyYWJfcmlnaHRfbG9vcF8yAAAAAAAAAMAAAADA/////wEAHgB2aXJhbF9WZWhpY2xlR3JhYl9yaWdodF9sb29wXzMAAAAAAAAAwAAAAMD/////AQAeAHZpcmFsX1ZlaGljbGVHcmFiX3JpZ2h0X2xvb3BfNAAAAAAAAADAAAAAwP////8BAB4AdmlyYWxfVmVoaWNsZUdyYWJfcmlnaHRfbG9vcF81AAAAAAAAAMAAAADA/////wEAHgB2aXJhbF9WZWhpY2xlR3JhYl9yaWdodF9sb29wXzYAAAAA0UgAAAAAAAABAAAAAAAAwAAAAMD/////AQAhAHZpcmFsX3ZlaGljbGVHcmFiX3JpZ2h0X2ZpbmlzaHdpbgAAAAAxSQAAAAAAAAEAAAAAAADAAAAAwP////8BACIAdmlyYWxfVmVoaWNsZUdyYWJfcmlnaHRfZmluaXNobG9zZQAAAACxSQAAAAAAAAEAAAAAAADAAAAAwP////8BACEAdmlyYWxfVmVoaWNsZUdyYWJfcmlnaHRfbGVhbl9sZWZ0AAAAANFJAAAAAAAAAQAAAAAAAMAAAADA/////wEAIgB2aXJhbF9WZWhpY2xlR3JhYl9yaWdodF9sZWFuX3JpZ2h0AAAAAPFJAAAAAAAAAQAAAAAAAMAAAADA/////wEAHwB2aXJhbF9WZWhpY2xlR3JhYl9yaWdodF90YXVudF8xAAAAAAFMAAAAAAAAAQAAAAAAAMAAAADA/////wEAHAB2aXJhbF9WZWhpY2xlR3JhYl9sZWZ0X2JlZ2luAAAAABFMAAAAAAAAAQAAAAAAAMAAAADA/////wEAHAB2aXJhbF9WZWhpY2xlR3JhYl9sZWZ0X2JlZ2luAAAAALFMAAAAAAAABgAAAAAAAMAAAADA/////wEAHQB2aXJhbF9WZWhpY2xlR3JhYl9sZWZ0X2xvb3BfMQAAAAAAAADAAAAAwP////8BAB0AdmlyYWxfVmVoaWNsZUdyYWJfbGVmdF9sb29wXzIAAAAAAAAAwAAAAMD/////AQAdAHZpcmFsX1ZlaGljbGVHcmFiX2xlZnRfbG9vcF8zAAAAAAAAAMAAAADA/////wEAHQB2aXJhbF9WZWhpY2xlR3JhYl9sZWZ0X2xvb3BfNAAAAAAAAADAAAAAwP////8BAB0AdmlyYWxfVmVoaWNsZUdyYWJfbGVmdF9sb29wXzUAAAAAAAAAwAAAAMD/////AQAdAHZpcmFsX1ZlaGljbGVHcmFiX2xlZnRfbG9vcF82AAAAANFMAAAAAAAAAQAAAAAAAMAAAADA/////wEAIAB2aXJhbF92ZWhpY2xlR3JhYl9sZWZ0X2ZpbmlzaHdpbgAAAAAxTQAAAAAAAAEAAAAAAADAAAAAwP////8BACEAdmlyYWxfVmVoaWNsZUdyYWJfbGVmdF9maW5pc2hsb3NlAAAAALFNAAAAAAAAAQAAAAAAAMAAAADA/////wEAIAB2aXJhbF9WZWhpY2xlR3JhYl9sZWZ0X2xlYW5fbGVmdAAAAADRTQAAAAAAAAEAAAAAAADAAAAAwP////8BACEAdmlyYWxfVmVoaWNsZUdyYWJfbGVmdF9sZWFuX3JpZ2h0AAAAAPFNAAAAAAAAAQAAAAAAAMAAAADA/////wEAHgB2aXJhbF9WZWhpY2xlR3JhYl9sZWZ0X3RhdW50XzEAAAAAAVAAAAAAAAABAAAAAAAAwAAAAMD/////AQAcAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfYmVnaW4AAAAAEVAAAAAAAAABAAAAAAAAwAAAAMD/////AQAcAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfYmVnaW4AAAAAsVAAAAAAAAAEAAAAAAAAwAAAAMD/////AQAdAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfbG9vcF8xAAAAAAAAAMAAAADA/////wEAHQB2aXJhbF9WZWhpY2xlR3JhYl9iYWNrX2xvb3BfMgAAAAAAAADAAAAAwP////8BAB0AdmlyYWxfVmVoaWNsZUdyYWJfYmFja19sb29wXzMAAAAAAAAAwAAAAMD/////AQAdAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfbG9vcF80AAAAANFQAAAAAAAAAQAAAAAAAMAAAADA/////wEAIAB2aXJhbF92ZWhpY2xlR3JhYl9iYWNrX2ZpbmlzaHdpbgAAAAAxUQAAAAAAAAEAAAAAAADAAAAAwP////8BACEAdmlyYWxfVmVoaWNsZUdyYWJfYmFja19maW5pc2hsb3NlAAAAALFRAAAAAAAAAQAAAAAAAMAAAADA/////wEAIAB2aXJhbF9WZWhpY2xlR3JhYl9iYWNrX2xlYW5fbGVmdAAAAADRUQAAAAAAAAEAAAAAAADAAAAAwP////8BACEAdmlyYWxfVmVoaWNsZUdyYWJfYmFja19sZWFuX3JpZ2h0AAAAAPFRAAAAAAAAAgAAAAAAAMAAAADA/////wEAHgB2aXJhbF9WZWhpY2xlR3JhYl9iYWNrX3RhdW50XzEAAAAAAAAAwAAAAMD/////AQAeAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfdGF1bnRfMgAAAAABVAAAAAAAAAEAAAAAAADAAAAAwP////8BACEAdmlyYWxfVmVoaWNsZUdyYWJfYmFja19sZWZ0X2JlZ2luAAAAABFUAAAAAAAAAQAAAAAAAMAAAADA/////wEAIQB2aXJhbF9WZWhpY2xlR3JhYl9iYWNrX2xlZnRfYmVnaW4AAAAAsVQAAAAAAAAEAAAAAAAAwAAAAMD/////AQAiAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfbGVmdF9sb29wXzEAAAAAAAAAwAAAAMD/////AQAiAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfbGVmdF9sb29wXzIAAAAAAAAAwAAAAMD/////AQAiAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfbGVmdF9sb29wXzMAAAAAAAAAwAAAAMD/////AQAiAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfbGVmdF9sb29wXzQAAAAA0VQAAAAAAAABAAAAAAAAwAAAAMD/////AQAlAHZpcmFsX3ZlaGljbGVHcmFiX2JhY2tfbGVmdF9maW5pc2h3aW4AAAAAMVUAAAAAAAABAAAAAAAAwAAAAMD/////AQAmAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfbGVmdF9maW5pc2hsb3NlAAAAALFVAAAAAAAAAQAAAAAAAMAAAADA/////wEAJgB2aXJhbF9WZWhpY2xlR3JhYl9iYWNrX2xlZnRfbGVhbl9yaWdodAAAAADRVQAAAAAAAAEAAAAAAADAAAAAwP////8BACUAdmlyYWxfVmVoaWNsZUdyYWJfYmFja19sZWZ0X2xlYW5fbGVmdAAAAADxVQAAAAAAAAIAAAAAAADAAAAAwP////8BACMAdmlyYWxfVmVoaWNsZUdyYWJfYmFja19sZWZ0X3RhdW50XzEAAAAAAAAAwAAAAMD/////AQAjAHZpcmFsX1ZlaGljbGVHcmFiX2JhY2tfbGVmdF90YXVudF8yAAAAAAFYAAAAAAAAAQAAAAAAAMAAAADA/////wEAIgB2aXJhbF9WZWhpY2xlR3JhYl9i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'
    'infected_data_custom_preset_volatile_wasteland_final_sir' = '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dm9sYXRpbGVfYWxhcm1pbmdfdXBzZXRfc3RvcF85MGwAAAAAgZ0AAAAAAAABAAAAAAAAwAAAAMD/////AQAhAHZvbGF0aWxlX2FsYXJtaW5nX3Vwc2V0X3N0b3BfMTgwbAAAAACBowAAAAAAAAEAAAAAAADAAAAAwP////8BACAAdm9sYXRpbGVfYWxhcm1pbmdfdXBzZXRfc3RvcF85MHIAAAAAgaUAAAAAAAABAAAAAAAAwAAAAMD/////AQAhAHZvbGF0aWxlX2FsYXJtaW5nX3Vwc2V0X3N0b3BfMTgwcgAAAAAVAAAAMQCAAAAAAAACAAAAAAAAwAAAAMD/////AQAmAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAJgB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9yaWdodF8wMgAAAABRAIAAAAAAAAIAAAAAAADAAAAAwP////8BACYAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAmAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX3JpZ2h0XzAyAAAAABEAACAAAAAAAgAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAJgB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9yaWdodF8wMQAAAAAxAAAgAAAAAAIAAAAAAADAAAAAwP////8BACUAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfYmFja18wMQAAAAAAAADAAAAAwP////8BACUAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfYmFja18wMgAAAABRAAAgAAAAAAIAAAAAAADAAAAAwP////8BACUAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfYmFja18wMQAAAAAAAADAAAAAwP////8BACUAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfYmFja18wMgAAAAARAAEgAAAAAAUAAAAAAADAAAAAwP////8BACIAdm9sYXRpbGVfaGl0cmVhY3Rpb25zX3Nob3RfYmFja18wMQAAAAAAAADAAAAAwP////8BACIAdm9sYXRpbGVfaGl0cmVhY3Rpb25zX3Nob3RfYmFja18wMgAAAAAAAADAAAAAwP////8BAB4Adm9sYXRpbGVfbGlnaHRfaGl0X3JlYWN0aW9uXzAxAAAAAAAAAMAAAADA/////wEAHgB2b2xhdGlsZV9saWdodF9oaXRfcmVhY3Rpb25fMDMAAAAAAAAAwAAAAMD/////AQAeAHZvbGF0aWxlX2xpZ2h0X2hpdF9yZWFjdGlvbl8wNAAAAAARABMgAAAAAAQAAAAAAADAAAAAwP////8BAB4Adm9sYXRpbGVfbGlnaHRfaGl0X3JlYWN0aW9uXzAxAAAAAAAAAMAAAADA/////wEAHgB2b2xhdGlsZV9saWdodF9oaXRfcmVhY3Rpb25fMDEAAAAAAAAAwAAAAMD/////AQAeAHZvbGF0aWxlX2xpZ2h0X2hpdF9yZWFjdGlvbl8wMwAAAAAAAADAAAAAwP////8BAB4Adm9sYXRpbGVfbGlnaHRfaGl0X3JlYWN0aW9uXzA0AAAAADGAUSIAAAAABQAAAAAAAMAAAADA/////wEAJgB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9yaWdodF8wMQAAAAAAAADAAAAAwP////8BACYAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAmAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX3JpZ2h0XzAxAAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9iYWNrXzAxAAAAADGAUSQAAAAAAwAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9iYWNrXzAxAAAAABEAADAAAAAAAgAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9sZWZ0XzAxAAAAAAAAAMAAAADA/////wEAHAB2b2xhdGlsZV9oaXRyZWFjdGlvbl9sZWZ0XzAxAAAAADEAADAAAAAAAQAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9sZWZ0XzAxAAAAAFEAADAAAAAAAQAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9sZWZ0XzAxAAAAABEAATAAAAAAAQAAAAAAAMAAAADA/////wEAHAB2b2xhdGlsZV9oaXRyZWFjdGlvbl9sZWZ0XzAxAAAAABEAAEAAAAAAAwAAAAAAAMAAAADA/////wEAJgB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9yaWdodF8wMQAAAAAAAADAAAAAwP////8BACYAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfcmlnaHRfMDIAAAAAAAAAwAAAAMD/////AQAdAHZvbGF0aWxlX2hpdHJlYWN0aW9uX3JpZ2h0XzAxAAAAADEAAEAAAAAAAQAAAAAAAMAAAADA/////wEAJgB2b2xhdGlsZV9jb3VudGVycmVhY3Rpb25faGVhZF9yaWdodF8wMQAAAABRAABAAAAAAAIAAAAAAADAAAAAwP////8BACYAdm9sYXRpbGVfY291bnRlcnJlYWN0aW9uX2hlYWRfcmlnaHRfMDEAAAAAAAAAwAAAAMD/////AQAmAHZvbGF0aWxlX2NvdW50ZXJyZWFjdGlvbl9oZWFkX3JpZ2h0XzAyAAAAABEAAUAAAAAAAQAAAAAAAMAAAADA/////wEAHQB2b2xhdGlsZV9oaXRyZWFjdGlvbl9yaWdodF8wMQAAAAARAABQAAAAAAMAAAAAAADAAAAAwP////8BAC4Adm9sYXRpbGVfc3RhbmRfaGl0cmVhY3Rpb25faGVhZF9sZWZ0X21lZGl1bV8wMQAAAAAAAADAAAAAwP////8BAC8Adm9sYXRpbGVfc3RhbmRfaGl0cmVhY3Rpb25faGVhZF9yaWdodF9tZWRpdW1fMDEAAAAAAAAAwAAAAMD/////AQAvAHZvbGF0aWxlX3N0YW5kX2hpdHJlYWN0aW9uX2hlYWRfcmlnaHRfbWVkaXVtXzAyAAAAABEAAVAAAAAAAwAAAAAAAMAAAADA/////wEALgB2b2xhdGlsZV9zdGFuZF9oaXRyZWFjdGlvbl9oZWFkX2xlZnRfbWVkaXVtXzAxAAAAAAAAAMAAAADA/////wEALwB2b2xhdGlsZV9zdGFuZF9oaXRyZWFjdGlvbl9oZWFkX3JpZ2h0X21lZGl1bV8wMQAAAAAAAADAAAAAwP////8BAC8Adm9sYXRpbGVfc3RhbmRfaGl0cmVhY3Rpb25faGVhZF9yaWdodF9tZWRpdW1fMDIAAAAAEQAAYAAAAAACAAAAAAAAwAAAAMD/////AQAuAHZvbGF0aWxlX3N0YW5kX2hpdHJlYWN0aW9uX2hlYWRfZG93bl9tZWRpdW1fMDEAAAAAAAAAwAAAAMD/////AQAuAHZvbGF0aWxlX3N0YW5kX2hpdHJlYWN0aW9uX2hlYWRfZG93bl9tZWRpdW1fMDIAAAAAEQABYAAAAAACAAAAAAAAwAAAAMD/////AQAuAHZvbGF0aWxlX3N0YW5kX2hpdHJlYWN0aW9uX2hlYWRfZG93bl9tZWRpdW1fMDEAAAAAAAAAwAAAAMD/////AQAuAHZvbGF0aWxlX3N0YW5kX2hpdHJlYWN0aW9uX2hlYWRfZG93bl9tZWRpdW1fMDIAAAAAAAAAACoAAAARCAAAAAAAAAIAAAAAAADAAAAAwP////8BABMAaW5mZWN0ZWRfanVtcF8wNW1fTAAAAAAAAADAAAAAwP////8BABMAaW5mZWN0ZWRfanVtcF8wNW1fUgAAAAAhCAAAAAAAAAIAAAAAAADAAAAAwP////8BABIAaW5mZWN0ZWRfanVtcF8xbV9MAAAAAAAAAMAAAADA/////wEAEgBpbmZlY3RlZF9qdW1wXzFtX1IAAAAAMQgAAAAAAAACAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAQQgAAAAAAAACAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAUQgAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAYQgAAAAAAAACAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAcQgAAAAAAAACAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAgQgAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAkQgAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAoQgAAAAAAAACAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAsQgAAAAAAAADAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAwQgAAAAAAAADAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAA0QgAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAA4QgAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAA8QgAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAQkAAAAAAAACAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAIQkAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAMQkAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAQQkAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAgQkAAAAAAAABAAAAAAAAwAAAAMD/////AQAQAHZvbGF0aWxlX2p1bXBfMDEAAAAAkQkAAAAAAAAKAAAAAAAAwAAAAMD/////AQATAHZvbGF0aWxlX2p1bXBfdXBfMDEAAAAAAAAAwAAAAMD/////AQAZAHZvbGF0aWxlX2NsaW1iaW5nX3VwXzNfM20AAAAAAAAAwAAAAMD/////AQAZAHZvbGF0aWxlX2NsaW1iaW5nX3VwXzZfNm0AAAAAAAAAwAAAAMD/////AQAZAHZvbGF0aWxlX2NsaW1iaW5nX3VwXzlfOW0AAAAAAAAAwAAAAMD/////AQAWAHZvbGF0aWxlX3J1bl9qdW1wX3VwX3IAAAAAAAAAwAAAAMD/////AQAWAHZvbGF0aWxlX3J1bl9qdW1wX3VwX2wAAAAAAAAAwAAAAMD/////AQAZAHZvbGF0aWxlX2NsaW1iaW5nX3VwXzNfM20AAAAAAAAAwAAAAMD/////AQAgAHZvbGF0aWxlX2NsaW1iaW5nX3VwXzNfM21fbWlycm9yAAAAAAAAAMAAAADA/////wEAGQB2b2xhdGlsZV9jbGltYmluZ191cF82XzZtAAAAAAAAAMAAAADA/////wEAGQB2b2xhdGlsZV9jbGltYmluZ191cF85XzltAAAAAKEJAAAAAAAACgAAAAAAAMAAAADA/////wEAGABpbmZlY3RlZF9qdW1wX2Rvd25fM21fMDEAAAAAAAAAwAAAAMD/////AQAYAGluZmVjdGVkX2p1bXBfZG93bl8zbV8wMgAAAAAAAADAAAAAwP////8BABgAaW5mZWN0ZWRfanVtcF9kb3duXzNtXzAzAAAAAAAAAMAAAADA/////wEAFgBtemlfdXBzZXRfanVtcF9kb3duXzAxAAAAAAAAAMAAAADA/////wEAFgBtemlfdXBzZXRfanVtcF9kb3duXzAxAAAAAAAAAMAAAADA/////wEAFgBtemlfdXBzZXRfanVtcF9kb3duXzAxAAAAAAAAAMAAAADA/////wEAGABtemlfdXBzZXRfc3ByaW50anVtcGRvd24AAAAAAAAAwAAAAMD/////AQAYAGluZmVjdGVkX2p1bXBfZG93bl8zbV8wMgAAAAAAAADAAAAAwP////8BABgAaW5mZWN0ZWRfanVtcF9kb3duXzNtXzAzAAAAAAAAAMAAAADA/////wEAGwB2b2xhdGlsZV9jbGltYmluZ19kb3duXzlfOW0AAAAAsQkAAAAAAAAGAAAAAAAAwAAAAMD/////AQAYAGluZmVjdGVkX2p1bXBfZG93bl8zbV8wMQAAAAAAAADAAAAAwP////8BABgAaW5mZWN0ZWRfanVtcF9kb3duXzNtXzAyAAAAAAAAAMAAAADA/////wEAGABpbmZlY3RlZF9qdW1wX2Rvd25fM21fMDMAAAAAAAAAwAAAAMD/////AQAWAG16aV91cHNldF9qdW1wX2Rvd25fMDEAAAAAAAAAwAAAAMD/////AQAWAG16aV91cHNldF9qdW1wX2Rvd25fMDEAAAAAAAAAwAAAAMD/////AQAWAG16aV91cHNldF9qdW1wX2Rvd25fMDEAAAAAwQkAAAAAAAAEAAAAAAAAwAAAAMD/////AQAXAGluZmVjdGVkX2p1bXBfZG93bl8ybV9SAAAAAAAAAMAAAADA/////wEAFwBpbmZlY3RlZF9qdW1wX2Rvd25fMm1fTAAAAAAAAADAAAAAwP////8BABsAaW5mZWN0ZWRfY2xpbWJpbmdfZG93bl82XzZtAAAAAAAAAMAAAADA/////wEAGwBpbmZlY3RlZF9jbGltYmluZ19kb3duXzlfOW0AAAAA0QkAAAAAAAABAAAAAAAAwAAAAMD/////AQARAG16aV91cHNldF9qdW1wX29uAAAAAOEJAAAAAAAAAQAAAAAAAMAAAADA/////wEAEgBtemlfdXBzZXRfanVtcF9vZmYAAAAA8QkAAAAAAAADAAAAAAAAwAAAAMD/////AQAbAG16aV91cHNldF9qdW1wX292ZXJfaGlnaF8wMQAAAAAAAADAAAAAwP////8BABsAbXppX3Vwc2V0X2p1bXBfb3Zlcl9oaWdoXzAyAAAAAAAAAMAAAADA/////wEAFQBtemlfdXBzZXRfc3ByaW50Y2xpbWIAAAAAAQoAAAAAAAABAAAAAAAAwAAAAMD/////AQAdAG16aV91cHNldF9zcHJpbnRiYXJyaWVyanVtcHVwAAAAABEKAAAAAAAAAgAAAAAAAMAAAADA/////wEAGgBtemlfdXBzZXRfanVtcF9vdmVyX2xvd18wMgAAAAAAAADAAAAAwP////8BAB8AbXppX3Vwc2V0X2p1bXBfb3Zlcl9sb3dfMDJfbGxlZwAAAAAhCgAAAAAAAAEAAAAAAADAAAAAwP////8BAB8AbXppX3Vwc2V0X3NwcmludGJhcnJpZXJqdW1wZG93bgAAAAAxCgAAAAAAAAEAAAAAAADAAAAAwP////8BABMAbXppX3Vwc2V0X2p1bXBfZmFpbAAAAABBCgAAAAAAAAIAAAAAAADAAAAAwP////8BABoAbXppX3Vwc2V0X2p1bXBfb3Zlcl9sb3dfMDIAAAAAAAAAwAAAAMD/////AQAfAG16aV91cHNldF9qdW1wX292ZXJfbG93XzAyX2xsZWcAAAAAUQoAAAAAAAACAAAAAAAAwAAAAMD/////AQAaAG16aV91cHNldF9qdW1wX3Rocm91Z2hfY2FyAAAAAAAAAMAAAADA/////wEAHwBtemlfdXBzZXRfanVtcF90aHJvdWdoX2Nhcl9sbGVnAAAAAGEKAAAAAAAAAQAAAAAAAMAAAADA/////wEAFgB2b2xhdGlsZV93YWxrX2xvb3BfdjA1AAAAAIEKAAAAAAAAAQAAAAAAAMAAAADA/////wEADwB2b2xhdGlsZV9ydW5fMDEAAAAAkQoAAAAAAAABAAAAAAAAwAAAAMD/////AQAPAHZvbGF0aWxlX3J1bl8wMQAAAAChCgAAAAAAAAEAAAAAAADAAAAAwP////8BAA8Adm9sYXRpbGVfcnVuXzAxAAAAALEKAAAAAAAAAQAAAAAAAMAAAADA/////wEADwB2b2xhdGlsZV9ydW5fMDEAAAAAwQoAAAAAAAABAAAAAAAAwAAAAMD/////AQAPAHZvbGF0aWxlX3J1bl8wMQAAAADRCgAAAAAAAAEAAAAAAADAAAAAwP////8BABUAdm9sYXRpbGVfcnVuX2xvb3BfMTdtAAAAAOEKAAAAAAAAAQAAAAAAAMAAAADA/////wEAFQB2b2xhdGlsZV9ydW5fbG9vcF8yMm0AAAAA8QoAAAAAAAABAAAAAAAAwAAAAMD/////AQAVAHZvbGF0aWxlX3J1bl9sb29wXzMwbQAAAAAAAAAAAAAAAAoAAAABAAgAAAAAAAEAAAAAAADAAAAAwP////8BABsAdm9sYXRpbGVfcnVuX3N0YXJ0X2Zyb250XzAxAAAAAAFgCgAAAAAAAQAAAAAAAMAAAADA/////wEAEwB2b2xhdGlsZV93YWxrX3N0YXJ0AAAAAAEA2AAAAAAAAQAAAAAAAMAAAADA/////wEAFgB2b2xhdGlsZV9ydW5fc3RhcnRfOTBMAAAAAAFg2gAAAAAAAQAAAAAAAMAAAADA/////wEAGQB2b2xhdGlsZV93YWxrX3N0YXJ0OTBsXzAxAAAAAAEA6AAAAAAAAQAAAAAAAMAAAADA/////wEAFwB2b2xhdGlsZV9ydW5fc3RhcnRfMTgwTAAAAAABYOoAAAAAAAEAAAAAAADAAAAAwP////8BABoAdm9sYXRpbGVfd2Fsa19zdGFydDE4MGxfMDEAAAAAAQAYAQAAAAABAAAAAAAAwAAAAMD/////AQAWAHZvbGF0aWxlX3J1bl9zdGFydF85MFIAAAAAAWAaAQAAAAABAAAAAAAAwAAAAMD/////AQAZAHZvbGF0aWxlX3dhbGtfc3RhcnQ5MHJfMDEAAAAAAQAoAQAAAAABAAAAAAAAwAAAAMD/////AQAXAHZvbGF0aWxlX3J1bl9zdGFydF8xODBSAAAAAAFgKgEAAAAAAQAAAAAAAMAAAADA/////wEAGgB2b2xhdGlsZV93YWxrX3N0YXJ0MTgwcl8wMQAAAAAKAAAAAQAIAAAAAAABAAAAAAAAwAAAAMD/////AQAaAHZvbGF0aWxlX3J1bl9zdG9wX2Zyb250XzAxAAAAAAFgCgAAAAAAAgAAAAAAAMAAAADA/////wEAFQB2b2xhdGlsZV93YWxrX3N0b3BfMDEAAAAAAAAAwAAAAMD/////AQAVAHZvbGF0aWxlX3dhbGtfc3RvcF8wMgAAAAABANgAAAAAAAEAAAAAAADAAAAAwP////8BABgAdm9sYXRpbGVfcnVuX3N0b3BfOTBsXzAxAAAAAAFg2gAAAAAAAgAAAAAAAMAAAADA/////wEAGAB2b2xhdGlsZV93YWxrX3N0b3A5MGxfMDEAAAAAAAAAwAAAAMD/////AQAYAHZvbGF0aWxlX3dhbGtfc3RvcDkwbF8wMgAAAAABAOgAAAAAAAEAAAAAAADAAAAAwP////8BABkAdm9sYXRpbGVfcnVuX3N0b3BfMTgwTF8wMQAAAAABYOoAAAAAAAEAAAAAAADAAAAAwP////8BABkAdm9sYXRpbGVfd2Fsa19zdG9wMTgwbF8wMQAAAAABABgBAAAAAAEAAAAAAADAAAAAwP////8BABgAdm9sYXRpbGVfcnVuX3N0b3BfOTByXzAxAAAAAAFgGgEAAAAAAgAAAAAAAMAAAADA/////wEAGAB2b2xhdGlsZV93YWxrX3N0b3A5MHJfMDEAAAAAAAAAwAAAAMD/////AQAYAHZvbGF0aWxlX3dhbGtfc3RvcDkwcl8wMgAAAAABACgBAAAAAAEAAAAAAADAAAAAwP////8BABgAdm9sYXRpbGVfcnVuX3N0b3BfOTByXzAxAAAAAAFgKgEAAAAAAQAAAAAAAMAAAADA/////wEAGQB2b2xhdGlsZV93YWxrX3N0b3AxODByXzAxAAAAAAAAAAAKAAAAAQAAAAAAAAADAAAAAAAAwAAAAMD/////AQAhAHZvbGF0aWxlX3N0YW5kX2lkbGVfYWdncmVzc2l2ZV8wMQAAAAAAAADAAAAAwP////8BABAAdm9sYXRpbGVfaWRsZV8wMQAAAAAAAADAAAAAwP////8BABAAdm9sYXRpbGVfaWRsZV8wMgAAAABBAAAAAAAAAAEAAAAAAADAAAAAwP////8BABAAdm9sYXRpbGVfaWRsZV8wMgAAAAABAQAAAAAAAAMAAAAAAADAAAAAwP////8BACMAdm9sYXRpbGVfcnVuX2ludG9fbGlnaHRfcmVhY3Rpb25fMDEAAAAAAAAAwAAAAMD/////AQAjAHZvbGF0aWxlX3J1bl9pbnRvX2xpZ2h0X3JlYWN0aW9uXzAyAAAAAAAAAMAAAADA/////wEAIwB2b2xhdGlsZV9ydW5faW50b19saWdodF9yZWFjdGlvbl8wNAAAAAABAgAAAAAAAAMAAAAAAADAAAAAwP////8BABIAdm9sYXRpbGVfc2NyZWFtXzAxAAAAAAAAAMAAAADA/////wEAEgB2b2xhdGlsZV9zY3JlYW1fMDIAAAAAAAAAwAAAAMD/////AQASAHZvbGF0aWxlX3NjcmVhbV8wMwAAAADBAgAAAAAAAAIAAAAAAADAAAAAwP////8BAB8Adm9sYXRpbGVfbGlnaHRfcmVhY3Rpb25fbG9vcF8wMQAAAAAAAADAAAAAwP////8BACQAaW5mZWN0ZWRfYmxpbmRlZF9jb3VudGVyX3JlYWN0aW9uXzAxAAAAAEEDAAAAAAAAAgAAAAAAAMAAAADA/////wEAEAB2b2xhdGlsZV9pZGxlXzAxAAAAAAAAAMAAAADA/////wEAEAB2b2xhdGlsZV9pZGxlXzAyAAAAAGEDAAAAAAAAAQAAAAAAAMAAAADA/////wEAIQB2b2xhdGlsZV9zdGFuZF9pZGxlX2FnZ3Jlc3NpdmVfMDEAAAAAgQMAAAAAAAABAAAAAAAAwAAAAMD/////AQAZAHZvbGF0aWxlX3N0YW5kX2xvb2tfYXRfMDEAAAAAwQcAAAAAAAADAAAAAAAAwAAAAMD/////AQARAHZvbGF0aWxlX3RhdW50XzAxAAAAAAAAAMAAAADA/////wEAEQB2b2xhdGlsZV90YXVudF8wMgAAAAAAAADAAAAAwP////8BABEAdm9sYXRpbGVfdGF1bnRfMDMAAAAAwQwAAAAAAAADAAAAAAAAwAAAAMD/////AQARAHZvbGF0aWxlX3RhdW50XzAxAAAAAAAAAMAAAADA/////wEAEQB2b2xhdGlsZV90YXVudF8wMgAAAAAAAADAAAAAwP////8BABEAdm9sYXRpbGVfdGF1bnRfMDMAAAAAAQAAAAEAHAAAAAAAAQAAAAAAAMAAAADA/////wEAGgB2b2xhdGlsZV9zdW5saWdodF9kZWF0aF8wMQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAANgAAAAEUAAAAAAAAAQAAAAAAAMAAAADA/////wEAGwB2b2xhdGlsZV9Wb2xhdGlsZUdyYWJfYmVnaW4AAAAAERQAAAAAAAABAAAAAAAAwAAAAMD/////AQAbAHZvbGF0aWxlX1ZvbGF0aWxlR3JhYl9iZWdpbgAAAACxFAAAAAAAAAEAAAAAAADAAAAAwP////8BABoAdm9sYXRpbGVfVm9sYXRpbGVHcmFiX2xvb3AAAAAA0RQAAAAAAAABAAAAAAAAwAAAAMD/////AQAfAHZvbGF0aWxlX1ZvbGF0aWxlR3JhYl9maW5pc2h3aW4AAAAA8RQAAAAAAAABAAAAAAAAwAAAAMD/////AQAdAHZvbGF0aWxlX1ZvbGF0aWxlR3JhYl9mYXN0d2luAAAAADEVAAAAAAAAAQAAAAAAAAAAAAAA/////wEAAAAAAAAAAUQAAAAAAAABAAAAAAAAwAAAAMD/////AQAgAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2Zyb250X2JlZ2luAAAAABFEAAAAAAAAAQAAAAAAAMAAAADA/////wEAIAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9mcm9udF9iZWdpbgAAAACxRAAAAAAAAAYAAAAAAADAAAAAwP////8BACEAdm9sYXRpbGVfVmVoaWNsZUdyYWJfZnJvbnRfbG9vcF8xAAAAAAAAAMAAAADA/////wEAIQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9mcm9udF9sb29wXzIAAAAAAAAAwAAAAMD/////AQAhAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2Zyb250X2xvb3BfMwAAAAAAAADAAAAAwP////8BACEAdm9sYXRpbGVfVmVoaWNsZUdyYWJfZnJvbnRfbG9vcF80AAAAAAAAAMAAAADA/////wEAIQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9mcm9udF9sb29wXzUAAAAAAAAAwAAAAMD/////AQAhAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2Zyb250X2xvb3BfNgAAAADRRAAAAAAAAAEAAAAAAADAAAAAwP////8BACQAdm9sYXRpbGVfVmVoaWNsZUdyYWJfZnJvbnRfZmluaXNod2luAAAAADFFAAAAAAAAAQAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9mcm9udF9maW5pc2hsb3NlAAAAALFFAAAAAAAAAQAAAAAAAMAAAADA/////wEAJAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9mcm9udF9sZWFuX2xlZnQAAAAA0UUAAAAAAAABAAAAAAAAwAAAAMD/////AQAlAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2Zyb250X2xlYW5fcmlnaHQAAAAA8UUAAAAAAAABAAAAAAAAwAAAAMD/////AQAiAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2Zyb250X3RhdW50XzEAAAAAAUgAAAAAAAABAAAAAAAAwAAAAMD/////AQAgAHZvbGF0aWxlX1ZlaGljbGVHcmFiX3JpZ2h0X2JlZ2luAAAAABFIAAAAAAAAAQAAAAAAAMAAAADA/////wEAIAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9yaWdodF9iZWdpbgAAAACxSAAAAAAAAAYAAAAAAADAAAAAwP////8BACEAdm9sYXRpbGVfVmVoaWNsZUdyYWJfcmlnaHRfbG9vcF8xAAAAAAAAAMAAAADA/////wEAIQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9yaWdodF9sb29wXzIAAAAAAAAAwAAAAMD/////AQAhAHZvbGF0aWxlX1ZlaGljbGVHcmFiX3JpZ2h0X2xvb3BfMwAAAAAAAADAAAAAwP////8BACEAdm9sYXRpbGVfVmVoaWNsZUdyYWJfcmlnaHRfbG9vcF80AAAAAAAAAMAAAADA/////wEAIQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9yaWdodF9sb29wXzUAAAAAAAAAwAAAAMD/////AQAhAHZvbGF0aWxlX1ZlaGljbGVHcmFiX3JpZ2h0X2xvb3BfNgAAAADRSAAAAAAAAAEAAAAAAADAAAAAwP////8BACQAdm9sYXRpbGVfdmVoaWNsZUdyYWJfcmlnaHRfZmluaXNod2luAAAAADFJAAAAAAAAAQAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9yaWdodF9maW5pc2hsb3NlAAAAALFJAAAAAAAAAQAAAAAAAMAAAADA/////wEAJAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9yaWdodF9sZWFuX2xlZnQAAAAA0UkAAAAAAAABAAAAAAAAwAAAAMD/////AQAlAHZvbGF0aWxlX1ZlaGljbGVHcmFiX3JpZ2h0X2xlYW5fcmlnaHQAAAAA8UkAAAAAAAABAAAAAAAAwAAAAMD/////AQAiAHZvbGF0aWxlX1ZlaGljbGVHcmFiX3JpZ2h0X3RhdW50XzEAAAAAAUwAAAAAAAABAAAAAAAAwAAAAMD/////AQAfAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2xlZnRfYmVnaW4AAAAAEUwAAAAAAAABAAAAAAAAwAAAAMD/////AQAfAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2xlZnRfYmVnaW4AAAAAsUwAAAAAAAAGAAAAAAAAwAAAAMD/////AQAgAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2xlZnRfbG9vcF8xAAAAAAAAAMAAAADA/////wEAIAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9sZWZ0X2xvb3BfMgAAAAAAAADAAAAAwP////8BACAAdm9sYXRpbGVfVmVoaWNsZUdyYWJfbGVmdF9sb29wXzMAAAAAAAAAwAAAAMD/////AQAgAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2xlZnRfbG9vcF80AAAAAAAAAMAAAADA/////wEAIAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9sZWZ0X2xvb3BfNQAAAAAAAADAAAAAwP////8BACAAdm9sYXRpbGVfVmVoaWNsZUdyYWJfbGVmdF9sb29wXzYAAAAA0UwAAAAAAAABAAAAAAAAwAAAAMD/////AQAjAHZvbGF0aWxlX3ZlaGljbGVHcmFiX2xlZnRfZmluaXNod2luAAAAADFNAAAAAAAAAQAAAAAAAMAAAADA/////wEAJAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9sZWZ0X2ZpbmlzaGxvc2UAAAAAsU0AAAAAAAABAAAAAAAAwAAAAMD/////AQAjAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2xlZnRfbGVhbl9sZWZ0AAAAANFNAAAAAAAAAQAAAAAAAMAAAADA/////wEAJAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9sZWZ0X2xlYW5fcmlnaHQAAAAA8U0AAAAAAAABAAAAAAAAwAAAAMD/////AQAhAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2xlZnRfdGF1bnRfMQAAAAABUAAAAAAAAAEAAAAAAADAAAAAwP////8BAB8Adm9sYXRpbGVfVmVoaWNsZUdyYWJfYmFja19iZWdpbgAAAAARUAAAAAAAAAEAAAAAAADAAAAAwP////8BAB8Adm9sYXRpbGVfVmVoaWNsZUdyYWJfYmFja19iZWdpbgAAAACxUAAAAAAAAAQAAAAAAADAAAAAwP////8BACAAdm9sYXRpbGVfVmVoaWNsZUdyYWJfYmFja19sb29wXzEAAAAAAAAAwAAAAMD/////AQAgAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2JhY2tfbG9vcF8yAAAAAAAAAMAAAADA/////wEAIAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX2xvb3BfMwAAAAAAAADAAAAAwP////8BACAAdm9sYXRpbGVfVmVoaWNsZUdyYWJfYmFja19sb29wXzQAAAAA0VAAAAAAAAABAAAAAAAAwAAAAMD/////AQAjAHZvbGF0aWxlX3ZlaGljbGVHcmFiX2JhY2tfZmluaXNod2luAAAAADFRAAAAAAAAAQAAAAAAAMAAAADA/////wEAJAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX2ZpbmlzaGxvc2UAAAAAsVEAAAAAAAABAAAAAAAAwAAAAMD/////AQAjAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2JhY2tfbGVhbl9sZWZ0AAAAANFRAAAAAAAAAQAAAAAAAMAAAADA/////wEAJAB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX2xlYW5fcmlnaHQAAAAA8VEAAAAAAAACAAAAAAAAwAAAAMD/////AQAhAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2JhY2tfdGF1bnRfMQAAAAAAAADAAAAAwP////8BACEAdm9sYXRpbGVfVmVoaWNsZUdyYWJfYmFja190YXVudF8yAAAAAAFUAAAAAAAAAQAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX3JpZ2h0X2JlZ2luAAAAABFUAAAAAAAAAQAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX3JpZ2h0X2JlZ2luAAAAALFUAAAAAAAABAAAAAAAAMAAAADA/////wEAJgB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX3JpZ2h0X2xvb3BfMQAAAAAAAADAAAAAwP////8BACYAdm9sYXRpbGVfVmVoaWNsZUdyYWJfYmFja19yaWdodF9sb29wXzIAAAAAAAAAwAAAAMD/////AQAmAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2JhY2tfcmlnaHRfbG9vcF8zAAAAAAAAAMAAAADA/////wEAJgB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX3JpZ2h0X2xvb3BfNAAAAADRVAAAAAAAAAEAAAAAAADAAAAAwP////8BACkAdm9sYXRpbGVfdmVoaWNsZUdyYWJfYmFja19yaWdodF9maW5pc2h3aW4AAAAAMVUAAAAAAAABAAAAAAAAwAAAAMD/////AQAqAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2JhY2tfcmlnaHRfZmluaXNobG9zZQAAAACxVQAAAAAAAAEAAAAAAADAAAAAwP////8BACoAdm9sYXRpbGVfVmVoaWNsZUdyYWJfYmFja19yaWdodF9sZWFuX3JpZ2h0AAAAANFVAAAAAAAAAQAAAAAAAMAAAADA/////wEAKQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX3JpZ2h0X2xlYW5fbGVmdAAAAADxVQAAAAAAAAIAAAAAAADAAAAAwP////8BACcAdm9sYXRpbGVfVmVoaWNsZUdyYWJfYmFja19yaWdodF90YXVudF8xAAAAAAAAAMAAAADA/////wEAJwB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX3JpZ2h0X3RhdW50XzIAAAAAAVgAAAAAAAABAAAAAAAAwAAAAMD/////AQAkAHZvbGF0aWxlX1ZlaGljbGVHcmFiX2JhY2tfbGVmdF9iZWdpbgAAAAARWAAAAAAAAAEAAAAAAADAAAAAwP////8BACQAdm9sYXRpbGVfVmVoaWNsZUdyYWJfYmFja19sZWZ0X2JlZ2luAAAAALFYAAAAAAAABAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX2xlZnRfbG9vcF8xAAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX2xlZnRfbG9vcF8yAAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX2xlZnRfbG9vcF8zAAAAAAAAAMAAAADA/////wEAJQB2b2xhdGlsZV9WZWhpY2xlR3JhYl9iYWNrX2xlZnRfbG9vcF80AAAAANFYAAAAAAAAAQAAAAAAAMAAAADA/////wEAKAB2b2xhdGlsZV92ZWhpY2xlR3JhYl9iYWNrX2xlZnRfZmluaXNod2luAAAAADFZ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AgAAAAAAyEJVAQAAAQIAAAAAAAA/VgEAAAECAAAAAAAgQVcBAAABAgAAAAAAoEBYAQAAAQIAAAAAAAxCWQEAAAECAAAAAAAgQFsBAAABAwAAAABnAQAAAQEAAAADAAAAaAEAAAEBAAAAAgAAAHoBAAABAgAAAAAA4EB7AQAAAQIAAAAAACBBfAEAAAECAAAAAABgQX0BAAABAgAAAGZmpj9+AQAAAQIAAADNzMw9gQEAAAEDAAAAAJABAAABAgAAAGZmZj+RAQAAAQIAAAAAAMBAmwEAAAECAAAAAADAP50BAAABAgAAAAAAgD+eAQAAAQIAAAAAAIA/nwEAAAECAAAAAACAP6ABAAABAgAAAAAAgD+iAQAAAQMAAAAApQEAAAEDAAAAALUBAAABAgAAAMP1qD62AQAAAQIAAAAAAIA/ygEAAAECAAAAAAAAAPkBAAABAgAAAAAAQED7AQAAAQIAAAAAAIBA/AEAAAECAAAAAABgQQECAAABAwAAAAARAgAAAQMAAAAAGAIAAAEDAAAAAR0CAAABAgAAAAAAgD8eAgAAAQIAAAAAAIA/HwIAAAECAAAAAACAPyACAAABAgAAAAAAgD8iAgAAAQIAAADNzEw+IwIAAAECAAAAzcxMPiUCAAABAwAAAAEvAgAAAQIAAAAAAPpDMAIAAAECAAAAAAD6Q0MCAAABAgAAAAAAgEBGAgAAAQMAAAABUAIAAAEDAAAAAFcCAAABAwAAAABnAgAAAQIAAAAAACBBaAIAAAEDAAAAAWkCAAABAwAAAABvAgAAAQMAAAAAdgIAAAEDAAAAAXcCAAABAgAAAAAAgD94AgAAAQIAAAAAAABAfQIAAAEDAAAAAX4CAAABAgAAAAAAoEF/AgAAAQIAAACamZk+gAIAAAECAAAAAABwQYECAAABAgAAAJqZmT+CAgAAAQIAAAAzM7M/gwIAAAECAAAAZmbmP4QCAAABAgAAAAAAAECHAgAAAQIAAADNzEw+iAIAAAECAAAAAADIQZACAAABAgAAAAAAAACRAgAAAQMAAAABpAIAAAECAAAAAAAgQaUCAAABAgAAAAAAoEGmAgAAAQIAAAAAAAA/pwIAAAECAAAAAADAP6gCAAABAgAAAAAAAD+pAgAAAQIAAAAAAMA/qgIAAAECAAAAAACgQasCAAABAgAAAJqZMUGsAgAAAQIAAAAAAMhBrgIAAAECAAAAAAAAQa8CAAABAgAAAAAAgECwAgAAAQIAAADNzMw9tAIAAAEDAAAAALUCAAABAwAAAAAEAAAAIQAAABMAdm9sYXRpbGVfY29tYm9fcHJvYi0AAAApAHZvbGF0aWxlX3NpZ2h0X3JhbmdlX2hlaWdodF9yZWR1Y3Rpb25fbXVsHgAAAA8Adm9sYXRpbGVfaGVhbHRoHwAAABUAdm9sYXRpbGVfbWVsZWVfZGFtYWdlAAAAAA=='
}


# Following enemies in Harran (-MotherInHarran): every Harran map (and the DLC side maps, whose start files may outrank Data3.pak)
# loads the final-boss archive; the Mother's AI data goes in precompiled, with The Following's AI files it relies on.
if ($WfUsed.Count) {
    $l1w = [Text.Encoding]::GetEncoding(28591)
    if ($WfUsed -contains "Viral_WL_Final_Fight_Hard" -or $WfUsed -contains "SIR_Mother_Volatile") {
        foreach ($n in $MotherDat.Keys) { $patched["data/ai/infected/$n.dat"] = [Convert]::FromBase64String($MotherDat[$n]) }
    }
    # ghosts: copies of the big military viral (humanai.pre) and the human ghost (humanai_dlc17.pre) in the ghost-follower skin
    $ghostsUsed = @($WfUsed | Where-Object { $GhostList -contains $_ })
    if ($ghostsUsed.Count) {
        if ($patched.ContainsKey("data/presets/humanai.pre")) { $preG = $l1w.GetString([byte[]]$patched["data/presets/humanai.pre"]) }
        else { $bzg = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak")); $r = New-Object IO.StreamReader($bzg.GetEntry("data/presets/humanai.pre").Open(), $l1w); $preG = $r.ReadToEnd(); $r.Close(); $bzg.Dispose() }
        $dzg = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW_DLC17\DataDLC17_0.pak")); $r = New-Object IO.StreamReader($dzg.GetEntry("data/presets/humanai_dlc17.pre").Open(), $l1w); $dlcG = $r.ReadToEnd(); $r.Close(); $dzg.Dispose()
        $srcG = @{ "SIR_Ghost_Human" = @($dlcG, "Ghost_WastelandSpecial") }
        $nlg = if ($preG.Contains("`r`n")) { "`r`n" } else { "`n" }
        $blocksG = foreach ($n in $ghostsUsed) {
            $blk = [regex]::Match($srcG[$n][0], "(?s)[ \t]*Preset\(`"$($srcG[$n][1])`"\)\s*\{.*?\n\s*\}").Value
            if (-not $blk) { "Ghosts: $($srcG[$n][1]) not found, skipped" | Out-Host; continue }
            $blk = $blk.Replace("Preset(`"$($srcG[$n][1])`")", "Preset(`"$n`")")
            ([regex]::Replace($blk, 'SetField\("SkinName",\s*"[^"]*"\)', 'SetField("SkinName", "Ghost_Follower")')) -replace "`r?`n", $nlg
        }
        $lastG = [regex]::Matches($preG, '(?s)[ \t]*Preset\("[^"]+"\)\s*\{.*?\n\s*\}') | Select-Object -Last 1; $atG = $lastG.Index + $lastG.Length
        $patched["data/presets/humanai.pre"] = $l1w.GetBytes($preG.Substring(0, $atG) + $nlg + $nlg + "        // ---- Ghosts for Harran (Dying Light Randomiser mod) ----" + $nlg + ($blocksG -join ($nlg + $nlg)) + $preG.Substring($atG))
        if ($ghostsUsed -contains "SIR_Ghost_Human") { foreach ($n in $GhostDat.Keys) { $patched["data/ai/human/$n.dat"] = [Convert]::FromBase64String($GhostDat[$n]) } }
    }
    $bzw = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak")); $dzw = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW_DLC17\DataDLC17_0.pak"))
    $aiW = 0
    foreach ($e in $dzw.Entries) {
        if (-not ($e.FullName -match '^data/ai/' -and $e.Length) -or $bzw.GetEntry($e.FullName) -or $patched.ContainsKey($e.FullName)) { continue }
        $ms = New-Object IO.MemoryStream; $st = $e.Open(); $st.CopyTo($ms); $st.Close(); $patched[$e.FullName] = $ms.ToArray(); $aiW++
    }
    $bzw.Dispose(); $dzw.Dispose()
    # final-boss archive for the Mother and the ghosts, main archive for the military viral
    # Both archives hold survivor_b.msh; the main archive must supply it for the military skin, so it goes first.
    $wfPacks = @(); if ($WfUsed -contains "Viral_Big_Humanity") { $wfPacks += "wasteland" }; if (@($WfUsed | Where-Object { $_ -ne "Viral_Big_Humanity" }).Count) { $wfPacks += "wasteland_final" }
    $mapW = 0
    $wfPaks = @(Join-Path $Game "DW\Data2.pak") + @(Get-ChildItem $Game -Directory -Filter "DW_DLC*" | Where-Object { $_.Name -notin "DW_DLC17", "DW_DLC49" } | ForEach-Object { Get-ChildItem $_.FullName -Filter *.pak } | ForEach-Object { $_.FullName })
    foreach ($pk in $wfPaks) {
        $zw = [IO.Compression.ZipFile]::OpenRead($pk)
        foreach ($e in @($zw.Entries | Where-Object { $_.Name -like "*.startprop" -and $_.Name -ne "menu_lvl_new.startprop" })) {
            if ($patched.ContainsKey($e.FullName)) { $spw = $l1w.GetString([byte[]]$patched[$e.FullName]) }   # already given the Hellraid line
            else { $r = New-Object IO.StreamReader($e.Open(), $l1w); $spw = $r.ReadToEnd(); $r.Close() }
            $add = @($wfPacks | Where-Object { -not $spw.Contains("CrossLevelPack(`"$_`"") }); if (-not $add.Count) { continue }
            $m = [regex]::Matches($spw, '(?m)^([ \t]*)CrossLevelPack\([^\r\n]*') | Select-Object -Last 1
            if (-not $m) { continue }
            $snl = if ($spw.Contains("`r`n")) { "`r`n" } else { "`n" }
            $patched[$e.FullName] = $l1w.GetBytes($spw.Insert($m.Index + $m.Length, (@($add | ForEach-Object { $snl + $m.Groups[1].Value + "CrossLevelPack(`"$_`", `"`")" }) -join ""))); $mapW++
        }
        $zw.Dispose()
    }
    "Following enemies in Harran: {0}; {1} AI files copied; {2} maps load The Following's archives ({3})" -f ($WfUsed -join ", "), $aiW, $mapW, ($wfPacks -join ", ")
}
# Enemy AI (-AISwap): each enemy keeps its body, look, size and voice but gets another enemy's "brain" (AI data, knowledge base,
# modules, goal rules, AI class and weapon). Swaps stay within the same AI folder (zombie / infected / human) and body shape: tested; swapping across
# body shapes (Demolisher, Toad, Volatile, Bolter, Bomber, Screamer get other bodies' brains) crashed on spawn. Rolled from the seed.
# rewrite blocks from the end so earlier match positions stay valid
if ($AISwap) {
    $l1a = [Text.Encoding]::GetEncoding(28591)
    if ($patched.ContainsKey("data/presets/humanai.pre")) { $preA = $l1a.GetString([byte[]]$patched["data/presets/humanai.pre"]) }
    else { $bza = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak")); $r = New-Object IO.StreamReader($bza.GetEntry("data/presets/humanai.pre").Open(), $l1a); $preA = $r.ReadToEnd(); $r.Close(); $bza.Dispose() }
    $bza = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak")); $datDir = @{}
    foreach ($e in $bza.Entries) { if ($e.FullName -match '^data/ai/(human|zombie|infected)/\1_data_custom_preset_(.+)\.dat$') { $datDir[$Matches[2]] = $Matches[1] } }; $bza.Dispose()
    $brainFields = "m_CustomDataPreset", "m_KnowledgeBasePreset", "m_ModulesPreset", "m_MainGoalRulesPreset", "m_Type", "m_PrimaryWeaponName", "m_PrimaryWeaponProbability", "m_ThrowableWeaponName", "m_NeverHolsterWeapon", "m_GrabEnabled"
    $swapNames = @(
        "Biter_Man", "Biter_Policeman", "Biter_Woman", "Biter_Worker", "BiterBurn_Man", "BiterBurn_Woman", "BiterLurker_Man", "BiterLurker_Woman", "BiterNurker_Man",
        "BiterWeapon_Man", "BiterWeapon_Woman", "ViralHumanity_Man", "ViralHumanity_Man_OldTown", "ViralHumanity_Woman", "ViralHumanity_Woman_OldTown",
        "Goon_Slums", "Toad_OldTown", "Demolisher", "Bomber", "RunningBomber", "Screamer", "GasTank", "Volatile", "Enemy_Headhunter_Melee",
        "enc_slums_maskedbandit_lvl02", "enc_slums_maskedbanditrifle_lvl02", "Quest_Museum_TahirBoss", "Demolisher_Blister", "DemolisherTough", "Demolisher_Prison",
        "Goon_Hazmat", "Goon_Poison", "Goon_Blisters", "Goon_OldTown", "Goon_OldTown_Gaas", "Toad_Poison", "Bomber_Poison", "GasTankGray", "Volatile_Super",
        "ViralBurn_Man", "ViralPoison_Man", "ViralBlister_Man", "Prime", "PrimeNight")
    $blk = @{}; $brain = @{}; $dirOf = @{}
    foreach ($n in $swapNames) {
        $m = [regex]::Match($preA, "(?s)[ \t]*Preset\(`"$n`"\)\s*\{.*?\n\s*\}"); if (-not $m.Success) { continue }
        $blk[$n] = $m
        $brain[$n] = @(foreach ($f in $brainFields) { $x = [regex]::Match($m.Value, "(?m)^[ \t]*SetField\(`"$f`",[^\r\n]*"); if ($x.Success) { $x.Value.Trim() } })
        $cd = ([regex]::Match($m.Value, 'SetField\("m_CustomDataPreset",\s*"([^"]*)"').Groups[1].Value -split ';')[0]; $dirOf[$n] = $datDir[$cd]
        # body family: only enemies sharing a body shape swap (unique bodies only among their own variants)
        $mesh = [regex]::Match($m.Value, 'SetField\("MeshName",\s*"([^"]*)"').Groups[1].Value.ToLower()
        $fam = switch -Regex ($mesh) { '^armored' { 'demolisher' } 'spitter' { 'toad' } 'suicider' { 'bomber' } 'screamer' { 'screamer' } 'voleteile' { 'volatile' } 'prime' { 'bolter' } default { 'humanoid' } }
        $dirOf[$n] = "$($datDir[$cd])/$fam"; if (-not $datDir[$cd]) { $dirOf[$n] = "" }
    }
    $swapLog = New-Object Collections.ArrayList; $donor = @{}
    foreach ($grp in ($dirOf.Keys | Group-Object { $dirOf[$_] })) {
        if (-not $grp.Name) { continue }
        $ns = @($grp.Group | Sort-Object); if ($ns.Count -lt 2) { continue }
        do { $perm = @($ns | Get-Random -Count $ns.Count); $fixed = 0; for ($i = 0; $i -lt $ns.Count; $i++) { if ($perm[$i] -eq $ns[$i]) { $fixed++ } } } while ($fixed -gt 0)   # nobody keeps its own brain
        for ($i = 0; $i -lt $ns.Count; $i++) { $donor[$ns[$i]] = $perm[$i] }
    }
    foreach ($n in @($donor.Keys | Sort-Object { $blk[$_].Index } -Descending)) {
        $old = $blk[$n].Value; $new = $old
        foreach ($f in $brainFields) { $new = [regex]::Replace($new, "(?m)^[ \t]*SetField\(`"$f`",[^\r\n]*\r?\n", "") }
        $nlA = if ($new.Contains("`r`n")) { "`r`n" } else { "`n" }; $ind = [regex]::Match($old, "(?m)^([ \t]*)SetField").Groups[1].Value
        $close = $new.LastIndexOf("}"); $lineStart = $new.LastIndexOf("`n", $close) + 1
        $new = $new.Substring(0, $lineStart) + (@($brain[$donor[$n]] | ForEach-Object { $ind + $_ + $nlA }) -join "") + $new.Substring($lineStart)
        $preA = $preA.Substring(0, $blk[$n].Index) + $new + $preA.Substring($blk[$n].Index + $blk[$n].Length)
        [void]$swapLog.Add(("{0,-34} gets the brain of  {1}" -f $n, $donor[$n]))
    }
    $patched["data/presets/humanai.pre"] = $l1a.GetBytes($preA)
    $patched["randomiser_ai_swaps.txt"] = "Dying Light Randomiser mod - which enemy got which enemy's AI (body first)`r`n" + (($swapLog | Sort-Object) -join "`r`n") + "`r`n"
    "Enemy AI: {0} enemy types got another enemy's AI (list in randomiser_ai_swaps.txt inside the pak)" -f $swapLog.Count
}

# Which settings built this pak (the game ignores the file; it answers "which Data3.pak is this?")
$settings = ($PSBoundParameters.GetEnumerator() | Where-Object { $_.Key -notin "Game", "OutFile", "Seed" } |
    ForEach-Object { if ($_.Value -is [switch]) { "-$($_.Key)" } else { "-$($_.Key) $($_.Value)" } }) -join " "
$patched["randomiser_settings.txt"] = "Dying Light Randomiser mod 2.0`r`nbuild.ps1 $settings -Seed $Seed`r`nLoot $Loot, Shops $Shops, Quartermaster $Quartermaster, Tiers $Tiers, Quantity $Quantity, UI colours $UIColours$(if ($UIIcons -and $UIColours -ne "Off") { " + icons" }), World colours $WorldColours, Subtitles $(if ($Subtitles) { "shuffled" } else { "normal" }), Quest rewards $QuestRewards, Dialogue $Dialogue, Hellraid $(if ($Hellraid -and $hrUsed.Count) { "on" + $(if ($HellraidFollowing) { " (+ The Following)" }) } else { "off" }), Enemy AI $(if ($AISwap) { "swapped" } else { "normal" }), Following enemies in Harran $(if ($WfUsed.Count) { "on" } else { "off" }), Crowds $CrowdMode$(if ($CrowdMode -eq 'Custom') { " ($Crowd1 / $Crowd2)" }), Spawns $(if ($NoSpawns) { 'off' } else { 'on' + $(if ($Events) { ' + events' }) + $(if ($IcedBolter) { ' + Iced Bolter' }) }), The Following $(if ($NoFollowing) { 'vanilla' } else { 'randomised' })`r`n"
"Seed $Seed"

$tmp = if ($OutFile) { $OutFile } else { Join-Path $PSScriptRoot "Data3.pak" }
New-Item -ItemType Directory -Force (Split-Path $tmp) | Out-Null
Write-Pak $tmp $patched

if ($OutFile) { if ($Subtitles) { Write-LangPak $script:SubSource "$OutFile.lang.pak" $script:SubBins }; "Built $OutFile (not installed)"; return }
Copy-Item $tmp $target -Force
"Installed $target"
$dlc0 = Join-Path $Game "DW_DLC17\DataDLC17_0.pak"
$keep = @()
if ($script:SubBins.Count) { $keep += "$($script:SubLangPath).randomiser-backup" }
if ($script:DlcDialogue.Count) { $keep += "$dlc0.randomiser-backup" }
if ($script:DlcMaps.Count) { $keep += "$dlc2.randomiser-backup" }
foreach ($f in $script:SubLoose.Keys) { $keep += "$f.randomiser-backup" }
Restore-LangPaks -Keep $keep   # anything no longer in use goes back to vanilla
if ($script:SubBins.Count) { Set-ModdedPak $script:SubLangPath $script:SubBins; "Subtitles written to $(Split-Path $script:SubLangPath -Leaf) (original kept as a backup)" }
foreach ($f in $script:SubLoose.Keys) {
    if (-not (Test-Path "$f.randomiser-backup")) { Copy-Item $f "$f.randomiser-backup" }
    [IO.File]::WriteAllBytes($f, $script:SubLoose[$f])
}
if ($script:SubLoose.Count) { "The Following's subtitles written ($($script:SubLoose.Count) files, originals kept as backups)" }
if ($script:DlcDialogue.Count) { Set-ModdedPak $dlc0 $script:DlcDialogue; "The Following's dialogue written to DataDLC17_0.pak (original kept as a backup)" }
if ($script:DlcMaps.Count) { Set-ModdedPak $dlc2 $script:DlcMaps; "The Following's map set to load the Hellraid archive in DataDLC17_2.pak (original kept as a backup)" }
# undo an older test build's DataDLC17_1.pak (anything but the 1-entry placeholder)
if (Test-Path $dlcTarget) {
    $cur = [IO.File]::ReadAllBytes($dlcTarget)
    if ([Convert]::ToBase64String($cur) -ne [Convert]::ToBase64String($VanillaPlaceholder)) { Write-VanillaPlaceholder $dlcTarget; "Restored the vanilla DataDLC17_1.pak" }
}
