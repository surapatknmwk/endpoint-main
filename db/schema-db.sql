-- =====================================================================
-- Endpoint Services - schema
-- Generated from JPA entities (com.authen, com.core, com.master).
-- com.search entities map onto the same physical tables as com.core,
-- so no separate DDL is needed for them.
-- The app runs with ddl-auto: none, so this file must create every table.
-- Setup order for a new database: see db/README.md.
-- =====================================================================

-- ---- Master data ----

CREATE TABLE provinces (
    province_id BIGSERIAL PRIMARY KEY,
    code        VARCHAR(10)  NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    created_at  TIMESTAMP,
    updated_at  TIMESTAMP
);

-- lat/lng = centroid ของอำเภอ/ตำบล (เติมโดย db/scripts/district_distance_batch.py sync-*)
CREATE TABLE districts (
    district_id BIGSERIAL PRIMARY KEY,
    province_id BIGINT NOT NULL REFERENCES provinces(province_id),
    code        VARCHAR(10)  NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    lat         DECIMAL(9, 6),
    lng         DECIMAL(9, 6),
    created_at  TIMESTAMP,
    updated_at  TIMESTAMP
);

CREATE TABLE subdistricts (
    subdistrict_id BIGSERIAL PRIMARY KEY,
    district_id    BIGINT NOT NULL REFERENCES districts(district_id),
    code           VARCHAR(10)  NOT NULL UNIQUE,
    name           VARCHAR(100) NOT NULL,
    zip_code       VARCHAR(10),
    lat            DECIMAL(9, 6),
    lng            DECIMAL(9, 6),
    created_at     TIMESTAMP,
    updated_at     TIMESTAMP
);

-- ระยะทางเส้นตรง (haversine) ระหว่างอำเภอทุกคู่ — เติมโดย district_distance_batch.py compute-distances
CREATE TABLE district_distances (
    district_distance_id    BIGSERIAL PRIMARY KEY,
    origin_district_id      BIGINT NOT NULL REFERENCES districts(district_id),
    destination_district_id BIGINT NOT NULL REFERENCES districts(district_id),
    distance_km             DECIMAL(10, 2) NOT NULL CHECK (distance_km >= 0),
    calc_method             VARCHAR(20) NOT NULL DEFAULT 'haversine',
    created_at              TIMESTAMP NOT NULL DEFAULT now(),
    updated_at              TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_district_distances_pair UNIQUE (origin_district_id, destination_district_id),
    CONSTRAINT ck_district_distances_not_self CHECK (origin_district_id <> destination_district_id)
);

CREATE INDEX idx_district_distances_origin ON district_distances(origin_district_id);
CREATE INDEX idx_district_distances_destination ON district_distances(destination_district_id);

-- ระยะทางระหว่างตำบล: เส้นตรงจาก batch script (calc_method = 'haversine', google_fetched = false)
-- หรือระยะถนนจริงที่ backend cache จาก Google Routes API (calc_method = 'google', google_fetched = true)
CREATE TABLE subdistrict_distances (
    subdistrict_distance_id    BIGSERIAL PRIMARY KEY,
    origin_subdistrict_id      BIGINT NOT NULL REFERENCES subdistricts(subdistrict_id),
    destination_subdistrict_id BIGINT NOT NULL REFERENCES subdistricts(subdistrict_id),
    distance_km                DECIMAL(10, 2) NOT NULL CHECK (distance_km >= 0),
    calc_method                VARCHAR(20) NOT NULL DEFAULT 'haversine',
    google_fetched             BOOLEAN NOT NULL DEFAULT false,
    duration_seconds           BIGINT,
    created_at                 TIMESTAMP NOT NULL DEFAULT now(),
    updated_at                 TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_subdistrict_distances_pair UNIQUE (origin_subdistrict_id, destination_subdistrict_id),
    CONSTRAINT ck_subdistrict_distances_not_self CHECK (origin_subdistrict_id <> destination_subdistrict_id)
);

CREATE INDEX idx_subdistrict_distances_origin ON subdistrict_distances(origin_subdistrict_id);
CREATE INDEX idx_subdistrict_distances_destination ON subdistrict_distances(destination_subdistrict_id);

-- จำนวนครั้งที่ยิง Google Routes API จริงต่อวัน (Asia/Bangkok) ใช้คุมโควตา configuration.GR_DAILY
CREATE TABLE google_routes_usage (
    usage_date     DATE PRIMARY KEY,
    call_count     INTEGER NOT NULL DEFAULT 0 CHECK (call_count >= 0),
    rejected_count INTEGER NOT NULL DEFAULT 0 CHECK (rejected_count >= 0),
    created_at     TIMESTAMP NOT NULL DEFAULT now(),
    updated_at     TIMESTAMP NOT NULL DEFAULT now()
);

-- ระยะทาง (กม.) ระหว่าง 2 ตำแหน่ง ซึ่งแต่ละฝั่งเป็นได้ทั้งระดับอำเภอหรือตำบล
-- (origin/destination_subdistrict_id เป็น NULL หมายถึงระบุระยะทางถึงระดับอำเภอเท่านั้น)
-- ความ unique ของคู่ตำแหน่ง (รวมทิศทางย้อนกลับ) ตรวจสอบที่ service layer เนื่องจาก
-- UNIQUE constraint ของ Postgres ไม่ถือว่า NULL ซ้ำกัน
CREATE TABLE location_distances (
    distance_id                BIGSERIAL PRIMARY KEY,
    origin_district_id         BIGINT NOT NULL REFERENCES districts(district_id),
    origin_subdistrict_id      BIGINT REFERENCES subdistricts(subdistrict_id),
    destination_district_id    BIGINT NOT NULL REFERENCES districts(district_id),
    destination_subdistrict_id BIGINT REFERENCES subdistricts(subdistrict_id),
    distance_km                DECIMAL(10, 2) NOT NULL CHECK (distance_km > 0),
    notes                      TEXT,
    status                     CHAR(1) DEFAULT 'A',
    created_at                 TIMESTAMP,
    updated_at                 TIMESTAMP,
    created_by                 VARCHAR(20),
    updated_by                 VARCHAR(20)
);

CREATE INDEX idx_location_distances_origin ON location_distances(origin_district_id, origin_subdistrict_id);
CREATE INDEX idx_location_distances_destination ON location_distances(destination_district_id, destination_subdistrict_id);

CREATE TABLE configuration (
    config_id  BIGSERIAL PRIMARY KEY,
    code       VARCHAR(10)  NOT NULL UNIQUE,
    group_code VARCHAR(100),
    name       VARCHAR(100),
    value_1    VARCHAR(100),
    value_2    VARCHAR(100),
    value_3    VARCHAR(100),
    status     CHAR(1) DEFAULT 'A',
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- ---- Authentication ----

CREATE TABLE roles (
    role_id     SERIAL PRIMARY KEY,
    role_name   VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMP,
    updated_at  TIMESTAMP
);

CREATE TABLE providers (
    provider_id SERIAL PRIMARY KEY,
    method      VARCHAR(255),
    api         VARCHAR(255),
    status      CHAR(1) DEFAULT 'A',
    created_at  TIMESTAMP,
    created_by  VARCHAR(20)
);

CREATE TABLE users (
    user_id       SERIAL PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email         VARCHAR(100),
    first_name    VARCHAR(100),
    last_name     VARCHAR(100),
    phone         VARCHAR(20),
    role_id       INTEGER NOT NULL REFERENCES roles(role_id),
    is_active     BOOLEAN DEFAULT TRUE,
    last_login    TIMESTAMP,
    created_at    TIMESTAMP,
    updated_at    TIMESTAMP
);

CREATE TABLE permissions (
    permission_id SERIAL PRIMARY KEY,
    role_id       INTEGER NOT NULL REFERENCES roles(role_id),
    provider_id   INTEGER NOT NULL REFERENCES providers(provider_id),
    status        CHAR(1) DEFAULT 'A',
    created_at    TIMESTAMP,
    created_by    VARCHAR(20)
);

CREATE TABLE user_sessions (
    session_id SERIAL PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES users(user_id),
    token      VARCHAR(1000) NOT NULL UNIQUE,
    ip_address VARCHAR(45),
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP
);

-- ---- Core (orders) ----

CREATE TABLE customers (
    customer_id     BIGSERIAL PRIMARY KEY,
    title_id        INTEGER,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    name            VARCHAR(200),
    phone           VARCHAR(20),
    email           VARCHAR(100),
    notes           TEXT,
    customer_status VARCHAR(3),
    status          CHAR(1) DEFAULT 'A',
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    created_by      VARCHAR(20),
    updated_by      VARCHAR(20)
);

CREATE TABLE order_addresses (
    address_id       BIGSERIAL PRIMARY KEY,
    address_line     TEXT NOT NULL,
    subdistrict_code VARCHAR(10),
    district_code    VARCHAR(10),
    province_code    VARCHAR(10) NOT NULL,
    zip_code         VARCHAR(10),
    lat              VARCHAR(50),
    lng              VARCHAR(50),
    map_link         VARCHAR(500),
    is_default       BOOLEAN DEFAULT FALSE,
    status           CHAR(1) DEFAULT 'A',
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    created_by       VARCHAR(20),
    updated_by       VARCHAR(20)
);

CREATE TABLE orders (
    order_id      BIGSERIAL PRIMARY KEY,
    order_code    VARCHAR(50) NOT NULL UNIQUE,
    customer_id   BIGINT NOT NULL REFERENCES customers(customer_id),
    platform_id   BIGINT NOT NULL,
    address_id    BIGINT NOT NULL REFERENCES order_addresses(address_id),
    commodity     VARCHAR(255),
    size          VARCHAR(10),
    price         DECIMAL(10, 2),
    weight        DECIMAL(10, 2),
    width         DECIMAL(10, 2),
    height        DECIMAL(10, 2),
    sequence_no   INTEGER DEFAULT 1,
    detail        TEXT,
    remark        TEXT,
    order_status  VARCHAR(20) DEFAULT 'NEW' CHECK (order_status IN ('NEW', 'PENDING', 'IN_TRANSIT', 'COMPLETED', 'CANCELLED')),
    delivery_date TIMESTAMP,
    status        CHAR(1) DEFAULT 'A',
    created_at    TIMESTAMP,
    updated_at    TIMESTAMP,
    created_by    VARCHAR(20),
    updated_by    VARCHAR(20)
);

CREATE TABLE delivery_jobs (
    job_id          BIGSERIAL PRIMARY KEY,
    job_code        VARCHAR(50) NOT NULL UNIQUE,
    job_name        VARCHAR(255),
    origin_subdistrict_code      VARCHAR(10),
    origin_district_code         VARCHAR(10),
    origin_province_code         VARCHAR(10),
    total_orders    INTEGER DEFAULT 0,
    delivery_status VARCHAR(20) DEFAULT 'NEW',
    status          CHAR(1) DEFAULT 'A',
    scheduled_date  TIMESTAMP,
    completed_date  TIMESTAMP,
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    created_by      VARCHAR(20),
    updated_by      VARCHAR(20)
);

CREATE TABLE delivery_routing (
    route_id       BIGSERIAL PRIMARY KEY,
    job_id         BIGINT NOT NULL REFERENCES delivery_jobs(job_id),
    order_id       BIGINT NOT NULL REFERENCES orders(order_id),
    sequence_no    INTEGER NOT NULL,
    routing_status VARCHAR(20) DEFAULT 'NEW',
    notes          TEXT,
    created_at     TIMESTAMP,
    updated_at     TIMESTAMP,
    created_by     VARCHAR(20),
    updated_by     VARCHAR(20),
    UNIQUE (job_id, order_id)
);
