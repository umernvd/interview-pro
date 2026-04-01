# InterviewPro App - Production Proguard Rules
# Add project specific ProGuard rules here.

# Keep Flutter and Dart classes
-keep class io.flutter.** { *; }
-keep class androidx.** { *; }
-dontwarn io.flutter.**

# Keep Appwrite SDK classes
-keep class io.appwrite.** { *; }
-dontwarn io.appwrite.**

# Keep model classes for JSON serialization
-keep class com.interviewpro.app.models.** { *; }

# Keep Dart model classes and enums (critical for JSON deserialization)
-keep class * extends java.lang.Enum {
    public static **[] values();
    public static ** valueOf(java.lang.String);
    public java.lang.String name();
}

# Keep all Dart-generated model classes
-keep class com.example.interview_pro_app.** { *; }
-keepclassmembers class com.example.interview_pro_app.** {
    public <init>(...);
    public <methods>;
    public <fields>;
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Remove debug logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Optimize and obfuscate
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose

# Keep line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile