# Masaüstü <-> mobil .habitsync uçtan uca denetimi (tek komut):  pwsh -File tool/e2e/calistir.ps1
# İki "cihaz" geçici SQLite dosyalarıdır ve masaüstüyle AYNI senkron kodunu çalıştırır
# (tool/esitle.ps1 kopyalar, test/uyum_test.dart özetle denetler). Gerçek veriye dokunulmaz.
# flutter_tester bu makinede rastgele çöker (0xC0000005): çökme imzasında yeniden denenir,
# gerçek test hatasında denenmez.
param([int]$Deneme = 5)
$kok = (Resolve-Path "$PSScriptRoot\..\..").Path
Push-Location $kok
try {
    for ($i = 1; $i -le $Deneme; $i++) {
        $cikti = flutter test tool/e2e/senkron_e2e_test.dart 2>&1 | Out-String
        if ($cikti -match 'All tests passed!') { Write-Host $cikti; Write-Host 'E2E GECTI.'; exit 0 }
        $cokme = ($cikti -match 'did not complete|Connection closed before test suite loaded') -and
                 -not ($cikti -match 'Expected:|Actual:|TestFailure|Bad state')
        if (-not $cokme) { Write-Host $cikti; exit 1 }
    }
    Write-Host 'Motor cokmesi nedeniyle tamamlanamadi.'; exit 1
} finally { Pop-Location }
