# ตั้งค่า Android / iOS หลังรัน `flutter create`

## Android — `android/app/src/main/AndroidManifest.xml`

วางไว้ใน `<manifest>` ก่อน `<application>`:

```xml
<!-- BLE scan (Android 12+) — ไม่ใส่ neverForLocation เพราะเราใช้สัญญาณหาตำแหน่ง -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<!-- Android 11 ลงไป -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<!-- สแกนต่อตอนปิดจอระหว่างเกิดเหตุ -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

ถ้าเซิร์ฟเวอร์ใช้ `http://` (ไม่ใช่ https) ระหว่างทดลอง ให้เพิ่มใน `<application>`:
`android:usesCleartextTraffic="true"`

`android/app/build.gradle` → `minSdkVersion 21` ขึ้นไป

## iOS — `ios/Runner/Info.plist`

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>SafeAlert ใช้บลูทูธหาตำแหน่งของคุณในอาคาร เพื่อนำทางไปทางออกที่ปลอดภัย</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>ใช้ระบุว่าคุณอยู่โซนไหนของอาคารเมื่อเกิดเหตุ</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>ใช้ปลุกแอปเมื่อคุณเข้าอาคาร และนำทางเมื่อเกิดเหตุ</string>
<key>UIBackgroundModes</key>
<array><string>bluetooth-central</string><string>location</string></array>
```

**ข้อจำกัด iOS:** iOS ไม่ให้ CoreBluetooth อ่านข้อมูล iBeacon ได้ ตัว `BlePlusBeaconScanner` จึงใช้ได้แค่บน Android
บน iOS ต้องเขียนคลาสใหม่ที่ implement `BeaconScanner` แล้วใช้ CoreLocation ranging ตาม UUID ของโปรเจกต์
(เช่น ปลั๊กอินตระกูล `flutter_beacon` หรือเขียน platform channel เอง) แล้วส่งออกมาเป็น `ScanWindow` แบบเดียวกัน
ส่วนอื่นของแอปไม่ต้องแก้
