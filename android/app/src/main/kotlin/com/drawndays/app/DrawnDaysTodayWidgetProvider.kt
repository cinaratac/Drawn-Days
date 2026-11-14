package com.drawndays.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private fun renderDayNumber(context: Context, day: String): Bitmap {
    val density = context.resources.displayMetrics.density
    val width = (48 * density).toInt()
    val height = (44 * density).toInt()
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val typeface = try {
        Typeface.createFromAsset(
            context.assets,
            "flutter_assets/lib/assets/fonts/PatrickHand-Regular.ttf",
        )
    } catch (_: RuntimeException) {
        Typeface.create("cursive", Typeface.NORMAL)
    }
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(23, 63, 50)
        textSize = 29 * density
        this.typeface = typeface
    }
    val metrics = paint.fontMetrics
    val baseline = ((height - metrics.bottom - metrics.top) / 2f) - density
    Canvas(bitmap).drawText(day, 2 * density, baseline, paint)
    return bitmap
}

class DrawnDaysTodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = Date()
        val currentDateKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now)
        val storedDateKey = widgetData.getString("today_date_key", "")
        val hasDoodle = widgetData.getBoolean("has_doodle", false) &&
            storedDateKey == currentDateKey
        val day = SimpleDateFormat("d", Locale.US).format(now)
        val imagePath = widgetData.getString("today_doodle", null)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.drawn_days_today_widget).apply {
                setImageViewBitmap(R.id.widget_day, renderDayNumber(context, day))

                val bitmap = if (hasDoodle && imagePath != null) {
                    BitmapFactory.decodeFile(imagePath)
                } else {
                    null
                }
                if (bitmap != null) {
                    setImageViewBitmap(R.id.widget_doodle, bitmap)
                    setViewVisibility(R.id.widget_doodle, View.VISIBLE)
                    setViewVisibility(R.id.widget_empty_state, View.GONE)
                    setViewVisibility(R.id.widget_tape, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_doodle, View.GONE)
                    setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                    setViewVisibility(R.id.widget_tape, View.GONE)
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

abstract class DrawnDaysArtworkWidgetProvider(
    private val artworkKey: String,
    private val destination: String,
) : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val imagePath = widgetData.getString(artworkKey, null)
        val bitmap = imagePath?.let(BitmapFactory::decodeFile)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.drawn_days_artwork_widget).apply {
                if (bitmap != null) {
                    setImageViewBitmap(R.id.widget_artwork, bitmap)
                    setViewVisibility(R.id.widget_artwork, View.VISIBLE)
                    setViewVisibility(R.id.widget_artwork_placeholder, View.GONE)
                } else {
                    setViewVisibility(R.id.widget_artwork, View.GONE)
                    setViewVisibility(R.id.widget_artwork_placeholder, View.VISIBLE)
                }
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(destination),
                )
                setOnClickPendingIntent(R.id.widget_container, launchIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class DrawnDaysWeekWidgetProvider : DrawnDaysArtworkWidgetProvider(
    artworkKey = "week_widget",
    destination = "drawndays://calendar/week?homeWidget",
)

class DrawnDaysMonthWidgetProvider : DrawnDaysArtworkWidgetProvider(
    artworkKey = "month_widget",
    destination = "drawndays://calendar/month?homeWidget",
)
