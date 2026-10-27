# อัตราการเต้นหัวใจ (HR) จากเซนเซอร์ BLE และนาฬิกา

สถานะ: **เฟส 1 ทำแล้ว 2026-10-27** (แอป + API v1.5) — เฟส 2 ย้ายไป [health-import.md](health-import.md)

### ต่างจากสเปกเดิมตอนลงมือ
- **ไม่ใช้ flutter_blue_plus** (ไลเซนส์เฉพาะ: ใช้เชิงพาณิชย์ต้องซื้อ) → เขียน native เอง
  ตามแนว wfm-mobile: `HeartRateBridge.swift` (CoreBluetooth) / `HeartRateBridge.kt` (BluetoothGatt)
  ผ่าน MethodChannel + EventChannel; native ส่ง byte ดิบ, Dart ถอดรหัส
- API เป็น **v1.5** (v1.4 เป็น planned routes ไปแล้ว) และ **ไม่มี avgHr/maxHr ใน summary**
  (ยังไม่มีหน้ารายการที่ใช้) — heartRate อยู่เฉพาะ full activity
- DB v6 เก็บเป็น JSON ในคอลัมน์ `activities.heart_rate` (`[[t, bpm], ...]`)
- ยังไม่ทำ: HR ใน Live Activity / Android notification, voice cue, สถิติ share image, แคลอรี่จาก HR
งานต่อยอด: [watch-standalone.md](watch-standalone.md) (แอป Wear OS) ใช้โมเดล HR ชุดนี้

## เป้าหมาย
- แสดง HR สดบนหน้าบันทึก พร้อมโซน
- เก็บ HR ไว้กับกิจกรรม แล้วสรุปบนหน้ารายละเอียด: ค่าเฉลี่ย, สูงสุด, เวลาในแต่ละโซน, กราฟ
- ซิงก์ HR ขึ้นเซิร์ฟเวอร์

เมื่อ ship แล้วต้องแก้กฎ "Not in the app on purpose: heart rate" ใน CLAUDE.md

## Strava ทำอย่างไร (ข้อมูลอ้างอิง)

| ทาง | HR สด | อุปกรณ์ | สำหรับเรา |
|---|---|---|---|
| เซนเซอร์ BLE จับคู่กับแอปมือถือตรง ๆ | ✅ | สายคาดอก + นาฬิกาที่เปิดโหมด broadcast | **เฟส 1** |
| แอปของตัวเองบนนาฬิกา (watchOS / Wear OS) | ✅ | Apple Watch, Galaxy/Pixel Watch | Wear OS → watch-standalone.md; watchOS ไม่ทำ |
| ซิงก์คลาวด์ของแบรนด์ (Garmin Connect → Strava) | ❌ ได้ไฟล์ FIT หลังจบ | Garmin, Coros, Polar, Suunto | **ทำไม่ได้** (ดูด้านล่าง) |
| นำเข้าจาก Apple Health / Health Connect | ❌ หลังจบ | ทุกอย่างที่เขียนลง Health | **เฟส 2** |

- Strava รองรับ **BLE เท่านั้น ไม่รองรับ ANT+** — เราทำเหมือนกัน (มือถือส่วนใหญ่ไม่มี ANT+)
- เซนเซอร์หนึ่งตัวต่อได้ทีละแอป: ต้องตัดจาก Garmin Connect / Wahoo / แอปของนาฬิกาก่อน
- iPhone ไม่มี HR สดในตัว ต้องมาจาก Apple Watch หรือเซนเซอร์ภายนอก
  การ mirror `HKWorkoutSession` (iOS 17+) ยังต้องมีแอป watchOS ของเราอยู่ดี → ไม่ทำ
- Apple Watch ไม่ broadcast HR เป็น BLE มาตรฐานเอง → ใช้เฟส 1 ไม่ได้ ต้องใช้เฟส 2
- **Garmin Connect Developer Program หยุดรับคำขอใหม่** ตั้งแต่ราวมี.ค.–เม.ย. 2026 (ยังไม่เปิด ณ ก.ย. 2026)
  และว่ากันว่าต้องสมัครในนามนิติบุคคล → ตัดทางนี้ทิ้ง ผู้ใช้ Garmin ใช้ Broadcast HR แทน

## เฟส 1: เซนเซอร์ BLE (สายคาดอก + นาฬิกาที่ broadcast ได้)

### อุปกรณ์ที่ใช้ได้
| อุปกรณ์ | เมนูบนเครื่อง | ข้อสังเกต |
|---|---|---|
| สายคาดอก / สายรัดแขน (Polar H9/H10/Verity, Garmin HRM, Wahoo, Coros) | — | ทำงานทันที |
| Garmin (รวม vívosmart ที่ไม่มี GPS) | Broadcast Heart Rate | ตั้งให้ broadcast อัตโนมัติตอนเริ่มกิจกรรมได้, กินแบต |
| Huawei Band 8/9/10 และบางรุ่น Watch | HR Data Broadcasts | รุ่นต่อได้ทีละเครื่องจะหลุดจาก Huawei Health; WATCH 5 ใช้ได้เฉพาะโหมดประหยัดแบต |
| Amazfit (Zepp OS 3.0+) | Heart Rate Push | บางรุ่นส่งเฉพาะตอนเริ่ม workout บนนาฬิกา |
| Xiaomi Mi Band (เช่น 6) | HR broadcast | Runkeeper / Wahoo เจอ แต่ Zwift บางครั้งไม่เจอ |
| Fitbit, Apple Watch, นาฬิกาจีนราคาถูก | ไม่มี | → เฟส 2 |

นาฬิกาที่ไม่มี GPS ใช้ได้ปกติ: มือถือจับ GPS เอง นาฬิกาแค่ส่ง HR

### โปรโตคอล (Bluetooth SIG Heart Rate Service)
- Service `0x180D`, characteristic Heart Rate Measurement `0x2A37` — **notify อย่างเดียว** (subscribe, อ่านตรงไม่ได้)
- byte 0 = flags
  - bit 0: `0` = HR เป็น uint8 (byte 1), `1` = uint16 little-endian (byte 1–2) — **ต้องเช็คทุกครั้ง**
  - bit 1–2: sensor contact (`0b11` = แนบผิว, `0b10` = ไม่แนบ, `0b0x` = ไม่รองรับ) → สถานะ "สายหลุด"
  - bit 3: มี Energy Expended (uint16) ตามมา — ข้าม
  - bit 4: มี RR-interval (uint16 หน่วย 1/1024 วินาที, ได้หลายค่า) — เก็บไว้ใช้ทีหลัง (HRV) ได้ ไม่บังคับ
- UUID: iOS คืนแบบสั้น (`2A37`), Android คืนแบบ 128-bit (`00002a37-0000-1000-8000-00805f9b34fb`)
  → เทียบด้วย helper ที่รับได้ทั้งสองแบบ
- Parser เป็น pure Dart (`List<int>` → `HeartRateReading`) อยู่ใน domain ได้ และ test ด้วย byte ตัวอย่างทั้ง uint8 / uint16 / มี RR

### การสแกนและจับคู่
- **อย่ากรองด้วย service UUID ใน advertisement อย่างเดียว** — สายรัดข้อมือบางรุ่นอาจไม่ประกาศ `0x180D`
  แต่มีหลังเชื่อมต่อ (อนุมานจากกรณี Mi Band ↔ Zwift ยังไม่ยืนยัน)
  - แสดงอุปกรณ์ที่ประกาศ `0x180D` ก่อน, ที่เหลือที่มีชื่อแสดงในกลุ่ม "อุปกรณ์อื่น"
  - เชื่อมต่อแล้ว discover services: ไม่มี `0x180D` → แจ้ง "อุปกรณ์นี้ไม่ได้ส่งค่าชีพจร"
- จำอุปกรณ์ล่าสุด (remote id + ชื่อ) ใน `kv` เป็น device setting → ต่ออัตโนมัติเมื่อเปิดหน้าบันทึก
- คำแนะนำในชีต (ภาษาไทย): "เปิดโหมดส่งค่าชีพจรบนนาฬิกา" และ "ปิดการเชื่อมต่อกับแอปของนาฬิกาก่อน"
- iOS remote id ไม่ใช่ MAC และเปลี่ยนได้หลังรีเซ็ต — เก็บชื่อไว้ใช้ match สำรอง

### ระหว่างบันทึก
- ต่อใหม่อัตโนมัติเมื่อหลุด (backoff สั้น ๆ) ไม่หยุดการบันทึก GPS
- สถานะบนหน้าบันทึก: กำลังรับ / ไม่แนบผิว / หลุด (ไม่มีค่าเกิน ~5 วินาที แสดง `--`)
- ช่วงหยุดชั่วคราว: ยังรับ HR ได้แต่ **ไม่นับ** ในสรุป (เหมือน moving time)
- เก็บตัวอย่างไม่เกิน 1 ค่า/วินาที (เซนเซอร์ส่งราว 1 Hz อยู่แล้ว ถ้าถี่กว่าให้เก็บค่าล่าสุดของวินาทีนั้น)
- Live Activity / Android notification: เพิ่ม HR ใน `RecordState` mirror ได้ แต่ไม่บังคับในเฟส 1
- Voice cue รายกม.: เพิ่ม "ชีพจรเฉลี่ย …" เป็นตัวเลือกได้ทีหลัง

### สิทธิ์และการตั้งค่าแพลตฟอร์ม (ยังไม่ได้ยืนยันกับเอกสารล่าสุด — ต้องเช็คตอนลงมือ)
- iOS Info.plist: `NSBluetoothAlwaysUsageDescription` (ข้อความไทย),
  `UIBackgroundModes` เพิ่ม `bluetooth-central` (มี `location`, `audio` อยู่แล้ว) — จำเป็นเพราะบันทึกต่อตอนล็อกจอ
- Android 12+: `BLUETOOTH_SCAN` (`android:usesPermissionFlags="neverForLocation"`) + `BLUETOOTH_CONNECT`;
  ต่ำกว่า 12: `BLUETOOTH`, `BLUETOOTH_ADMIN` (`maxSdkVersion="30"`) + location (มีอยู่แล้ว)
- foreground service ของการบันทึกมีอยู่แล้ว — เช็คว่าต้องเพิ่ม `connectedDevice` ใน foregroundServiceType หรือไม่

### ปลั๊กอิน
- `flutter_blue_plus` (2.3.x ณ ต.ค. 2026 — เช็คเวอร์ชันล่าสุดและ license บน pub.dev ก่อนเพิ่ม)
- ห่อไว้ใน `data/` เท่านั้น และเพิ่ม `package:flutter_blue_plus` ใน banned list ของ `test/architecture_test.dart`

## โมเดลข้อมูล (ใช้ร่วมทุกเฟส + แอปนาฬิกา)

### Domain (pure Dart)
- `HeartRateSample { DateTime timestamp; int bpm; }` — **ซีรีส์แยกจาก GPS** ไม่ใช่ field ของ `TrackPoint`
  (HR กับ GPS มาคนละจังหวะ, เฟส 2 เติม HR ทีหลังได้โดยไม่แตะ track)
- `HeartRateSource` enum: `ble`, `health`, `watch` — เก็บว่าได้มาจากไหน (เฟส 2 ห้ามทับ BLE)
- `Activity` เพิ่ม `heartRate` (list ว่าง = ไม่มี) + `heartRateSource`
- Port: `HeartRateMonitor` (scan → `Stream<List<HrDevice>>`, connect, `Stream<HeartRateReading>`, `Stream<HrConnectionState>`, disconnect)
- `heart_rate_summary.dart` (service): avg / max / เวลาในแต่ละโซน จาก samples + ช่วงหยุด
  ใช้ `heartRateZones(maxHr)` และ `resolveMaxHr` เดิมใน `features/athlete/domain/services/heart_rate_zones.dart`
  - เวลาในโซน: ให้แต่ละ sample ถือช่วงเวลาถึง sample ถัดไป แต่ไม่เกิน 5 วินาที (กันช่องว่างตอนหลุด)
- Cross-feature: activity → athlete domain (zones) ต้องเช็คกับกฎ "same layer or inward" ใน architecture_test
  ถ้าไม่ผ่าน ให้ส่ง `MaxHr` เข้ามาเป็น typedef ผ่าน `app.dart` เหมือน `DefaultShoe`

### DB v6
- ตาราง `activity_heart_rate (activity_id, t_ms, bpm)` หรือเก็บเป็น blob/JSON ต่อกิจกรรม
  (กิจกรรม 1 ชม. ≈ 3,600 แถว — blob ง่ายและเร็วกว่า; เลือกตอนลงมือ)
- `activities.hr_source`, `activities.avg_hr`, `activities.max_hr` (ไว้แสดงในรายการโดยไม่ต้องโหลดซีรีส์)
- mapping อยู่ใน `activity_row_mapper.dart` ตามกฎเดิม
- migration test บน `sqflite_common_ffi` เหมือน v2–v5

### API (แก้ `../rinning_API/docs/api.md` ก่อน — additive, v1.4)
```json
{
  "heartRate": {
    "source": "ble | health | watch",
    "samples": [ { "t": 0, "bpm": 142 } ]
  }
}
```
- `t` = มิลลิวินาทีนับจาก `startedAt` (ประหยัดกว่า ISO8601 ต่อ sample)
- ไม่มี field = ไม่มี HR; client เก่าไม่ส่งก็ไม่เป็นไร
- Summary เพิ่ม `avgHr`, `maxHr` (nullable) — เซิร์ฟเวอร์คำนวณ, สูตรต้องตรงกันทั้งสองฝั่งเหมือน `distanceM`
- Validation: `bpm` ∈ [25, 250], `t` ≥ 0 และไม่ลดลง; ขนาดยังอยู่ใต้ 5 MB (gzip)
- ซีรีส์ HR ไปพร้อม segments (POST แทนทั้งก้อน, LWW เดิม) และดาวน์โหลดพร้อม track ตอนเปิดครั้งแรก
- mapping อยู่ใน `activity_json_mapper.dart`

## UI
- **หน้าบันทึก:** tile HR (ตัวเลข + สีโซน + PulseDot ตามจังหวะ) แทนที่ช่องเดิมหนึ่งช่องเมื่อมีเซนเซอร์
  ปุ่มเซนเซอร์ (ไอคอนหัวใจ) เปิดชีตจับคู่ — Obsidian Kinetic, ไม่ใช้สีแดง (เตือนใช้ `AppColors.negative`)
- **หน้ารายละเอียด:** BentoStat avg / max HR, แถบเวลาในโซน 1–5 (ใช้สีเดียวกับ `HeartRateZonesCard`),
  กราฟ HR ตามเวลา; ไม่มี HR → แสดงแคลอรี่ประมาณการเหมือนเดิม
- **แคลอรี่:** มี HR แล้วจะใช้สูตรจาก HR แทน MET ได้ — ทำทีหลัง ไม่อยู่ในเฟส 1
- **Share image:** ตัวเลือกสถิติเพิ่ม "ชีพจรเฉลี่ย" ได้ทีหลัง
- ห้ามแสดงค่าตัวอย่างจากดีไซน์ (กฎเดิม)

## เฟส 2: นำเข้า HR จาก Apple Health / Health Connect
**ย้ายไปรวมใน [health-import.md](health-import.md)** (นำเข้าทั้งกิจกรรม + เติม HR ย้อนหลัง) — ด้านล่างเก็บไว้เป็นบันทึก

สำหรับนาฬิกาที่ broadcast ไม่ได้ (Fitbit, Apple Watch, รุ่นราคาถูก)

- วิ่งด้วยแอปเรา (GPS จากมือถือ) + นาฬิกาวัด HR อยู่ → แอปนาฬิกาซิงก์เข้า Health →
  แอปเราอ่าน HR ในช่วง `startedAt`–`endedAt` แล้วเก็บเป็น `HeartRateSample` (`source = health`)
- iOS: HealthKit `HKQuantityTypeIdentifier.heartRate`; Android: Health Connect `HeartRateRecord`
- ปลั๊กอิน: `health` (pub.dev) หรือเขียน channel เอง — อยู่ใน `data/` และเพิ่มใน banned list
- **ข้อจำกัด:**
  - ไม่ได้เริ่ม workout บนนาฬิกา → HR มักห่างหลายนาที ใช้ทำโซนไม่ได้
    → ถ้าห่างเฉลี่ยเกิน ~30 วินาที แสดงแค่ avg/max ไม่แสดงโซน และบอกผู้ใช้ให้เริ่ม workout บนนาฬิกาด้วย
  - ซิงก์ช้าได้ถึงหลายชั่วโมง → ปุ่ม "ดึงชีพจรจาก Health" บนหน้ารายละเอียด
    + ลองดึงอัตโนมัติเมื่อเปิดแอปสำหรับกิจกรรมที่ยังไม่มี HR (ภายใน ~48 ชม.)
  - แหล่งหนึ่งบอกว่า Mi Fitness / Zepp เขียนเฉพาะ avg HR ของกิจกรรม GPS — ต้องทดสอบกับเครื่องจริง
- ไม่ทับ HR ที่มาจาก BLE

## ไม่ทำ
- ANT+, Garmin Connect API (ปิดรับ), แอป watchOS, ซิงก์จาก Huawei Health / Zepp cloud โดยตรง
- เซนเซอร์อื่น (power, cadence, footpod) — ทำทีหลังบน `HeartRateMonitor` แบบเดียวกันได้

## ทดสอบ
- Unit: parser (uint8/uint16/contact/RR/ข้อมูลสั้นผิดรูป), summary (โซน, ช่วงหยุด, ช่องว่างตอนหลุด)
- Bloc: RecordBloc ได้ reading → state; หลุด → `--`; หยุดชั่วคราว → ไม่นับ
- Mapper + migration v5 → v6 + sync กับ `fake_server.dart` (ส่ง / ดึง HR)
- Debug: `features/debug` เพิ่ม `SimulatedHeartRateMonitor` (HR ขึ้นตามเพซของ route จำลอง) ให้ทดสอบบน simulator ได้
  เพราะ iOS Simulator ไม่มี Bluetooth
- เครื่องจริง: สายคาดอก 1 ตัว + Garmin broadcast + Huawei/Amazfit/Mi Band อย่างน้อย 1 รุ่น, ทดสอบล็อกจอ 30 นาที

## อ้างอิง
- [Strava – Pairing Sensors with the Strava app](https://support.strava.com/hc/en-us/articles/360049550432-Pairing-Sensors-with-the-Strava-app)
- [Garmin – Broadcasting Heart Rate Data](https://www8.garmin.com/manuals/webhelp/GUID-9D99A9D4-467A-4F1A-A0EA-023184FEA3DD/EN-US/GUID-D8D363C2-0690-48D4-95E2-A3557E7D53C2.html)
- [Huawei – Heart rate broadcasts on your watch/band](https://consumer.huawei.com/en/support/content/en-us15827504/)
- [HypeRate – Amazfit Heart Rate Push](https://blog.hyperate.io/post/amazfit-heart-rate-push-live-bluetooth-heart-rate-streaming-with-zepp-os-hyperate-compatible/)
- [Zwift forum – Mi Band as HRM](https://forums.zwift.com/t/zwift-cant-find-mi-band-as-a-hrm-device/510782)
- [SimpleBLE – Heart rate monitor](https://docs.simpleble.org/recipes/heart-rate-monitor)
- [Apple Developer Forums – HKWorkoutSession mirroring](https://developer.apple.com/forums/thread/740630)
- [the5krunner – Garmin developer API access paused (2026-09)](https://the5krunner.com/2026/09/14/garmin-developer-api-access-paused/)
- [FitMesh – Xiaomi/Amazfit Health Connect](https://www.fitmesh.fit/en/blog/xiaomi-amazfit-health-connect-data-dashboard)
