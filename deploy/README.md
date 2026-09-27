# Deploy บน VPS เครื่องเดียว

รันทุกอย่างบน Ubuntu 24.04 เครื่องเดียวโดยไม่ใช้ Docker เพื่อประหยัด RAM

```
Internet ──443──▶ Caddy (HTTPS อัตโนมัติ)
                   ├─ /                         → /var/www/endpoint        (endpoint-webapp/dist)
                   └─ /endpoint-*-service/*     → 127.0.0.1:8080           (endpoint-service, systemd)
                                                       │
                                                  PostgreSQL 16 (localhost เท่านั้น)
```

**Spec ที่แนะนำ:** 2 vCPU / RAM 4 GB / SSD 40 GB (ใช้ได้ถึงขั้นต่ำ 2 GB เพราะสคริปต์เพิ่ม swap 2 GB ให้)
RAM ที่ใช้โดยประมาณ: OS + Caddy ~300 MB, Postgres ~300 MB, JVM ~800 MB (heap จำกัดไว้ 512 MB)

| ไฟล์ | ติดตั้งไปที่ | หน้าที่ |
| --- | --- | --- |
| `setup-server.sh` | — | ตั้งเครื่องใหม่ครั้งเดียว (แพ็กเกจ, firewall, swap, user, config ทั้งหมดด้านล่าง) รันซ้ำได้ |
| `endpoint.service` | `/etc/systemd/system/` | รัน jar ด้วยค่า JVM ที่จำกัด RAM |
| `endpoint.env.example` | `/etc/endpoint/endpoint.env` | ค่า env ของ backend (รหัส DB, JWT, Google key) — **ไม่ commit ไฟล์จริง** |
| `Caddyfile` | `/etc/caddy/Caddyfile` | HTTPS + เสิร์ฟ SPA + reverse proxy ไป backend |
| `postgresql-endpoint.conf` | `/etc/postgresql/16/main/conf.d/endpoint.conf` | ปรับ Postgres สำหรับเครื่องเล็ก |
| `backup-db.sh` | `/usr/local/bin/endpoint-backup-db.sh` | `pg_dump` ทุกคืน 02:30 เก็บ 14 วันที่ `/var/backups/endpoint` |
| `deploy.sh` | — (รันจากเครื่องตัวเอง) | build → upload → restart → health check |

---

## ตั้งเครื่องครั้งแรก

1. **ก่อนเริ่ม:** ชี้ DNS (A record) ของโดเมนมาที่ IP ของ VPS — Caddy ต้องใช้ขอใบ HTTPS
   และ login เข้าเครื่องด้วย user ปกติที่มี sudo (ไม่ใช่ root) ผ่าน SSH key

2. **ติดตั้งเครื่อง** (จากเครื่องตัวเอง ที่ root repo):

   ```bash
   scp -r deploy <server>:~/
   ssh <server>
   cd ~/deploy && sudo ./setup-server.sh your-domain.com
   ```

   user ที่รันสคริปต์นี้จะเป็น user สำหรับ deploy (เป็นเจ้าของ `/opt/endpoint`, `/var/www/endpoint`
   และสั่ง `sudo systemctl restart endpoint` ได้โดยไม่ต้องใส่รหัส)

3. **สร้าง database** ตาม [db/README.md](../db/README.md) ทาง B บนเครื่อง server:

   ```bash
   sudo -u postgres psql   # แล้วรัน CREATE ROLE / CREATE DATABASE / ALTER DATABASE จาก db/README
   ```

   ขั้นที่ 2–6 (schema, ข้อมูลพื้นที่, user, สิทธิ์) รันจากเครื่องตัวเองผ่าน SSH tunnel ได้
   โดยไม่ต้องลง Python บน server:

   ```bash
   ssh -N -L 15432:localhost:5432 <server> &
   export PGHOST=localhost PGPORT=15432 PGDATABASE=endpoint_db PGUSER=endpoint_app PGPASSWORD='<รหัส DB>'
   # แล้วทำตาม db/README.md ขั้นที่ 2–6
   ```

4. **ใส่ค่า env:**

   ```bash
   sudo nano /etc/endpoint/endpoint.env   # DB_PASSWORD, JWT_SECRET (openssl rand -base64 48), GOOGLE_MAPS_API_KEY
   ```

5. **deploy ครั้งแรก** (จากเครื่องตัวเอง) — ดูหัวข้อถัดไป

6. **ปิด login SSH ด้วยรหัสผ่าน** (หลังทดสอบแล้วว่า login ด้วย key ได้ **ห้ามปิด session เดิมจนกว่าจะเปิด session ใหม่ได้**):
   ตั้ง `PasswordAuthentication no` และ `PermitRootLogin no` ใน `/etc/ssh/sshd_config` แล้ว `sudo systemctl reload ssh`

## Deploy

ต้องมี `mvn`, `npm` และ `node_modules` ของ webapp บนเครื่องตัวเอง (ไม่ build บน server เพราะกิน RAM เกินเครื่องเล็ก)

```bash
DEPLOY_HOST=<server> ./deploy/deploy.sh            # ทั้งคู่
DEPLOY_HOST=<server> ./deploy/deploy.sh backend    # เฉพาะ endpoint-service
DEPLOY_HOST=<server> ./deploy/deploy.sh frontend   # เฉพาะ endpoint-webapp
```

backend จะเก็บ jar ก่อนหน้าไว้ที่ `/opt/endpoint/app.jar.prev` ถ้า health check ไม่ผ่านภายใน ~90 วินาที
สคริปต์จะพิมพ์คำสั่ง rollback ให้

## งานประจำ

| งาน | คำสั่ง |
| --- | --- |
| ดู log backend | `sudo journalctl -u endpoint -f` |
| สถานะ / restart | `systemctl status endpoint` / `sudo systemctl restart endpoint` |
| ดู RAM | `free -h` และ `systemctl status endpoint` (บรรทัด Memory) |
| backup ทันที | `sudo -u postgres /usr/local/bin/endpoint-backup-db.sh` |
| ดึง backup ออกนอกเครื่อง | จากเครื่องตัวเอง: `rsync -a <server>:/var/backups/endpoint/ ./backups/` |
| restore | `sudo -u postgres pg_restore --clean --if-exists -d endpoint_db <file>.dump` |
| อัปเดตแพ็กเกจ OS | `sudo apt update && sudo apt upgrade` |

**backup ต้องมีสำเนานอกเครื่องเสมอ** ถ้า VPS พัง backup ที่อยู่ในเครื่องเดียวกันจะหายไปด้วย

## ปรับ RAM

- เครื่อง 2 GB: ใช้ค่าในไฟล์ตามที่ให้ไว้
- เครื่อง 4 GB ขึ้นไปและผู้ใช้เยอะขึ้น: เพิ่ม `-Xmx` ใน `endpoint.service` เป็น `1g` และ `shared_buffers`
  ใน `postgresql-endpoint.conf` เป็น `512MB` แล้วรัน `setup-server.sh` ซ้ำ
