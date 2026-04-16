# Сохранить все классы NetworkInfo
-keep class dev.fluttercommunity.plus.network_info.** { *; }
-keep class android.net.** { *; }

# Сохранить WebSocket
-keep class java.net.** { *; }
-keep class org.java_websocket.** { *; }
-keep class com.google.gson.** { *; }

# Сохранить всё, что связано с сокетами
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Не удалять аннотации
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Сохранить все классы вашего приложения (осторожно!)
-keep class com.example.merlen_messenger_clean.** { *; }
-keep class dev.fluttercommunity.** { *; }

# Правила для сетевых пакетов
-dontwarn org.chromium.**
-dontwarn com.google.errorprone.annotations.**

# Сохранить WebSocket соединения
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Сохранить BroadcastReceiver
-keep class * extends android.content.BroadcastReceiver { *; }

# Не оптимизировать рефлексию
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations