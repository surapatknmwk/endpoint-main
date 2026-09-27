# ตั้งค่าฐานข้อมูล (Database setup)

คู่มือสร้างฐานข้อมูล PostgreSQL ของ `endpoint-service` ตั้งแต่ยังไม่มี database จนแอปใช้งานได้
แอปรันด้วย `ddl-auto: none` จึง**ไม่สร้างตารางเอง** ทุกอย่างต้องมาจากไฟล์ในโฟลเดอร์นี้ ตามลำดับด้านล่าง

| ไฟล์ | ใช้ทำอะไร | รันซ้ำได้? |
| --- | --- | --- |
| `schema-db.sql` | สร้างทุกตาราง (master data, ระยะทาง, auth, order, job) | ไม่ได้ — ใช้กับ DB ว่างเท่านั้น |
| `scripts/district_distance_batch.py` | สร้างจังหวัด/อำเภอ/ตำบล (รหัสทางการ + พิกัด) และระยะทางเส้นตรง — รายละเอียดใน [scripts/README.md](scripts/README.md) | ได้ (upsert) |
| `subdistrict-zip-codes.sql` | ใส่รหัสไปรษณีย์ให้ตำบล (ตามอำเภอ) | ได้ |
| `configuration-data.sql` | ช่องทางการสั่ง (platforms) + โควตา Google Routes ต่อวัน (`GR_DAILY`) | ได้ |
| `roles-users-data.sql` | role `USER_VIP_0` + user แรกสำหรับ login (รับ username/password ตอนรัน) | ได้ |
| `permissions-orders-data.sql` | สิทธิ์ endpoint ของ orders ให้ทุก role | ได้ |
| `permissions-jobs-data.sql` | สิทธิ์ endpoint ของ jobs ให้ทุก role | ได้ |
| `docker-compose.yml` | Postgres 16 สำหรับเครื่อง dev | — |
| `dev/mock-orders*.sql` | ข้อมูล order ทดสอบ — **ห้ามรันบน prod** | ไม่ได้ |

## สิ่งที่ต้องมี

- **PostgreSQL 16** (ตรงกับ `docker-compose.yml`) และ `psql`
- **Python 3.9+** สำหรับสคริปต์ข้อมูลพื้นที่
- **อินเทอร์เน็ต** ตอนรันขั้นที่ 3 ครั้งแรก — สคริปต์ดาวน์โหลดขอบเขตอำเภอ/ตำบลจาก GitHub
  (OpenGISData-Thailand) มาเก็บที่ `scripts/.cache/` ถ้าเครื่องปลายทางออกเน็ตไม่ได้ ให้คัดลอกไฟล์
  `scripts/.cache/*.geojson` จากเครื่องที่เคยรันไปวางไว้ที่เดียวกันก่อน
- ทุกคำสั่งด้านล่างรันจากโฟลเดอร์ `db/`

---

## ขั้นที่ 1 — สร้าง database

เลือกทางใดทางหนึ่ง

### ทาง A: เครื่อง dev ด้วย Docker

```bash
cd db
docker compose up -d
```

ได้ database `endpoint_db` ที่ `localhost:5433` (user `admin` / รหัส `admin123`) และ Docker จะรัน
`schema-db.sql` ให้เอง **ครั้งแรกที่สร้าง volume เท่านั้น** → ข้ามขั้นที่ 2 ไปขั้นที่ 3 ได้เลย

> ถ้าเคยรัน compose นี้มาก่อน volume เดิมยังอยู่ schema จะไม่ถูกสร้างใหม่
> ถ้าต้องการเริ่มใหม่จริงๆ ใช้ `docker compose down -v` — **คำสั่งนี้ลบข้อมูลใน DB dev ทั้งหมด**

### ทาง B: เซิร์ฟเวอร์ PostgreSQL (prod)

ต่อด้วย user ที่มีสิทธิ์สร้าง role/database (เช่น `postgres`) แล้วรัน:

```sql
CREATE ROLE endpoint_app LOGIN PASSWORD '<รหัสผ่าน DB>';
CREATE DATABASE endpoint_db OWNER endpoint_app ENCODING 'UTF8' TEMPLATE template0;
ALTER DATABASE endpoint_db SET timezone TO 'Asia/Bangkok';
```

- `ENCODING 'UTF8'` จำเป็น เพราะชื่อจังหวัด/ลูกค้าเป็นภาษาไทย
- ให้ `endpoint_app` เป็นเจ้าของ database และ**รันทุกขั้นต่อจากนี้ด้วย user นี้** เพื่อให้ตารางเป็นของ
  user ที่แอปใช้ (ไม่ต้อง GRANT เพิ่ม)
- `timezone` ทำให้ `now()` ในไฟล์ seed เป็นเวลาไทย

---

## ขั้นที่ 2 — สร้างตาราง

ตั้งตัวแปรการเชื่อมต่อไว้ใช้ทุกขั้น (แทนค่าในวงเล็บ):

```bash
cd db
export PGHOST=<host> PGPORT=<port> PGDATABASE=endpoint_db PGUSER=endpoint_app PGPASSWORD='<รหัสผ่าน DB>'

psql -v ON_ERROR_STOP=1 -f schema-db.sql
```

`psql` อ่านค่าจากตัวแปร `PG*` เอง (ทาง A: `PGHOST=localhost PGPORT=5433 PGUSER=admin PGPASSWORD=admin123`)

## ขั้นที่ 3 — ข้อมูลจังหวัด / อำเภอ / ตำบล + ระยะทาง

```bash
cd scripts
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
DB_HOST=$PGHOST DB_PORT=$PGPORT DB_NAME=$PGDATABASE DB_USER=$PGUSER DB_PASSWORD=$PGPASSWORD \
  .venv/bin/python district_distance_batch.py run-all --with-subdistricts --force
cd ..
```

- **ต้องใส่ `--force` เสมอกับ DB ใหม่** — ไฟล์ checkpoint ใน `scripts/.cache/` จำงานที่เคยทำกับ DB อื่น
  ถ้าไม่ใส่ สคริปต์จะข้ามทุกอย่างแต่ยังรายงานว่า `done` (ได้อำเภอ 0 ตำบล 0)
- ครอบคลุม 8 จังหวัด: สกลนคร, ร้อยเอ็ด, อุบลราชธานี, กาฬสินธุ์, มหาสารคาม, นครพนม, อุดรธานี, บึงกาฬ
- ใช้เวลาประมาณ 1 นาทีเมื่อมี cache (ครั้งแรกนานขึ้นตามความเร็วดาวน์โหลด)
- ผลที่ถูกต้องจะลงท้ายด้วย 4 บรรทัด `... done: ... 0 failed` / `0 origin(s) failed`
  (มี `WARNING: skipping ... no lat/lng` ได้ ถ้ามีตำบลที่ข้อมูลต้นทางไม่มีพิกัด)

## ขั้นที่ 4 — รหัสไปรษณีย์ และค่าตั้งต้น

```bash
psql -v ON_ERROR_STOP=1 -f subdistrict-zip-codes.sql   # ต้องหลังขั้นที่ 3
psql -v ON_ERROR_STOP=1 -f configuration-data.sql
```

## ขั้นที่ 5 — role และ user แรก

```bash
psql -v ON_ERROR_STOP=1 -v admin_username=admin -v admin_password='<รหัสผ่านสำหรับ login เว็บ>' \
  -f roles-users-data.sql
```

ไม่ต้องเขียนรหัสผ่านลงไฟล์ ถ้าลืมใส่ `-v` สคริปต์จะหยุดพร้อม `ERROR: missing -v ...`

## ขั้นที่ 6 — สิทธิ์ใช้งาน endpoint

```bash
psql -v ON_ERROR_STOP=1 -f permissions-orders-data.sql
psql -v ON_ERROR_STOP=1 -f permissions-jobs-data.sql
```

ต้องหลังขั้นที่ 5 เพราะสิทธิ์ผูกกับ role ที่มีอยู่ตอนรัน ใน profile `prod` ถ้า endpoint ไหนไม่มีสิทธิ์
แอปจะตอบ `401` และเว็บจะ logout ผู้ใช้ทันที

---

## ขั้นที่ 7 — ต่อ `endpoint-service` เข้ากับ database

ตั้ง environment variable ของ backend (profile `prod` อ่านจาก `application-prod.yml`):

| ตัวแปร | ค่า |
| --- | --- |
| `SPRING_PROFILES_ACTIVE` | `prod` |
| `DB_HOST` / `DB_PORT` / `DB_NAME` | ที่อยู่ database จากขั้นที่ 1 (`DB_NAME=endpoint_db`) |
| `DB_USERNAME` / `DB_PASSWORD` | `endpoint_app` และรหัสผ่านจากขั้นที่ 1 (สังเกต: ฝั่งแอปชื่อ `DB_USERNAME` ส่วนสคริปต์ขั้นที่ 3 ใช้ `DB_USER`) |
| `JWT_SECRET` | ข้อความสุ่มยาวอย่างน้อย 32 ตัวอักษร เช่น `openssl rand -base64 48` |
| `GOOGLE_MAPS_APIKEY` | API key ที่เปิด Routes API (ไม่ใส่ = ใช้ค่าใน `application.yml`) |
| `SERVER_PORT` | ไม่บังคับ ค่าเริ่มต้น `8080` |
| `JWT_EXPIRATION` | ไม่บังคับ อายุ token (ms) ค่าเริ่มต้น `3600000` (1 ชม.) |

แนะนำให้ตั้ง `TZ=Asia/Bangkok` ให้ process ของ backend ด้วย — เวลาสร้าง order/งานที่แสดงในเว็บมาจาก
นาฬิกาของ JVM ถ้าเครื่อง/container เป็น UTC เวลาจะคลาดไป 7 ชั่วโมง

## ตรวจว่าพร้อมใช้งาน

**ข้อมูลใน database:**

```bash
psql -c "
SELECT 'provinces' AS t, count(*) FROM provinces
UNION ALL SELECT 'districts', count(*) FROM districts
UNION ALL SELECT 'subdistricts', count(*) FROM subdistricts
UNION ALL SELECT 'subdistricts มีพิกัด', count(lat) FROM subdistricts
UNION ALL SELECT 'subdistricts มี zip', count(zip_code) FROM subdistricts
UNION ALL SELECT 'subdistrict_distances', count(*) FROM subdistrict_distances
UNION ALL SELECT 'configuration', count(*) FROM configuration
UNION ALL SELECT 'users', count(*) FROM users
UNION ALL SELECT 'providers', count(*) FROM providers
UNION ALL SELECT 'permissions', count(*) FROM permissions;"
```

ค่าที่ได้จากการรันทดสอบ (ข้อมูลต้นทางรุ่นที่ cache ไว้ — ถ้าดาวน์โหลดใหม่ตัวเลขพื้นที่อาจต่างเล็กน้อย):

| t | ควรได้ |
| --- | --- |
| provinces | 8 |
| districts | 134 |
| subdistricts / มีพิกัด | ~1,100 (เท่ากันทั้งสองแถว) |
| subdistricts มี zip | 211 |
| subdistrict_distances | ~170,000 |
| configuration | 8 |
| users | 1 |
| providers | 13 |
| permissions | 13 × จำนวน role |

**แอป** (หลังสตาร์ท backend):

```bash
curl -s http://<backend>:8080/endpoint-authen-service/health
curl -s -X POST http://<backend>:8080/endpoint-authen-service/auth/login \
  -H 'Content-Type: application/json' -d '{"username":"admin","password":"<รหัสผ่าน>"}'
```

login ต้องได้ `"token"` กลับมา จากนั้นเข้าเว็บ ลองเพิ่มออเดอร์ 1 รายการ แล้วสร้างงานจากออเดอร์นั้น
ถ้าผ่านทั้งสองอย่าง แปลว่า schema, สิทธิ์ และข้อมูลพื้นที่พร้อมแล้ว

---

## งานที่ทำภายหลัง

**เพิ่มผู้ใช้**

```sql
INSERT INTO users (username, password_hash, role_id, is_active, created_at)
SELECT '<username>', '<รหัสผ่าน>', role_id, true, now() FROM roles WHERE role_name = 'USER_VIP_0';
```

**ปิดผู้ใช้** — `UPDATE users SET is_active = false WHERE username = '<username>';`

**เพิ่ม role ใหม่** — insert ลง `roles` แล้วรันขั้นที่ 6 ซ้ำ เพื่อผูกสิทธิ์ให้ role นั้น

**ปรับโควตา Google ต่อวัน** — `UPDATE configuration SET value_1 = '300', updated_at = now() WHERE code = 'GR_DAILY';`
(มีผลทันที ไม่ต้อง restart)

**สำรองข้อมูล** — ทำหลังตั้งค่าเสร็จ และเป็นระยะ:

```bash
pg_dump -Fc -f endpoint_db-$(date +%Y%m%d).dump
```

## ปัญหาที่พบบ่อย

| อาการ | สาเหตุ / วิธีแก้ |
| --- | --- |
| สคริปต์ขั้นที่ 3 บอก `done: 0 upserted` | ลืม `--force` — รันใหม่พร้อม `--force` |
| login แล้วถูกเด้งกลับหน้า login ทันที หรือกดบางปุ่มแล้วถูก logout | ไม่มีสิทธิ์ endpoint นั้น → รันขั้นที่ 6 (และตรวจว่า user ผูก role ที่มีสิทธิ์) |
| login ไม่ผ่าน "Invalid username or password" | ยังไม่ได้รันขั้นที่ 5 หรือรหัสผ่านไม่ตรงกับที่ใส่ตอนรัน |
| สร้างงานแล้วได้ error 500 | database สร้างจาก `schema-db.sql` รุ่นเก่าที่ CHECK ไม่มี `IN_TRANSIT` — ดู [orders.md](../docs/user-stories/orders.md#schema-note-the-ordersorder_status-check-constraint) |
| ไม่มีช่องทางให้เลือกในฟอร์มออเดอร์ | ยังไม่ได้รัน `configuration-data.sql` |
| order แสดง "ไม่ทราบระยะ" ตอนสร้างงาน | ตำบลนั้นไม่มีพิกัด หรือยังไม่ได้รันขั้นที่ 3 |
| ภาษาไทยเป็นตัวอักษรแปลก | database ไม่ได้สร้างด้วย `ENCODING 'UTF8'` — ต้องสร้าง database ใหม่ |
| backend สตาร์ทไม่ขึ้นเพราะต่อ DB ไม่ได้ | ตรวจ `DB_HOST`/`DB_PORT`/`DB_USERNAME` (ไม่ใช่ `DB_USER`) และให้เครื่อง backend เข้าถึงพอร์ต DB ได้ |

## ข้อจำกัดของข้อมูลตั้งต้น

- **รหัสไปรษณีย์** มีเฉพาะ 24 อำเภอใน สกลนคร / ร้อยเอ็ด / กาฬสินธุ์ ตำบลอื่นจะว่าง (ฟอร์ม order
  ไม่ auto-fill แต่ผู้ใช้พิมพ์เองได้)
- **ระยะถนนจาก Google** (`subdistrict_distances.google_fetched = true`) ไม่ได้มาจากไฟล์ในนี้ — แอปเรียก
  Google แล้วเก็บเองเมื่อใช้งาน (นับโควตา `GR_DAILY`) ถ้าจะย้ายค่าที่เคยเรียกไว้จาก DB เดิม
  (ประหยัดโควตา) ให้รันหลังขั้นที่ 3:

  ```bash
  # จาก DB เดิม
  psql "<DB เดิม>" -c "\copy (SELECT o.code, d.code, s.distance_km, s.duration_seconds FROM subdistrict_distances s JOIN subdistricts o ON o.subdistrict_id = s.origin_subdistrict_id JOIN subdistricts d ON d.subdistrict_id = s.destination_subdistrict_id WHERE s.google_fetched) TO 'google-distances.csv' CSV"

  # เข้า DB ใหม่ (จับคู่ด้วยรหัสตำบล เพราะ id ใน DB ใหม่ต่างกัน)
  psql -v ON_ERROR_STOP=1 <<'SQL'
  CREATE TEMP TABLE g (origin_code text, destination_code text, distance_km numeric, duration_seconds bigint);
  \copy g FROM 'google-distances.csv' CSV
  INSERT INTO subdistrict_distances (origin_subdistrict_id, destination_subdistrict_id, distance_km,
                                     calc_method, google_fetched, duration_seconds)
  SELECT o.subdistrict_id, d.subdistrict_id, g.distance_km, 'google', true, g.duration_seconds
  FROM g
  JOIN subdistricts o ON o.code = g.origin_code
  JOIN subdistricts d ON d.code = g.destination_code
  ON CONFLICT (origin_subdistrict_id, destination_subdistrict_id) DO UPDATE SET
      distance_km = EXCLUDED.distance_km, calc_method = 'google', google_fetched = true,
      duration_seconds = EXCLUDED.duration_seconds, updated_at = now();
  SQL
  ```
- **รหัสผ่าน** ระบบเทียบรหัสผ่านแบบ plain text ค่าใน `users.password_hash` คือรหัสผ่านจริง
