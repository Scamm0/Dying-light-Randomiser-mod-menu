# Randomiser mod for Dying Light 1 (1.0)
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
    [int]$Seed,                 # same seed + settings = same build-time rolls (0 = new random seed)
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

# The vanilla Data3.pak holds one empty placeholder.file and nothing else.
function Write-Pak([string]$path, [hashtable]$files) {
    if (Test-Path $path) { Remove-Item $path }
    $zip = [IO.Compression.ZipFile]::Open($path, "Create")
    foreach ($f in $files.Keys) {
        $d = $zip.CreateEntry($f, "Optimal")
        $w = New-Object IO.StreamWriter($d.Open(), (New-Object Text.UTF8Encoding($false)))
        $w.Write($files[$f]); $w.Close()
    }
    $zip.Dispose()
}

if ($Uninstall) {
    Write-Pak $target @{ "placeholder.file" = "" }
    "Restored the vanilla Data3.pak"
    if (Test-Path $dlcTarget) { Write-Pak $dlcTarget @{ "placeholder.file" = "" }; "Restored the vanilla DataDLC17_1.pak" }
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
$CrowdSpecials = @($Specials | Where-Object { $_ -notmatch 'Headhunter|bandit|Wasteland|ZombieHunt|Prime|Viral|Gaas|Tahir' -and $EventList -notcontains $_ })

# Individually switched-off enemies (menu sub-window)
$Off = @($Exclude -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Off) {
    $Specials      = @($Specials | Where-Object { $Off -notcontains $_ })
    $FollowingOnly = @($FollowingOnly | Where-Object { $Off -notcontains $_ })
    $kept = @($CrowdSpecials | Where-Object { $Off -notcontains $_ })
    if ($kept) { $CrowdSpecials = $kept }   # all crowd-safe specials off: "Random special" still rolls from the full set
    if (-not $NoSpawns -and -not $Specials) { throw "Every Harran enemy is switched off. Turn at least one back on, or untick 'Randomise noise / viral spawns'." }
    "Left out: " + ($Off -join ", ")
}
$SpecialsFollowing = (@($Specials + $FollowingOnly) | Select-Object -Unique) -join ";"
$Specials = $Specials -join ";"

$Replace = '^(Biter\w*|NightWalker_\w+)$'
# Virals (incl. the ones loud noises call in); HumanToViralTransformation is left alone
if (-not $NoVirals) { $Replace = '^(Biter\w*|NightWalker_\w+|ViralHumanity_\w+|Viral_(Man|Woman))$' }

# Spawn tricks that play biter/viral-only animations (lying dead, eating, climbing
# out of the ground). Special infected have no such anims and stay in T-pose.
$BiterOnlyFields = '^\s*(DiffLvlTableName|SetDeadBody|AttractorToSpawnWithAI|MeshToSpawnWithAI|CanSpawnInAttractor|SarcophagusTime)\('

function Convert-Presets([string]$text, [string]$list = $Specials) {
    $out = New-Object System.Text.StringBuilder
    $inBlock = $false
    foreach ($line in $text -split "\r?\n") {
        if ($line -match '^\s*PresetDef\(') { $inBlock = $false }
        if ($line -match '^(\s*)AIPreset\("([^"]*)"\)') {
            $indent = $Matches[1]; $was = $Matches[2]
            $names = $was.Split(";") | Where-Object { $_ }
            if ($names -and -not ($names | Where-Object { $_ -notmatch $Replace })) {
                $line = "${indent}AIPreset(`"$list`") // was: $was"
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
               else { Convert-Presets $t }
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
    # GRE Goon: its zombie data set sits under infected/ in Data0, where the zombie loader never looks
    $d0 = [IO.Compression.ZipFile]::OpenRead((Join-Path $Game "DW\Data0.pak"))
    $zh = "zombie_data_custom_preset_thug_armed_hard_zombie_hunt.scr"
    $patched["data/ai/zombie/$zh"] = ReadEntry $d0 "data/ai/infected/$zh"
    $d0.Dispose()
}

if (-not $NoFollowing -and (Test-Path (Join-Path $Game "DW_DLC17"))) { Add-FollowingOverrides }
else { $patched.Remove("data/maps/wasteland/wasteland_presets.scr") }

# Which settings built this pak (the game ignores the file; it answers "which Data3.pak is this?")
$settings = ($PSBoundParameters.GetEnumerator() | Where-Object { $_.Key -notin "Game", "OutFile", "Seed" } |
    ForEach-Object { if ($_.Value -is [switch]) { "-$($_.Key)" } else { "-$($_.Key) $($_.Value)" } }) -join " "
$patched["randomiser_settings.txt"] = "Dying Light Randomiser mod 1.0`r`nbuild.ps1 $settings -Seed $Seed`r`nLoot $Loot, Shops $Shops, Quartermaster $Quartermaster, Tiers $Tiers, Quantity $Quantity, Crowds $CrowdMode$(if ($CrowdMode -eq 'Custom') { " ($Crowd1 / $Crowd2)" }), Spawns $(if ($NoSpawns) { 'off' } else { 'on' + $(if ($Events) { ' + events' }) + $(if ($IcedBolter) { ' + Iced Bolter' }) }), The Following $(if ($NoFollowing) { 'vanilla' } else { 'randomised' })`r`n"
"Seed $Seed"

$tmp = if ($OutFile) { $OutFile } else { Join-Path $PSScriptRoot "Data3.pak" }
New-Item -ItemType Directory -Force (Split-Path $tmp) | Out-Null
Write-Pak $tmp $patched

if ($OutFile) { "Built $OutFile (not installed)"; return }
Copy-Item $tmp $target -Force
"Installed $target"
# undo an older test build's DataDLC17_1.pak (anything but the 1-entry placeholder)
if (Test-Path $dlcTarget) {
    $z = [IO.Compression.ZipFile]::OpenRead($dlcTarget); $n = $z.Entries.Count; $z.Dispose()
    if ($n -gt 1) { Write-Pak $dlcTarget @{ "placeholder.file" = "" }; "Restored the vanilla DataDLC17_1.pak (old test files)" }
}
