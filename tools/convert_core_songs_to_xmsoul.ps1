$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Escape-Xml([string]$s) {
    if ($null -eq $s) { return '' }
    return $s.Replace('&', '&amp;').Replace('"', '&quot;').Replace('<', '&lt;').Replace('>', '&gt;').Replace("'", '&apos;')
}

function NumStr($n) {
    if ($null -eq $n) { return '0' }
    try {
        return ([double]$n).ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
        return '0'
    }
}

function Normalize-Type($t) {
    if ($null -eq $t) { return 'normal' }
    if ($t -is [int] -or $t -is [long] -or $t -is [double]) {
        if ([double]$t -eq 0) { return 'normal' }
    }
    $v = [string]$t
    if ([string]::IsNullOrWhiteSpace($v)) { return 'normal' }
    return $v
}

function Get-Prop($obj, $name, $default = $null) {
    if ($null -eq $obj) { return $default }
    $p = $obj.PSObject.Properties[$name]
    if ($null -eq $p) { return $default }
    return $p.Value
}

$songs = @(
    'tutorial',
    'bopeebo', 'fresh', 'dadbattle',
    'spookeez', 'south', 'monster',
    'pico', 'philly nice', 'blammed',
    'satin panties', 'high', 'milf',
    'ugh', 'guns', 'stress'
)

$root = 'assets/preload/songs'
$convertedCharts = 0
$writtenEvents = 0
$writtenMeta = 0

foreach ($song in $songs) {
    $songDir = Join-Path $root $song
    if (!(Test-Path $songDir)) { continue }

    $chartsDir = Join-Path $songDir 'charts'
    $diffMeta = @{}
    $chartEventsFromNormal = @()

    if (Test-Path $chartsDir) {
        $jsonCharts = Get-ChildItem $chartsDir -Filter '*.json' -File -ErrorAction SilentlyContinue
        foreach ($chartFile in $jsonCharts) {
            $diffName = [System.IO.Path]::GetFileNameWithoutExtension($chartFile.Name).ToLower()
            $raw = Get-Content $chartFile.FullName -Raw
            $chartObj = $raw | ConvertFrom-Json

            $topEvents = @(Get-Prop $chartObj 'events' @())
            $scrollSpeed = 1.0
            $stageName = ''
            $strumLines = @()

            if ((Get-Prop $chartObj 'strumLines' $null) -ne $null) {
                $strumLines = @($chartObj.strumLines)
                $scrollSpeed = [double](Get-Prop $chartObj 'scrollSpeed' (Get-Prop $chartObj 'speed' 1.0))
                $stageName = [string](Get-Prop $chartObj 'stage' '')
            }
            elseif ((Get-Prop $chartObj 'song' $null) -ne $null) {
                $songNode = $chartObj.song
                $scrollSpeed = [double](Get-Prop $songNode 'speed' (Get-Prop $songNode 'scrollSpeed' 1.0))
                $stageName = [string](Get-Prop $songNode 'stage' '')

                $opp = New-Object System.Collections.ArrayList
                $ply = New-Object System.Collections.ArrayList
                $sections = @(Get-Prop $songNode 'notes' @())

                foreach ($sec in $sections) {
                    $mustHit = [bool](Get-Prop $sec 'mustHitSection' $true)
                    $sectionNotes = @(Get-Prop $sec 'sectionNotes' @())

                    foreach ($rn in $sectionNotes) {
                        if ($rn -is [System.Array]) {
                            if ($rn.Count -lt 2) { continue }

                            $time = [double]$rn[0]
                            $laneRaw = [int]$rn[1]
                            $len = 0.0
                            if ($rn.Count -gt 2) { $len = [double]$rn[2] }
                            $nt = 'normal'
                            if ($rn.Count -gt 3) { $nt = Normalize-Type $rn[3] }

                            if ($laneRaw -ge 4) { $mustPress = -not $mustHit } else { $mustPress = $mustHit }
                            $lane = (($laneRaw % 4) + 4) % 4

                            $noteObj = [pscustomobject]@{
                                id = $lane
                                sLen = $len
                                time = $time
                                type = $nt
                            }

                            if ($mustPress) {
                                [void]$ply.Add($noteObj)
                            }
                            else {
                                [void]$opp.Add($noteObj)
                            }
                        }
                    }
                }

                $strumLines = @(
                    [pscustomobject]@{
                        visible = $true
                        keyCount = 4
                        notes = $opp
                        position = 'dad'
                        type = 'opponent'
                        characters = 'dad'
                    },
                    [pscustomobject]@{
                        visible = $true
                        keyCount = 4
                        notes = $ply
                        position = 'boyfriend'
                        type = 'player'
                        characters = 'bf'
                    }
                )
            }

            if ($diffName -eq 'normal' -and $topEvents.Count -gt 0) {
                $chartEventsFromNormal = $topEvents
            }

            $xml = New-Object System.Collections.Generic.List[string]
            $stageAttr = ''
            if (-not [string]::IsNullOrWhiteSpace($stageName)) {
                $stageAttr = ' stage="' + (Escape-Xml $stageName) + '"'
            }

            [void]$xml.Add('<?xml version="1.0" encoding="utf-8"?>')
            [void]$xml.Add('<chart version="1.6.0" codenameChart="false" scrollSpeed="' + (NumStr $scrollSpeed) + '"' + $stageAttr + '>')

            if ($topEvents.Count -gt 0) {
                [void]$xml.Add('    <events>')
                foreach ($ev in $topEvents) {
                    $name = [string](Get-Prop $ev 'name' '')
                    $time = NumStr (Get-Prop $ev 'time' 0.0)
                    $params = @(Get-Prop $ev 'params' @())
                    $val1 = ''
                    $val2 = ''
                    if ($params.Count -gt 0) { $val1 = [string]$params[0] }
                    if ($params.Count -gt 1) { $val2 = [string]$params[1] }
                    [void]$xml.Add('        <event time="' + $time + '" name="' + (Escape-Xml $name) + '" val1="' + (Escape-Xml $val1) + '" val2="' + (Escape-Xml $val2) + '" />')
                }
                [void]$xml.Add('    </events>')
            }

            for ($i = 0; $i -lt $strumLines.Count; $i++) {
                $sl = $strumLines[$i]
                $visible = [bool](Get-Prop $sl 'visible' $true)
                if (-not $visible) { continue }

                $slType = [string](Get-Prop $sl 'type' '')
                if ($slType -eq '0') { $slType = 'opponent' }
                elseif ($slType -eq '1') { $slType = 'player' }
                if ([string]::IsNullOrWhiteSpace($slType)) {
                    if ($i -eq 0) { $slType = 'opponent' } else { $slType = 'player' }
                }

                if ($slType -ne 'opponent' -and $slType -ne 'player') {
                    $posGuess = [string](Get-Prop $sl 'position' '')
                    if ($posGuess.ToLower().Contains('boyfriend') -or $posGuess.ToLower().Contains('player')) {
                        $slType = 'player'
                    }
                    elseif ($posGuess.ToLower().Contains('dad') -or $posGuess.ToLower().Contains('opponent')) {
                        $slType = 'opponent'
                    }
                    else {
                        if ($i -eq 0) { $slType = 'opponent' } else { $slType = 'player' }
                    }
                }

                $pos = [string](Get-Prop $sl 'position' '')
                if ([string]::IsNullOrWhiteSpace($pos)) {
                    if ($slType -eq 'player') { $pos = 'boyfriend' } else { $pos = 'dad' }
                }

                $charsVal = Get-Prop $sl 'characters' $null
                $chars = ''
                if ($charsVal -is [System.Array]) {
                    $chars = (($charsVal | ForEach-Object { [string]$_ }) -join ',')
                }
                elseif ($null -ne $charsVal) {
                    $chars = [string]$charsVal
                }
                if ([string]::IsNullOrWhiteSpace($chars)) {
                    if ($slType -eq 'player') { $chars = 'bf' } else { $chars = 'dad' }
                }

                $keyCount = [int](Get-Prop $sl 'keyCount' 4)
                if ($keyCount -le 0) { $keyCount = 4 }

                [void]$xml.Add('    <strumLine position="' + (Escape-Xml $pos) + '" type="' + (Escape-Xml $slType.ToLower()) + '" characters="' + (Escape-Xml $chars) + '">')

                foreach ($n in @(Get-Prop $sl 'notes' @())) {
                    $laneRaw = [int](Get-Prop $n 'lane' (Get-Prop $n 'id' 0))
                    $lane = (($laneRaw % $keyCount) + $keyCount) % $keyCount
                    $len = NumStr (Get-Prop $n 'len' (Get-Prop $n 'sLen' (Get-Prop $n 'sustainLength' 0.0)))
                    $time = NumStr (Get-Prop $n 'time' (Get-Prop $n 'strumTime' 0.0))
                    $ntype = Normalize-Type (Get-Prop $n 'type' (Get-Prop $n 'noteType' 'normal'))
                    [void]$xml.Add('        <note time="' + $time + '" lane="' + $lane + '" len="' + $len + '" type="' + (Escape-Xml $ntype) + '" />')
                }

                [void]$xml.Add('    </strumLine>')
            }

            [void]$xml.Add('</chart>')

            $targetChart = Join-Path $chartsDir ($diffName + '.xmsoul')
            Set-Content -Path $targetChart -Value ($xml -join "`r`n") -Encoding UTF8

            $diffMeta[$diffName] = [pscustomobject]@{
                speed = $scrollSpeed
                stage = $stageName
            }
            $convertedCharts++
        }
    }

    $eventsPathJson = Join-Path $songDir 'events.json'
    $eventsSource = $null

    if (Test-Path $eventsPathJson) {
        $eventsSource = (Get-Content $eventsPathJson -Raw | ConvertFrom-Json).events
    }
    elseif ($chartEventsFromNormal.Count -gt 0) {
        $eventsSource = $chartEventsFromNormal
    }

    if ($null -ne $eventsSource -and @($eventsSource).Count -gt 0) {
        $ex = New-Object System.Collections.Generic.List[string]
        [void]$ex.Add('<?xml version="1.0" encoding="utf-8"?>')
        [void]$ex.Add('<events>')

        foreach ($ev in @($eventsSource)) {
            $name = [string](Get-Prop $ev 'name' '')
            $time = NumStr (Get-Prop $ev 'time' 0.0)
            $params = @(Get-Prop $ev 'params' @())
            $val1 = ''
            $val2 = ''
            if ($params.Count -gt 0) { $val1 = [string]$params[0] }
            if ($params.Count -gt 1) { $val2 = [string]$params[1] }
            [void]$ex.Add('    <event time="' + $time + '" name="' + (Escape-Xml $name) + '" val1="' + (Escape-Xml $val1) + '" val2="' + (Escape-Xml $val2) + '" />')
        }

        [void]$ex.Add('</events>')
        Set-Content -Path (Join-Path $songDir 'events.xmsoul') -Value ($ex -join "`r`n") -Encoding UTF8
        $writtenEvents++
    }

    $metaPathJson = Join-Path $songDir 'meta.json'
    if (Test-Path $metaPathJson) {
        $meta = Get-Content $metaPathJson -Raw | ConvertFrom-Json

        $displayName = [string](Get-Prop $meta 'displayName' $song)
        $bpm = [double](Get-Prop $meta 'bpm' 120.0)
        $icon = [string](Get-Prop $meta 'icon' 'face')
        $color = [string](Get-Prop $meta 'color' '#AF66CE')
        if ($color.StartsWith('#')) {
            if ($color.Length -eq 7) {
                $color = '0xFF' + $color.Substring(1)
            }
            elseif ($color.Length -eq 9) {
                $color = '0x' + $color.Substring(1)
            }
        }
        $needsVoices = Get-Prop $meta 'needsVoices' $true

        $defaultDiff = 'normal'
        if (-not $diffMeta.ContainsKey('normal')) {
            if ($diffMeta.ContainsKey('hard')) {
                $defaultDiff = 'hard'
            }
            elseif ($diffMeta.Keys.Count -gt 0) {
                $defaultDiff = @($diffMeta.Keys)[0]
            }
        }

        $diffList = @($diffMeta.Keys | Sort-Object)
        if ($diffList.Count -eq 0) {
            if (Test-Path $chartsDir) {
                $existingX = Get-ChildItem $chartsDir -Filter '*.xmsoul' -File -ErrorAction SilentlyContinue
                foreach ($c in $existingX) {
                    $dn = [System.IO.Path]::GetFileNameWithoutExtension($c.Name).ToLower()
                    if (-not $diffList.Contains($dn)) {
                        $diffList += $dn
                    }
                }
            }
        }

        $repChart = $null
        if (Test-Path $chartsDir) {
            if (Test-Path (Join-Path $chartsDir 'normal.json')) {
                $repChart = Get-Content (Join-Path $chartsDir 'normal.json') -Raw | ConvertFrom-Json
            }
            elseif (Test-Path (Join-Path $chartsDir 'hard.json')) {
                $repChart = Get-Content (Join-Path $chartsDir 'hard.json') -Raw | ConvertFrom-Json
            }
        }

        $stage = ''
        $player1 = 'bf'
        $player2 = 'dad'
        $gfVersion = 'gf'

        if ($null -ne $repChart) {
            if ((Get-Prop $repChart 'song' $null) -ne $null) {
                $snode = $repChart.song
                $stage = [string](Get-Prop $snode 'stage' '')
                $player1 = [string](Get-Prop $snode 'player1' $player1)
                $player2 = [string](Get-Prop $snode 'player2' $player2)
                $gfVersion = [string](Get-Prop $snode 'gfVersion' $gfVersion)
            }
            else {
                $stage = [string](Get-Prop $repChart 'stage' '')
                $sls = @(Get-Prop $repChart 'strumLines' @())
                foreach ($sl in $sls) {
                    $tp = [string](Get-Prop $sl 'type' '')
                    $chars = Get-Prop $sl 'characters' $null
                    $ch = ''
                    if ($chars -is [System.Array]) {
                        if ($chars.Count -gt 0) { $ch = [string]$chars[0] }
                    }
                    elseif ($null -ne $chars) {
                        $ch = [string]$chars
                    }

                    if ($tp -eq 'player' -and -not [string]::IsNullOrWhiteSpace($ch)) { $player1 = $ch }
                    if ($tp -eq 'opponent' -and -not [string]::IsNullOrWhiteSpace($ch)) { $player2 = $ch }
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($stage)) {
            if ($song -in @('ugh', 'guns', 'stress')) {
                $stage = 'tank'
            }
            else {
                $stage = 'stage'
            }
        }

        if ($diffList.Count -eq 0) {
            $diffList = @('normal')
        }

        $mx = New-Object System.Collections.Generic.List[string]
        [void]$mx.Add('<?xml version="1.0" encoding="utf-8"?>')
        [void]$mx.Add('<songMeta displayName="' + (Escape-Xml $displayName) + '" bpm="' + (NumStr $bpm) + '" icon="' + (Escape-Xml $icon) + '" color="' + (Escape-Xml $color) + '" needsVoices="' + ([string]$needsVoices).ToLower() + '">')
        [void]$mx.Add('    <stage name="' + (Escape-Xml $stage) + '" />')
        [void]$mx.Add('    <characters player1="' + (Escape-Xml $player1) + '" player2="' + (Escape-Xml $player2) + '" gfVersion="' + (Escape-Xml $gfVersion) + '" />')
        [void]$mx.Add('    <difficulties list="' + (($diffList -join ',')) + '" default="' + (Escape-Xml $defaultDiff) + '">')
        foreach ($d in $diffList) {
            $spd = 2.0
            if ($diffMeta.ContainsKey($d)) { $spd = [double]$diffMeta[$d].speed }
            [void]$mx.Add('        <difficulty name="' + (Escape-Xml $d) + '" speed="' + (NumStr $spd) + '" />')
        }
        [void]$mx.Add('    </difficulties>')
        [void]$mx.Add('</songMeta>')

        Set-Content -Path (Join-Path $songDir 'meta.xmsoul') -Value ($mx -join "`r`n") -Encoding UTF8
        $writtenMeta++
    }

    if ($song -eq 'tutorial') {
        $easyPath = Join-Path $chartsDir 'easy.xmsoul'
        $normalPath = Join-Path $chartsDir 'normal.xmsoul'
        if (!(Test-Path $easyPath) -and (Test-Path $normalPath)) {
            Copy-Item $normalPath $easyPath -Force
        }
    }

    if ($song -eq 'ugh') {
        $hardPath = Join-Path $chartsDir 'hard.xmsoul'
        if (Test-Path $hardPath) {
            $normalPath = Join-Path $chartsDir 'normal.xmsoul'
            $easyPath = Join-Path $chartsDir 'easy.xmsoul'
            if (!(Test-Path $normalPath)) { Copy-Item $hardPath $normalPath -Force }
            if (!(Test-Path $easyPath)) { Copy-Item $hardPath $easyPath -Force }
        }
    }
}

Write-Output "Converted charts: $convertedCharts"
Write-Output "Wrote events.xmsoul: $writtenEvents"
Write-Output "Wrote meta.xmsoul: $writtenMeta"
