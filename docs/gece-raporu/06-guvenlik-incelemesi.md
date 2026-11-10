# 06 Güvenlik incelemesi (salt okunur)

## Yapıldı
- Mobil repo ve masaüstü v5 çalışma kopyasındaki sync kodu kaynak okumasıyla incelendi. Tam bulgu listesi: `guvenlik/incelemeler/v0.1.0.md` (TASLAK, `Sonuç:` bilerek boş, "geçti" yazılmadı).
- Kod, manifest, workflow ve betiklerde değişiklik yok; yalnız bu rapor ve taslak kayıt eklendi. Commit atılmadı.

## Doğrulananlar (kanıtla, dosya okundu)
- Repo geçmişinde keystore/parola yok; imza yalnız ortam değişkeninden.
- Güncelleyici ağ katmanı, adres denetimi, indirme sınırları, PackageInstaller yol/paket/versionCode denetimi, intent filtreleri (`content://`, BROWSABLE yok, onay), sync ayrıştırıcı sınırları, birleşik release manifesti, widget alıcısı.
- Masaüstü ve mobil `sync_*.dart` dosyaları birebir aynı (`diff`).

## Doğrulanmadı
- Hiçbir şey cihazda/emülatörde çalıştırılmadı; sahte GitHub ile güncelleme denenmedi; sync saldırı dosyaları (gelecek damga, 100 bin alışkanlık) fiilen üretilip denenmedi, bulgular kod akışından çıkarıldı.
- Pub paketlerinin (home_widget vb.) tamamı denetlenmedi; yalnız home_widget PendingIntent bayrakları ve alıcısı okundu.

## Başlıca bulgular
1. Güncelleyici arayüze bağlı değil; onay, yalnız Wi-Fi ve kurulum öncesi özet yeniden denetimi hiçbir yerde uygulanmıyor. Bu hâliyle güncelleme akışı "geçti" denemez (B1).
2. `.habitsync` içinde gelecek tarihli `updated_at`/`deleted_at` LWW'yi kalıcı zehirler; onay penceresi silinecek sayıyı göstermiyor (B2).
3. Sync'te tür başına sınır yok, eşleştirme O(n²) (B3). Yedek JSON içe aktarma sınırları zayıf (B4).
4. Public repodaki ekran görüntüleri gerçek alışkanlık adlarını gösteriyor; yayından önce repo geçmişinden temizlenmeli (B5). Henüz push yok.
5. `release.yml`: yazma yetkisi tüm işte, anahtar+şifre derleme ortamında, aksiyonlar SHA'ya sabit değil, etiketsiz elle çalıştırmada sürüm anahtarıyla imza (B6).
6. Düşükler: plan dışı izinler (VIBRATE/WAKE_LOCK/FOREGROUND_SERVICE), Kotlin'de imza ön denetimi yok, HTTPS yalnız Dart koduna bağlı, ana iş parçacığında dosya okuma, anahtar betiği şifre düz metin, kişisel yol, widget gizliliği.

## Sapma/engel
- Yok; plan ile çelişen bir adım atılmadı.

## Açık işler (Arda)
- `Sonuç:` kararı ve `Kapsam:` commit'i Arda'da; düzeltmelerden sonra inceleme yenilenmeli.
- B1, B2, B3, B5, B6 yayından önce karar/düzeltme ister; B2/B3 masaüstü ve mobilde ortak kod olduğu için `esitle.ps1` ile birlikte yapılmalı.
