# Masaüstü reposundaki (tungarix/habit-tracker) ortak kodu mobile kopyalar ve
# tool/kaynak_ozet.json'u yeniden yazar. Kopyalanan dosyalar mobilde ELLE DEĞİŞTİRİLMEZ;
# bilerek değiştirilecekse dosya kaynak_ozet.json "bilincli_sapmalar" listesine gerekçesiyle girer.
#
# Özet (SHA-256) satır sonları LF'ye çevrilerek hesaplanır: Windows (CRLF) ve CI (LF) aynı sonucu versin.
param(
    [string]$Kaynak = 'C:\Users\Arda\Desktop\Aktenak\Projeler\habit-tracker'
)
$ErrorActionPreference = 'Stop'
$kok = Split-Path $PSScriptRoot -Parent
$ozetYolu = Join-Path $PSScriptRoot 'kaynak_ozet.json'

# Masaüstüne özgü ya da arayüze bağlı testler kopyalanmaz.
$testHaric = 'package:aktenak_habit_tracker/(app|features/|shared/|core/window_placement)'

function Ozet([string]$yol) {
    $metin = [IO.File]::ReadAllText($yol).Replace("`r`n", "`n")
    $bayt = [Text.UTF8Encoding]::new($false).GetBytes($metin)
    ([BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($bayt)) -replace '-', '').ToLower()
}

# Kopyalanacak göreli yollar (kaynak köküne göre, / ayraçlı).
$liste = [System.Collections.Generic.List[string]]::new()
Get-ChildItem "$Kaynak\lib\core" -Filter *.dart | Where-Object Name -ne 'window_placement.dart' |
    ForEach-Object { $liste.Add("lib/core/$($_.Name)") }
foreach ($f in 'tables.dart', 'database.dart', 'database.g.dart') { $liste.Add("lib/data/database/$f") }
foreach ($f in 'data_location.dart', 'auto_backup.dart', 'providers.dart') { $liste.Add("lib/data/$f") }
Get-ChildItem "$Kaynak\lib\data\repositories" -Filter *.dart | ForEach-Object { $liste.Add("lib/data/repositories/$($_.Name)") }
# providers.dart bunu içe aktarır (saf Dart, arayüz yok).
Get-ChildItem "$Kaynak\lib\data\models" -Filter *.dart | ForEach-Object { $liste.Add("lib/data/models/$($_.Name)") }
Get-ChildItem "$Kaynak\test" -Filter *.dart | Where-Object {
    $_.Name -eq 'helpers.dart' -or -not (Select-String -Path $_.FullName -Pattern $testHaric -Quiet)
} | ForEach-Object { $liste.Add("test/$($_.Name)") }

# Önceki özetteki bilinçli sapmalar korunur.
$sapmalar = @()
if (Test-Path $ozetYolu) { $sapmalar = @((Get-Content $ozetYolu -Raw | ConvertFrom-Json).bilincli_sapmalar) }
$sapmaDosyalari = @($sapmalar | ForEach-Object { $_.dosya })
# Dosya özetini etkilemeyen bilinçli farklar (örn. lib/platform/db_baglanti.dart) da korunur.
$farklar = @()
if (Test-Path $ozetYolu) { $farklar = @((Get-Content $ozetYolu -Raw | ConvertFrom-Json).bilincli_farklar) }

$dosyalar = [ordered]@{}
foreach ($g in ($liste | Sort-Object)) {
    $hedef = Join-Path $kok $g
    New-Item -ItemType Directory -Force (Split-Path $hedef) | Out-Null
    if ($sapmaDosyalari -notcontains $g) { Copy-Item (Join-Path $Kaynak $g) $hedef -Force }
    $dosyalar[$g] = Ozet (Join-Path $Kaynak $g)   # kaynağın özeti; sapmalı dosyada kopya ile tutmaz
}

$sha = (git -C $Kaynak rev-parse HEAD).Trim()
$etiket = (git -C $Kaynak describe --tags --abbrev=0).Trim()
# Kopyalar etiketteki dosyalarla birebir mi? (etiketten bu yana değişen / kirli dosya var mı)
$kirli = @(git -C $Kaynak diff --name-only $etiket -- @($liste)) + @(git -C $Kaynak status --porcelain -- @($liste))
if ($kirli.Count -gt 0) { Write-Warning "Kopyalanan dosyalar '$etiket' etiketiyle tutmuyor: $($kirli -join ', ')" }

[ordered]@{
    kaynak           = 'tungarix/habit-tracker'
    kaynak_commit    = $sha
    etiket           = $etiket
    etiketle_ayni    = ($kirli.Count -eq 0)
    dosyalar         = $dosyalar
    bilincli_sapmalar = $sapmalar
    bilincli_farklar  = $farklar
} | ConvertTo-Json -Depth 5 | Set-Content $ozetYolu -Encoding utf8
Write-Host "$($dosyalar.Count) dosya eşitlendi; kaynak $etiket ($($sha.Substring(0,7)))."
