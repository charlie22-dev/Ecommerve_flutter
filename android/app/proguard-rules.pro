# Firebase / Play Services use reflection for model classes.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep PayMongo webview / JS bridge callbacks if any are added later.
-keepattributes JavascriptInterface
