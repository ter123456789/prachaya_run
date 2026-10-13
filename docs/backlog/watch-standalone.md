# แอปบันทึกกิจกรรมบนนาฬิกา Wear OS (วิ่งโดยไม่พกมือถือ)

สถานะ: **เป้าหมายระยะยาว ยังไม่ได้ลงมือ** — คุยไว้ 2026-10-13
ทำต่อจาก: เซนเซอร์ HR ผ่าน BLE (ทำก่อน) และ [recording-recovery.md](recording-recovery.md)

## เป้าหมาย
นาฬิกาบันทึก GPS และ HR เองทั้งรอบ แล้วซิงก์เข้าระบบเดิม มือถือไม่ต้องอยู่ด้วยหรือจะปิดอยู่ก็ได้

## ขอบเขต
- รองรับเฉพาะ **Wear OS** (Galaxy Watch 4 ขึ้นไป, Pixel Watch, TicWatch)
- ไม่ทำ Garmin (Connect IQ / Monkey C), Huawei, Xiaomi และ Apple Watch (watchOS / Swift) ในรอบนี้

## แนวคิด
- **ตัวบันทึกบนนาฬิกา:** ใช้ Health Services `ExerciseClient` ของ Wear OS ผ่าน platform channel (Kotlin)
  ระบบจัดการ GPS + HR ให้ ประหยัดแบต และบันทึกต่อได้แม้แอปไม่อยู่หน้าจอ
  ไม่ใช้ geolocator เพราะบนนาฬิกากินแบตกว่ามาก
- **ใช้ domain เดิมร่วมกัน:** `RecordingSession`, `geo_math`, `live_metrics` และ heart_rate_zones เป็น pure Dart อยู่แล้ว
  แยกออกเป็น package กลาง (เช่น `packages/run_core`) ให้แอปมือถือและแอปนาฬิกา import ร่วมกัน
- **ซิงก์ 2 ทาง (เลือกทางที่ใช้ได้):**
  1. นาฬิกามีเน็ต (Wi‑Fi/LTE) → `POST /activities` ตรงเข้าเซิร์ฟเวอร์ (ต้องมี token บนนาฬิกา)
  2. ไม่มีเน็ต → ส่งผ่าน Wearable Data Layer ไปให้มือถือ แล้วมือถือซิงก์ต่อตามปกติ
  - activity id เป็น UUID ที่นาฬิกาสร้าง และ `POST /activities` เป็น upsert อยู่แล้ว
    ส่งซ้ำทั้งสองทางก็ไม่เกิดกิจกรรมซ้ำ
- **การกู้คืน:** ใช้แนวคิด Recording Journal จาก recording-recovery.md เหมือนกัน (แบตนาฬิกาหมดกลางทาง)
- **UI จอกลม:** หน้าเลือกประเภท, หน้าบันทึก (เวลา / ระยะ / เพซ / HR + โซน), ปุ่มหยุด/จบ
  ใช้ธีม Obsidian Kinetic ฉบับย่อ
- **ระบุที่มา:** เพิ่ม field ที่บอกว่ากิจกรรมบันทึกจากอุปกรณ์ไหน (phone / watch) — additive ใน API

## สิ่งที่ต้องมีจากงาน BLE HR ก่อน
- โมเดล `HeartRateSample` (ซีรีส์แยกจาก GPS) + ตาราง DB + field ใน API
- สรุป HR (avg / max / เวลาในแต่ละโซน) บนหน้ารายละเอียด

## ความเสี่ยง / คำถาม
- Flutter บน Wear OS: ขนาดแอป, ประสิทธิภาพบนชิปนาฬิการุ่นเก่า, จอกลม
- การล็อกอินบนนาฬิกา (พิมพ์รหัสบนนาฬิกาไม่ได้จริง) → ส่ง token จากมือถือผ่าน Data Layer
- แบต: GPS เต็มที่บนนาฬิกาได้ราว 5–10 ชั่วโมง
- ทดสอบ: ต้องมีนาฬิกาจริงหรือ Wear OS emulator; จำลองเส้นทางผ่าน `features/debug` แบบเดียวกับมือถือ
