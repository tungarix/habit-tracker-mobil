package com.aktenak.habit_tracker

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Bundle
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Bridge to Dart (no extra plugin): in-app update only.
 *  - agTuru: 'wifi' (unmetered) | 'mobil' (metered) | 'yok',
 *  - kurulumIzniVar / kurulumIzniAc: "install unknown apps" permission,
 *  - apkKur: installs an APK from the app cache dir through a PackageInstaller session. Only an APK
 *    with this package name and a higher versionCode is accepted; the final word is Android's
 *    signature check (an APK signed with another key cannot be installed over this one).
 *  - uygulamaAyarlariniAc: this app's system settings page (re-grant the camera permission for QR pairing),
 *  - kurulumSonucu (Kotlin -> Dart): session result.
 *  - bekleyenDosya / dosyaGeldi: a .habitsync opened with "Open with" / Share. Only content:// is read, at most
 *    16 MB; the bytes go to Dart, which validates and asks the user before anything is merged.
 */
class MainActivity : FlutterActivity() {
    private var kanal: MethodChannel? = null
    private var bekleyen: Map<String, Any>? = null

    // After Dart's first "bekleyenDosya" call its listener is ready; a push before that would be lost.
    private var dartHazir = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A recreated process must not handle the same intent twice.
        if (savedInstanceState == null) dosyayiOku(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        dosyayiOku(intent)
    }

    // Remove only OUR listener: a second MainActivity instance may have replaced it.
    private var benimDinleyici: ((Int, String?) -> Unit)? = null

    override fun onDestroy() {
        if (KurulumAlici.sonucDinleyici === benimDinleyici) KurulumAlici.sonucDinleyici = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val dinleyici: (Int, String?) -> Unit = { durum, mesaj ->
            runOnUiThread { kanal?.invokeMethod("kurulumSonucu", mapOf("durum" to durum, "mesaj" to mesaj)) }
        }
        benimDinleyici = dinleyici
        KurulumAlici.sonucDinleyici = dinleyici
        kanal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aktenak.habit_tracker/kopru").also { k ->
            k.setMethodCallHandler { cagri, sonuc ->
                when (cagri.method) {
                    "agTuru" -> sonuc.success(agTuru())
                    "kurulumIzniVar" -> sonuc.success(Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls())
                    "kurulumIzniAc" -> {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        sonuc.success(null)
                    }
                    "uygulamaAyarlariniAc" -> {
                        startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        sonuc.success(null)
                    }
                    "apkKur" -> apkKur(cagri.argument<String>("yol"), cagri.argument<String>("ozet"), sonuc)
                    "bekleyenDosya" -> {
                        dartHazir = true
                        val b = bekleyen
                        bekleyen = null
                        sonuc.success(b)
                    }
                    else -> sonuc.notImplemented()
                }
            }
        }
    }

    private fun agTuru(): String {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        if (cm.activeNetwork == null) return "yok"
        return if (cm.isActiveNetworkMetered) "mobil" else "wifi"
    }

    private fun apkKur(yol: String?, ozet: String?, sonuc: MethodChannel.Result) {
        var oturumNo = -1
        var commitEdildi = false
        try {
            require(yol != null && ozet != null && ozet.length == 64) { "yol ya da özet yok" }
            val dosya = File(yol).canonicalFile
            val klasor = cacheDir.canonicalFile
            require(dosya.path.startsWith(klasor.path + File.separator) && dosya.isFile && dosya.name.endsWith(".apk")) { "APK uygulamanın geçici klasöründe değil" }
            val pm = packageManager
            val yeni = pm.getPackageArchiveInfo(dosya.path, 0) ?: throw IllegalStateException("APK okunamadı")
            require(yeni.packageName == packageName) { "paket adı farklı" }
            val mevcut = pm.getPackageInfo(packageName, 0)
            fun kod(p: android.content.pm.PackageInfo): Long =
                if (Build.VERSION.SDK_INT >= 28) p.longVersionCode else @Suppress("DEPRECATION") p.versionCode.toLong()
            require(kod(yeni) > kod(mevcut)) { "sürüm kodu daha yüksek değil" }

            val kurucu = pm.packageInstaller
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            params.setAppPackageName(packageName)
            val id = kurucu.createSession(params)
            oturumNo = id
            kurucu.openSession(id).use { oturum ->
                // Hash exactly the bytes handed to the installer; a mismatch abandons the session pre-commit.
                val md = java.security.MessageDigest.getInstance("SHA-256")
                java.security.DigestInputStream(dosya.inputStream(), md).use { girdi ->
                    oturum.openWrite("habit-tracker.apk", 0, dosya.length()).use { cikti ->
                        girdi.copyTo(cikti)
                        oturum.fsync(cikti)
                    }
                }
                val gercek = md.digest().joinToString("") { "%02x".format(it) }
                require(gercek == ozet.lowercase()) { "SHA-256 özeti tutmuyor" }
                val niyet = Intent(this, KurulumAlici::class.java)
                val bayrak = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
                oturum.commit(PendingIntent.getBroadcast(this, id, niyet, bayrak).intentSender)
                commitEdildi = true
            }
            sonuc.success(null)
        } catch (e: Exception) {
            // After commit the session may sit in the user's confirm dialog: abandon only on pre-commit failure.
            if (oturumNo >= 0 && !commitEdildi) try { packageManager.packageInstaller.abandonSession(oturumNo) } catch (_: Exception) {}
            sonuc.error("kurulum", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun dosyayiOku(i: Intent?) {
        if (i == null) return
        val uri: Uri? = when (i.action) {
            Intent.ACTION_VIEW -> i.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                else @Suppress("DEPRECATION") i.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) return
        // Only content:// is accepted. The manifest filter alone is not enough: an explicit intent skips it and
        // a file:// URI could make the app read its own private files.
        if (uri.scheme != "content") {
            setIntent(Intent())
            return
        }
        // The file is read off the main thread (a slow or hung content provider must not cause an ANR);
        // Throwable, so an OutOfMemoryError on a huge stream becomes an error message, not a crash.
        // The same file must not be handled again (e.g. on coming back to the foreground).
        setIntent(Intent())
        Thread {
            val sonuc: Map<String, Any> = try {
                val sinir = 16 * 1024 * 1024
                val cikti = ByteArrayOutputStream()
                contentResolver.openInputStream(uri).use { girdi ->
                    if (girdi == null) throw IllegalStateException("dosya açılamadı")
                    val tampon = ByteArray(64 * 1024)
                    while (true) {
                        val n = girdi.read(tampon)
                        if (n < 0) break
                        cikti.write(tampon, 0, n)
                        if (cikti.size() > sinir) throw IllegalStateException("dosya çok büyük (en çok 16 MB)")
                    }
                }
                mapOf("bayt" to cikti.toByteArray())
            } catch (e: Throwable) {
                mapOf("hata" to (e.message ?: e.javaClass.simpleName))
            }
            runOnUiThread {
                if (dartHazir && kanal != null) kanal?.invokeMethod("dosyaGeldi", sonuc) else bekleyen = sonuc
            }
        }.start()
    }
}
