# Vosk loads its native library through JNA, which finds Java classes and
# fields by name from native code. R8 renames or strips them in release
# builds, which crashes the app at startup ("Can't obtain peer field ID for
# class com.sun.jna.Pointer"). Keep both libraries intact.
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.** { public *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.**
-dontwarn com.sun.jna.**
