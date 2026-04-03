plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aegis"
    compileSdk = 35 
    
    // 1. Manually set the NDK version to satisfy the plugins
    ndkVersion = "27.0.12077973"

    compileOptions {
        // 2. Enable Core Library Desugaring
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.aegis"
        minSdk = 21 
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // 3. Enable MultiDex (important for older Android versions)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 4. Add the desugaring library here
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}