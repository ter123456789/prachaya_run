# Prachaya Run

แอปบันทึกการวิ่ง / ปั่น / เดินป่า สไตล์ Strava เขียนด้วย Flutter
(รายละเอียดสถาปัตยกรรมและกติกาโค้ดอยู่ใน [CLAUDE.md](CLAUDE.md))

## เตรียมเครื่อง

- Flutter 3.38+ (`flutter doctor` ต้องผ่านทั้ง Android toolchain และ Xcode)
- Android: Android SDK + JDK 17 (มากับ Android Studio)
- iOS: macOS + Xcode, CocoaPods (`sudo gem install cocoapods` หรือ `brew install cocoapods`)
  และบัญชี Apple Developer ที่อยู่ในทีม `GHQ3V3PZ5P` (ตั้งไว้ใน Xcode project)
- พื้นที่ดิสก์ว่างอย่างน้อย ~10 GB (build iOS + Android กินที่เยอะ)

```bash
flutter pub get
cd ios && pod install && cd ..
```

## ค่าที่ต้องส่งตอน build (`--dart-define`)

| ตัวแปร | ใช้ทำอะไร | ค่าเริ่มต้น |
| --- | --- | --- |
| `API_BASE_URL` | URL ของ backend (`rinning_API`) | `http://localhost:3000` |
| `GOOGLE_CLIENT_ID` | Google Sign-In บน iOS (ไม่ใส่ = ไม่มีปุ่ม Google) | – |
| `GOOGLE_SERVER_CLIENT_ID` | Google Sign-In บน Android (web client id) | – |

> **สำคัญ:** build release ต้องใส่ `API_BASE_URL` เป็น **https** เสมอ — ค่าเริ่มต้น `localhost`
> ใช้ได้แค่ตอน dev และ release ไม่อนุญาต cleartext (http) บน Android

สะดวกกว่าถ้าเก็บค่าไว้ในไฟล์ `dart_defines.prod.json` ที่ root ของโปรเจกต์ แล้วใช้
`--dart-define-from-file` (อย่า commit ถ้ามีค่าลับ):

```json
{
  "API_BASE_URL": "https://<your-api-domain>"
}
```

## เลขเวอร์ชัน

เวอร์ชันมาจาก `version:` ใน `pubspec.yaml` (`1.0.0+1` = versionName `1.0.0`, build number `1`)
ทุกครั้งที่จะส่งขึ้น store ต้องเพิ่มเลขหลัง `+` หรือส่งทับตอน build:

```bash
--build-name=1.0.1 --build-number=2
```

## Build APK (Android)

```bash
flutter build apk --release --dart-define-from-file=dart_defines.prod.json
```

ไฟล์ที่ได้: `build/app/outputs/flutter-apk/app-release.apk` — ส่งไฟล์นี้ไปติดตั้งบนเครื่องได้เลย
(ต้องเปิด "ติดตั้งแอปจากแหล่งที่ไม่รู้จัก") หรือติดตั้งผ่านสายด้วย `flutter install` / `adb install`

ตัวเลือกที่ใช้บ่อย:

- `--split-per-abi` — แยก APK ตามสถาปัตยกรรม CPU (`app-arm64-v8a-release.apk` ฯลฯ) ไฟล์เล็กลงมาก
- ส่งขึ้น Google Play ใช้ App Bundle แทน:
  `flutter build appbundle --release --dart-define-from-file=dart_defines.prod.json`
  → `build/app/outputs/bundle/release/app-release.aab`

> **ตอนนี้ release ยัง sign ด้วย debug key** (`android/app/build.gradle.kts`) จึงติดตั้งทดสอบได้
> แต่ส่งขึ้น Google Play ไม่ได้ และอัปเดตทับจากเครื่อง build อื่นไม่ได้ ก่อนขึ้น store ต้อง
> สร้าง upload keystore แล้วตั้ง `signingConfigs.release` ตาม
> [คู่มือ Flutter](https://docs.flutter.dev/deployment/android#sign-the-app)
> (`key.properties`, `*.jks` ถูก ignore ไว้แล้ว — ห้าม commit)
> และต้องเปลี่ยน `applicationId` จาก `com.example.prachaya_run` เพราะ Play ไม่รับ `com.example`

## Build IPA (iOS)

```bash
flutter build ipa --release --dart-define-from-file=dart_defines.prod.json
```

ไฟล์ที่ได้:

- `build/ios/ipa/*.ipa` — ไฟล์สำหรับอัปโหลด
- `build/ios/archive/Runner.xcarchive` — เปิดใน Xcode (Window → Organizer) เพื่อ Distribute ได้

ค่าเริ่มต้น export แบบ App Store (`--export-method app-store`) เลือกแบบอื่นได้:

| `--export-method` | ใช้เมื่อ |
| --- | --- |
| `app-store` | อัปโหลดขึ้น App Store Connect / TestFlight |
| `ad-hoc` | แจกติดตั้งตรงบนเครื่องที่ลงทะเบียน UDID ไว้ใน provisioning profile |
| `development` | ติดตั้งบนเครื่อง dev ของทีม |

อัปโหลดขึ้น TestFlight: ลากไฟล์ `.ipa` ใส่แอป **Transporter** หรือ

```bash
xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

หมายเหตุ iOS:

- Signing เป็นแบบ Automatic (ทีม `GHQ3V3PZ5P`) ต้อง login บัญชี Apple ใน Xcode → Settings → Accounts
  ก่อน ถ้า build ไม่ผ่านเรื่อง signing ให้เปิด `ios/Runner.xcworkspace` แล้วเช็ก Signing & Capabilities
  ของทั้ง target `Runner` และ `RecordingWidget` (Live Activity)
- Bundle id ยังเป็น `com.example.prachayaRun` (+ `.RecordingWidget`) ต้องเปลี่ยนเป็นของตัวเอง
  ก่อนส่ง App Store — เปลี่ยนให้ตรงกันทั้งสอง target
- Sign in with Apple ยังปิดอยู่ (ไม่ได้ตั้ง `CODE_SIGN_ENTITLEMENTS`) ดูวิธีเปิดใน CLAUDE.md

## ถ้า build พัง

```bash
flutter clean && flutter pub get
cd ios && pod install && cd ..
rm -rf ~/Library/Developer/Xcode/DerivedData   # ล้าง cache ของ Xcode (คืนพื้นที่ดิสก์ด้วย)
```

## พัฒนา / ทดสอบ

```bash
flutter analyze   # ต้องไม่มี warning
flutter test
```

E2E บน simulator กับ backend จริง ดูหัวข้อ Commands ใน [CLAUDE.md](CLAUDE.md)
