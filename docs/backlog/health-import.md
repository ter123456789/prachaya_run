# นำเข้ากิจกรรมจากนาฬิกา ผ่าน Health Connect / Apple Health

สถานะ: **ทำแล้ว 2026-10-27** (แอป + API v1.6) — ต้องเปิด HealthKit capability ก่อนใช้บน iOS; ทดสอบกับนาฬิกาจริงยังไม่ได้ทำ
รวมเฟส 2 ของ [ble-heart-rate.md](ble-heart-rate.md) (ดึง HR ย้อนหลัง) ไว้ในงานนี้
งานคู่กัน: [watch-account-link.md](watch-account-link.md) (เชื่อมบัญชีแบรนด์ฝั่งเซิร์ฟเวอร์)

## เป้าหมาย
ผู้ใช้บันทึกกิจกรรมด้วย **แอปของนาฬิกาเอง** (Samsung Health, Garmin Connect, Apple Workout, Zepp ฯลฯ)
แล้วกิจกรรมเข้าแอปเราเองโดยไม่ต้องทำอะไร เหมือนที่ Strava รับจาก Samsung Health
— แต่ไม่ต้องเป็นพาร์ตเนอร์ของแบรนด์ เพราะอ่านจากคลังสุขภาพของเครื่อง

และ: วิ่งด้วยแอปเรา + นาฬิกาที่ส่ง HR สดไม่ได้ (Apple Watch, Fitbit) → เติม HR ย้อนหลังให้กิจกรรมนั้น

## ใครได้อะไร (ต้องทดสอบกับเครื่องจริงทุกข้อ)
| นาฬิกา / แอป | ทางเข้า | ที่รู้แล้ว |
|---|---|---|
| Galaxy Watch → Samsung Health | Health Connect | ซิงก์สองทางตั้งแต่ Samsung Health 6.22.5 (ต.ค. 2022); **เส้นทาง GPS ยังไม่ยืนยัน** |
| Apple Watch → Workout | Apple Health | มี workout + route + HR ครบ (HKWorkoutRoute) |
| Garmin Connect | Apple Health / Health Connect | ยังไม่ได้เช็คว่าเขียนอะไรบ้าง |
| Zepp / Mi Fitness | Health Connect | แหล่งหนึ่งบอกว่าเขียนแค่ระยะเวลา แคลอรี่ HR เฉลี่ย ไม่มีเส้นทาง |
| Huawei Health | — | Android: ยังไม่ชัดว่ารองรับ Health Connect; iOS: เขียนลง Apple Health ได้บางส่วน |

## สิ่งที่ผู้ใช้เห็น
- **โปรไฟล์ → การตั้งค่า:** แถว "นำเข้ากิจกรรมจากนาฬิกา" + สวิตช์ (Android: "Health Connect", iOS: "Apple Health")
  - เปิดครั้งแรก: ขอสิทธิ์ แล้วถามช่วงย้อนหลัง "30 วัน / ตั้งแต่วันนี้"
  - บรรทัดย่อย: "นำเข้าล่าสุด 07:42 · 3 กิจกรรม" + ปุ่ม "นำเข้าตอนนี้"
- **หน้าแรก:** แถบ "นำเข้ากิจกรรมใหม่จากนาฬิกา 2 รายการ" (แตะ → ประวัติ) ครั้งเดียวต่อรอบนำเข้า
- **ป้ายที่มา** บนการ์ดประวัติ / หน้ารายละเอียด: "⌚ Samsung Health" / "⌚ Apple Watch"
- กิจกรรมที่นำเข้า**เป็นกิจกรรมปกติทุกอย่าง:** หน้าแรก (สัปดาห์ / ชาเลนจ์), ประวัติ, รายละเอียด, สถิติรวม,
  ระยะรองเท้าหลัก, ติ๊กแผนซ้อม, ซิงก์ขึ้นเซิร์ฟเวอร์ / เครื่องอื่น
- **กิจกรรมที่ไม่มีเส้นทาง:** หน้ารายละเอียดไม่มีแผนที่ (แสดงการ์ดสรุปแทน), ไม่มีสปลิต,
  รูปแชร์ใช้ได้แค่แบบ statsOnly — **ตอนนี้ทั้งแอปถือว่ามี track เสมอ ต้องไล่แก้ทุกจุด**

## การทำงาน

### อ่านอะไร
- **Android (Health Connect):**
  - `ExerciseSessionRecord` (ชนิด, เริ่ม–จบ, ชื่อ, `metadata.dataOrigin` = แอปที่เขียน)
  - เส้นทาง: `ExerciseRoute` ของ session — สิทธิ์ `READ_EXERCISE_ROUTES`; เส้นทางที่แอปอื่นเขียน
    อาจต้องให้ผู้ใช้ยืนยันทีละ session (ต้องเช็คกับเอกสาร Health Connect ตอนลงมือ)
  - `HeartRateRecord`, `DistanceRecord`, `ElevationGainedRecord` ในช่วงของ session
  - อ่านเบื้องหลัง: `READ_HEALTH_DATA_IN_BACKGROUND`; ย้อนหลังเกิน 30 วันก่อนได้สิทธิ์: `READ_HEALTH_DATA_HISTORY`
  - ดึงเฉพาะที่เปลี่ยน: Changes API (changes token เก็บใน `kv`)
- **iOS (HealthKit):**
  - `HKWorkout` (activity type, เริ่ม–จบ, totalDistance, `sourceRevision` = แอปที่เขียน)
  - เส้นทาง: `HKWorkoutRoute` → `HKWorkoutRouteQuery` → `CLLocation`
  - HR: `HKQuantityType(.heartRate)` ในช่วงของ workout
  - ดึงเฉพาะที่เปลี่ยน: `HKAnchoredObjectQuery` (anchor เก็บใน `kv`); ปลุกแอปเมื่อมีของใหม่:
    `HKObserverQuery` + background delivery (entitlement `com.apple.developer.healthkit.background-delivery`)
  - ต้องเปิด capability HealthKit ให้ Runner (เช็คว่าทีมเซ็นได้ — เคยติดแบบนี้กับ Sign in with Apple)

### ชนิดกิจกรรม
running / treadmill → `run`, cycling / biking → `ride`, hiking / walking → `hike` (walking ถามก่อน:
อาจเป็นแค่เดินเล่น — ตั้งค่า "นำเข้าการเดินด้วย" ปิดไว้ก่อน), อื่น ๆ (ว่ายน้ำ, เวท, โยคะ) ไม่นำเข้า

### กันซ้ำ
1. **id คงที่:** UUID v5 จาก (`health-connect` | `healthkit`, id ของ record/workout) → นำเข้าซ้ำ = upsert id เดิม
   - iOS: เช็คว่า UUID ของ HKWorkout ตรงกันข้ามเครื่องที่ซิงก์ iCloud หรือไม่ (ถ้าไม่ตรง สองเครื่องจะนำเข้าซ้ำ → ใช้ข้อ 2 กันอีกชั้น)
2. **ทับกับกิจกรรมที่บันทึกด้วยแอปเรา** (เวลาซ้อนกัน ≥ 50 %): ไม่สร้างใหม่ — เติม HR ให้กิจกรรมเดิม
   ถ้ายังไม่มี (`source = health`), ไม่ทับ HR จาก BLE
3. **ไม่อ่านของตัวเอง:** ถ้าวันหนึ่งแอปเราเขียนลง Health ด้วย ให้กรอง `dataOrigin` / `HKSource` ของแอปเราออก
4. **ผู้ใช้ลบกิจกรรมที่นำเข้า:** ไม่นำกลับมาอีก — tombstone เดิม (`deleted_at`) ใช้ id เดียวกันอยู่แล้ว
   และเซิร์ฟเวอร์ไม่ revive กิจกรรมที่ soft-deleted

### บันทึก
- use case ใหม่ `ImportActivities` (domain, มี logic: แปลง, กันซ้ำ, รวม HR) — ใช้ hook เดียวกับ `SaveActivity`
  (รองเท้าหลัก, `CompleteWorkoutForActivity`) แต่ไม่ใช้เกณฑ์ระยะขั้นต่ำ 50 ม. กับกิจกรรมที่ไม่มีเส้นทาง
- เมื่อไร: เปิดแอป / กลับเข้าแอป / background delivery (iOS) / ปุ่ม "นำเข้าตอนนี้"
- ยังไม่ล็อกอิน: เก็บในเครื่องตามปกติ (owner_id NULL) แล้วไปตามกติกา 07.1 เดิม

### Port / โครงสร้าง (ตามกฎ Clean Architecture เดิม)
- domain: `HealthSource` port (`requestAccess`, `workoutsSince(anchor)`, `heartRate(from, to)`),
  entity `ImportedWorkout`, use case `ImportActivities`
- data: `NativeHealthSource` — แนะนำเขียน channel เอง (`prachaya/health`) แบบเดียวกับ BLE เพราะต้องใช้
  API เฉพาะแพลตฟอร์ม (route consent, anchors, background delivery); ดูปลั๊กอิน `health` (pub.dev, MIT)
  ก่อนว่ารองรับ workout + route ครบไหม ถ้าครบอาจใช้แทนได้ (ต้องเพิ่มใน banned list ของ presentation)
- presentation: `HealthImportCubit` (สวิตช์, สถานะ, จำนวนที่นำเข้า), แถวในการตั้งค่า, แถบบนหน้าแรก

## ข้อมูล / API (v1.6 — แก้ `../rinning_API/docs/api.md` ก่อน)
- **ที่มาของกิจกรรม** (ใช้ร่วมกับ watch-account-link):
  ```json
  "origin": { "kind": "phone | health | polar | garmin", "app": "Samsung Health", "device": "Galaxy Watch7" }
  ```
  ไม่มี = `phone` (กิจกรรมเดิมทั้งหมด)
- **กิจกรรมไม่มีเส้นทาง:** ตอนนี้เซิร์ฟเวอร์บังคับ `segments` ≥ 1 จุด และคำนวณ `distanceM` จาก segments เอง
  → v1.6: ยอม `segments: []` เมื่อ `origin.kind != phone` และรับ `distanceM` / `elevationGainM` จาก client
  เฉพาะกรณีนั้น (มี segments เมื่อไร เซิร์ฟเวอร์คำนวณเองเหมือนเดิม)
- แอป: `Activity` เพิ่ม `origin` + ระยะ/ความสูงที่ให้มา (ใช้เมื่อไม่มี track); DB v7: `activities.origin` (JSON),
  `distance_m` / `elevation_gain_m` มีอยู่แล้ว

## ต่างจากสเปกตอนลงมือ
- ไม่ใช้ anchor / Changes API: อ่านตามช่วงเวลา (ตั้งแต่รอบที่แล้ว − 7 วัน) แล้วกันซ้ำด้วย id คงที่ + รายการ `seen`
  ทำให้แอปขอรายละเอียด (เส้นทาง + HR) เฉพาะ workout ใหม่ และไม่ต้องจัดการ token หมดอายุ
- ไม่มี background delivery บน iOS (ต้องใช้ entitlement เพิ่ม) — นำเข้าตอนเปิด / กลับเข้าแอปแทน
- เส้นทางจาก Health Connect ที่ต้องขอ consent รายครั้ง → นำเข้าแบบไม่มีเส้นทางไปก่อน
- ID ของ Health Connect ใช้ `metadata.id`; HealthKit ใช้ `HKWorkout.uuid`

## ไม่ทำในงานนี้
- เขียนกิจกรรมของแอปเราลง Health (ทำทีหลังได้ — กรองของตัวเองไว้แล้ว)
- นำเข้าไฟล์ .fit / .gpx ด้วยมือ (ทางสำรองที่ครบที่สุด — ทำแยกได้)
- ชนิดกิจกรรมนอก run / ride / hike

## ทดสอบ
- Unit: แปลงชนิด, id คงที่, กฎทับเวลา 50 %, เติม HR, ไม่มีเส้นทาง → ระยะจาก Health
- Fake `HealthSource` ใน `test/helpers/fakes.dart`; sync test กับ `fake_server.dart` (origin, segments ว่าง)
- เครื่องจริง: Galaxy Watch + Samsung Health (มีเส้นทางไหม?), Apple Watch Workout, Garmin Connect ทั้งสองแพลตฟอร์ม
- Android: แอป Health Connect Toolbox ใส่ข้อมูลทดสอบ; iOS Simulator: ปุ่ม debug เขียน workout ตัวอย่างลง HealthKit
- `responsive_layout_test`: หน้ารายละเอียดของกิจกรรมที่ไม่มีเส้นทางที่ 3 ขนาดจอ

## อ้างอิง
- [Samsung – Accessing Samsung Health data through Health Connect](https://developer.samsung.com/health/blog/en/accessing-samsung-health-data-through-health-connect)
- [FitMesh – Xiaomi/Amazfit Health Connect](https://www.fitmesh.fit/en/blog/xiaomi-amazfit-health-connect-data-dashboard)
