-- ===================================================
-- Initial Data: role + first login user
--
-- ใส่ username / password ตอนรัน (ห้ามเขียนรหัสผ่านลงไฟล์นี้):
--   psql "<connection>" -v ON_ERROR_STOP=1 \
--        -v admin_username=admin -v admin_password='<รหัสผ่าน>' \
--        -f roles-users-data.sql
--
-- หมายเหตุ: ระบบตอนนี้เทียบรหัสผ่านแบบ plain text (AuthenticationService.login)
-- ค่า password_hash จึงเก็บรหัสผ่านตรงๆ ไม่ใช่ hash
-- Safe to run more than once: an existing role/username is left untouched.
-- ===================================================

\if :{?admin_username}
\else
    \echo 'ERROR: missing -v admin_username=...'
    SELECT 1 / 0 AS missing_admin_username;
\endif
\if :{?admin_password}
\else
    \echo 'ERROR: missing -v admin_password=...'
    SELECT 1 / 0 AS missing_admin_password;
\endif

-- role ที่ permissions-*-data.sql จะผูกสิทธิ์ให้ (ผูกให้ทุก role ที่มีอยู่)
INSERT INTO roles (role_name, description, created_at)
VALUES ('USER_VIP_0', 'ผู้ใช้งานหลัก (operator)', now())
ON CONFLICT (role_name) DO NOTHING;

INSERT INTO users (username, password_hash, role_id, is_active, created_at)
SELECT :'admin_username', :'admin_password', r.role_id, true, now()
FROM roles r
WHERE r.role_name = 'USER_VIP_0'
ON CONFLICT (username) DO NOTHING;
