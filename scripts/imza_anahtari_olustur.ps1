# Habit Tracker (Android) sürüm imza anahtarını BİR KEZ oluşturur ve GitHub secret'larına yükler.
#
# - Anahtar depo DIŞINA yazılır ve İKİ yere konur (PLAN): Belgeler\habit-tracker-mobil-imza ve
#   D:\Yedek-Imza-Anahtarlari\. Anahtar kaybolursa sonraki sürümler eskisinin üstüne kurulamaz
#   (ilk sürümden itibaren hep aynı anahtar kullanılmalı).
# - Şifre rastgele üretilir; ekrana basılmaz, komut satırına girmez (keytool: ortam değişkeni,
#   gh: stdin). Anahtar klasörlerinde DÜZ METİN şifre dosyası YOKTUR. Şifre yalnız (a) GitHub
#   secret'ında (yazma-yalnız), (b) bu kullanıcıya bağlı DPAPI ile şifreli sifre.dpapi dosyasında
#   (yalnız ana klasörde, yedeğe kopyalanmaz) ve (c) panoya bir kez konur: parola yöneticine kaydet.
# - Ekrana yalnız sertifikanın SHA-256 parmak izi basılır (gizli değil).
#
# Kullanım (depo kökünde, gh oturumu açıkken):
#   powershell -ExecutionPolicy Bypass -File scripts\imza_anahtari_olustur.ps1

param(
    [string]$Klasor = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'habit-tracker-mobil-imza'),
    [string]$YedekKlasor = 'D:\Yedek-Imza-Anahtarlari',
    [string]$Repo = 'tungarix/habit-tracker-mobil'
)
$ErrorActionPreference = 'Stop'

$anahtar = Join-Path $Klasor 'habit-surum.jks'
$sifreDosyasi = Join-Path $Klasor 'sifre.dpapi'
if ((Test-Path $anahtar) -and -not (Test-Path $sifreDosyasi)) {
    # Yarım kalmış önceki deneme: şifresi kaydedilmemiş anahtar kullanılamaz.
    # Silinmez, kenara alınır.
    $kenar = "$anahtar.yarim-$(Get-Date -Format yyyyMMddHHmmss)"
    Move-Item $anahtar $kenar
    Write-Host "Şifresiz yarım anahtar kenara alındı: $kenar"
}
if (Test-Path $anahtar) {
    throw "Anahtar zaten var: $anahtar. Üzerine yazılmaz; yeni anahtar eski APK'larla uyumsuz olur."
}

$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
    # PATH'teki java çoğu zaman Oracle'ın javapath kısayolu; keytool JDK'nın bin'inde.
    $keytool = Get-ChildItem 'C:\Program Files\Java', 'C:\Program Files\Eclipse Adoptium' `
        -Recurse -Depth 3 -Filter keytool.exe -ErrorAction SilentlyContinue |
        Select-Object -Last 1 -ExpandProperty FullName
}
if (-not $keytool -or -not (Test-Path $keytool)) { throw 'keytool bulunamadı (Java ile gelir).' }

New-Item -ItemType Directory -Force $Klasor | Out-Null

# 32 karakter rastgele şifre (harf + rakam; keytool argümanında kaçış gerektirmez).
$harfler = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$bayt = New-Object byte[] 32
$rng.GetBytes($bayt)
$sifre = -join ($bayt | ForEach-Object { $harfler[$_ % $harfler.Length] })

# Parola komut satırında görünmesin: keytool ortam değişkeninden okur (-storepass:env).
$env:HABIT_ANAHTAR_PAROLA = $sifre

# keytool ve gh bilgi satırlarını stderr'e yazar; Windows PowerShell 5.1 bunu Stop
# altında hata sayıp betiği keserdi. Buradan sonra yalnız çıkış kodlarına bakılır.
$ErrorActionPreference = 'Continue'
& $keytool -genkeypair -keystore $anahtar -storetype PKCS12 -alias habit `
    -keyalg RSA -keysize 4096 -validity 10000 `
    -storepass:env HABIT_ANAHTAR_PAROLA -keypass:env HABIT_ANAHTAR_PAROLA `
    -dname 'CN=Aktenak Habit Tracker, O=Aktenak, C=TR' 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'keytool anahtarı oluşturamadı.' }

# DPAPI: yalnız bu Windows kullanıcısı çözebilir; düz metin değildir.
ConvertTo-SecureString $sifre -AsPlainText -Force | ConvertFrom-SecureString |
    Set-Content -Path $sifreDosyasi -Encoding ascii
@"
Habit Tracker (Android) sürüm imza anahtarı ($(Get-Date -Format yyyy-MM-dd))
Alias: habit. Şifre bu klasörde DEĞİL: parola yöneticisinde (anahtar ve alias için aynı).
GitHub secret'ları: HABIT_KEYSTORE_BASE64, HABIT_KEYSTORE_PASSWORD ($Repo).
Bu klasörü yedekle. Kaybolursa sonraki APK'lar eskisinin üstüne kurulmaz.
"@ | Set-Content -Path (Join-Path $Klasor 'BENIOKU.txt') -Encoding utf8

# Secret'lar stdin'den gider (komut satırında görünmez). PowerShell pipe'ı sona satır sonu
# eklerdi; bu yüzden süreç doğrudan açılıp baytlar sonsuz satırsız yazılır.
function Set-GhSecret([string]$Ad, [string]$Deger) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Command gh).Source
    $psi.Arguments = "secret set $Ad -R $Repo"
    $psi.RedirectStandardInput = $true
    $psi.UseShellExecute = $false
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($Deger)
    $p.StandardInput.Close()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw "Secret yüklenemedi: $Ad (gh auth status?)." }
}
Set-GhSecret 'HABIT_KEYSTORE_BASE64' ([Convert]::ToBase64String([IO.File]::ReadAllBytes($anahtar)))
Set-GhSecret 'HABIT_KEYSTORE_PASSWORD' $sifre

# İkinci yedek konumu: yalnız anahtar + BENIOKU (şifre dosyası kopyalanmaz).
if (Test-Path (Split-Path $YedekKlasor -Qualifier)) {
    New-Item -ItemType Directory -Force $YedekKlasor | Out-Null
    Copy-Item $anahtar, (Join-Path $Klasor 'BENIOKU.txt') $YedekKlasor
    Write-Host "İkinci yedek: $YedekKlasor"
} else {
    Write-Warning "Yedek sürücüsü yok ($YedekKlasor). Anahtarı elle ikinci bir yere kopyala."
}

Write-Host "Tamam. Anahtar: $Klasor"
Write-Host 'Sertifika parmak izi:'
& $keytool -list -v -keystore $anahtar -storepass:env HABIT_ANAHTAR_PAROLA -alias habit 2>$null |
    Select-String 'SHA256:'

# Şifreyi parola yöneticisine kaydetmen için panoya koy, sonra panoyu temizle.
Set-Clipboard -Value $sifre
Read-Host 'Şifre panoda. Parola yöneticisine yapıştırıp kaydet, sonra Enter (pano temizlenir)' | Out-Null
Set-Clipboard -Value ' '
Remove-Item Env:HABIT_ANAHTAR_PAROLA
$sifre = $null
Write-Host "Anahtar iki yerde: $Klasor ve $YedekKlasor. Şifre yalnız parola yöneticisinde ve GitHub secret'ında."
