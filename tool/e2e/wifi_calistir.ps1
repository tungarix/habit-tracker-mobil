# QR + Wi-Fi senkron uçtan uca: masaüstü GERÇEK sunucusu (geçici DB, 127.0.0.1) + mobil istemci kodu.
#   pwsh -File tool/e2e/wifi_calistir.ps1 [-Masaustu <masaüstü çalışma klasörü>]
# Yalnız kendi başlattığı süreci PID ile kapatır. Gerçek %APPDATA% verisine dokunmaz. flutter_tester çökmesinde
# ("did not complete") yeniden dener; gerçek test hatasında denemez.
param(
    [string]$Masaustu = 'C:\Users\Arda\Desktop\Aktenak\Projeler\habit-tracker-v5-calisma',
    [int]$Port = 48731,
    [int]$Deneme = 4
)
$kok = (Resolve-Path "$PSScriptRoot\..\..").Path
$env:E2E_KONTROL_PORT = "$Port"
$log = Join-Path ([IO.Path]::GetTempPath()) "wifi_e2e_masaustu_$PID.log"
for ($d = 1; $d -le $Deneme; $d++) {
    Remove-Item $log, "$log.err" -ErrorAction SilentlyContinue
    $p = Start-Process -FilePath cmd.exe -ArgumentList '/c', 'flutter test tool/e2e/wifi_kontrol_sunucu_test.dart' `
        -WorkingDirectory $Masaustu -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden
    try {
        $hazir = $false
        for ($i = 0; $i -lt 120 -and -not $hazir -and -not $p.HasExited; $i++) {
            Start-Sleep -Seconds 1
            if ((Test-Path $log) -and (Select-String -Path $log -Pattern 'KONTROL HAZIR' -Quiet)) { $hazir = $true }
        }
        if (-not $hazir) { Write-Host "Masaüstü kontrol sunucusu açılmadı (deneme $d)"; Get-Content $log -Tail 20; continue }
        Push-Location $kok
        try {
            $cikti = flutter test tool/e2e/wifi_e2e_test.dart 2>&1 | Out-String
        } finally { Pop-Location }
        Write-Host $cikti
        if ($cikti -match 'All tests passed!') { Write-Host 'WIFI E2E GECTI.'; exit 0 }
        # Masaüstü kontrol süreci test sırasında öldüyse (motor çökmesi) bu da çökmedir: yeniden dene.
        $cokme = $p.HasExited -or (($cikti -match 'did not complete|Connection closed before test suite loaded') -and
                 -not ($cikti -match 'Expected:|Actual:|TestFailure|Bad state'))
        if (-not $cokme) { exit 1 }
    } finally {
        if (-not $p.HasExited) { & taskkill /T /F /PID $p.Id | Out-Null }
    }
}
Write-Host 'Motor çökmesi nedeniyle tamamlanamadı.'; exit 1
