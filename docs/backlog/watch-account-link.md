# เชื่อมบัญชีแบรนด์นาฬิกา (แบบ Strava) — Polar ก่อน, Garmin เมื่อเปิดรับ

สถานะ: **ทำแล้ว 2026-10-27 (Polar)** — แอป + API v1.6; Garmin รอโปรแกรมเปิด; ยังไม่ได้ลองกับบัญชี Polar จริง
งานคู่กัน: [health-import.md](health-import.md) (อ่านจาก Health ในเครื่อง — ใช้ `origin` และกิจกรรมไม่มีเส้นทางร่วมกัน)

## Strava ทำอย่างไร
ผู้ใช้บันทึกด้วยนาฬิกาตามปกติ → นาฬิกาซิงก์เข้าคลาวด์แบรนด์ → **คลาวด์แบรนด์ส่งต่อให้เซิร์ฟเวอร์ Strava**
→ แอป Strava ดึงจากเซิร์ฟเวอร์ตัวเอง ไม่มีแอปบนนาฬิกาเกี่ยว

| แบรนด์ | กลไก | เราทำได้ไหม (ต.ค. 2026) |
|---|---|---|
| Garmin | Activity API: Push หรือ Ping/Pull แจ้งภายในไม่กี่วินาทีหลังซิงก์, ไฟล์ .FIT/GPX/TCX | ❌ หยุดรับแอปใหม่ตั้งแต่ราว มี.ค.–เม.ย. 2026 ยังไม่มีกำหนด; ว่ากันว่าต้องเป็นนิติบุคคล |
| Samsung | Samsung เลือกพาร์ตเนอร์เอง (Samsung Health → General → Connected services) | ❌ ไม่มี API เปิด → ใช้ health-import.md |
| **Polar** | **AccessLink API v3:** ผู้ใช้ Polar Flow ทุกคนสร้าง API client เองได้, OAuth2, ดึงไฟล์ FIT ต่อ exercise | ✅ เริ่มได้เลย |
| Coros, Suunto, Wahoo, Huawei | โปรแกรมพาร์ตเนอร์ของแต่ละแบรนด์ | สมัครทีละแบรนด์ทีหลัง |

## แนวคิด: ทำครั้งเดียว ใช้ได้ทุกแบรนด์
**แอปมือถือแทบไม่ต้องแก้:** เซิร์ฟเวอร์สร้างกิจกรรมให้ผู้ใช้ แล้ว sync `?updatedSince=` เดิมดึงเข้าเครื่องเอง
(เหมือนกิจกรรมที่บันทึกจากมือถืออีกเครื่อง) → ขึ้นหน้าแรก ประวัติ รายละเอียด ซิงก์ทุกเครื่อง

```
นาฬิกา → คลาวด์แบรนด์ ──(webhook / pull)──▶ rinning_API ──(sync feed)──▶ แอป
                         ▲ OAuth ตอนเชื่อมบัญชี
```

## ฝั่งเซิร์ฟเวอร์ (rinning_API)

### เชื่อมบัญชี (OAuth2) — api.md v1.6 (แก้ contract ก่อน)
- `GET /me/links` → `[{ "provider": "polar", "linkedAt": "...", "status": "ok | expired | revoked", "lastImportAt": "..." }]`
- `POST /links/:provider/start` (auth) → `{ "authorizeUrl": "..." }` (มี `state` สุ่ม ผูกกับ user, อายุ 10 นาที)
- `GET /links/:provider/callback?code&state` (เบราว์เซอร์ ไม่มี auth header) → แลก token → ลงทะเบียน user
  กับแบรนด์ (Polar: `POST /v3/users`) → redirect ไป `prachayarun://links/polar?status=ok | error`
- `DELETE /me/links/:provider` → ยกเลิกที่แบรนด์ (Polar: deregister user) + ลบ token; กิจกรรมที่นำเข้าแล้วยังอยู่
- ไม่ได้ตั้ง `POLAR_CLIENT_ID` / `POLAR_CLIENT_SECRET` → 503 `provider_not_configured`
  (แอปซ่อนปุ่ม แบบเดียวกับ Sign in with Apple / Google)
- `DELETE /me` ยกเลิกทุก link ด้วย

### ตาราง
`provider_links (user_id, provider, provider_user_id, access_token_enc, refresh_token_enc, expires_at,
status, linked_at, last_import_at)` — token เข้ารหัสด้วยคีย์จาก env (`LINK_TOKEN_KEY`)

### รับกิจกรรม
- **Polar:** pull ตามรอบ (เช่น ทุก 10 นาที) ผ่าน exercise transactions ของ AccessLink
  (สร้าง transaction → ดูรายการ → ดึง FIT → commit) + webhook ถ้า AccessLink รองรับ
  (มีแหล่งบุคคลที่สามบอกว่ามี และส่ง PING ตอนลงทะเบียน — ต้องเช็คเอกสาร Polar)
- **Garmin (ภายหลัง):** Push notification → ดึง FIT
- งานรับกิจกรรมต้องทนต่อการส่งซ้ำ (idempotent ตาม id ด้านล่าง) และทำต่อได้ถ้าเซิร์ฟเวอร์รีสตาร์ท

### แปลงไฟล์ FIT → กิจกรรม
- ตัวอ่าน FIT: Garmin FIT JavaScript SDK (`@garmin/fitsdk`) หรือไลบรารีอื่น — เช็คไลเซนส์ก่อน
- `session.sport` → run / ride / hike (อื่น ๆ ไม่นำเข้า); `start_time`, `total_timer_time` → movingTime
- `record` (lat/lng/altitude/timestamp) → segments; ตัด segment ที่ event timer stop/start หรือช่องว่าง > 30 วิ
- `record.heart_rate` → `heartRate { source: "watch", samples }`
- ไม่มีพิกัด (ลู่วิ่ง / ในร่ม) → กิจกรรมไม่มีเส้นทาง + `distanceM` จาก session (กติกาเดียวกับ health-import v1.6)
- `origin: { kind: "polar", device: "Polar Pacer Pro" }`
- **id คงที่:** UUID v5 จาก (`polar`, exercise id) → ส่งซ้ำ = upsert; ผู้ใช้ลบแล้วไม่กลับมา
  (soft-deleted ไม่ revive อยู่แล้ว)
- `updatedAt` = เวลาที่นำเข้า; ผู้ใช้แก้ในแอปภายหลังชนะตาม LWW เดิม

### กันซ้ำกับกิจกรรมจากมือถือ / Health
เวลาซ้อนกัน ≥ 50 % กับกิจกรรมของ user คนเดียวกัน → ไม่สร้างใหม่; เติม HR ให้กิจกรรมเดิมถ้ายังไม่มี
(กติกาเดียวกับ health-import ทำฝั่งเซิร์ฟเวอร์) — ถ้าผู้ใช้เปิดทั้ง Health import และ link Polar
อาจได้ซ้ำจากสองทาง: id ต่างกันแต่กฎทับเวลากันไว้

### ความปลอดภัย
- `state` กัน CSRF; callback รับเฉพาะ state ที่ยังไม่หมดอายุและไม่เคยใช้
- token เข้ารหัสที่เก็บ, ไม่ส่งกลับให้แอป
- webhook ตรวจลายเซ็นตามที่แบรนด์กำหนด
- log ไม่มี token / พิกัด

## ฝั่งแอป
- **ต้องล็อกอิน** (เซิร์ฟเวอร์เป็นคนรับ) — ยังไม่ล็อกอิน: แถวนี้ชวนสมัครแบบ guest invite เดิม
- **โปรไฟล์:** การ์ด "บัญชีที่เชื่อมต่อ" — แถวละแบรนด์ (Polar, ภายหลัง Garmin): "เชื่อมต่อ" / "นำเข้าล่าสุด 07:42" / "ยกเลิก"
  แสดงเฉพาะแบรนด์ที่เซิร์ฟเวอร์ตั้งค่าไว้ (probe แบบเดียวกับปุ่ม Apple/Google)
- **OAuth:** เปิดเบราว์เซอร์ระบบด้วย `authorizeUrl` แล้วรอ deep link `prachayarun://links/...`
  - ต้องตั้ง custom URL scheme (iOS Info.plist, Android intent-filter)
  - ปลั๊กอินที่น่าใช้: `flutter_web_auth_2` (ASWebAuthenticationSession / Custom Tabs) — อยู่ใน `data/`
    และเพิ่มใน banned list ของ presentation; หรือเขียน channel เองแบบ BLE
- กลับมาจาก OAuth → `SyncCubit.sync()` ทันที
- ป้ายที่มา "⌚ Polar" บนการ์ด / รายละเอียด (จาก `origin`, ร่วมกับ health-import)
- domain port: `AccountLinkRepository` (`links()`, `start(provider)`, `unlink(provider)`) ใน features/auth

## ทางเลือกที่ควรพิจารณา: เชื่อม Strava แทน
ผู้ใช้จำนวนมากมี Strava ที่รับจาก Garmin / Samsung / Coros อยู่แล้ว → ถ้าเชื่อม Strava API (เปิดให้สมัครเอง)
ได้กิจกรรมจากทุกแบรนด์ทางเดียว — **แต่ต้องอ่านข้อตกลง Strava API ฉบับปัจจุบันก่อน**
(มีข้อจำกัดเรื่องการแสดงข้อมูลและการใช้ข้อมูล ยังไม่ได้ตรวจ) และเราจะพึ่งคู่แข่งโดยตรง

## ต่างจากสเปกตอนลงมือ
- ตัวอ่าน FIT: `fit-file-parser` (MIT) — `@garmin/fitsdk` ใช้ไลเซนส์เฉพาะของ Garmin (ใช้ภายในเท่านั้น) จึงไม่เลือก
- Polar: ใช้ exercise transactions (เอกสาร Polar ระบุว่า deprecated แต่ยังใช้ได้) — เปลี่ยนเป็น
  `GET /v3/exercises` ได้ใน `polar-client.ts` ที่เดียว; ยังไม่มี webhook (poll อย่างเดียว)
- แอปไม่รับ deep link เอง: callback redirect ไป `prachayarun://links/...` แค่พาแอปกลับมา แล้ว resume โหลดสถานะใหม่
- เปิดเบราว์เซอร์ด้วย channel `prachaya/browser` ของเราเอง (ไม่ใช้ `flutter_web_auth_2`)
- รายละเอียดที่ยังไม่ได้ยืนยันกับ Polar จริง: ดูหัวข้อ "Details settled" ใน api.md และ README ของ rinning_API

## ลำดับงาน
1. API v1.6 `origin` + กิจกรรมไม่มีเส้นทาง (ทำร่วมกับ health-import)
2. OAuth link + ตาราง + `/me/links` + การ์ดในแอป
3. Polar: รับ + แปลง FIT + กันซ้ำ
4. Garmin: เมื่อ Connect Developer Program เปิดรับอีกครั้ง (และมีนิติบุคคลถ้ายังจำเป็น)

## ทดสอบ
- เซิร์ฟเวอร์: unit test แปลง FIT (ไฟล์ตัวอย่างมีพิกัด / ไม่มีพิกัด / มี pause), id คงที่, ทับเวลา,
  state หมดอายุ/ใช้ซ้ำ; e2e ด้วย fake Polar (ไม่ยิงของจริง)
- แอป: fake `AccountLinkRepository`; widget test การ์ดโปรไฟล์; deep link กลับมาแล้ว sync
- ของจริง: บัญชี Polar Flow + นาฬิกา Polar 1 เรือน

## อ้างอิง
- [Polar AccessLink API v3](https://www.polar.com/accesslink-api/)
- [Polar AccessLink example (Python)](https://github.com/polarofficial/accesslink-example-python)
- [Garmin – Activity API](https://developer.garmin.com/gc-developer-program/activity-api/)
- [Garmin forum – Connect Developer Program still paused](https://forums.garmin.com/developer/connect-iq/f/discussion/440200/connect-developer-program-activity-api-access-no-response-is-the-program-still-paused)
- [the5krunner – Garmin developer API access paused (2026-09)](https://the5krunner.com/2026/09/14/garmin-developer-api-access-paused/)
- [Samsung Community – Samsung Health connected services → Strava](https://eu.community.samsung.com/t5/wearables/hoe-sync-ik-van-samsung-health-naar-strava/td-p/3065530)
