package com.dev.alootrack

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AlooTrackWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.aloo_track_widget).apply {
                val status = widgetData.getString("status", "Clocked out")
                val buttonLabel = widgetData.getString("button_label", "Clock In")
                val profile = widgetData.getString("profile", "") ?: ""
                val elapsed = widgetData.getString("elapsed", "") ?: ""

                setTextViewText(R.id.widget_status, status)
                val subtitle = listOf(profile, elapsed).filter { it.isNotEmpty() }.joinToString("  ")
                setTextViewText(R.id.widget_subtitle, subtitle)
                setTextViewText(R.id.widget_button, buttonLabel)

                val taskViews = intArrayOf(R.id.widget_task1, R.id.widget_task2, R.id.widget_task3)
                for (i in 0 until 3) {
                    val t = widgetData.getString("task${i + 1}", "") ?: ""
                    if (t.isEmpty()) {
                        setViewVisibility(taskViews[i], View.GONE)
                    } else {
                        setViewVisibility(taskViews[i], View.VISIBLE)
                        setTextViewText(taskViews[i], t)
                    }
                }

                // Clock in/out button → Dart background callback.
                val toggleIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("alootrack://clock_toggle")
                )
                setOnClickPendingIntent(R.id.widget_button, toggleIntent)

                // Tapping the body opens the app.
                val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, openApp)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
