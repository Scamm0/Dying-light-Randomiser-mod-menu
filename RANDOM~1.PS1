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
    Freaks = "Freaks + Ultras"; FreaksInHarran = $true; Events = $false; IcedBolter = $false; Following = $true; Exclude = ""
    Loot = "Off"; Shops = "Off"; Quartermaster = "Off"; Tiers = "Off"; Quantity = "Off"; Seed = ""
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
# name. Unticked names go to build.ps1 -Exclude. Groups in $GroupBoxes (and Tahir) are tied to their main-window
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
        "ViralPoison_Man" = "Toxic viral"; "ViralBlister_Man" = "Blistered viral"; "Viral_Big_Humanity" = "Big military viral (Following only)" }
    "GRE operatives" = [ordered]@{ "Demolisher_ZombieHunt" = "GRE Demolisher"; "Goon_ZombieHunt" = "GRE Goon (needs Freaks in Harran)" }
    "Bolters" = [ordered]@{ "Prime" = "Bolter (day)"; "PrimeNight" = "Bolter (night)" }
    "Iced Bolter" = [ordered]@{ "Prime_Winter" = "Iced Bolter" }
    "Freaks of Nature (needs a Freaks option)" = [ordered]@{ "Demolisher_WastelandSpecial" = "Freak Demolisher"; "Goon_WastelandSpecial" = "Freak Goon"
        "Bolter_WastelandSpecial" = "Freak Bolter"; "Toad_WastelandSpecial" = "Freak Toad"
        "GasTank_WastelandSpecial" = "Freak Gas Tank biter (Following only)"; "Biter_WastelandSpecial" = "Freak biter (Following only)" }
    "Ultras (needs Freaks + Ultras or Freaks in Harran)" = [ordered]@{ "Demolisher_WastelandUltra" = "Behemoth"; "Demolisher_WastelandUltra_H" = "Behemoth (second type)"
        "Goon_WastelandUltra" = "Ultra Goon"; "Biter_WastelandUltra" = "Ultra biter (Following only)"; "Toad_WastelandUltra" = "Ultra Toad (Following only)" }
    "Event enemies" = [ordered]@{ "rust_scientist_range" = "Rust rifleman (Zombie with gun)"
        "astronaut_melee" = "Astronaut invader (melee)"; "astronaut_range" = "Astronaut invader (rifle)"; "Medieval_Armored" = "Chivalry knight" }
}
# picker group / single enemy => main-window checkbox variable
$GroupBoxes = @{ "Variants" = "vars"; "GRE operatives" = "gre"; "Bolters" = "bolt"; "Iced Bolter" = "iced"; "Event enemies" = "events" }
$ItemBoxes  = @{ "Quest_Museum_TahirBoss" = "tahir" }

# build.ps1 arguments for a settings table (saved or from the menu).
function Get-BuildArgs($cfg, [switch]$NewSeed) {
    $a = @()
    if (-not $cfg.Spawns) { $a += "-NoSpawns" }
    else {
        if (-not $cfg.Night)    { $a += "-DayOnly" }
        if (-not $cfg.Virals)   { $a += "-NoVirals" }
        if (-not $cfg.Variants) { $a += "-NoVariants" }
        if (-not $cfg.GRE)      { $a += "-NoGRE" }
        if (-not $cfg.Bolters)  { $a += "-NoBolters" }
        if (-not $cfg.Tahir)    { $a += "-NoTahir" }
        if ($cfg.FreaksInHarran) { $a += "-FreaksInHarran" }
        if ($cfg.Events)         { $a += "-Events" }
        if ($cfg.IcedBolter)     { $a += "-IcedBolter" }
        $a += "-Freaks", @{ "Off" = "None"; "Freaks" = "Freaks"; "Freaks + Ultras" = "Ultra" }[$cfg.Freaks]
        if ("$($cfg.Exclude)".Trim()) { $a += "-Exclude", "$($cfg.Exclude)".Trim() }
    }
    if ($cfg.Following -eq $false) { $a += "-NoFollowing" }
    $one = $cfg.CrowdOverall -and $cfg.CrowdOverall -ne $Separate
    $c1 = $CrowdTypes[$(if ($one) { $cfg.CrowdOverall } else { $cfg.Crowd1 })]
    $c2 = $CrowdTypes[$(if ($one) { $cfg.CrowdOverall } else { $cfg.Crowd2 })]
    if (-not $c1) { $c1 = "L4D" }; if (-not $c2) { $c2 = "L4D" }
    if ($c1 -eq "Vanilla" -and $c2 -eq "Vanilla") { $a += "-CrowdMode", "Off" } else { $a += "-Crowd1", $c1, "-Crowd2", $c2 }
    $a += "-Loot", $cfg.Loot, "-Shops", $cfg.Shops, "-Quartermaster", $cfg.Quartermaster, "-Tiers", $cfg.Tiers, "-Quantity", $cfg.Quantity
    if (-not $NewSeed -and "$($cfg.Seed)".Trim() -match '^\d+$') { $a += "-Seed", "$($cfg.Seed)".Trim() }
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
    Text = "Dying Light Randomiser Mod 1.0"; Size = New-Object Drawing.Size(560, 900)
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
$tahir  = Add-Check "Tahir" $cfg.Tahir 280 "Tahir (museum boss fight version) can spawn."
$y += 26
$night  = Add-Check "Night spawns too" $cfg.Night 12 "Also randomise the night biters."
$gre    = Add-Check "GRE operatives (Zombie Hunt)" $cfg.GRE 280 "The giant 'former GRE operative' Demolisher."
$y += 26
$virals = Add-Check "Virals too" $cfg.Virals 12 "Also replace virals, including the ones loud noises call in."
$bolt   = Add-Check "Bolters" $cfg.Bolters 280 "Day and night Bolters."
$y += 26
$vars   = Add-Check "Variants (Demolishers, Goons, ...)" $cfg.Variants 12 "Tougher and elemental versions of the specials."
$fih    = Add-Check "Freaks of Nature in Harran" $cfg.FreaksInHarran 280 "Freak Demolisher/Goon/Bolter/Toad, Behemoths, Ultra Goon and GRE Goon in Harran. Needs The Following."
$y += 26
$events = Add-Check "Event enemies" $cfg.Events 12 "Community event enemies: Rust rifleman (a biter with a rifle), low-gravity astronaut invaders (melee and rifle), Chivalry knight."
$pickBtn = Add-Control (New-Object Windows.Forms.Button) 280 250 24 "Switch single enemies on or off. Ticking an enemy also ticks its group's box here (Variants, GRE, Bolters, Iced Bolter, Event enemies, Tahir)."
$script:excluded = @("$($cfg.Exclude)" -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^HR_' })   # HR_: Hellraid names from test builds
function Update-PickText { $pickBtn.Text = "Pick individual enemies..." + $(if ($script:excluded.Count) { "  ($($script:excluded.Count) off)" }) }
Update-PickText
$pickBtn.Add_Click({
    $dlg = New-Object Windows.Forms.Form -Property @{
        Text = "Pick individual enemies"; Size = New-Object Drawing.Size(440, 720); FormBorderStyle = "FixedDialog"
        MaximizeBox = $false; MinimizeBox = $false; StartPosition = "CenterParent"; Font = $form.Font
    }
    $note = New-Object Windows.Forms.Label -Property @{ Text = "Click + to see a group's enemies. Ticked enemies can spawn, and their group's box in the main window follows. Freaks and Ultras also need a Freaks option."; Location = New-Object Drawing.Point(12, 10); Size = New-Object Drawing.Size(400, 50) }
    # bold tree font with regular-weight enemies: a bold NodeFont on a regular tree gets its text clipped
    $tree = New-Object Windows.Forms.TreeView -Property @{ CheckBoxes = $true; Location = New-Object Drawing.Point(12, 62); Size = New-Object Drawing.Size(400, 564)
        Font = New-Object Drawing.Font($form.Font, [Drawing.FontStyle]::Bold) }
    $boxOn = { param($name) (Get-Variable $name -ValueOnly).Checked }
    foreach ($g in $EnemyGroups.Keys) {
        $gn = $tree.Nodes.Add($g)
        $groupOn = -not $GroupBoxes[$g] -or (& $boxOn $GroupBoxes[$g])
        foreach ($p in $EnemyGroups[$g].Keys) {
            $n = $gn.Nodes.Add($EnemyGroups[$g][$p]); $n.Tag = $p; $n.NodeFont = $form.Font
            $n.Checked = $groupOn -and ($script:excluded -notcontains $p) -and (-not $ItemBoxes[$p] -or (& $boxOn $ItemBoxes[$p]))
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
    $allOn  = New-Object Windows.Forms.Button -Property @{ Text = "All on";  Location = New-Object Drawing.Point(12, 636);  Size = New-Object Drawing.Size(80, 28) }
    $allOff = New-Object Windows.Forms.Button -Property @{ Text = "All off"; Location = New-Object Drawing.Point(98, 636);  Size = New-Object Drawing.Size(80, 28) }
    $ok     = New-Object Windows.Forms.Button -Property @{ Text = "OK";      Location = New-Object Drawing.Point(246, 636); Size = New-Object Drawing.Size(80, 28); DialogResult = "OK" }
    $cancel = New-Object Windows.Forms.Button -Property @{ Text = "Cancel";  Location = New-Object Drawing.Point(332, 636); Size = New-Object Drawing.Size(80, 28); DialogResult = "Cancel" }
    $allOn.Add_Click({ & $setAll $true }); $allOff.Add_Click({ & $setAll $false })
    $dlg.Controls.AddRange(@($note, $tree, $allOn, $allOff, $ok, $cancel)); $dlg.AcceptButton = $ok; $dlg.CancelButton = $cancel
    if ($dlg.ShowDialog($form) -eq "OK") {
        $script:excluded = @(foreach ($gn in $tree.Nodes) {
            $box = $GroupBoxes[$gn.Text]
            # a tied group's box follows its ticks; a group switched off by its box needs no exclusions
            if ($box) { (Get-Variable $box -ValueOnly).Checked = [bool]$gn.Checked; if (-not $gn.Checked) { continue } }
            foreach ($c in $gn.Nodes) {
                if ($ItemBoxes[$c.Tag]) { (Get-Variable $ItemBoxes[$c.Tag] -ValueOnly).Checked = $c.Checked; continue }
                if (-not $c.Checked) { $c.Tag }
            }
        })
        Update-PickText
    }
    $dlg.Dispose()
})
$y += 26
$iced = Add-Check "Iced Bolter (winter event)" $cfg.IcedBolter 12 "The winter event's Iced Bolter. Like any Bolter, it puts a Bolter icon on screen while it's around."
$fol  = Add-Check "Randomise The Following too" $cfg.Following 280 "The Following DLC map: its spawns, street crowds and loot. Untick to leave The Following vanilla and only randomise Harran."
$y += 30
$freaks = Add-Choice "Freaks in The Following" @("Off", "Freaks", "Freaks + Ultras") $cfg.Freaks "Freaks of Nature (and Ultras) on The Following's map. Needs The Following."
$y += 30
$y += 6
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

Add-Heading "Loot and shops" "What you find in containers and on bodies, what shops and the Quartermaster sell, weapon rarity odds and how many of each item drop. Quest items are never changed."; $y += 24
$lootNote = Add-Control (New-Object Windows.Forms.Label -Property @{
    Text = "Note: loot and shops are randomised once, when you press Install, using the seed. They stay the same in game until you install again with a new seed (or use the new-roll-on-launch option). Your current seed is in randomiser_settings.txt inside DW\Data3.pak (open the pak as a zip)."
    ForeColor = [Drawing.Color]::FromArgb(70, 70, 70) }) 12 518 64
$y += 70
$loot  = Add-Choice "Container / body loot" @("Off", "Shuffle", "Chaos") $cfg.Loot "Shuffle: each container type gets another type's loot table. Chaos: each container type gets 8 random loot lists from all of them. Quest items and empty chances stay."
$y += 30
$shops = Add-Choice "Shop stock" @("Off", "Random") $cfg.Shops "Random: every shop list sells random items of the same kind (melee, guns, blueprints...). Quartermaster gear and quest items stay."
$y += 30
$qm    = Add-Choice "Quartermaster stock" @("Off", "Random") $cfg.Quartermaster "Random: the Tower Quartermaster's supplies can be any Harran shop item; The Following's buggy parts, bolts and mines shuffle among themselves. Grappling hook, UV flashlight, shield, bow and arrows stay."
$y += 30
$tiers = Add-Choice "Weapon tiers" @("Off", "Crates", "All") $cfg.Tiers "Shuffles the white/green/blue/violet/orange odds. Crates: weapon, lockpick, valuables and airdrop crates. All: also bodies and everyday containers."
$y += 30
$qty   = Add-Choice "Loot quantity" @("Off", "Random") $cfg.Quantity "Random amounts: crafting parts, ammo, throwables, consumables, valuables and cash. Weapons and blueprints stay at one."
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

$enemyOpts = @($night, $virals, $vars, $tahir, $gre, $bolt, $fih, $events, $pickBtn, $iced, $freaks)
$syncEnemies = {
    foreach ($c in $enemyOpts) { $c.Enabled = $spawns.Checked }
    # The Following DLC options need the DLC (DW_DLC17); greyed out for players without it
    $dlc = $game.Text -and (Test-Path (Join-Path $game.Text "DW_DLC17"))
    $fol.Enabled = $dlc; $fih.Enabled = $spawns.Checked -and $dlc
    $freaks.Enabled = $spawns.Checked -and $fol.Checked -and $dlc   # Freaks in The Following need The Following randomised
}
$spawns.Add_CheckedChanged($syncEnemies); $fol.Add_CheckedChanged($syncEnemies); $game.Add_TextChanged($syncEnemies)
& $syncEnemies

function Save-Settings {
    $cfg = [ordered]@{
        Game = $game.Text; Spawns = $spawns.Checked; Night = $night.Checked; Virals = $virals.Checked
        CrowdOverall = $overall.SelectedItem; Crowd1 = $crowd1.SelectedItem; Crowd2 = $crowd2.SelectedItem
        Variants = $vars.Checked; GRE = $gre.Checked; Bolters = $bolt.Checked; Tahir = $tahir.Checked
        Freaks = $freaks.SelectedItem; FreaksInHarran = $fih.Checked; Events = $events.Checked; IcedBolter = $iced.Checked; Following = $fol.Checked; Exclude = ($script:excluded -join ",")
        Loot = $loot.SelectedItem; Shops = $shops.SelectedItem; Quartermaster = $qm.SelectedItem; Tiers = $tiers.SelectedItem; Quantity = $qty.SelectedItem; Seed = $seed.Text
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
