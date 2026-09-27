# endpoint-main
endpoint main github

## ฐานข้อมูล

สร้างและตั้งค่า PostgreSQL ให้พร้อมใช้งาน (ตั้งแต่สร้าง database จนต่อ backend ได้): [db/README.md](db/README.md)

## Deploy

ตั้ง VPS และ deploy (Caddy + systemd + PostgreSQL บนเครื่องเดียว): [deploy/README.md](deploy/README.md)

## Git Submodules

โปรเจกต์นี้ใช้ git submodules สำหรับ:
- `endpoint-webapp` — https://github.com/surapatknmwk/endpoint-webapp.git
- `endpoint-service` — https://github.com/surapatknmwk/endpoint-service.git

### Clone โปรเจกต์พร้อม submodules (ครั้งแรก)

```bash
git clone --recurse-submodules <url ของ repo นี้>
```

หรือถ้า clone repo นี้ไปแล้วโดยไม่ได้ใส่ `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### ดึงอัปเดตล่าสุดของ submodules

```bash
git submodule update --remote --merge
```

### Pull โปรเจกต์หลักพร้อมอัปเดต submodules ในคำสั่งเดียว

```bash
git pull --recurse-submodules
```

### แก้ไขโค้ดใน submodule

1. เข้าไปที่โฟลเดอร์ submodule (เช่น `cd endpoint-webapp`)
2. ทำงานตามปกติ (checkout branch, commit, push) เหมือน repo แยกต่างหาก
3. กลับมาที่ root แล้ว commit การอัปเดต reference ของ submodule:
   ```bash
   cd ..
   git add endpoint-webapp
   git commit -m "update endpoint-webapp submodule"
   git push
   ```

### เช็คสถานะ submodules

```bash
git submodule status
```
