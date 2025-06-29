# Flutter Local Notifications ProGuard Rules
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.** { *; }
-keep class androidx.core.content.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class android.app.** { *; }

# Keep generic types needed for reflection
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Specifically for the ScheduledNotificationReceiver
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Keep serializable objects
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
