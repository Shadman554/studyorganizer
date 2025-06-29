package com.example.study_organizer

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class DailyTasksRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return DailyTasksRemoteViewsFactory(this.applicationContext)
    }
}

class DailyTasksRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var tasks = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val tasksJson = widgetData.getString("daily_tasks", "[]")
            android.util.Log.d("DailyTasksWidget", "Raw tasks JSON: $tasksJson")
            tasks = JSONArray(tasksJson)
            android.util.Log.d("DailyTasksWidget", "Parsed ${tasks.length()} tasks")
        } catch (e: Exception) {
            android.util.Log.e("DailyTasksWidget", "Error in onDataSetChanged: ${e.message}")
            e.printStackTrace()
            tasks = JSONArray()
        }
    }

    override fun onDestroy() {
        tasks = JSONArray()
    }

    override fun getCount(): Int = tasks.length()

    override fun getViewAt(position: Int): RemoteViews {
        return try {
            if (position >= tasks.length()) {
                return RemoteViews(context.packageName, R.layout.daily_task_item)
            }

            val task = tasks.getJSONObject(position)
            android.util.Log.d("DailyTasksWidget", "Creating view for task: $task")
            
            RemoteViews(context.packageName, R.layout.daily_task_item).apply {
                setTextViewText(R.id.task_name, task.getString("name"))
                setTextViewText(R.id.task_info, 
                    "${task.getString("type")} - ${task.getString("subject")}")
            }
        } catch (e: Exception) {
            android.util.Log.e("DailyTasksWidget", "Error creating view at position $position: ${e.message}")
            e.printStackTrace()
            RemoteViews(context.packageName, R.layout.daily_task_item)
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
} 