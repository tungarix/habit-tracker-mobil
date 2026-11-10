package com.aktenak.habit_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

/**
 * Receives the PackageInstaller session result (own app only, exported=false).
 * When user confirmation is needed it opens the system install dialog; every other result
 * (failure, signature mismatch...) is forwarded to the app so the user is not left guessing.
 * On success the process is replaced by the new one anyway.
 */
class KurulumAlici : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val durum = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (durum != PackageInstaller.STATUS_PENDING_USER_ACTION) {
            sonucDinleyici?.invoke(durum, intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE))
            return
        }
        val onay: Intent? =
            if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            else @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_INTENT)
        // Only the system's install-confirmation intent is launched (UnsafeIntentLaunch defence).
        if (onay != null && onay.action == ONAY_EYLEMI) context.startActivity(onay.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    companion object {
        private const val ONAY_EYLEMI = "android.content.pm.action.CONFIRM_INSTALL"

        /** Set while MainActivity is alive; the result goes to Dart as `kurulumSonucu`. */
        @Volatile
        var sonucDinleyici: ((Int, String?) -> Unit)? = null
    }
}
