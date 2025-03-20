## Overview

This package simulates a Rider's experience of navigating nearby stores and customers within a 10 km radius. It randomly generates stores and customers based on the Rider's current location and allows the Rider to mock order assignments to customers from stores within this range. 

This package is ideal for testing or demonstrating applications related to delivery, logistics, or any scenario where a Rider needs to navigate between multiple locations.

Google Maps is integrated to provide route drawing, navigation, and real-time location updates for a seamless experience.



## Key Use Cases:

- **Delivery Apps:** For Riders who need to navigate between stores and customers.
- **Logistics Management:** When managing orders and deliveries from stores to customers.
- **Fleet Management:** For optimizing routing and order assignment for drivers or riders.


## Features

### 🚀 Store & Customer Generation
- Randomly generates stores and customers within a 10 km radius from the Rider’s current location.
- Provides mock data for stores and customers, including names, locations, and sample orders.

### 📦 Order Assignment (Mocking)
- Allows Riders to simulate order assignments from nearby stores to customers.
- Generates mock orders with item names and quantities, which can be modified for testing purposes.

### 🗺️ Navigation
- Uses Google Maps to navigate from the Rider’s location to selected stores and customers.
- Displays routes using custom polylines on the map.

### 🔄 Random Data Simulation
- Automatically generates customer and store data for quick testing and demos.
- Simulates different Rider locations and order conditions.

### 🎯 Custom Markers
- Uses custom marker icons:
  - Stores: `restaurant.png`
  - Customers: `here.png`
  - Riders: `driver.png`
- Markers are dynamically generated based on simulated data and can be customized.


## Getting Started

To get started, ensure you have Flutter and Dart installed on your system. Follow these steps:

1. **Add this package to your `pubspec.yaml` file:**
   ```yaml
   dependencies:
     flutter_rider_locator: ^1.0.0
    ```

2. **Run the following command to install dependencies:**
    ```
    flutter pub get
    ```
    
3. **Import the package in your Dart file:**
    ```
    import 'package:flutter_rider_locator/flutter_rider_locator.dart';
    ```
    
4. **Set up your Google Maps API Key (Required for map functionality)**
    - Follow the official guide to obtain an API key: [Google Maps API Documentation](https://developers.google.com/maps/documentation/javascript/get-api-key)
    - Add the key to your `AndroidManifest.xml` and `AppDelegate.swift` as per the Flutter Google Maps setup guide.

## Example
1. In `main.dart` file :
    ```dart
    void main() {
        runApp(MyApp());
    }

    class MyApp extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        return MaterialApp(
            home: StoreFinder(),  // Use StoreFinder from the package
            );
        }
    }
    ```

2. In `AndroidManifest.xml` file (from: `android\app\src\main\AndroidManifest.xml`) :

    * Add this code in the `AndroidManifest.xml`:
        ```xml
        <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_GOOGLE_MAPS_API_KEY"/> 
        ```

    * Also, add this code:
        ```xml
        <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
        <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
        <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
        ```

    * Example of a complete `AndroidManifest.xml`:
        ```xml
        <manifest xmlns:android="http://schemas.android.com/apk/res/android">
            <application android:label="flutter_rider_locator_test" android:name="${applicationName}" android:icon="@mipmap/ic_launcher">

                <!-- this line -->
                <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
                <!-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ -->

                <activity android:name=".MainActivity" android:exported="true" android:launchMode="singleTop" android:taskAffinity="" android:theme="@style/LaunchTheme" android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode" android:hardwareAccelerated="true" android:windowSoftInputMode="adjustResize">
                <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />
                        <intent-filter>
                            <action android:name="android.intent.action.MAIN"/>
                            <category android:name="android.intent.category.LAUNCHER"/>
                        </intent-filter>
                    </activity>
                <meta-data android:name="flutterEmbedding" android:value="2" />
            </application>

            <!-- add this line too! -->
            <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
            <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
            <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
            <!-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ -->

            <queries>
                <intent>
                    <action android:name="android.intent.action.PROCESS_TEXT"/>
                    <data android:mimeType="text/plain"/>
                </intent>
            </queries>
        </manifest>
        ```

3. In `MainActivity.kt` file:
    ```kt
    package com.example.flutter_rider_locator_test

    import io.flutter.embedding.android.FlutterActivity
    import io.flutter.plugin.common.MethodChannel
    import android.os.Bundle
    import android.content.pm.PackageManager
    import android.util.Log

    class MainActivity: FlutterActivity() {
        private val CHANNEL = "com.example.geo/navigation"

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,CHANNEL
                ).setMethodCallHandler { call, result ->
                if (call.method == "getApiKey") {
                    try {
                        val appInfo = packageManager.getApplicationInfo(
                            packageName, PackageManager.GET_META_DATA
                        )
                        val apiKey = appInfo.metaData.getString(
                            "com.google.android.geo.API_KEY"
                        )
                        result.success(apiKey)
                    } catch (e: PackageManager.NameNotFoundException) {
                        Log.e("MainActivity", "Error retrieving API key", e)
                        result.error("UNAVAILABLE", "API Key not found", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        }
    }
    ```

4. In `pubspec.yaml` file :
    ```yaml
    dependencies:
        flutter:
            sdk: flutter

        flutter_lints: ^5.0.0
        google_maps_flutter: ^2.0.6
        google_maps_flutter_web: any
        geolocator: ^10.1.0
        google_directions_api: ^0.10.0
        http: ^1.1.0
        flutter_polyline_points: any
        location: any
        cupertino_icons: ^1.0.8
        flutter_rider_locator: 1.0.0

    dependency_overrides:
        google_maps_flutter_web: ^0.5.4


    flutter:
        uses-material-design: true

        assets:
            - assets/images/

    ```


## Important Step: Add Image Assets

Please make sure to create a folder named `assets/images/..` in your project directory. Inside this folder, add the following three image files with the exact names:

1. **`driver.png`** (Icon for Rider)
2. **`here.png`** (Icon for Customer)
3. **`restaurant.png`** (Icon for Store)

This is essential for properly displaying custom markers on the map. 
<br/>

## 💗 Thank You!

for using Flutter Rider Locator! We hope this package helps with your testing and demos.

- Please note that the order assignment feature is mocked for simulation purposes and does not involve real order processing.

- Currently, the package is available in a pre-configured version that cannot be customized. However, a customizable version is in development. Please stay tuned!

- If you search for `flutter_rider_locator_custom` and find it, that means the custom version has been completed.

🚀 Stay tuned for future updates and customization options! ✨