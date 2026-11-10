package com.aktenak.habit_tracker

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Bridge to Dart (no extra plugin): in-app update only.
 *  - agTuru: 'wifi' (unmetered) | 'mobil' (metered) | 'yok',
 *  - kurulumIzniVar / kurulumIzniAc: "install unknown apps" permission,
 *  - apkKur: installs an APK from the app cache dir through a PackageInstaller session. Only an APK
 *    with this package name and a higher versionCode is accepted; the final word is Android's
 *    signature check (an APK signed with another key cannot be installed over this one).
 *  - kurulumSonucu (Kotlin -> Dart): session result.
 */
class MainActivity : FlutterActivity() {
    private var kanal: MethodChannel? = null

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
                    "apkKur" -> apkKur(cagri.arguments as? String, sonuc)
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

    private fun apkKur(yol: String?, sonuc: MethodChannel.Result) {
        var oturumNo = -1
        var commitEdildi = false
        try {
            require(yol != null) { "yol yok" }
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
                dosya.inputStream().use { girdi ->
                    oturum.openWrite("habit-tracker.apk", 0, dosya.length()).use { cikti ->
                        girdi.copyTo(cikti)
                        oturum.fsync(cikti)
                    }
                }
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
}
