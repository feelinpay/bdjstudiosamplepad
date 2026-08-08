# Flutter plugins are registered through generated code. Keep native bridge names.
-keep class io.flutter.plugins.** { *; }
-keep class com.bdjstudio.samplepadpro.** { *; }

# Isar (base de datos) - evita que R8 elimine su inicializacion nativa/startup.
-keep class dev.isar.** { *; }
-keep class androidx.startup.** { *; }

# flutter_secure_storage / device_info - usan bridges nativos.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# SoLoud (audio nativo) - preserva nombres del puente JNI.
-keep class xyz.luan.** { *; }
-keepattributes *Annotation*
-dontwarn dev.isar.**
