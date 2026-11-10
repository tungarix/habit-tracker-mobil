# Faz 4 spike: saf Dart ile oz imzali HTTPS sunucusu

Durum: tamam (kucuk deneme calisti). Uretim kodu degil; `tool/spike_tls` bagimsiz bir Dart paketi (Flutter yok).

## Ne yapildi
- `tool/spike_tls/bin/spike.dart`: `basic_utils` 5.8.2 ile ECDSA P-256 anahtar + CSR + oz imzali sertifika (SAN = 127.0.0.1, 1 gun) uretir; `SecurityContext.useCertificateChainBytes` / `usePrivateKeyBytes` ile `HttpServer.bindSecure` acar. Ayni surecte Dart istemcisi sertifikayi DER SHA-256 (base64url, 43 karakter) ile sabitleyerek baglanir (`badCertificateCallback` yalniz parmak izi tutarsa true; sistem kok sertifikalari kapali).
- Sunucu 128 bit rastgele token ister (`Authorization: Bearer`), tek kullanimlik.
- Calistirma: `cd tool/spike_tls; dart run bin/spike.dart` (Windows, Dart 3.13.4).

## Dogrulanan (gercekten calistirildi, cikti goruldu)
| Senaryo | Sonuc |
|---|---|
| Yanlis token, dogru parmak izi | 401 yetkisiz |
| Dogru token, yanlis parmak izi | Baglanti reddedildi (HandshakeException) |
| Dogru token, dogru parmak izi | 200 |
| Ayni token ikinci kez | 401 (tek kullanimlik) |

Anahtar + sertifika uretimi ~90-120 ms. Kod tabani saf Dart, native bagimlilik yok.

## Dogrulanmadi
- Uretilen sertifikanin ayrintilari (notBefore, imza algoritmasi parametreleri, SAN'in gercekten girdigi) `openssl x509 -text` ile incelenmedi: ilgili komut guvenlik kancasi tarafindan engellendi (gecici `.pem` yolu), alternatif denemedim. Sunucu ile istemci birbirini kabul ettigi icin cihaz-ici akis calisiyor, ama Android'in (BoringSSL, farkli Dart surumu) ayni sertifikayi kabul ettigi dogrulanmadi.
- Sunucu yalniz 127.0.0.1'e baglandi; ozel LAN IP'si, Windows guvenlik duvari istemi ve gercek telefon istemcisi denenmedi.
- Mobil `wifi_istemci.dart` ile uyum denenmedi (dokunulmadi).
- `notBefore` varsayilani: telefon ile masaustu saati farkliysa 1 gunluk sertifika gecersiz sayilabilir; kontrol edilmedi (bkz. zorluklar).

## Sapmalar / notlar
- `pub get` yeni paketleri indirdi (basic_utils + pointycastle ~9 MB, onbellekte yoktu). "Kucuk paket" izni kapsaminda kabul ettim.
- Imza algoritmasi alani cikti baytlarindan `ecdsa-with-SHA256` + NULL parametre gibi gorundu (`BQAw`); standartta ECDSA icin parametre bulunmaz. Dart/BoringSSL bunu kabul etti (masaustu), ama bu bir uyumluluk riski; sunucuyu paketlemeden once Android istemcisiyle denenmeli.
- Alternatif (gerekmedi): Git'in `openssl.exe`'si (`C:\Program Files\Git\usr\bin\openssl.exe` var) alt surec olarak kullanilabilir, ama son kullanici makinesinde Git olmayabilir; masaustu uygulamasina openssl gommek gerekirdi. Saf Dart yolu calistigi icin onerilen yol bu.

## senkron-wifi.md protokolunu Dart'a tasirken zorlanacak noktalar
1. **Sertifika uretimi**: `basic_utils` kucuk bir topluluk paketi; ECDSA'da NULL parametre sorunu olabilir. Gerekirse RSA 2048 (yavas, ~saniyeler) ya da ASN.1'i `asn1lib` ile elle yazmak. Alternatif: Git/openssl alt sureci.
2. **Ozel anahtar diske yazilmama kurali** (§3): Dart `usePrivateKeyBytes` bellekten yukleyebiliyor (Python'daki gecici dosya hilesi gerekmedi), bu belgedeki kuraldan daha iyi. Ancak `basic_utils`'in PEM ciktisi CRLF iceriyor; DER'e cevirirken `\r` temizlenmeli (spike'ta ilk hata buydu).
3. **Kaynak IP basina sayac, baglanti sinirlari**: `HttpServer` baglanti seviyesinde kontrol vermez. "Kimlik dogrulanana dek 10 sn toplam omur (TLS dahil)", "IP basina en cok 2 baglanti", "yanitsiz kapat" icin `HttpServer` yerine `SecureServerSocket` + elle HTTP ayristirma (ya da `HttpServer.listenOn` ile once ham soketi sarmalama) gerekebilir. TLS el sikismasi `bindSecure` icinde yapilir, takilan istemciyi kesmek zor. En buyuk is burasi.
4. **Slowloris / govde zaman asimi (30 sn toplam)**: `HttpRequest` govdesini okurken toplam sure sinirini `Stream.timeout` ile degil elle toplam sayacla yapmak gerekir.
5. **Content-Length zorunlu (411) ve 16 MiB sinir govde okunmadan 413**: `HttpServer` chunked'i otomatik ceziyor; chunked'i 411 ile reddetmek icin `request.contentLength == -1` kontrolu yeterli. Reddedilen govdeyi okuyup atma (TCP RST tuzagi) Dart'ta da gecerli.
6. **Kimlik yoluna gore once**: yetkisiz istek 404/405 yerine 401 almali; `Expect: 100-continue`'da Dart 100 Continue'yu kendisi gonderebilir, bu kontrol edilmeli.
7. **Sabit zamanli token karsilastirma**: Dart standart kutuphanesinde `compare_digest` yok; elle XOR dongusu.
8. **Varsayilan yoldaki IPv4 secimi** (§3): Dart'ta `NetworkInterface.list` var ama "default route" bilgisi yok; UDP soketi `connect` hilesi (Dart `RawDatagramSocket` ile yerel adres okumak) ya da arayuz heuristigi gerekir. VPN/cok arayuzde yanlis IP riski.
9. **Ozel aralik denetimi**: `InternetAddress.isLoopback/isLinkLocal` var, 10/8, 172.16/12, 192.168/16, 100.64/10 icin elle yazilmali (Python'daki `is_private` tuzagi burada da var).
10. **Eszamanli POST ve onay beklemesi (60 sn)**: tek isolate'ta sorun degil ama arayuz isolate'i ile sunucu ayni isolate ise onay penceresi akisi `Completer` ile kurulmali; CPU agir dogrulama (500.000 ornek butcesi) ana isolate'i dondurmamak icin `Isolate.run` gerektirebilir. Bu habit-tracker icin daha hafif (takvim RRULE'u yok), butce kosullari yeniden tanimlanmali.
11. **Sunucu omru ve sert kapatma**: `server.close(force: true)` var; "bitir once token'i oldur sonra dinleyiciyi kapat" sirasi elle yapilmali; uygulama kapanisinda acik oturum temizligi.
12. **Windows guvenlik duvari istemi**: `bindSecure` ilk seferde istem tetikler; Dart tarafindan engellenemez, arayuz metniyle anlatilmali.
13. **Ozel IP'ye baglanma + hostname dogrulamasi**: `badCertificateCallback` devredeyken ana makine adi/SAN denetimi yapilmaz; guvenlik yalniz parmak izine dayanir (protokolun istedigi de bu), ama `host` ve IP-SAN testi yazilmali.
14. **Android istemci**: `Sertifika sabitleme` `badCertificateCallback` ile ayni calisir; `usesCleartextTraffic=false` ile cakismaz. Ancak sertifika uretici Dart surumleri arasinda farkli ASN.1 sikligi gosterebilir (madde Sapmalar).
15. **Saat farki**: 1 gunluk gecerlilik, telefon-masaustu saat farkinda sorun cikarabilir; `notBefore` biraz geriye cekilmeli (parametre var: `notBefore`).

## Acik isler
- Uretilen sertifikayi `openssl x509 -text` ile (engelsiz bir yolla) incele ve ECDSA NULL parametre durumunu netle.
- Android emulatorde `HttpClient` ile ayni sertifikanin kabulunu dene (ayri asama).
- `SecureServerSocket` tabanli baglanti sinirlari icin ikinci kucuk deneme (madde 3).
