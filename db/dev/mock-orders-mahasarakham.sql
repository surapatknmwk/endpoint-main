-- ===================================================
-- Mock Data เพิ่มเติม: Customers, Order Addresses, Orders (6 รายการ)
-- ทั้งหมดอยู่ในจังหวัดมหาสารคาม (province_code = 44)
-- อ้างอิงจาก docs/task/mock-location-001.md
-- สำหรับทดสอบ/dev เท่านั้น
-- ===================================================

-- ===================================================
-- CUSTOMERS (ผู้รับปลายทาง - ร้าน/วัด ตามสถานที่จริง)
-- ===================================================
INSERT INTO customers (title_id, first_name, last_name, name, phone, email, notes, customer_status, status, created_at, updated_at, created_by, updated_by) VALUES
(NULL, NULL, NULL, 'ครัวกลิ่นหอม รับจัดเบรค&ข้าวกล่อง', '0812345601', NULL, NULL, 'REG', 'A', NOW(), NOW(), 'admin', 'admin'),
(NULL, NULL, NULL, 'ร้านอาหาร ชีวาฬคาเฟ่ มหาสารคาม', '0812345602', NULL, NULL, 'REG', 'A', NOW(), NOW(), 'admin', 'admin'),
(NULL, NULL, NULL, 'วัดบ้านดินดำ', '0812345603', NULL, NULL, 'REG', 'A', NOW(), NOW(), 'admin', 'admin'),
(NULL, NULL, NULL, 'ร้านไม้มะค่า', '0812345604', NULL, NULL, 'REG', 'A', NOW(), NOW(), 'admin', 'admin'),
(NULL, NULL, NULL, 'วัดป่าโคกหนองจาน', '0812345605', NULL, NULL, 'REG', 'A', NOW(), NOW(), 'admin', 'admin'),
(NULL, NULL, NULL, 'ที่พักสงฆ์ป่า เจริญธรรม', '0812345606', NULL, NULL, 'REG', 'A', NOW(), NOW(), 'admin', 'admin');

-- ===================================================
-- ORDER ADDRESSES
-- ===================================================
INSERT INTO order_addresses (address_line, subdistrict_code, district_code, province_code, zip_code, map_link, is_default, status, created_at, updated_at, created_by, updated_by) VALUES
('598 ครัวกลิ่นหอม รับจัดเบรค&ข้าวกล่อง ต.ท่าขอนยาง อ.กันทรวิชัย จ.มหาสารคาม', '440404', '4404', '44', '44150', NULL, FALSE, 'A', NOW(), NOW(), 'admin', 'admin'),
('22 ร้านอาหาร ชีวาฬคาเฟ่ มหาสารคาม ต.ท่าขอนยาง อ.กันทรวิชัย จ.มหาสารคาม', '440404', '4404', '44', '44150', NULL, FALSE, 'A', NOW(), NOW(), 'admin', 'admin'),
('วัดบ้านดินดำ 67GC+F4M ต.เกิ้ง อ.เมืองมหาสารคาม จ.มหาสารคาม', '440107', '4401', '44', '44000', NULL, FALSE, 'A', NOW(), NOW(), 'admin', 'admin'),
('176 ร้านไม้มะค่า 57C9+8PC ต.แก่งเลิงจาน อ.เมืองมหาสารคาม จ.มหาสารคาม', '440108', '4401', '44', '44000', NULL, FALSE, 'A', NOW(), NOW(), 'admin', 'admin'),
('วัดป่าโคกหนองจาน 46VX+M7J ต.แก่งเลิงจาน อ.เมืองมหาสารคาม จ.มหาสารคาม', '440108', '4401', '44', '44000', NULL, FALSE, 'A', NOW(), NOW(), 'admin', 'admin'),
('ที่พักสงฆ์ป่า เจริญธรรม 24PR+WC ต.บรบือ อ.บรบือ จ.มหาสารคาม', '440601', '4406', '44', '44130', NULL, FALSE, 'A', NOW(), NOW(), 'admin', 'admin');

-- ===================================================
-- ORDERS (6 รายการ, สถานะ NEW ทั้งหมด)
-- ===================================================
INSERT INTO orders (order_code, customer_id, platform_id, address_id, commodity, size, price, weight, width, height, sequence_no, detail, remark, order_status, delivery_date, status, created_at, updated_at, created_by, updated_by) VALUES
('ORD-2026-0061', (SELECT customer_id FROM customers WHERE name = 'ครัวกลิ่นหอม รับจัดเบรค&ข้าวกล่อง'), 1, (SELECT address_id FROM order_addresses WHERE address_line = '598 ครัวกลิ่นหอม รับจัดเบรค&ข้าวกล่อง ต.ท่าขอนยาง อ.กันทรวิชัย จ.มหาสารคาม'), 'ข้าวกล่อง', 'M', 1200.00, 8.50, 40.00, 30.00, 1, 'mock order มหาสารคาม #61 - ครัวกลิ่นหอม', NULL, 'NEW', '2026-09-20 10:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0062', (SELECT customer_id FROM customers WHERE name = 'ร้านอาหาร ชีวาฬคาเฟ่ มหาสารคาม'), 1, (SELECT address_id FROM order_addresses WHERE address_line = '22 ร้านอาหาร ชีวาฬคาเฟ่ มหาสารคาม ต.ท่าขอนยาง อ.กันทรวิชัย จ.มหาสารคาม'), 'อาหารและเครื่องดื่ม', 'S', 850.00, 4.20, 30.00, 25.00, 1, 'mock order มหาสารคาม #62 - ชีวาฬคาเฟ่', NULL, 'NEW', '2026-09-20 10:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0063', (SELECT customer_id FROM customers WHERE name = 'วัดบ้านดินดำ'), 2, (SELECT address_id FROM order_addresses WHERE address_line = 'วัดบ้านดินดำ 67GC+F4M ต.เกิ้ง อ.เมืองมหาสารคาม จ.มหาสารคาม'), 'เครื่องไทยธรรม', 'L', 2500.00, 12.00, 45.00, 35.00, 1, 'mock order มหาสารคาม #63 - วัดบ้านดินดำ', NULL, 'NEW', '2026-09-20 10:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0064', (SELECT customer_id FROM customers WHERE name = 'ร้านไม้มะค่า'), 2, (SELECT address_id FROM order_addresses WHERE address_line = '176 ร้านไม้มะค่า 57C9+8PC ต.แก่งเลิงจาน อ.เมืองมหาสารคาม จ.มหาสารคาม'), 'เฟอร์นิเจอร์ไม้', 'L', 4500.00, 25.00, 60.00, 50.00, 1, 'mock order มหาสารคาม #64 - ร้านไม้มะค่า', NULL, 'NEW', '2026-09-20 10:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0065', (SELECT customer_id FROM customers WHERE name = 'วัดป่าโคกหนองจาน'), 3, (SELECT address_id FROM order_addresses WHERE address_line = 'วัดป่าโคกหนองจาน 46VX+M7J ต.แก่งเลิงจาน อ.เมืองมหาสารคาม จ.มหาสารคาม'), 'เครื่องไทยธรรม', 'M', 1800.00, 9.30, 35.00, 30.00, 1, 'mock order มหาสารคาม #65 - วัดป่าโคกหนองจาน', NULL, 'NEW', '2026-09-20 10:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0066', (SELECT customer_id FROM customers WHERE name = 'ที่พักสงฆ์ป่า เจริญธรรม'), 3, (SELECT address_id FROM order_addresses WHERE address_line = 'ที่พักสงฆ์ป่า เจริญธรรม 24PR+WC ต.บรบือ อ.บรบือ จ.มหาสารคาม'), 'เครื่องอุปโภคบริโภค', 'M', 1500.00, 10.00, 38.00, 28.00, 1, 'mock order มหาสารคาม #66 - ที่พักสงฆ์ป่าเจริญธรรม', NULL, 'NEW', '2026-09-20 10:00:00', 'A', NOW(), NOW(), 'admin', 'admin');
