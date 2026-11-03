# MapLibre GL Native Rules
-keep class org.maplibre.android.** { *; }
-dontwarn org.maplibre.android.**
-keep class com.mapbox.mapboxsdk.** { *; }
-dontwarn com.mapbox.mapboxsdk.**

# Flutter Secure Storage & Crypto Rules
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Flutter Engine & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
