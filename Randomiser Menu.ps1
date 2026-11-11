# Mod menu for the Dying Light 1 randomiser: tick features, press Install, and it runs build.ps1
# (same folder) to write DW\Data3.pak. Settings are remembered in menu-settings.json.
# Start it with "Randomiser Menu.bat". Close the game first: Dying Light locks its paks.
# -Launch: no window; re-roll with the saved choices and a new seed, then start the game. Anything after
# -Launch is the game's command line (Steam launch option "... -Launch %command%"); without one it starts
# the game through Steam. The build's output goes to last-launch.log.
param([switch]$Launch)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$build    = Join-Path $PSScriptRoot "build.ps1"
$settings = Join-Path $PSScriptRoot "menu-settings.json"
# Finds Dying Light in any Steam library (Steam's registry path + libraryfolders.vdf); "" if not found.
function Find-DyingLight {
    $steam = @()
    foreach ($k in "HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam") {
        try { $p = Get-ItemProperty $k -ErrorAction Stop; $steam += @($p.SteamPath, $p.InstallPath) | Where-Object { $_ } } catch {}
    }
    $libs = @()
    foreach ($s in $steam | Select-Object -Unique) {
        $s = $s -replace '/', '\'; $libs += $s
        $vdf = Join-Path $s "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) { $libs += [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' } }
    }
    foreach ($l in $libs | Select-Object -Unique) {
        $g = Join-Path $l "steamapps\common\Dying Light"
        if (Test-Path (Join-Path $g "DW\Data0.pak")) { return $g }
    }
    ""
}
$defaults = [ordered]@{
    Game = ""
    Spawns = $true; Night = $true; Virals = $true
    CrowdOverall = "Biter (vanilla)"; Crowd1 = "Biter (vanilla)"; Crowd2 = "Biter (vanilla)"
    Variants = $true; GRE = $true; Bolters = $true; Tahir = $true
    Freaks = "Freaks + Ultras"; FreaksInHarran = $true; MotherInHarran = $false; FollowingArchive = $false; AISwap = $false; HellraidFollowing = $false; Events = $false; Friendlies = $false; IcedBolter = $false; Following = $true; Exclude = ""; PoolV2 = $false; PoolNames = ""
    Loot = "Off"; Shops = "Off"; Quartermaster = "Off"; Tiers = "Off"; Quantity = "Off"; UIColours = "Off"; UIIcons = $false; WorldColours = "Off"; Subtitles = $false; QuestRewards = "Off"; Dialogue = "Off"; Seed = ""
}
$cfg = $defaults
if (Test-Path $settings) {
    try { $saved = Get-Content $settings -Raw | ConvertFrom-Json; foreach ($p in $saved.PSObject.Properties) { if ($cfg.Contains($p.Name)) { $cfg[$p.Name] = $p.Value } } } catch {}
    if ($saved.Crowds -eq "Off" -and -not $saved.CrowdOverall) { $cfg.CrowdOverall = "Biter (vanilla)" }   # settings from test builds
}
if (-not $cfg.Game -or -not (Test-Path (Join-Path $cfg.Game "DW\Data0.pak"))) { $found = Find-DyingLight; if ($found) { $cfg.Game = $found } }
# Crowd choices: menu name => build.ps1 -Crowd1/-Crowd2 value. Humans and Bolters are left out (untested
# in the crowd system), except the event enemies, which are all here.
$CrowdTypes = [ordered]@{
    "Biter (vanilla)" = "Vanilla"; "L4D runner" = "L4D"; "Viral" = "Viral"; "Random special" = "Random"
    "Goon" = "Goon_Slums"; "Hammer Goon (Old Town)" = "Goon_OldTown"; "Hazmat Goon" = "Goon_Hazmat"
    "Fireman Goon" = "Goon_Poison"; "Blistered Goon" = "Goon_Blisters"
    "Toad" = "Toad_OldTown"; "Poison Toad" = "Toad_Poison"
    "Demolisher" = "Demolisher"; "Blistered Demolisher" = "Demolisher_Blister"; "Black-masked Demolisher" = "DemolisherTough"
    "Prison Demolisher" = "Demolisher_Prison"; "Military Demolisher" = "Demolisher_Wasteland"
    "Bomber" = "Bomber"; "Poison Bomber" = "Bomber_Poison"; "Suicider" = "RunningBomber"; "Screamer" = "Screamer"
    "Gas Tank biter" = "GasTank"; "Grey Gas Tank biter" = "GasTankGray"; "Volatile" = "Volatile"; "Super Volatile" = "Volatile_Super"
    "Event: Rust rifleman (Zombie with gun)" = "rust_scientist_range"; "Event: Iced Bolter" = "Prime_Winter"
    "Event: Astronaut invader (melee)" = "astronaut_melee"; "Event: Astronaut invader (rifle)" = "astronaut_range"
    "Event: Chivalry knight" = "Medieval_Armored"
}
$Separate = "(set Type 1 and Type 2)"
# Crowd choices from test builds that were renamed or removed (event enemies that didn't spawn, crashed or
# T-posed, and Hellraid enemies, which never load outside Hellraid mode).
foreach ($k in "CrowdOverall", "Crowd1", "Crowd2") {
    if ($cfg[$k] -eq "Event: Rust scientist (rifle)") { $cfg[$k] = "Event: Rust rifleman (Zombie with gun)" }
    elseif ($cfg[$k] -match '^(Event|Hellraid): ' -and -not $CrowdTypes.Contains($cfg[$k])) { $cfg[$k] = "L4D runner" }
}
# Every enemy build.ps1 can put in the spawn lists, for the individual picker: group => preset name => menu
# name. Unticked names go to build.ps1 -Exclude; the Enemy spawn pool selection window is the only on/off switch for them.
# checkbox: the picker shows them unticked while it's off, and on OK sets it from whether any are ticked.
# Freaks and Ultras depend on two options (Freaks in Harran, Freaks in The Following), so they stay separate.
$EnemyGroups = [ordered]@{
    "Specials" = [ordered]@{ "Goon_Slums" = "Goon"; "Toad_OldTown" = "Toad (spitter)"; "Demolisher" = "Demolisher"; "Bomber" = "Bomber"
        "RunningBomber" = "Suicider"; "Screamer" = "Screamer"; "GasTank" = "Gas Tank biter"; "Volatile" = "Volatile" }
    "Humans" = [ordered]@{ "Enemy_Headhunter_Melee" = "Old Town bandit"; "enc_slums_maskedbandit_lvl02" = "Rais's man (melee)"
        "enc_slums_maskedbanditrifle_lvl02" = "Rais's man (rifle)"; "Quest_Museum_TahirBoss" = "Tahir" }
    "Variants" = [ordered]@{ "Demolisher_Blister" = "Blistered Demolisher"; "DemolisherTough" = "Black-masked Demolisher"
        "Demolisher_Prison" = "Prison Demolisher"; "Demolisher_Wasteland" = "Military Demolisher"; "Goon_Hazmat" = "Hazmat Goon"
        "Goon_Poison" = "Fireman Goon"; "Goon_Blisters" = "Blistered Goon"; "Goon_OldTown" = "Hammer Goon (Old Town)"
        "Goon_OldTown_Gaas" = "Mutated Goon"; "Toad_Poison" = "Poison Toad"; "Bomber_Poison" = "Poison Bomber"
        "GasTankGray" = "Grey Gas Tank biter"; "Volatile_Super" = "Super Volatile"; "ViralBurn_Man" = "Burning viral"
        "ViralPoison_Man" = "Toxic viral"; "ViralBlister_Man" = "Blistered viral"; "Viral_Big_Humanity" = "Big military viral (Harran: see the options below)" }
    "GRE operatives" = [ordered]@{ "Demolisher_ZombieHunt" = "GRE Demolisher"; "Goon_ZombieHunt" = "GRE Goon (needs Freaks in Harran)" }
    "Bolters" = [ordered]@{ "Prime" = "Bolter (day)"; "PrimeNight" = "Bolter (night)" }
    "Iced Bolter" = [ordered]@{ "Prime_Winter" = "Iced Bolter" }
    "Freaks of Nature (see the Freaks options below)" = [ordered]@{ "Demolisher_WastelandSpecial" = "Freak Demolisher"; "Goon_WastelandSpecial" = "Freak Goon"
        "Bolter_WastelandSpecial" = "Freak Bolter"; "Toad_WastelandSpecial" = "Freak Toad"
        "GasTank_WastelandSpecial" = "Freak Gas Tank biter (Following only)"; "Biter_WastelandSpecial" = "Freak biter (Following only)" }
    "Ultras (see the Freaks options below)" = [ordered]@{ "Demolisher_WastelandUltra" = "Behemoth"; "Demolisher_WastelandUltra_H" = "Behemoth (second type)"
        "Goon_WastelandUltra" = "Ultra Goon"; "Biter_WastelandUltra" = "Ultra biter (Following only)"; "Toad_WastelandUltra" = "Ultra Toad (Following only)" }
    "Hellraid" = [ordered]@{ "HR_Skeletor_l1" = "Skeleton"; "HR_Skeletor_Order_l2" = "Skeleton (Order)"; "HR_Skeletor_l3" = "Skeleton (armoured)"
        "HR_Adept_Fire_lvl0" = "Fire adept"; "HR_Adept_Energy_lvl0" = "Lightning adept"; "HR_Adept_Poison_lvl0" = "Poison adept"; "HR_Darkknight" = "Dark Knight"; "HR_Minotaur" = "Minotaur" }
    "The Mother (Harran: see the options below)" = [ordered]@{ "Viral_WL_Final_Fight_Hard" = "The Mother (viral form)"; "SIR_Mother_Volatile" = "The Mother (Volatile form)" }
    "Ghosts (Harran: see the options below)" = [ordered]@{ "SIR_Ghost_Human" = "Human ghost (knife thrower)" }
    "Friendly NPCs" = [ordered]@{ "enc_looting_proplayer" = "Armed survivor"; "enc_story_teller_SurvivorEnc01" = "Survivor (unarmed 1)"; "enc_story_teller_SurvivorEnc02" = "Survivor (unarmed 2)"
        "enc_story_teller_SurvivorEnc03" = "Survivor (unarmed 3)"; "enc_survivor_escort_Ahmet" = "Ahmet"; "enc_survivor_escort_Babar" = "Babar"; "enc_survivor_escort_Faruk" = "Faruk"
        "Brecken_Soldier_001" = "Tower soldier (rifle)"; "Dahlia_Bodyguard" = "Bodyguard (rifle)"; "Jade_Museum" = "Jade (museum)" }
    "Event enemies" = [ordered]@{ "rust_scientist_range" = "Rust rifleman (Zombie with gun)"
        "astronaut_melee" = "Astronaut invader (melee)"; "astronaut_range" = "Astronaut invader (rifle)"; "Medieval_Armored" = "Chivalry knight" }
}
# picker group / single enemy => main-window checkbox variable
# New installs and settings saved before the spawn pool window took over: the old group settings become unticked enemies.
if (-not $cfg.PoolV2) {
    $oldOff = @("$($cfg.Exclude)" -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $oldGroups = @{ Variants = "Variants"; GRE = "GRE operatives"; Bolters = "Bolters"; Events = "Event enemies"; IcedBolter = "Iced Bolter"; Friendlies = "Friendly NPCs" }
    foreach ($k in $oldGroups.Keys) { if (-not $cfg[$k]) { $oldOff += @($EnemyGroups[$oldGroups[$k]].Keys) } }
    if (-not $cfg.Tahir) { $oldOff += "Quest_Museum_TahirBoss" }
    $cfg.Exclude = (@($oldOff | Select-Object -Unique) -join ",")
    $cfg.PoolV2 = $true
}

# Enemies added in later versions start switched off when they're opt-in kinds (events, Iced Bolter, friendlies, Hellraid).
# PoolNames remembers every enemy the menu knew about when settings were last saved.
$allPool = @(foreach ($grp in $EnemyGroups.Keys) { $EnemyGroups[$grp].Keys })
$knownPool = if ("$($cfg.PoolNames)".Trim()) { @("$($cfg.PoolNames)" -split ',') } else { @($allPool | Where-Object { $EnemyGroups["Hellraid"].Keys -notcontains $_ -and $EnemyGroups["The Mother (Harran: see the options below)"].Keys -notcontains $_ }) }
$newOff = @(foreach ($grp in "Event enemies", "Iced Bolter", "Friendly NPCs", "Hellraid", "The Mother (Harran: see the options below)") { @($EnemyGroups[$grp].Keys) | Where-Object { $knownPool -notcontains $_ } })
if ($newOff.Count) { $cfg.Exclude = (@(@("$($cfg.Exclude)" -split ',' | Where-Object { $_ }) + $newOff) | Select-Object -Unique) -join "," }
$cfg.PoolNames = $allPool -join ","

function Get-BuildArgs($cfg, [switch]$NewSeed) {
    $a = @()
    if (-not $cfg.Spawns) { $a += "-NoSpawns" }
    else {
        if (-not $cfg.Night)    { $a += "-DayOnly" }
        if (-not $cfg.Virals)   { $a += "-NoVirals" }
        $poolOff = @("$($cfg.Exclude)" -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $anyOn = { param($group) [bool]@($EnemyGroups[$group].Keys | Where-Object { $poolOff -notcontains $_ }).Count }
        if ($cfg.FreaksInHarran) { $a += "-FreaksInHarran" }
        if ($cfg.MotherInHarran) { $a += "-MotherInHarran" }
        if ($cfg.FollowingArchive) { $a += "-FollowingArchive" }
        if (& $anyOn "Event enemies") { $a += "-Events" }
        if (& $anyOn "Friendly NPCs") { $a += "-Friendlies" }
        if (& $anyOn "Iced Bolter")   { $a += "-IcedBolter" }
        if (& $anyOn "Hellraid")      { $a += "-Hellraid"; if ($cfg.HellraidFollowing -and $cfg.Following -ne $false) { $a += "-HellraidFollowing" } }
        if (& $anyOn "The Mother (Harran: see the options below)") { $a += "-Mother" }
        $a += "-Freaks", @{ "Off" = "None"; "Freaks" = "Freaks"; "Freaks + Ultras" = "Ultra" }[$cfg.Freaks]
        if ("$($cfg.Exclude)".Trim()) { $a += "-Exclude", "$($cfg.Exclude)".Trim() }
    }
    if ($cfg.Following -eq $false) { $a += "-NoFollowing" }
    $one = $cfg.CrowdOverall -and $cfg.CrowdOverall -ne $Separate
    $c1 = $CrowdTypes[$(if ($one) { $cfg.CrowdOverall } else { $cfg.Crowd1 })]
    $c2 = $CrowdTypes[$(if ($one) { $cfg.CrowdOverall } else { $cfg.Crowd2 })]
    if (-not $c1) { $c1 = "L4D" }; if (-not $c2) { $c2 = "L4D" }
    if ($c1 -eq "Vanilla" -and $c2 -eq "Vanilla") { $a += "-CrowdMode", "Off" } else { $a += "-Crowd1", $c1, "-Crowd2", $c2 }
    $a += "-Loot", $cfg.Loot, "-Shops", $cfg.Shops, "-Quartermaster", $cfg.Quartermaster, "-Tiers", $cfg.Tiers, "-Quantity", $cfg.Quantity, "-UIColours", $cfg.UIColours
    if ($cfg.UIIcons -and $cfg.UIColours -ne "Off") { $a += "-UIIcons" }
    $a += "-WorldColours", $cfg.WorldColours, "-QuestRewards", $cfg.QuestRewards, "-Dialogue", ("$($cfg.Dialogue)" -replace " ", "")
    if ($cfg.Subtitles) { $a += "-Subtitles" }; if ($cfg.AISwap) { $a += "-AISwap" }    if (-not $NewSeed -and "$($cfg.Seed)".Trim() -match '^\d+$') { $a += "-Seed", "$($cfg.Seed)".Trim() }
    $a
}

if ($Launch) {
    $logFile = Join-Path $PSScriptRoot "last-launch.log"
    if (Get-Process DyingLightGame -ErrorAction SilentlyContinue) { "Dying Light is already running; nothing re-rolled." | Set-Content $logFile }
    elseif (-not (Test-Path (Join-Path $cfg.Game "DW\Data0.pak"))) { "No DW\Data0.pak in $($cfg.Game). Open the menu and pick the game folder." | Set-Content $logFile }
    else {
        $buildArgs = Get-BuildArgs $cfg -NewSeed
        & powershell -NoProfile -ExecutionPolicy Bypass -File $build -Game $cfg.Game @buildArgs 2>&1 | ForEach-Object { "$_" } | Set-Content $logFile
    }
    # The game starts even if the build failed (it then uses the Data3.pak already there).
    if ($args.Count) {
        $run = @{ FilePath = $args[0]; WorkingDirectory = (Split-Path $args[0]); Wait = $true }
        if ($args.Count -gt 1) { $run.ArgumentList = @($args | Select-Object -Skip 1) }
        Start-Process @run
    }
    else { Start-Process "steam://rungameid/239140" }
    exit
}

$form = New-Object Windows.Forms.Form -Property @{
    Text = "Dying Light Randomiser Mod 2.0"; Size = New-Object Drawing.Size(560, 900)
    FormBorderStyle = "FixedDialog"; MaximizeBox = $false; StartPosition = "CenterScreen"
    Font = New-Object Drawing.Font("Segoe UI", 9)
}
$tip = New-Object Windows.Forms.ToolTip -Property @{ AutoPopDelay = 30000; InitialDelay = 200; ReshowDelay = 100 }
$y = 12
function Add-Control($c, [int]$x, [int]$w, [int]$h = 24, [string]$help) {
    $c.Location = New-Object Drawing.Point($x, $script:y); $c.Size = New-Object Drawing.Size($w, $h)
    if ($help) { $tip.SetToolTip($c, $help) }
    $form.Controls.Add($c); $c
}
function Add-Label([string]$text, [int]$x = 12, [int]$w = 520, [switch]$Bold) {
    $l = New-Object Windows.Forms.Label -Property @{ Text = $text; AutoSize = $false }
    if ($Bold) { $l.Font = New-Object Drawing.Font("Segoe UI", 10, [Drawing.FontStyle]::Bold) }
    Add-Control $l $x $w 22
}
# section title with a round blue "i" beside it; hovering the icon (or the title) shows what the section affects
function Add-Heading([string]$text, [string]$help) {
    $l = Add-Label $text -Bold
    $l.AutoSize = $true
    $tip.SetToolTip($l, $help)
    $w = [Windows.Forms.TextRenderer]::MeasureText($text, $l.Font).Width
    $i = New-Object Windows.Forms.Label -Property @{
        Text = "i"; TextAlign = "MiddleCenter"; ForeColor = [Drawing.Color]::White; BackColor = [Drawing.Color]::FromArgb(0, 102, 204)
        Font = New-Object Drawing.Font("Segoe UI", 8, [Drawing.FontStyle]::Bold); Cursor = [Windows.Forms.Cursors]::Help
    }
    $i.Location = New-Object Drawing.Point((12 + $w + 2), ($script:y + 3)); $i.Size = New-Object Drawing.Size(16, 16)
    $path = New-Object Drawing.Drawing2D.GraphicsPath; $path.AddEllipse(0, 0, 16, 16); $i.Region = New-Object Drawing.Region($path)
    $tip.SetToolTip($i, $help)
    $form.Controls.Add($i); $i.BringToFront()
}
function Add-Check([string]$text, [bool]$on, [int]$x, [string]$help) {
    Add-Control (New-Object Windows.Forms.CheckBox -Property @{ Text = $text; Checked = $on }) $x 250 24 $help
}
# half-width label + dropdown; column 0 or 1, so two share a row
function Add-Half([int]$col, [string]$label, [string[]]$items, [string]$value, [string]$help) {
    [void](Add-Label $label $(if ($col) { 280 } else { 12 }) $(if ($col) { 120 } else { 125 }))
    $c = New-Object Windows.Forms.ComboBox -Property @{ DropDownStyle = "DropDownList" }
    $c.Items.AddRange($items); $c.SelectedItem = $(if ($items -contains $value) { $value } else { $items[0] })
    Add-Control $c $(if ($col) { 402 } else { 138 }) $(if ($col) { 130 } else { 125 }) 24 $help
}
function Add-Choice([string]$label, [string[]]$items, [string]$value, [string]$help) {
    [void](Add-Label $label 12 150)
    $c = New-Object Windows.Forms.ComboBox -Property @{ DropDownStyle = "DropDownList" }
    $c.Items.AddRange($items); $c.SelectedItem = $(if ($items -contains $value) { $value } else { $items[0] })
    Add-Control $c 170 260 24 $help
}

Add-Heading "Game folder" "Where Dying Light is installed (the folder with DW in it). Install writes DW\Data3.pak there; Remove mod puts the vanilla files back."; $y += 24
$game = Add-Control (New-Object Windows.Forms.TextBox -Property @{ Text = $cfg.Game }) 12 430
$browse = Add-Control (New-Object Windows.Forms.Button -Property @{ Text = "Browse..." }) 450 80 24
$browse.Add_Click({
    $d = New-Object Windows.Forms.FolderBrowserDialog -Property @{ SelectedPath = $game.Text; Description = "Pick the Dying Light folder (the one with DW in it)" }
    if ($d.ShowDialog() -eq "OK") { $game.Text = $d.SelectedPath }
})
$y += 36

Add-Heading "Enemies" "What comes out of spawn points: noise and viral spawns, patrols, night biters and the enemies that appear around you, in Harran and (if ticked) The Following. Story enemies, quest fights and street crowds aren't changed here."; $y += 24
$spawns = Add-Check "Randomise noise / viral spawns" $cfg.Spawns 12 "Biters and virals from spawn points become random specials and humans."
$fol  = Add-Check "Randomise The Following too" $cfg.Following 280 "The Following DLC map: its spawns, street crowds and loot. Untick to leave The Following vanilla and only randomise Harran."
$y += 26
$night  = Add-Check "Night spawns too" $cfg.Night 12 "Also randomise the night biters."
$virals = Add-Check "Virals too" $cfg.Virals 280 "Also replace virals, including the ones loud noises call in."
$y += 26
$aiSwap = Add-Check "Randomise enemy AI (Experimental)" $cfg.AISwap 12 "Each enemy type keeps its body but gets the behaviour of another enemy with the same body shape, rolled from the seed: a Goon that acts like a biter, a viral that acts like a Suicider, a Rais soldier that fights like Tahir. Weapons come along but some attacks don't (biters with a Goon's hammer still hit with their hands). Harran's regular biters, virals and specials; the Mother, ghosts, Freaks, Hellraid and event enemies keep their own AI."
$y += 30
$pickBtn = Add-Control (New-Object Windows.Forms.Button) 12 518 26 "Choose exactly which enemies can spawn, including variants, Bolters, GRE operatives, Tahir, event enemies, friendly NPCs, Freaks and Ultras. New installs start with event enemies, the Iced Bolter and friendly NPCs off."
$script:excluded = @("$($cfg.Exclude)" -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $allPool -contains $_ })   # drops names from old test builds that the menu no longer lists
$script:poolFih = [bool]$cfg.FreaksInHarran; $script:poolMih = [bool]$cfg.MotherInHarran; $script:poolFa = [bool]$cfg.FollowingArchive; $script:poolHf = [bool]$cfg.HellraidFollowing; $script:poolFreaks = "$($cfg.Freaks)"
function Update-PickText { $pickBtn.Text = "Enemy spawn pool selection..." + $(if ($script:excluded.Count) { "  ($($script:excluded.Count) off)" }) }
Update-PickText
$pickBtn.Add_Click({
    $dlg = New-Object Windows.Forms.Form -Property @{
        Text = "Enemy spawn pool selection"; Size = New-Object Drawing.Size(440, 868); FormBorderStyle = "FixedDialog"
        MaximizeBox = $false; MinimizeBox = $false; StartPosition = "CenterParent"; Font = $form.Font
    }
    $note = New-Object Windows.Forms.Label -Property @{ Text = "Click + to see a group's enemies. Ticked enemies can spawn. Freaks, Ultras, the Mother, ghosts and the big military viral in Harran need the options under this list."; Location = New-Object Drawing.Point(12, 10); Size = New-Object Drawing.Size(400, 50) }
    # bold tree font with regular-weight enemies: a bold NodeFont on a regular tree gets its text clipped
    $tree = New-Object Windows.Forms.TreeView -Property @{ CheckBoxes = $true; Location = New-Object Drawing.Point(12, 62); Size = New-Object Drawing.Size(400, 494)
        Font = New-Object Drawing.Font($form.Font, [Drawing.FontStyle]::Bold) }
    foreach ($g in $EnemyGroups.Keys) {
        $gn = $tree.Nodes.Add($g)
        foreach ($p in $EnemyGroups[$g].Keys) {
            $n = $gn.Nodes.Add($EnemyGroups[$g][$p]); $n.Tag = $p; $n.NodeFont = $form.Font
            $n.Checked = $script:excluded -notcontains $p
        }
        $gn.Checked = [bool]($gn.Nodes | Where-Object { $_.Checked })
    }
    # groups start collapsed so every heading is visible without scrolling; + expands
    $tree.CollapseAll(); $tree.ShowPlusMinus = $true; $tree.ItemHeight = 22
    # ticking a group ticks all its enemies; a group stays ticked while any of its enemies is
    $tree.Add_AfterCheck({ param($s, $e)
        if ($e.Action -eq "Unknown") { return }
        if ($e.Node.Tag) { $e.Node.Parent.Checked = [bool]($e.Node.Parent.Nodes | Where-Object { $_.Checked }) }
        else { foreach ($c in $e.Node.Nodes) { $c.Checked = $e.Node.Checked } }
    })
    $setAll = { param($on) foreach ($gn in $tree.Nodes) { $gn.Checked = $on; foreach ($c in $gn.Nodes) { $c.Checked = $on } } }
    $allOn  = New-Object Windows.Forms.Button -Property @{ Text = "All on";  Location = New-Object Drawing.Point(12, 784);  Size = New-Object Drawing.Size(80, 28) }
    $allOff = New-Object Windows.Forms.Button -Property @{ Text = "All off"; Location = New-Object Drawing.Point(98, 784);  Size = New-Object Drawing.Size(80, 28) }
    $ok     = New-Object Windows.Forms.Button -Property @{ Text = "OK";      Location = New-Object Drawing.Point(246, 784); Size = New-Object Drawing.Size(80, 28); DialogResult = "OK" }
    $cancel = New-Object Windows.Forms.Button -Property @{ Text = "Cancel";  Location = New-Object Drawing.Point(332, 784); Size = New-Object Drawing.Size(80, 28); DialogResult = "Cancel" }
    $allOn.Add_Click({ & $setAll $true }); $allOff.Add_Click({ & $setAll $false })
    $hasDlc = $game.Text -and (Test-Path (Join-Path $game.Text "DW_DLC17"))
    $fihBox = New-Object Windows.Forms.CheckBox -Property @{ Text = "Freaks of Nature in Harran"; Checked = $script:poolFih; Enabled = $hasDlc; Location = New-Object Drawing.Point(12, 562); Size = New-Object Drawing.Size(400, 24) }
    $tip.SetToolTip($fihBox, "Lets the ticked Freaks, Ultras and the GRE Goon spawn in Harran, with their proper Following behaviour and size (their AI data is rebuilt for Harran at Install). Needs The Following.")
    $mihBox = New-Object Windows.Forms.CheckBox -Property @{ Text = "The Mother and ghosts in Harran"; Checked = $script:poolMih; Enabled = $hasDlc; Location = New-Object Drawing.Point(12, 590); Size = New-Object Drawing.Size(400, 24) }
    $tip.SetToolTip($mihBox, "Lets the ticked Mother forms and ghosts spawn in Harran too (the human ghost wears the ghost-follower look from the Mother's hallucinations). Every Harran map then also loads The Following's final-boss archive (about 430 MB), so maps take longer to load. The Prison map and the Be the Zombie tutorial crash while this is on. Needs The Following.")
    $faBox = New-Object Windows.Forms.CheckBox -Property @{ Text = "Big military viral in Harran (2.2 GB archive, no human ghost)"; Checked = $script:poolFa; Enabled = $hasDlc; Location = New-Object Drawing.Point(12, 618); Size = New-Object Drawing.Size(400, 24) }
    $tip.SetToolTip($faBox, "Lets the ticked big military viral spawn in Harran with its real look. Every Harran map then also loads The Following's main archive (2.2 GB), so maps take longer to load and use more memory. While this is on the human ghost is left out: both share one body model, and this archive's version turns the ghost into a plain survivor. The Prison map and the Be the Zombie tutorial crash while this is on. Needs The Following.")
    $hfBox = New-Object Windows.Forms.CheckBox -Property @{ Text = "Hellraid enemies in The Following too (Experimental)"; Checked = $script:poolHf; Enabled = ($hasDlc -and $fol.Checked); Location = New-Object Drawing.Point(12, 682); Size = New-Object Drawing.Size(400, 24) }
    $tip.SetToolTip($hfBox, "Lets the ticked Hellraid enemies spawn on The Following's map too. That map's start file is inside The Following's own DataDLC17_2.pak, so Install edits that pak to load the Hellraid archive (the original is kept as a backup; Remove mod, or installing with this off, puts it back). Needs Hellraid and The Following.")
    $archWarn = New-Object Windows.Forms.Label -Property @{ Text = "Warning: Hellraid enemies, 'The Mother and ghosts in Harran' and 'Big military viral in Harran' make every map load an extra DLC archive. With any of them on, the Prison map and the Be the Zombie tutorial crash."; ForeColor = [Drawing.Color]::FromArgb(190, 60, 0); Location = New-Object Drawing.Point(12, 712); Size = New-Object Drawing.Size(400, 64) }
    $freaksLabel = New-Object Windows.Forms.Label -Property @{ Text = "Freaks in The Following"; Location = New-Object Drawing.Point(12, 654); Size = New-Object Drawing.Size(150, 22) }
    $freaksBox = New-Object Windows.Forms.ComboBox -Property @{ DropDownStyle = "DropDownList"; Location = New-Object Drawing.Point(170, 650); Size = New-Object Drawing.Size(242, 24); Enabled = ($hasDlc -and $fol.Checked) }
    $freaksBox.Items.AddRange([string[]]@("Off", "Freaks", "Freaks + Ultras")); $freaksBox.SelectedItem = $(if (@("Off", "Freaks", "Freaks + Ultras") -contains $script:poolFreaks) { $script:poolFreaks } else { "Off" })
    $tip.SetToolTip($freaksBox, "Which of the ticked Freaks and Ultras can spawn on The Following's map.")
    $dlg.Controls.AddRange(@($note, $tree, $fihBox, $mihBox, $faBox, $hfBox, $archWarn, $freaksLabel, $freaksBox, $allOn, $allOff, $ok, $cancel)); $dlg.AcceptButton = $ok; $dlg.CancelButton = $cancel
    if ($dlg.ShowDialog($form) -eq "OK") {
        $script:excluded = @(foreach ($gn in $tree.Nodes) { foreach ($c in $gn.Nodes) { if (-not $c.Checked) { $c.Tag } } })
        $script:poolFih = $fihBox.Checked; $script:poolMih = $mihBox.Checked; $script:poolFa = $faBox.Checked; $script:poolHf = $hfBox.Checked; $script:poolFreaks = "$($freaksBox.SelectedItem)"
        Update-PickText
    }
    $dlg.Dispose()
})
$y += 38
Add-Heading "Street crowds" "The biters standing and wandering around the streets (not the ones noise calls in). Applies to Harran and, if ticked, The Following."; $y += 24
$names   = [string[]]@($CrowdTypes.Keys)
$overall = Add-Choice "Overall street crowd" (@($Separate) + $names) $cfg.CrowdOverall "Makes both crowd types the same enemy. Pick '$Separate' to choose Type 1 and Type 2 yourself."
$y += 30
$crowd1  = Add-Choice "Type 1 (male biters)" $names $cfg.Crowd1 "Replaces the crowd's male biters. L4D runner = the 2020 Left 4 Dead event's fast biters. Random special = one special rolled at install."
$y += 30
$crowd2  = Add-Choice "Type 2 (female biters)" $names $cfg.Crowd2 "Replaces the crowd's female biters."
$y += 30
$crowdWarn = Add-Control (New-Object Windows.Forms.Label -Property @{
    Text = "Warning: crowds of special infected can make some of them glitch into deformed biter models or shrunken versions of themselves. Many crowd combinations are unstable and may crash the game. The only confirmed stable crowds are Biters (vanilla), Virals and Left 4 Dead runners."
    ForeColor = [Drawing.Color]::FromArgb(190, 60, 0) }) 12 518 64
$y += 72
$syncCrowds = {
    $one = $overall.SelectedItem -ne $Separate
    if ($one) { $crowd1.SelectedItem = $overall.SelectedItem; $crowd2.SelectedItem = $overall.SelectedItem }
    $crowd1.Enabled = -not $one; $crowd2.Enabled = -not $one
}
$overall.Add_SelectedIndexChanged($syncCrowds)
& $syncCrowds

Add-Heading "UI colours" "The colours of the HUD, menus and on-screen text. Rolled from the seed when you press Install. Colours built into images and icons don't change."
$uiCol = New-Object Windows.Forms.ComboBox -Property @{ DropDownStyle = "DropDownList" }
$uiCol.Items.AddRange([string[]]@("Off", "Accents", "Everything")); $uiCol.SelectedItem = $(if (@("Off", "Accents", "Everything") -contains $cfg.UIColours) { $cfg.UIColours } else { "Off" })
$uiCol = Add-Control $uiCol 170 260 24 "Accents: every coloured part of the interface moves to a random colour. Everything: white and grey text gets random colours too. Black backgrounds stay, so text remains readable."
$uiIcons = Add-Control (New-Object Windows.Forms.CheckBox -Property @{ Text = "Icons too"; Checked = [bool]$cfg.UIIcons }) 440 100 24 "Also tints HUD, radar and map icons, and recolours map areas and elemental effects. Needs UI colours on. Icons are tinted, so some colours come out darker or mixed."
$syncUi = { $uiIcons.Enabled = $uiCol.SelectedItem -ne "Off" }
$uiCol.Add_SelectedIndexChanged($syncUi)
& $syncUi
$y += 36
Add-Heading "World colours" "Sunlight, clouds, water and stars, in Harran and The Following. Rolled from the seed when you press Install."
$world = New-Object Windows.Forms.ComboBox -Property @{ DropDownStyle = "DropDownList" }
$world.Items.AddRange([string[]]@("Off", "Tinted", "Wild")); $world.SelectedItem = $(if (@("Off", "Tinted", "Wild") -contains $cfg.WorldColours) { $cfg.WorldColours } else { "Off" })
$world = Add-Control $world 170 260 24 "Tinted: each time of day gets a gentle colour tint. Wild: much stronger tints, and the colours of the sky itself get swapped."
$y += 36
Add-Heading "Dialogue" "What characters say, and the subtitles for it. Rolled from the seed when you press Install. Quests still start the right conversations; only the lines inside them change."
$dlg2 = New-Object Windows.Forms.ComboBox -Property @{ DropDownStyle = "DropDownList" }
$dlg2.Items.AddRange([string[]]@("Off", "Same character", "Everyone")); $dlg2.SelectedItem = $(if (@("Off", "Same character", "Everyone") -contains $cfg.Dialogue) { $cfg.Dialogue } else { "Off" })
$dlg2 = Add-Control $dlg2 170 190 24 "Same character: each character says their own lines in the wrong order. Everyone: any line from that map can come from anyone. Lips won't match, and conversations won't make sense. In The Following this edits DataDLC17_0.pak: the original is kept as a backup, and Remove mod puts it back."
$subs = Add-Control (New-Object Windows.Forms.CheckBox -Property @{ Text = "Shuffle subtitles"; Checked = [bool]$cfg.Subtitles }) 375 150 24 "Turn subtitles on in the game's options to see this. Spoken lines swap text with each other. This edits your language pak (DataEn.pak for English) and The Following's text files: the originals are kept as backups, and Remove mod or unticking this and pressing Install puts it back."
$y += 34
Add-Heading "Loot and shops" "What you find in containers and on bodies, what shops and the Quartermaster sell, weapon rarity odds and how many of each item drop. Quest items are never changed."; $y += 24
$lootNote = Add-Control (New-Object Windows.Forms.Label -Property @{
    Text = "Note: loot and shops are randomised once, when you press Install, using the seed. They stay the same in game until you install again with a new seed (or use the new-roll-on-launch option). Your current seed is in randomiser_settings.txt inside DW\Data3.pak (open the pak as a zip)."
    ForeColor = [Drawing.Color]::FromArgb(70, 70, 70) }) 12 518 64
$y += 70
$loot  = Add-Half 0 "Container / body loot" @("Off", "Shuffle", "Chaos") $cfg.Loot "Shuffle: each container type gets another type's loot table. Chaos: each container type gets 8 random loot lists from all of them. Quest items and empty chances stay."
$shops = Add-Half 1 "Shop stock" @("Off", "Random") $cfg.Shops "Random: every shop list sells random items of the same kind (melee, guns, blueprints...). Quartermaster gear and quest items stay."
$y += 30
$qm    = Add-Half 0 "Quartermaster stock" @("Off", "Random") $cfg.Quartermaster "Random: the Tower Quartermaster's supplies can be any Harran shop item; The Following's buggy parts, bolts and mines shuffle among themselves. Grappling hook, UV flashlight, shield, bow and arrows stay."
$tiers = Add-Half 1 "Weapon tiers" @("Off", "Crates", "All") $cfg.Tiers "Shuffles the white/green/blue/violet/orange odds. Crates: weapon, lockpick, valuables and airdrop crates. All: also bodies and everyday containers."
$y += 30
$qty   = Add-Half 0 "Loot quantity" @("Off", "Random") $cfg.Quantity "Random amounts: crafting parts, ammo, throwables, consumables, valuables and cash. Weapons and blueprints stay at one."
$quest = Add-Half 1 "Quest rewards" @("Off", "Random") $cfg.QuestRewards "Random: side quest and encounter rewards. Blueprints, weapons and upgrades swap for others of the same kind, and cash ranges from half to double. Story missions only give XP, so they don't change."
$y += 30
[void](Add-Label "Seed (blank = new roll)" 12 150)
$seed = Add-Control (New-Object Windows.Forms.TextBox -Property @{ Text = $cfg.Seed }) 170 120 24 "Same seed + same ticks = the same loot shuffle and shop stock. Leave blank for a fresh roll each install."
$y += 40

$install = Add-Control (New-Object Windows.Forms.Button -Property @{ Text = "Install" ; Font = New-Object Drawing.Font("Segoe UI", 10, [Drawing.FontStyle]::Bold) }) 12 250 34
$remove  = Add-Control (New-Object Windows.Forms.Button -Property @{ Text = "Remove mod (vanilla)" }) 280 250 34
$y += 44
$steamOpt = Add-Control (New-Object Windows.Forms.Button -Property @{ Text = "Copy Steam launch option (new roll every time the game starts)" }) 12 518 30 "Paste it into Steam > Dying Light > Properties > Launch Options. Every Play then re-rolls with these choices and a new seed (the seed box is ignored). Press Install once after changing choices so they're saved."
$y += 40
$log = Add-Control (New-Object Windows.Forms.TextBox -Property @{ Multiline = $true; ReadOnly = $true; ScrollBars = "Vertical"; Font = New-Object Drawing.Font("Consolas", 8.5) }) 12 518 90
$form.ClientSize = New-Object Drawing.Size($form.ClientSize.Width, ($y + 90 + 12))   # window grows to fit everything

$enemyOpts = @($night, $virals, $pickBtn)
$syncEnemies = {
    foreach ($c in $enemyOpts) { $c.Enabled = $spawns.Checked }
    # The Following DLC options need the DLC (DW_DLC17); greyed out for players without it
    $dlc = $game.Text -and (Test-Path (Join-Path $game.Text "DW_DLC17"))
    $fol.Enabled = $dlc
}
$spawns.Add_CheckedChanged($syncEnemies); $fol.Add_CheckedChanged($syncEnemies); $game.Add_TextChanged($syncEnemies)
& $syncEnemies

function Save-Settings {
    $cfg = [ordered]@{
        Game = $game.Text; Spawns = $spawns.Checked; Night = $night.Checked; Virals = $virals.Checked; AISwap = $aiSwap.Checked
        CrowdOverall = $overall.SelectedItem; Crowd1 = $crowd1.SelectedItem; Crowd2 = $crowd2.SelectedItem
        PoolV2 = $true; PoolNames = ($allPool -join ",")
        Freaks = $script:poolFreaks; FreaksInHarran = $script:poolFih; MotherInHarran = $script:poolMih; FollowingArchive = $script:poolFa; HellraidFollowing = $script:poolHf; Following = $fol.Checked; Exclude = ($script:excluded -join ",")
        Loot = $loot.SelectedItem; Shops = $shops.SelectedItem; Quartermaster = $qm.SelectedItem; Tiers = $tiers.SelectedItem; Quantity = $qty.SelectedItem; UIColours = $uiCol.SelectedItem; UIIcons = $uiIcons.Checked; WorldColours = $world.SelectedItem; Subtitles = $subs.Checked; QuestRewards = $quest.SelectedItem; Dialogue = $dlg2.SelectedItem; Seed = $seed.Text
    }
    $cfg | ConvertTo-Json | Set-Content $settings -Encoding UTF8
    $cfg
}

function Run-Build([string[]]$buildArgs) {
    if (Get-Process DyingLightGame -ErrorAction SilentlyContinue) { $log.Text = "Close Dying Light first (it locks Data3.pak)."; return }
    if (-not (Test-Path (Join-Path $game.Text "DW\Data0.pak"))) { $log.Text = "No DW\Data0.pak in that folder. Pick the Dying Light game folder."; return }
    if (-not (Test-Path $build)) { $log.Text = "build.ps1 must be in the same folder as this menu."; return }
    $form.Cursor = "WaitCursor"; $log.Text = "Working..."; $form.Refresh()
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $build -Game $game.Text @buildArgs 2>&1
    $log.Text = ($out | ForEach-Object { "$_" }) -join "`r`n"
    $form.Cursor = "Default"
}

$install.Add_Click({ Run-Build (Get-BuildArgs (Save-Settings)) })
$remove.Add_Click({ [void](Save-Settings); Run-Build @("-Uninstall") })
$steamOpt.Add_Click({
    [void](Save-Settings)
    $opt = 'powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $PSScriptRoot "Randomiser Menu.ps1") + '" -Launch %command%'
    [Windows.Forms.Clipboard]::SetText($opt)
    $log.Text = "Copied. In Steam: right-click Dying Light > Properties > General > Launch Options, paste, close.`r`n" +
        "Every Play now re-rolls (about a few seconds) before the game loads. Last roll's log: last-launch.log`r`n" +
        "Keep this folder where it is: the option points here. To stop, clear the Launch Options box.`r`n`r`n$opt"
})

[void]$form.ShowDialog()
