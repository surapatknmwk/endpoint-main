-- ===================================================
-- Initial Data: Configuration (Master Data)
-- Safe to run more than once (existing codes are left untouched).
-- ===================================================

-- กลุ่ม platforms: ช่องทางการติดต่อ/สั่งซื้อของลูกค้า (ใช้ในหน้าเพิ่ม/แก้ไข order)
--   value_1 = ชื่อสี Bootstrap ของจุดบนป้ายช่องทาง (primary/success/info/warning/danger/dark/secondary)
--             ว่าง = สีเทา
INSERT INTO configuration (code, group_code, name, value_1, status, created_at) VALUES
('FB',     'platforms', 'Facebook',  'primary', 'A', now()),
('LINE',   'platforms', 'Line',      'success', 'A', now()),
('CALL',   'platforms', 'โทรศัพท์',   NULL,      'A', now()),
('SHOPEE', 'platforms', 'Shopee',    NULL,      'A', now()),
('LAZADA', 'platforms', 'Lazada',    NULL,      'A', now()),
('TIKTOK', 'platforms', 'TikTok',    'danger',  'A', now()),
('IG',     'platforms', 'Instagram', NULL,      'A', now())
ON CONFLICT (code) DO NOTHING;

-- โควตาเรียก Google Routes API ต่อวัน — อ่านสดทุกครั้งที่จะยิง Google (แก้ได้โดยไม่ต้อง restart แอป)
--   value_1 = จำนวนครั้งสูงสุดต่อวัน (จำนวนเต็ม >= 0, 0 = ปิดการยิง Google)
--   status  = 'A' ใช้ค่านี้ อื่นๆ = กลับไปใช้ google.maps.daily-request-limit ใน application.yml (ค่าเริ่มต้น 100)
-- ตัวอย่างปรับเป็น 300:  UPDATE configuration SET value_1 = '300', updated_at = now() WHERE code = 'GR_DAILY';
INSERT INTO configuration (code, group_code, name, value_1, status, created_at)
VALUES ('GR_DAILY', 'google_routes', 'โควตาเรียก Google Routes API ต่อวัน (ครั้ง)', '100', 'A', now())
ON CONFLICT (code) DO NOTHING;
