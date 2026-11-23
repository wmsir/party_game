# ProGuard / R8 keep rules for Party Game Flutter release builds
-keep class com.partygame.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class android.speech.tts.** { *; }

-keepattributes Signature,InnerClasses,EnclosingMethod,RuntimeVisibleAnnotations,*Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }

# Suppress warnings for optional Flutter deferred components / annotations / media plugins
-dontwarn com.google.android.play.core.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.checkerframework.**
-dontwarn javax.annotation.**
-dontwarn com.google.j2objc.annotations.**
-dontwarn kotlinx.**
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**
-keep class com.google.android.play.core.** { *; }
