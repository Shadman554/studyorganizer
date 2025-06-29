package com.example.study_organizer

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import android.util.Log

class CalendarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { widgetId ->
            updateAppWidget(context, appWidgetManager, widgetId)
        }
    }
    
    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.calendar_widget_layout)
        
        // Get the JSON string of upcoming events
        val widgetData = HomeWidgetPlugin.getData(context)
        val eventsJson = widgetData.getString("upcoming_events", "[]")
        
        try {
            // Parse the JSON array
            val events = JSONArray(eventsJson)
            
            if (events.length() == 0) {
                // Show empty view if no events
                views.setViewVisibility(R.id.events_list, android.view.View.GONE)
                views.setViewVisibility(R.id.empty_view, android.view.View.VISIBLE)
            } else {
                // Show list and hide empty view
                views.setViewVisibility(R.id.events_list, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.empty_view, android.view.View.GONE)
                
                // Update up to 5 events in the widget
                val dateFormat = SimpleDateFormat("MMM d", Locale.getDefault())
                for (i in 0 until minOf(events.length(), 5)) {
                    val event = events.getJSONObject(i)
                    val date = Date(event.getLong("date"))
                    val title = event.getString("title")
                    val type = event.getString("type")
                    
                    val eventText = "${dateFormat.format(date)} - $title ($type)"
                    
                    // Add event to ListView
                    // Note: You'll need to implement a proper ListView adapter for better results
                    val textViewId = context.resources.getIdentifier(
                        "event_${i + 1}",
                        "id",
                        context.packageName
                    )
                    if (textViewId != 0) {
                        views.setTextViewText(textViewId, eventText)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("CalendarWidget", "Error updating widget", e)
            // Show error state
            views.setViewVisibility(R.id.events_list, android.view.View.GONE)
            views.setViewVisibility(R.id.empty_view, android.view.View.VISIBLE)
            views.setTextViewText(R.id.empty_view, "Error loading events")
        }
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
} 