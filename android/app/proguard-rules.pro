# Keep OkHttp classes used by UCrop
-dontwarn okhttp3.**
-dontwarn okio.**

# flutter_local_notifications — Gson TypeToken needs generic signatures preserved
# Without this, R8 strips type info and scheduled notifications crash at runtime
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
