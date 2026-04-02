plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.interview_pro_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Original application ID
        applicationId = "com.example.interview_pro_app"
        
        // Optimized SDK versions for production
        minSdk = flutter.minSdkVersion  // Android 5.0 (API level 21) for broader compatibility
        targetSdk = 34  // Latest stable Android API
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // App metadata for production
        resValue("string", "app_name", "InterviewPro")
        
        // Performance optimizations
        multiDexEnabled = true
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
        }
        
        release {
            // Production release configuration
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            
            // Code obfuscation and optimization
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            
            // Configure proper signing for production release
            // Uses keystore from gradle.properties (INTERVIEW_PRO_KEYSTORE_PATH, INTERVIEW_PRO_KEYSTORE_PASSWORD, etc.)
            // For development: uses debug keys. For production: configure gradle.properties with real keystore
            signingConfig = if (project.hasProperty("INTERVIEW_PRO_KEYSTORE_PATH")) {
                signingConfigs.create("release") {
                    storeFile = file(project.property("INTERVIEW_PRO_KEYSTORE_PATH") as String)
                    storePassword = project.property("INTERVIEW_PRO_KEYSTORE_PASSWORD") as String
                    keyAlias = project.property("INTERVIEW_PRO_KEY_ALIAS") as String
                    keyPassword = project.property("INTERVIEW_PRO_KEY_PASSWORD") as String
                }
                signingConfigs.getByName("release")
            } else {
                // Fallback to debug signing for development builds
                signingConfigs.getByName("debug")
            }
        }
    }

    // Force downgrade transitive dependencies that require newer AGP
    configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.core:core-ktx:1.13.1")
            force("androidx.core:core:1.13.1")
        }
    }
    
    // Build optimization
    buildFeatures {
        buildConfig = true
    }
    
    // Packaging options for production
    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
    
    // Lint options for production quality
    lint {
        checkReleaseBuilds = true
        abortOnError = false
        warningsAsErrors = false
    }
}

flutter {
    source = "../.."
}
