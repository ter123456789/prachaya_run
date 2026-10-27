# วาดรูปบนแผนที่ แล้วคำนวณเส้นทางวิ่งให้ได้รูปนั้น (Route Draw / GPS Art)

สถานะ: **ทำแล้วขั้น 1–4** (2026-10-27) เหลือขั้น 5 (ใช้ตอนวิ่ง) กับ 6 (auto-fit) คุยไว้ 2026-10-26

## สิ่งที่ทำแล้ว และสิ่งที่ต่างจากแผนเดิม
- **แอป:** `lib/features/route_builder/`
  - หน้า RouteListPage / RouteDrawPage เข้าได้จากการ์ด "เส้นทางวิ่งจากรูปวาด" ในหน้าตารางซ้อม (09)
  - DB v5 เพิ่มตาราง `planned_routes`
  - sync ผ่าน `/routes` และรวมอยู่ใน guest merge/keep
- **Backend:** `rinning_API` api.md v1.4
  - `POST /routes/snap` เรียก Valhalla ผ่าน `VALHALLA_URL` ถ้าไม่ได้ตั้งค่าจะตอบ 503 `provider_not_configured`
  - CRUD `/routes` (body limit 64 KB) พร้อม migration `planned_routes`
  - ทดสอบกับ Valhalla สาธารณะของ FOSSGIS แล้ว ได้เส้นทางจริง และถ้าวาดลงทะเลจะได้ `no_route`
- **ข้ามขั้น MVP แบบ Mapbox** ไปเรียก Valhalla ผ่าน backend เลย จึงไม่ต้องมี key
- **คะแนนคำนวณในแอป ไม่ได้คำนวณที่ server**
  - ไม่ได้ใช้ Fréchet เพราะช่วงอ้อมช่วงเดียวจะดึงคะแนนลงทั้งเส้น
  - ใช้ coverage สองทาง:
    1. สัดส่วนของเส้นทางที่อยู่ห่างจากรูปไม่เกิน tolerance
    2. สัดส่วนของรูปที่เส้นทางครอบคลุม
  - เอาค่าที่น้อยกว่าเป็นคะแนน
  - tolerance = 6 % ของเส้นทแยงรูป อยู่ในช่วง 30–120 ม.
- **snap ต้องมีบัญชี** (ตามกติกา "ไม่ล็อกอิน ไม่ส่งอะไรออก")
  - ไม่ล็อกอินหรือออฟไลน์ยังบันทึก "รูปวาด" ได้ โดย `route` เป็น null
- **ยังไม่ทำ:** ความสูงสะสม (`elevationGainM`), การลากจุดเพื่อแก้ทีละช่วง, export GPX
- **ก่อนเปิดใช้บน production:** ต้องตั้ง Valhalla เป็น service บน Railway แล้วใส่ `VALHALLA_URL` (ดู README ของ `rinning_API`)

## เป้าหมาย

ผู้ใช้วาดรูปด้วยนิ้วบนแผนที่ เช่น หัวใจ ตัวอักษร หรือสัตว์ แอปแปลงเส้นที่วาดให้เป็นเส้นทางที่วิ่งได้จริงบนถนนหรือทางเดิน แล้วแสดงสามอย่าง:
- เส้นทางจริง
- ระยะทาง
- ความเหมือนกับรูปที่วาด

จากนั้นบันทึกเส้นทางไว้ใช้ตอนวิ่ง (แนวเดียวกับ Route Builder แบบ draw mode ของ Strava)

## Pipeline

```
วาดบนแผนที่ → LatLng[] → ลดจุด / resample → snap เข้าถนน → ให้คะแนนความเหมือน → แสดง / แก้ / บันทึก
```

### 1. วาด
- ใช้ `flutter_map` + `latlong2` ที่มีอยู่แล้ว (`activity/presentation/widgets/route_map.dart`)
- โหมดวาด:
  - ปิด drag/pan ของแผนที่ (`InteractionOptions`)
  - วาง `GestureDetector` ทับ แล้วรับ `onPanStart/Update/End`
  - แปลงจุดบนจอเป็นพิกัดด้วย `MapCamera.pointToLatLng`
  - วาดเส้นสดด้วย `PolylineLayer` สีมะนาว (`AppColors.lime`)
- สลับโหมด "วาด / เลื่อนแผนที่" ด้วยปุ่มเดียว มีปุ่ม undo ทีละเส้น และปุ่มล้าง
- วาดได้หลายเส้น (stroke) ระบบจะต่อปลายเส้นหนึ่งเข้ากับต้นเส้นถัดไปเป็นเส้นทางเดียว เพราะวิ่งได้ทีละเส้นเท่านั้น

### 2. ลดจุด / resample (pure Dart → `domain/`)
- ลากนิ้วครั้งเดียวได้หลายร้อยจุดที่สั่นตามนิ้ว ให้ลดจุดด้วย **Ramer–Douglas–Peucker** โดยใช้ tolerance เป็นเมตร ซึ่งปรับตาม zoom
- **Resample** ให้จุดห่างกันเท่าๆ กันประมาณ 30–80 ม. เพราะ map matching ทำงานได้ดีเมื่อจุดสม่ำเสมอ
- งานทั้งหมดเป็นเรขาคณิตบนพิกัด จึงใช้ระยะทาง haversine ตัวเดียวกับที่คำนวณระยะกิจกรรม

### 3. Snap เข้าถนน (หัวใจของฟีเจอร์)

ทำได้สองแบบ:

| วิธี | ทำงานยังไง | ข้อดี | ข้อเสีย |
|---|---|---|---|
| **Map matching** (เลือกแบบนี้) | ส่งเส้นทั้งเส้นให้ engine หาเส้นทางบนถนนที่ใกล้รูปที่สุด | ออกแบบมาสำหรับงานนี้โดยตรง รูปเพี้ยนน้อย | ต้องใช้ engine ที่มี matching |
| Routing ทีละช่วง | หาเส้นทางเดินจากจุด i ไป i+1 แล้วต่อกัน | engine ไหนก็ทำได้ | ถ้าจุดตกบนตึกหรือแม่น้ำ เส้นจะอ้อมไกลจนรูปเสีย |

engine ที่ใช้ได้ (ข้อมูลถนนมาจาก OpenStreetMap ทั้งหมด):
- **Valhalla** `trace_route`
  - ตั้งค่า: `shape_match: "map_snap"`, `costing: "pedestrian"` ใช้ `search_radius` / `gps_accuracy` คุมว่ายอมให้หลุดจากเส้นที่วาดได้แค่ไหน
  - ข้อดี: ตรงงานที่สุด self-host ได้ และมี `/height` สำหรับความสูง
- **OSRM** `/match` โปรไฟล์ foot: เร็ว แต่ต้อง build ข้อมูลแยกตามโปรไฟล์
- **GraphHopper** map matching / **Mapbox Map Matching API** (`walking`, ไม่เกิน 100 จุดต่อครั้ง): แบบ hosted มี free tier เหมาะทำ MVP
- **ห้าม**ใช้ demo server สาธารณะของ OSRM/Valhalla ใน production เพราะผิด usage policy

### 4. ให้คะแนนความเหมือน (pure Dart → `domain/`)
- **ความเหมือนของรูป:** discrete Fréchet distance (หรือ Hausdorff) ระหว่างเส้นที่วาดกับเส้นที่ snap แล้ว
  - แปลงเป็นคะแนน 0–100 โดยหารด้วยขนาดของรูป (เส้นทแยงของ bounding box) รูปใหญ่จึงยอมให้คลาดได้มากกว่า
- **ช่วงที่อ้อม:** ถ้าระยะบนถนนของช่วงใดยาวกว่าระยะตรงเกินประมาณ 2 เท่า
  - ไฮไลต์ช่วงนั้นด้วยสีเหลืองอำพัน `AppColors.negative` (แอปนี้ไม่ใช้สีแดง)
  - ให้ผู้ใช้ลากจุดหรือวาดช่วงนั้นใหม่
- `RouteShape` ที่มีอยู่แล้ว (แปลง track เป็น polyline ใน unit-box) ใช้ normalize เส้นทั้งสองก่อนเทียบได้

### 5. แสดงผล / แก้ / บันทึก
- แสดงเส้นที่วาดเป็นเส้นประจาง และเส้นจริงเป็นเส้นเรืองแสงสไตล์ `route_canvas`
- แผงข้อมูล: ระยะ (ตาม `context.units`), ความสูงสะสม, คะแนนความเหมือน และเวลาโดยประมาณจาก pace ที่ผู้ใช้ตั้ง
- ลากจุดบนเส้นจริงเพื่อแก้ได้ แล้ว snap ใหม่เฉพาะช่วงนั้น
- บันทึกเป็น `PlannedRoute` ตั้งชื่อได้ ระบบสร้าง thumbnail ด้วย `RoutePainter` ให้
- Export GPX ได้ เผื่อใช้กับนาฬิกาหรือแอปอื่น

### 6. ขั้นสูง: "หาที่วางรูปให้" (auto-fit)
- ผู้ใช้วาดรูปที่ไหนก็ได้ แล้วระบุระยะที่ต้องการ (เช่น 5–10 กม.) กับจุดเริ่ม (ตำแหน่งปัจจุบัน)
- ระบบค้นหา scale × มุมหมุน × ตำแหน่ง รอบจุดเริ่ม สำหรับแต่ละชุดจะ:
  1. match รูป
  2. คิดคะแนน
  3. เลือกชุดที่ดีที่สุด 3 อันดับให้ผู้ใช้เลือก
- ต้องลองหลายร้อยชุด จึงทำบน server ที่โหลดกราฟถนนของพื้นที่ไว้ในหน่วยความจำ ไม่ควรยิง API ทีละชุด
- ทำหลังจากที่ข้อ 1–5 ใช้งานได้แล้วเท่านั้น

## วางตามสถาปัตยกรรมเดิม

```
lib/features/route_builder/
  domain/        DrawnShape, PlannedRoute, RouteSnapper (port), PlannedRouteRepository (port)
                 shape_simplify.dart (RDP, resample), shape_score.dart (Fréchet, detour),
                 polyline_codec.dart (encoded polyline)
  data/          HttpRouteSnapper (ผ่าน ApiClient → rinning_API), OfflineFirstRouteRepository,
                 RouteJsonMapper, GpxWriter
  presentation/  RouteDrawCubit, RouteDrawPage, RouteListPage, RouteSheet
```

- `domain/` เป็น pure Dart ตามกติกา ทั้ง RDP, resample, Fréchet และ codec จึงเขียน unit test ได้ครบโดยไม่ต้องใช้แผนที่
- presentation ไม่ import `http` เอง แต่รับ `RouteSnapper` ผ่าน `RepositoryProvider` จาก `app.dart`
- เพิ่มทางเข้าใน `architecture_test.dart` ให้ครอบคลุม feature ใหม่ (ถ้าไม่ได้วนทุก feature อัตโนมัติ)

### Backend (`rinning_API`)
แก้ `docs/api.md` ก่อนตามกติกา (v1.4):
- **`POST /routes/snap`** (auth): request เป็น `{ shape: "<encoded polyline>", closed: bool }`
  - response: `{ route: "<encoded polyline>", distanceM, elevationGainM, score, detours: [{fromIndex, toIndex}] }`
  - server เรียก Valhalla ต่อ จึงซ่อน key, เปลี่ยน engine ทีหลังได้, cache ได้ และ rate-limit ต่อผู้ใช้ได้
  - คำถามเปิด: ผู้ใช้ที่ไม่ได้ล็อกอินใช้ได้ไหม (ดูคำถามข้อ 2)
- **Planned routes:** ใช้ `PUT /routes/:id`, `DELETE /routes/:id`, `GET /routes?updatedSince=` ตาม "Shared rules for shoes and planned workouts"
  ```json
  { "id": "uuid", "name": "string (1–60)", "drawn": "encoded polyline", "route": "encoded polyline",
    "distanceM": 7340, "elevationGainM": 42, "score": 87, "updatedAt": "ISO8601", "deletedAt": null }
  ```
  - body limit ตอนนี้ 16 KB ต้องคุมขนาดเส้นด้วยสองอย่าง:
    1. ลดจุดเส้นที่ snap แล้วด้วย RDP ประมาณ 3 ม.
    2. เข้ารหัสแบบ encoded polyline (precision 5, ราว 4–6 ไบต์ต่อจุด)
  - เส้น 20 กม. จะเหลือไม่กี่ KB ถ้ายังไม่พอให้ขยาย limit เฉพาะ `/routes`
- **Valhalla** เป็น service แยกบน Railway:
  - ใช้ไฟล์ OSM ประเทศไทยจาก Geofabrik (`thailand-latest.osm.pbf`, ประมาณ 250–300 MB)
  - build tiles ตอน deploy หรือเก็บใน volume
  - อัปเดตข้อมูลถนนเดือนละครั้ง

### แอป
- เก็บใน SQLite ด้วย `SyncedRecordStore` (ตาราง `planned_routes` หน้าตาเดียวกับ `shoes` / `planned_workouts`) แล้วเพิ่ม `RecordSyncParticipant` ตัวใหม่ จะได้ scoping ตาม `owner_id`, LWW และ tombstone ฟรี
  - ต้องขึ้น **DB v5** ซึ่งชนกับ `recording-recovery.md` ที่จองไว้เหมือนกัน ตัวไหนทำก่อนได้ v5 อีกตัวได้ v6
  - ต้องมี migration test
- ใส่ใน `claimGuestData` (Merge) และการ park ของ Keep ใน `GuestLinkSheet` ให้ครบเหมือน shoes/plans
- การ snap ต้องใช้เน็ต ถ้าออฟไลน์ให้บันทึกเฉพาะเส้นที่วาด (`route` เป็น null) แล้ว snap ทีหลัง

## ต่อยอดกับของที่มีอยู่
- **ตารางซ้อม:** ให้ `PlannedWorkout` มี `routeId` ที่ไม่บังคับ ตอนสร้างแผนให้ใช้ระยะของเส้นทางเป็นค่าเริ่มต้น
- **ตอนบันทึกวิ่ง:**
  - แสดงเส้นที่ต้องวิ่งเป็นเส้นจางใต้ track จริงบน `RouteMap`
  - ถ้าออกนอกเส้นเกินประมาณ 40 ม. ต่อเนื่อง 10 วินาที ให้ `TtsVoiceCoach` เตือนเป็นภาษาไทย
  - (ไม่บังคับ) บอกทางเลี้ยวล่วงหน้า โดยใช้ maneuvers จาก Valhalla
- **แชร์รูป:** วางเส้นที่วาดคู่กับเส้นที่วิ่งจริงบน photo overlay ("วาด vs วิ่งจริง")
- **Debug:** ให้ `RouteSimulator` วิ่งตามเส้นทางที่บันทึกไว้ได้ ใช้ทดสอบการเตือนออกนอกเส้นโดยไม่ต้องออกไปวิ่ง

## ลำดับงาน
1. **domain + test:** RDP, resample, Fréchet/คะแนน, ตรวจช่วงอ้อม, encoded polyline (ไม่ขึ้นกับ engine)
2. **MVP แบบเร็ว:** หน้า RouteDrawPage วาดได้ แล้วเรียก Mapbox Map Matching จากแอปผ่าน adapter ใน `data/` ชั่วคราว เพื่อดูว่าผลดีพอไหม
3. **Backend:** `POST /routes/snap` + Valhalla บน Railway แล้วสลับ adapter มาเรียกผ่าน `ApiClient`
4. **บันทึก + sync:** `planned_routes`, DB migration, `/routes` CRUD, รวมเข้า guest merge/keep
5. **ใช้ตอนวิ่ง:** แสดงเส้นบนแผนที่ เตือนออกนอกเส้น ผูกกับตารางซ้อม
6. **Auto-fit:** หาตำแหน่ง/ขนาด/มุมที่ดีที่สุดบน server

## คำถามที่ยังต้องตัดสินใจ
1. **MVP ใช้ engine ไหน:** Mapbox (เร็ว แต่ต้องสมัคร key) หรือข้ามไปตั้ง Valhalla เลย
2. **ผู้ใช้ไม่ล็อกอินใช้ snap ได้ไหม:** ปัจจุบันไม่ล็อกอินแอปจะไม่ส่งอะไรไป server เลย ถ้าให้ใช้ ต้องมี endpoint ที่ไม่ต้อง auth พร้อม rate-limit ตาม IP
3. **เส้นทางปิด:** บังคับให้จบที่จุดเริ่มเสมอ หรือเป็นตัวเลือก (รูปส่วนใหญ่เป็นวงปิด แต่ตัวอักษรไม่ใช่)
4. **ประเภททาง:** ยอมให้วิ่งในสวนหรือทางเดินที่ไม่ใช่ถนนไหม (`pedestrian` รวมไว้แล้ว) และหลีกเลี่ยงถนนใหญ่ไหม (Valhalla ปรับได้ด้วย `walkway_factor` / `use_roads`)
5. **รอบ auto-fit:** ทำใน v1 เลย หรือรอรอบหลัง
