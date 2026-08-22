package com.drawndays.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DrawnDaysTodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val language = widgetData.getString("widget_language", "english") ?: "english"
        val locale = if (language == "english") Locale.US else Locale("tr", "TR")
        val now = Date()
        val currentDateKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now)
        val storedDateKey = widgetData.getString("today_date_key", "")
        val hasDoodle = widgetData.getBoolean("has_doodle", false) &&
            storedDateKey == currentDateKey
        val day = SimpleDateFormat("d", locale).format(now)
        val weekday = SimpleDateFormat("EEEE", locale).format(now)
            .replaceFirstChar { it.uppercase(locale) }
        val prompt = if (language == "english") "Draw today" else "Bugünü çiz"
        val imagePath = widgetData.getString("today_doodle", null)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.drawn_days_today_widget).apply {
                setTextViewText(R.id.widget_day, day)
                setTextViewText(R.id.widget_weekday, weekday)
                setTextViewText(R.id.widget_prompt, prompt)

                val bitmap = if (hasDoodle && imagePath != null) {
                    BitmapFactory.decodeFile(imagePath)
                } else {
                    null
                }
                if (bitmap != null) {
                    setImageViewBitmap(R.id.widget_doodle, bitmap)
                    setViewVisibility(R.id.widget_doodle, View.VISIBLE)
                    setViewVisibility(R.id.widget_empty_icon, View.GONE)
                    setViewVisibility(R.id.widget_prompt, View.GONE)
                } else {
                    setViewVisibility(R.id.widget_doodle, View.GONE)
                    setViewVisibility(R.id.widget_empty_icon, View.VISIBLE)
                    setViewVisibility(R.id.widget_prompt, View.VISIBLE)
                }

                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("drawndays://draw/today?homeWidget"),
                )
                setOnClickPendingIntent(R.id.widget_container, launchIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
