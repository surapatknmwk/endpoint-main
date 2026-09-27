# district_distance_batch.py

คำนวณระยะห่าง (เส้นตรง / Haversine) ระหว่างอำเภอทุกคู่ และตำบลทุกคู่ (เฉพาะในจังหวัดเดียวกัน)
สำหรับ 8 จังหวัด (สกลนคร, ร้อยเอ็ด, อุบลราชธานี, กาฬสินธุ์, มหาสารคาม, นครพนม, อุดรธานี, บึงกาฬ)
แล้วเก็บลงตาราง `district_distances` / `subdistrict_distances` ที่สร้างแยกไว้โดยเฉพาะ

## Setup ครั้งแรก

ตาราง/คอลัมน์ที่สคริปต์ใช้ (`districts.lat/lng`, `subdistricts.lat/lng`, `district_distances`,
`subdistrict_distances`) สร้างโดย `db/schema-db.sql` แล้ว — ลำดับการสร้าง DB ใหม่ทั้งหมดดู `db/README.md`

```bash
cd db/scripts
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

ค่าเชื่อมต่อ DB อ่านจาก env vars (ค่า default ตรงกับ `db/docker-compose.yml` อยู่แล้ว):
`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`

## ระดับอำเภอ (district) vs ระดับตำบล (subdistrict)

| | ระดับอำเภอ | ระดับตำบล |
|---|---|---|
| คำสั่ง sync | `sync-districts` | `sync-subdistricts` |
| คำสั่งคำนวณระยะทาง | `compute-distances` | `compute-subdistrict-distances` |
| เก็บลงตาราง | `district_distances` | `subdistrict_distances` |
| ขอบเขตคู่ที่คำนวณ | ทุกคู่อำเภอในขอบเขต (ข้ามจังหวัดได้) | **เฉพาะคู่ตำบลในจังหวัดเดียวกัน** เท่านั้น (ข้ามอำเภอได้ แต่ไม่ข้ามจังหวัด) |
| ขนาดข้อมูล (8 จังหวัดนี้) | ~134 อำเภอ → ~18,000 คู่ | ~1,000 ตำบล → ~120,000 คู่ |

ตำบลระดับนี้ตั้งใจจำกัดขอบเขตแค่ในจังหวัดเดียวกัน เพราะคู่ตำบลข้ามจังหวัดทั่วทั้ง 8 จังหวัดจะกลาย
เป็นตารางขนาด ~1 ล้านแถวโดยไม่ค่อยมีประโยชน์ใช้งานจริง ถ้าต้องการขยายขอบเขตในอนาคต แก้ที่ฟังก์ชัน
`cmd_compute_subdistrict_distances` (group by `province_id`) ในสคริปต์

## รันแบบครบทุกขั้นตอน

```bash
# ระดับอำเภอเท่านั้น (เร็ว)
python3 district_distance_batch.py run-all

# ระดับอำเภอ + ตำบล (ครบทุกระดับ, ช้ากว่าเพราะข้อมูลมากกว่า)
python3 district_distance_batch.py run-all --with-subdistricts
```

`run-all` (ไม่มี `--with-subdistricts`) จะทำ 2 ขั้นตอนต่อกัน:

1. **sync-districts** — โหลดขอบเขตอำเภอจาก [OpenGISData-Thailand](https://github.com/chingchai/OpenGISData-Thailand)
   (cache ไว้ที่ `.cache/districts.geojson` ครั้งแรกครั้งเดียว) คำนวณจุดศูนย์กลาง (centroid)
   ของแต่ละอำเภอเป็น lat/lng แล้ว upsert ลงตาราง `provinces` / `districts`
   (จังหวัด/อำเภอที่ยังไม่มีในระบบจะถูกสร้างใหม่ให้อัตโนมัติ)
2. **compute-distances** — คำนวณระยะทางเส้นตรงทุกคู่อำเภอในขอบเขตที่เลือก แล้ว upsert
   ลง `district_distances` (เก็บทั้ง 2 ทิศทาง เพื่อ query ง่าย)

เติม `--with-subdistricts` แล้วจะทำต่ออีก 2 ขั้นตอน (เหมือน (1)-(2) แต่ระดับตำบล):

3. **sync-subdistricts** — โหลดขอบเขตตำบลจากไฟล์ `subdistricts.geojson` ของ repo เดียวกัน
   (ไฟล์ใหญ่กว่าเดิมมาก ~7,300 ตำบลทั่วประเทศ, cache ที่ `.cache/subdistricts.geojson`)
   คำนวณ centroid แล้ว upsert ลงตาราง `subdistricts` (ต้อง sync-districts ก่อนเสมอ เพราะต้องใช้
   `district_id` ของอำเภอแม่)
4. **compute-subdistrict-distances** — คำนวณระยะทางเฉพาะคู่ตำบลในจังหวัดเดียวกัน แล้ว upsert
   ลง `subdistrict_distances`

## รันทีละขั้นตอน

```bash
python3 district_distance_batch.py sync-districts
python3 district_distance_batch.py compute-distances

# ระดับตำบล (ต้องรัน sync-districts ให้เสร็จก่อนอย่างน้อยหนึ่งครั้ง)
python3 district_distance_batch.py sync-subdistricts
python3 district_distance_batch.py compute-subdistrict-distances
```

## กรณี error กลางทาง / ต้องการรันต่อโดยไม่เริ่มใหม่

ทุก write เป็น upsert (`ON CONFLICT ... DO UPDATE`) และมี checkpoint file ที่
`.cache/*.checkpoint.json` — แค่รันคำสั่งเดิมซ้ำ สคริปต์จะข้ามอำเภอ/คู่ที่ทำสำเร็จแล้ว
และทำต่อจากจุดที่ error โดยอัตโนมัติ ไม่ต้องเริ่มนับหนึ่งใหม่

```bash
python3 district_distance_batch.py compute-distances   # รันซ้ำได้เรื่อยๆ จนกว่าจะครบ
python3 district_distance_batch.py compute-subdistrict-distances   # เหมือนกัน ระดับตำบล
```

บังคับคำนวณใหม่ทั้งหมด (ไม่สนใจ checkpoint):

```bash
python3 district_distance_batch.py compute-distances --force
# หรือเคลียร์ checkpoint ทิ้งก่อน
python3 district_distance_batch.py compute-distances --reset-checkpoint
```

## อัปเดตเฉพาะบางอำเภอ / บางตำบล

```bash
# sync พิกัดใหม่เฉพาะ 2 อำเภอนี้ (เช่น แก้พิกัดผิด)
python3 district_distance_batch.py sync-districts --districts 4701,4702

# คำนวณระยะทางใหม่เฉพาะอำเภอที่ระบุ (เทียบกับทุกอำเภอในขอบเขต --provinces เดิม)
python3 district_distance_batch.py compute-distances --districts 4701,4702

# sync พิกัดใหม่เฉพาะตำบลที่ระบุ
python3 district_distance_batch.py sync-subdistricts --subdistricts 470101,470102

# sync ตำบลทั้งหมดของอำเภอที่ระบุ (ไม่ต้องพิมพ์รหัสตำบลทีละตัว)
python3 district_distance_batch.py sync-subdistricts --districts 4701

# คำนวณระยะทางใหม่เฉพาะตำบลที่ระบุ (เทียบกับตำบลอื่นในจังหวัดเดียวกัน)
python3 district_distance_batch.py compute-subdistrict-distances --subdistricts 470101,470102
```

`--districts` ใช้รหัสอำเภอ (คอลัมน์ `code` ในตาราง `districts`, เช่น `4701` = เมืองสกลนคร),
`--subdistricts` ใช้รหัสตำบล (คอลัมน์ `code` ในตาราง `subdistricts`, เช่น `470101` = ธาตุเชิงชุม)
ทั้งสองตัวจะ override `--provinces` เสมอ และ `--subdistricts` override `--districts` ด้วย

## จำกัดขอบเขตเป็นบางจังหวัด

```bash
python3 district_distance_batch.py run-all --provinces "สกลนคร,ร้อยเอ็ด"
python3 district_distance_batch.py run-all --with-subdistricts --provinces "สกลนคร,ร้อยเอ็ด"
```

## หลังรันสคริปต์ (backend + frontend)

ข้อมูลที่สคริปต์ upsert ลง DB ถูกใช้โดย backend ทันที ไม่ต้อง restart:

- `subdistricts.lat/lng` + `subdistrict_distances` — ใช้จัดอันดับ order ที่แนะนำตอนสร้างงาน
  (`GET /endpoint-core-service/api/jobs/candidate-orders`) และ preview เส้นทาง
  — ดู `docs/user-stories/jobs.md` (US-JOB-03, US-JOB-03a)
- ถ้าตำบลไหนไม่มี lat/lng ระยะทางของ order ในตำบลนั้นจะเป็น "ไม่ทราบระยะ" และถาม Google ไม่ได้

Endpoint อ่านอย่างเดียว (ผ่าน `endpoint-master-service`) ที่แสดงข้อมูลจากตารางเหล่านี้:

| Endpoint | ใช้สำหรับ |
|---|---|
| `GET /endpoint-master-service/api/district-distances?keyword=&page=&size=` | รายการระยะทางระดับอำเภอ (แบ่งหน้า, ค้นหาได้) |
| `GET /endpoint-master-service/api/subdistrict-distances?keyword=&page=&size=` | รายการระยะทางระดับตำบล (แบ่งหน้า, ค้นหาได้) |

หน้า **แผนที่ (Map)** ในเว็บที่เคยใช้ดูข้อมูลนี้ถูกปิดไว้ชั่วคราว (route ถูก comment ใน `router/routes.jsx`)

## หมายเหตุ

- ระยะทางเป็นเส้นตรง (Haversine) ไม่ใช่ระยะถนนจริง — ใช้เป็นค่าประมาณ ไม่เหมาะกับงานที่ต้องการ
  ความแม่นยำระดับกิโลเมตรที่ตรงกับถนนจริง (ถ้าต้องการ ต้องเปลี่ยนไปใช้ routing API/OSRM ภายหลังได้
  โดยไม่กระทบ schema เพราะมีคอลัมน์ `calc_method` เก็บไว้อยู่แล้ว)
- แถวใน `subdistrict_distances` ที่ `google_fetched = true` คือคู่ที่แอปเคยเรียก Google Routes API แล้ว
  (เป็นระยะถนนจริง) — `compute-subdistrict-distances` จะ**ไม่ทับ**แถวเหล่านี้ด้วยค่า Haversine
- ตาราง `district_distances` / `subdistrict_distances` แยกจาก `location_distances` เดิมในระบบโดยตั้งใจ ตามที่ระบุไว้
- ระดับตำบลคำนวณเฉพาะคู่ตำบล**ในจังหวัดเดียวกัน**เท่านั้น (ไม่ใช่ทุกคู่ทั่ว 8 จังหวัด) เพื่อคุมขนาดข้อมูล
- ไฟล์ `subdistricts.geojson` ที่ดาวน์โหลดมี ~7,300 ตำบลทั่วประเทศ (ใหญ่กว่า `districts.geojson`
  มาก) การดาวน์โหลดครั้งแรกอาจใช้เวลานานกว่าปกติ แต่ทำครั้งเดียวเพราะมี cache ไว้ที่ `.cache/`
- ถ้าอำเภอ/ตำบลบางแถวใน `districts`/`subdistricts` ไม่มี lat/lng (รหัสที่เพิ่มเองด้วยมือซึ่งไม่ตรงกับ
  รหัสทางการในข้อมูลต้นทาง) `compute-distances` / `compute-subdistrict-distances` จะ**ข้ามแถวนั้นแล้วเตือน
  ใน log** ไม่ทำให้ทั้งรันล้มเหลว
- สคริปต์ไม่ใส่ `zip_code` ให้ตำบล — รัน `db/subdistrict-zip-codes.sql` หลังสคริปต์ (ดู `db/README.md`)
