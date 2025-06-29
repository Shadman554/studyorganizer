package com.example.study_organizer

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class DailyTasksWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        android.util.Log.d("DailyTasksWidget", "onUpdate called for ${appWidgetIds.size} widgets")
        
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.daily_tasks_widget_layout)
            
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val tasksJson = widgetData.getString("daily_tasks", "[]")
                android.util.Log.d("DailyTasksWidget", "Raw tasks JSON: $tasksJson")
                
                val tasks = JSONArray(tasksJson)
                android.util.Log.d("DailyTasksWidget", "Parsed ${tasks.length()} tasks")
                
                if (tasks.length() == 0) {
                    android.util.Log.d("DailyTasksWidget", "No tasks found, showing empty view")
                    views.setViewVisibility(R.id.tasks_list, android.view.View.GONE)
                    views.setViewVisibility(R.id.empty_view, android.view.View.VISIBLE)
                } else {
                    android.util.Log.d("DailyTasksWidget", "Tasks found, showing list view")
                    views.setViewVisibility(R.id.tasks_list, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.empty_view, android.view.View.GONE)
                    
                    // Set up the remote adapter
                    val intent = Intent(context, DailyTasksRemoteViewsService::class.java).apply {
                        // Add the widget ID to the intent
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    }
                    views.setRemoteAdapter(R.id.tasks_list, intent)
                }
                
                // Force widget to update
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.tasks_list)
                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.d("DailyTasksWidget", "Widget $widgetId updated successfully")
            } catch (e: Exception) {
                android.util.Log.e("DailyTasksWidget", "Error updating widget $widgetId: ${e.message}")
                e.printStackTrace()
                
                // Show error state in widget
                views.setViewVisibility(R.id.tasks_list, android.view.View.GONE)
                views.setViewVisibility(R.id.empty_view, android.view.View.VISIBLE)
                views.setTextViewText(R.id.empty_view, "Error loading tasks")
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }
    }
} 