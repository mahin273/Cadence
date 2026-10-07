package com.cadence.cadence

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class CadenceGlanceWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.cadence_glance_widget).apply {
                val focusMinutes = widgetData.getInt("focus_minutes", 0)
                val steps = widgetData.getInt("today_steps", 0)
                val waterGlasses = widgetData.getInt("water_glasses", 0)
                val streak = widgetData.getInt("streak_days", 0)
                val phase = widgetData.getString("circadian_phase", "Daylight") ?: "Daylight"

                setTextViewText(R.id.widget_focus_value, "${focusMinutes}m")
                setTextViewText(R.id.widget_steps_value, String.format("%,d", steps))
                setTextViewText(R.id.widget_water_value, "$waterGlasses gl")
                setTextViewText(R.id.widget_streak_value, "$streak d")
                setTextViewText(R.id.widget_phase_label, "$phase Phase")

                // Open App on Widget body tap
                val openAppIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cadence://home")
                )
                setOnClickPendingIntent(R.id.widget_container, openAppIntent)

                // Quick Action: +1 Water
                val waterIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cadence://quick_action?type=water")
                )
                setOnClickPendingIntent(R.id.widget_btn_water, waterIntent)

                // Quick Action: Start Focus
                val focusIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cadence://quick_action?type=focus")
                )
                setOnClickPendingIntent(R.id.widget_btn_focus, focusIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
