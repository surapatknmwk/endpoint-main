-- ===================================================
-- Mock Data: Customers, Order Addresses, Orders (10 รายการ)
-- สำหรับทดสอบ/dev เท่านั้น
-- ===================================================

-- ===================================================
-- CUSTOMERS
-- ===================================================
INSERT INTO customers (title_id, first_name, last_name, name, phone, email, notes, customer_status, status, created_at, updated_at, created_by, updated_by) VALUES
(1, 'สมชาย', 'ใจดี', 'สมชาย ใจดี', '0891234567', 'somchai@example.com', NULL, 'VIP', 'A', NOW(), NOW(), 'admin', 'admin'),
(2, 'สมหญิง', 'รักไทย', 'สมหญิง รักไทย', '0899876543', 'somying@example.com', NULL, 'REG', 'A', NOW(), NOW(), 'admin', 'admin'),
(1, 'วีระ', 'แสงทอง', 'วีระ แสงทอง', '0812345678', 'weera@example.com', 'ลูกค้าประจำ', 'REG', 'A', NOW(), NOW(), 'admin', 'admin');

-- ===================================================
-- ORDER ADDRESSES
-- ===================================================
INSERT INTO order_addresses (address_line, subdistrict_code, district_code, province_code, zip_code, map_link, is_default, status, created_at, updated_at, created_by, updated_by) VALUES
('123 หมู่ 4 ต.ธาตุเชิงชุม อ.เมืองสกลนคร จ.สกลนคร', NULL, '4701', '47', '47000', NULL, TRUE, 'A', NOW(), NOW(), 'admin', 'admin'),
('45/2 ถ.เจริญเมือง อ.เมืองร้อยเอ็ด จ.ร้อยเอ็ด', NULL, '4501', '45', '45000', NULL, TRUE, 'A', NOW(), NOW(), 'admin', 'admin'),
('88 หมู่ 1 อ.เมืองกาฬสินธุ์ จ.กาฬสินธุ์', NULL, NULL, '46', '46000', NULL, FALSE, 'A', NOW(), NOW(), 'admin', 'admin');

-- ===================================================
-- ORDERS (10 รายการ)
-- ===================================================
INSERT INTO orders (order_code, customer_id, platform_id, address_id, commodity, size, price, weight, width, height, sequence_no, detail, remark, order_status, delivery_date, status, created_at, updated_at, created_by, updated_by) VALUES
('ORD-2026-0001', (SELECT customer_id FROM customers WHERE name = 'สมชาย ใจดี'),      1, (SELECT address_id FROM order_addresses WHERE province_code = '47'), 'เสื้อผ้า',        'M',  590.00,  0.50, 20.00, 15.00, 1, 'เสื้อยืดสีขาว 2 ตัว', NULL,                    'new',       '2026-08-10 10:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0002', (SELECT customer_id FROM customers WHERE name = 'สมหญิง รักไทย'),   2, (SELECT address_id FROM order_addresses WHERE province_code = '45'), 'อุปกรณ์ครัว',     'L',  1250.00, 2.30, 35.00, 25.00, 1, 'หม้อหุงข้าว 1 ใบ',     'ระวังแตก',              'PENDING',   '2026-08-11 14:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0003', (SELECT customer_id FROM customers WHERE name = 'วีระ แสงทอง'),     1, (SELECT address_id FROM order_addresses WHERE province_code = '46'), 'หนังสือ',         'S',  320.00,  0.80, 15.00, 10.00, 1, 'หนังสือนิยาย 3 เล่ม',  NULL,                    'new',       '2026-08-09 09:30:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0004', (SELECT customer_id FROM customers WHERE name = 'สมชาย ใจดี'),      3, (SELECT address_id FROM order_addresses WHERE province_code = '47'), 'เครื่องสำอาง',    'S',  890.00,  0.30, 12.00, 8.00,  2, 'ครีมบำรุงผิว',        NULL,                    'IN_TRANSIT','2026-08-08 16:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0005', (SELECT customer_id FROM customers WHERE name = 'สมหญิง รักไทย'),   2, (SELECT address_id FROM order_addresses WHERE province_code = '45'), 'ของเล่น',         'M',  450.00,  1.10, 25.00, 20.00, 1, 'ตุ๊กตาหมี',           'ของขวัญวันเกิด',        'new',       '2026-08-12 11:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0006', (SELECT customer_id FROM customers WHERE name = 'วีระ แสงทอง'),     1, (SELECT address_id FROM order_addresses WHERE province_code = '46'), 'อะไหล่รถยนต์',    'L',  3200.00, 5.00, 40.00, 30.00, 1, 'ผ้าเบรกหน้า-หลัง',     'เร่งด่วน',               'COMPLETED', '2026-08-05 08:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0007', (SELECT customer_id FROM customers WHERE name = 'สมชาย ใจดี'),      3, (SELECT address_id FROM order_addresses WHERE province_code = '47'), 'อาหารแห้ง',       'M',  680.00,  3.20, 30.00, 20.00, 1, 'ข้าวสารหอมมะลิ 5 กก.', NULL,                    'PENDING',   '2026-08-13 13:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0008', (SELECT customer_id FROM customers WHERE name = 'สมหญิง รักไทย'),   1, (SELECT address_id FROM order_addresses WHERE province_code = '45'), 'อุปกรณ์อิเล็กทรอนิกส์', 'S', 1990.00, 0.60, 18.00, 12.00, 1, 'หูฟังไร้สาย',        'สินค้าแตกหักง่าย',      'new',       '2026-08-10 17:00:00', 'A', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0009', (SELECT customer_id FROM customers WHERE name = 'วีระ แสงทอง'),     2, (SELECT address_id FROM order_addresses WHERE province_code = '46'), 'เฟอร์นิเจอร์',    'XL', 4500.00, 12.00, 60.00, 40.00, 1, 'เก้าอี้พลาสติก 4 ตัว', NULL,                    'CANCELLED', '2026-08-06 10:00:00', 'I', NOW(), NOW(), 'admin', 'admin'),
('ORD-2026-0010', (SELECT customer_id FROM customers WHERE name = 'สมชาย ใจดี'),      3, (SELECT address_id FROM order_addresses WHERE province_code = '47'), 'เครื่องเขียน',    'S',  150.00,  0.20, 10.00, 5.00,  1, 'สมุดโน้ต 5 เล่ม',      NULL,                    'IN_TRANSIT','2026-08-09 15:30:00', 'A', NOW(), NOW(), 'admin', 'admin');
