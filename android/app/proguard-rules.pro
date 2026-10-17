# ─── Flutter Embedding (gerçekten gerekli minimum set) ───────────────────────
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.platform.** { *; }
-keep class io.flutter.view.FlutterMain { *; }

# ─── Flutter GeneratedPluginRegistrant (kod üretimi) ────────────────────────
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ─── Firebase Core + Firestore (reflection tabanlı serializasyon) ────────────
-keep class com.google.firebase.FirebaseApp { *; }
-keep class com.google.firebase.FirebaseOptions { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google.firebase.provider.FirebaseInitProvider { *; }
-dontwarn com.google.firebase.**

# ─── Google Play Services Auth (sadece OAuth token gerekli alanlar) ──────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**

# ─── Google Play Billing ─────────────────────────────────────────────────────
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.android.billingclient.**

# ─── Google Play In-App Update (play-core, sadece appupdate + install) ───────
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.install.** { *; }
-keep class com.google.android.play.core.ktx.** { *; }
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ─── Androidx Credentials API (Zero-Tap / Restore Credentials) ───────────────
-keep class androidx.credentials.** { *; }
-keep class androidx.credentials.provider.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn androidx.credentials.**

# ─── Hive (annotation işlemcisi, reflection) ─────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keep class ** implements com.hive.objectboxbrowser.** { *; }

# ─── Kotlin Coroutines ve Serialization ──────────────────────────────────────
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# ─── Genel R8 güvenlik ağı ───────────────────────────────────────────────────
-dontwarn com.google.android.gms.common.annotation.NoNullnessRewrite
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
