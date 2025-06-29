package com.example.study_organizer

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class StudyWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.study_widget_layout)
                val widgetData = HomeWidgetPlugin.getData(context)
                
                // Get progress values
                val theoryPercentage = widgetData.getInt("theory_percentage", 0)
                val practicalPercentage = widgetData.getInt("practical_percentage", 0)
                val totalProgress = widgetData.getInt("total_progress", 0)

                android.util.Log.d("StudyWidgetProvider", 
                    "Theory: $theoryPercentage%, Practical: $practicalPercentage%, Total: $totalProgress%")

                // Update text views
                views.setTextViewText(R.id.theory_percentage, "$theoryPercentage%")
                views.setTextViewText(R.id.practical_percentage, "$practicalPercentage%")
                views.setTextViewText(R.id.total_percentage, "$totalProgress%")

                // Update progress bars
                views.setProgressBar(R.id.theory_progress, 100, theoryPercentage, false)
                views.setProgressBar(R.id.practical_progress, 100, practicalPercentage, false)
                views.setProgressBar(R.id.total_progress, 100, totalProgress, false)

                // Update the widget
                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.d("StudyWidgetProvider", "Widget updated successfully")

            } catch (e: Exception) {
                android.util.Log.e("StudyWidgetProvider", "Error updating widget: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        android.util.Log.d("StudyWidgetProvider", "Widget enabled")
        
        try {
            val views = RemoteViews(context.packageName, R.layout.study_widget_layout)
            
            // Initialize with default values
            views.setTextViewText(R.id.theory_percentage, "0%")
            views.setTextViewText(R.id.practical_percentage, "0%")
            views.setTextViewText(R.id.total_percentage, "0%")

            // Initialize progress bars
            views.setProgressBar(R.id.theory_progress, 100, 0, false)
            views.setProgressBar(R.id.practical_progress, 100, 0, false)
            views.setProgressBar(R.id.total_progress, 100, 0, false)

            // Get widget manager and update
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, StudyWidgetProvider::class.java)
            appWidgetManager.updateAppWidget(componentName, views)
            
        } catch (e: Exception) {
            android.util.Log.e("StudyWidgetProvider", "Error in onEnabled: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        android.util.Log.d("StudyWidgetProvider", "Widget disabled")
    }
} 