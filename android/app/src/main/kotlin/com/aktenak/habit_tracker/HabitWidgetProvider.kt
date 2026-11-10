package com.aktenak.habit_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONException

/**
 * Home-screen widget: today's habits, one tap writes a check.
 *
 * Dart (lib/platform/widget_servisi.dart) stores the list in the home_widget preferences:
 *  - widget_items: JSON [{"id":5,"ad":"Kitap","yapildi":false}, ...]
 *  - widget_bitis: epoch ms when the tracking day ends (after that the list is stale)
 * A row tap sends habitwidget://isaretle?id=<id> to the Dart background callback.
 */
class HabitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val bitis = widgetData.getLong("widget_bitis", 0L)
        val bayat = bitis != 0L && System.currentTimeMillis() >= bitis
        val kayitlar = try {
            JSONArray(widgetData.getString("widget_items", "[]"))
        } catch (_: JSONException) {
            JSONArray()
        }
        val n = if (bayat) 0 else kayitlar.length()
        var yapilan = 0
        for (i in 0 until n) if (kayitlar.optJSONObject(i)?.optBoolean("yapildi") == true) yapilan++

        for (widgetId in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.habit_widget)
            val acPending = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            v.setOnClickPendingIntent(R.id.widget_baslik, acPending)
            v.setTextViewText(
                R.id.widget_baslik,
                if (n > 0) context.getString(R.string.widget_baslik_sayili, yapilan, n)
                else context.getString(R.string.widget_baslik),
            )
            v.setViewVisibility(R.id.widget_bos, if (n == 0) View.VISIBLE else View.GONE)
            v.setTextViewText(
                R.id.widget_bos,
                context.getString(if (bayat) R.string.widget_bayat else R.string.widget_bos),
            )
            v.setOnClickPendingIntent(R.id.widget_bos, acPending)

            for (i in SATIRLAR.indices) {
                val kayit = if (i < n) kayitlar.optJSONObject(i) else null
                if (kayit == null) {
                    v.setViewVisibility(SATIRLAR[i], View.GONE)
                    continue
                }
                val ad = kayit.optString("ad")
                val yapildi = kayit.optBoolean("yapildi")
                v.setViewVisibility(SATIRLAR[i], View.VISIBLE)
                // The check mark (not only dimming) tells done from open: colour is never the only cue.
                v.setTextViewText(SATIRLAR[i], (if (yapildi) "✓  " else "○  ") + ad)
                v.setContentDescription(
                    SATIRLAR[i],
                    context.getString(if (yapildi) R.string.widget_satir_yapildi else R.string.widget_satir_bekliyor, ad),
                )
                v.setOnClickPendingIntent(
                    SATIRLAR[i],
                    HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("habitwidget://isaretle?id=${kayit.optInt("id")}")),
                )
            }
            val fazla = n - SATIRLAR.size
            v.setViewVisibility(R.id.widget_fazla, if (fazla > 0) View.VISIBLE else View.GONE)
            if (fazla > 0) {
                v.setTextViewText(R.id.widget_fazla, context.getString(R.string.widget_fazla, fazla))
                v.setOnClickPendingIntent(R.id.widget_fazla, acPending)
            }
            appWidgetManager.updateAppWidget(widgetId, v)
        }
    }

    companion object {
        private val SATIRLAR = intArrayOf(R.id.widget_satir0, R.id.widget_satir1, R.id.widget_satir2, R.id.widget_satir3, R.id.widget_satir4)
    }
}
