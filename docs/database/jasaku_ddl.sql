-- ============================================================
-- Jasaku Platform — SQL DDL for PowerDesigner Import
-- PostgreSQL 15 + PostGIS
-- Generate PDM → auto-generate LDM → auto-generate CDM
-- ============================================================

-- ═══════════════════════════════════════════════════════════
-- DOMAIN: Autentikasi & Pengguna
-- ═══════════════════════════════════════════════════════════

CREATE TABLE roles (
    id          SERIAL       PRIMARY KEY, 
    name        VARCHAR(50)  NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users (
    id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id             INTEGER      NOT NULL,
    email               VARCHAR(255) UNIQUE,
    phone               VARCHAR(20)  UNIQUE,
    password_hash       TEXT,
    google_id           VARCHAR(255),
    is_phone_verified   BOOLEAN      DEFAULT FALSE,
    is_email_verified   BOOLEAN      DEFAULT FALSE,
    status              VARCHAR(20)  DEFAULT 'active',
    created_at          TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP
);

CREATE TABLE profiles_customer (
    id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID         NOT NULL UNIQUE,
    full_name   VARCHAR(150) NOT NULL,
    nickname    VARCHAR(100),
    birth_date  DATE,
    gender      VARCHAR(10),
    address     TEXT,
    avatar_url  TEXT,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP
);

CREATE TABLE provider_profiles (
    id                      UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID         NOT NULL UNIQUE,
    full_name               VARCHAR(100) NOT NULL,
    nickname                VARCHAR(50),
    gender                  VARCHAR(10),
    birth_date              DATE,
    phone                   VARCHAR(20),
    address                 TEXT,
    domicile                VARCHAR(100),
    profile_photo           TEXT,
    ktp_photo               TEXT,
    selfie_photo            TEXT,
    is_verified             BOOLEAN      DEFAULT FALSE,
    verification_status     VARCHAR(20)  DEFAULT 'pending',
    verification_notes      TEXT,
    is_active               BOOLEAN      DEFAULT TRUE,
    onboarding_completed    BOOLEAN      DEFAULT FALSE,
    custom_task_enabled     BOOLEAN      DEFAULT FALSE,
    service_available       BOOLEAN      DEFAULT TRUE,
    task_available          BOOLEAN      DEFAULT TRUE,
    rating                  DECIMAL(2,1) DEFAULT 0,
    total_jobs              INTEGER      DEFAULT 0,
    total_reviews           INTEGER      DEFAULT 0,
    portfolios              TEXT[]       DEFAULT '{}',
    created_at              TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP
);

CREATE TABLE provider_locations (
    id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID         NOT NULL UNIQUE,
    address     TEXT,
    location    GEOMETRY(Point, 4326)
);

CREATE TABLE provider_documents (
    id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID         NOT NULL,
    type        VARCHAR(30)  NOT NULL,
    file_url    TEXT         NOT NULL,
    category_id UUID,
    description TEXT,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE provider_payout_methods (
    id             UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id    UUID         NOT NULL,
    type           VARCHAR(50),
    provider_name  VARCHAR(100),
    account_number VARCHAR(100),
    account_name   VARCHAR(150),
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE identity_verifications (
    id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id       UUID         NOT NULL UNIQUE,
    nik               VARCHAR,
    ocr_full_name     VARCHAR,
    ocr_birth_place   VARCHAR,
    ocr_birth_date    VARCHAR,
    ocr_address       TEXT,
    ocr_gender        VARCHAR,
    ocr_blood_type    VARCHAR,
    ocr_religion      VARCHAR,
    ocr_raw_result    JSONB,
    face_match_score  FLOAT,
    face_match_status VARCHAR(20)  DEFAULT 'pending',
    liveness_data     JSONB,
    liveness_status   VARCHAR(20)  DEFAULT 'pending',
    created_at        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    verified_at       TIMESTAMP
);

CREATE TABLE user_devices (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID         NOT NULL,
    fcm_token   TEXT         NOT NULL UNIQUE,
    device_type VARCHAR      NOT NULL,
    device_name VARCHAR,
    created_at  TIMESTAMPTZ  DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMPTZ
);

-- ═══════════════════════════════════════════════════════════
-- DOMAIN: Katalog Layanan
-- ═══════════════════════════════════════════════════════════

CREATE TABLE categories (
    id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url    TEXT,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pricing_types (
    id           UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    name         VARCHAR(50)  NOT NULL,
    default_unit VARCHAR,
    category_id  UUID
);

CREATE TABLE services (
    id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID         NOT NULL,
    name        VARCHAR(150) NOT NULL,
    description TEXT,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE provider_services (
    id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID         NOT NULL,
    service_id  UUID         NOT NULL,
    description TEXT,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE provider_service_prices (
    id                  UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_service_id UUID          NOT NULL,
    pricing_type_id     UUID          NOT NULL,
    price               DECIMAL(12,2) NOT NULL,
    unit                VARCHAR,
    created_at          TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);

-- ═══════════════════════════════════════════════════════════
-- DOMAIN: Pesanan (Orders)
-- ═══════════════════════════════════════════════════════════

CREATE TABLE orders (
    id                UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id       UUID          NOT NULL,
    provider_id       UUID          NOT NULL,
    custom_task_id    UUID,
    task_provider_id  UUID,
    status            VARCHAR(30)   DEFAULT 'pending',
    total_price       DECIMAL(12,2),
    platform_fee      DECIMAL(12,2),
    additional_fee    DECIMAL(12,2) DEFAULT 0,
    description       TEXT,
    work_date         DATE,
    start_date        TIMESTAMP,
    end_date          TIMESTAMP,
    assignment_type   VARCHAR(20)   DEFAULT 'manual',
    payout_confirmed  BOOLEAN       DEFAULT FALSE,
    payout_at         TIMESTAMP,
    created_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id        UUID          NOT NULL,
    service_id      UUID          NOT NULL,
    pricing_type_id UUID          NOT NULL,
    quantity        INTEGER       DEFAULT 1,
    price           DECIMAL(12,2),
    subtotal        DECIMAL(12,2)
);

CREATE TABLE order_locations (
    id       UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID         NOT NULL,
    address  TEXT,
    location GEOMETRY(Point, 4326)
);

CREATE TABLE order_attachments (
    id         UUID      PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id   UUID      NOT NULL,
    file_url   TEXT      NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_extensions (
    id                UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id          UUID          NOT NULL,
    provider_id       UUID          NOT NULL,
    customer_id       UUID          NOT NULL,
    requested_date    DATE          NOT NULL,
    additional_cost   DECIMAL(12,2) NOT NULL,
    platform_fee_rate DECIMAL(3,2)  NOT NULL,
    extension_count   INTEGER       DEFAULT 1,
    status            VARCHAR(20)   DEFAULT 'pending',
    response_note     TEXT,
    created_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE provider_schedules (
    id          UUID      PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID      NOT NULL,
    work_date   DATE      NOT NULL,
    is_booked   BOOLEAN   DEFAULT FALSE,
    order_id    UUID,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(provider_id, work_date)
);

-- ═══════════════════════════════════════════════════════════
-- DOMAIN: Pembayaran
-- ═══════════════════════════════════════════════════════════

CREATE TABLE payments (
    id            UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id      UUID          NOT NULL,
    method        VARCHAR(50),
    status        VARCHAR(30)   DEFAULT 'pending',
    amount        DECIMAL(12,2),
    paid_at       TIMESTAMP,
    payment_proof TEXT,
    created_at    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE admin_bank_accounts (
    id             UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_name  VARCHAR(100) NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    account_name   VARCHAR(150) NOT NULL,
    is_active      BOOLEAN      DEFAULT TRUE,
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE admin_ewallet_accounts (
    id             UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_name  VARCHAR(100) NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    account_name   VARCHAR(150) NOT NULL,
    is_active      BOOLEAN      DEFAULT TRUE,
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE admin_qris_accounts (
    id             UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_name  VARCHAR(100) NOT NULL,
    qris_image_url TEXT         NOT NULL,
    is_active      BOOLEAN      DEFAULT TRUE,
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ═══════════════════════════════════════════════════════════
-- DOMAIN: Custom Tasks (Tender)
-- ═══════════════════════════════════════════════════════════

CREATE TABLE custom_tasks (
    id                UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id       UUID          NOT NULL,
    title             VARCHAR(150)  NOT NULL,
    description       TEXT,
    budget_per_person DECIMAL(12,0) NOT NULL,
    required_people   INTEGER       DEFAULT 1,
    accepted_count    INTEGER       DEFAULT 0,
    platform_fee_rate DECIMAL(4,2)  DEFAULT 5.00,
    address           TEXT,
    location_detail   TEXT,
    publish_days      INTEGER       DEFAULT 1,
    expires_at        TIMESTAMP,
    payment_proof     TEXT,
    payment_status    VARCHAR(30)   DEFAULT 'unpaid',
    location          GEOMETRY(Point, 4326),
    status            VARCHAR(30)   DEFAULT 'open',
    created_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP
);

CREATE TABLE task_locations (
    id         UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id    UUID         NOT NULL,
    label      VARCHAR(100),
    address    TEXT         NOT NULL,
    location   GEOMETRY(Point, 4326),
    stop_order INTEGER      DEFAULT 0
);

CREATE TABLE task_providers (
    id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id          UUID        NOT NULL,
    provider_id      UUID        NOT NULL,
    status           VARCHAR(20) DEFAULT 'accepted',
    work_status      VARCHAR(20),
    accepted_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    completed_at     TIMESTAMP,
    payout_confirmed BOOLEAN     DEFAULT FALSE,
    payout_at        TIMESTAMP,
    UNIQUE(task_id, provider_id)
);

-- ═══════════════════════════════════════════════════════════
-- DOMAIN: Ulasan & Laporan
-- ═══════════════════════════════════════════════════════════

CREATE TABLE reviews (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id    UUID        NOT NULL UNIQUE,
    customer_id UUID        NOT NULL,
    provider_id UUID        NOT NULL,
    rating      INTEGER     NOT NULL,
    review      TEXT,
    created_at  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP
);

CREATE TABLE reports (
    id             UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id    UUID         NOT NULL,
    reporter_role  VARCHAR(20)  NOT NULL,
    order_id       UUID,
    subject        VARCHAR(200) NOT NULL,
    description    TEXT         NOT NULL,
    attachments    TEXT[]       DEFAULT '{}',
    status         VARCHAR(20)  DEFAULT 'open',
    admin_response TEXT,
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP,
    resolved_at    TIMESTAMPTZ
);

-- ═══════════════════════════════════════════════════════════
-- FOREIGN KEY CONSTRAINTS
-- ═══════════════════════════════════════════════════════════

-- Users domain
ALTER TABLE users               ADD CONSTRAINT fk_user_role        FOREIGN KEY (role_id)        REFERENCES roles(id);
ALTER TABLE profiles_customer   ADD CONSTRAINT fk_profile_user     FOREIGN KEY (user_id)        REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE provider_profiles   ADD CONSTRAINT fk_provider_user    FOREIGN KEY (user_id)        REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE provider_locations  ADD CONSTRAINT fk_provider_loc     FOREIGN KEY (provider_id)    REFERENCES users(id);
ALTER TABLE user_devices        ADD CONSTRAINT fk_device_user      FOREIGN KEY (user_id)        REFERENCES users(id) ON DELETE CASCADE;

-- Provider domain
ALTER TABLE identity_verifications ADD CONSTRAINT fk_idverif_provider FOREIGN KEY (provider_id) REFERENCES provider_profiles(id) ON DELETE CASCADE;
ALTER TABLE provider_documents     ADD CONSTRAINT fk_pdoc_provider    FOREIGN KEY (provider_id) REFERENCES provider_profiles(id) ON DELETE CASCADE;
ALTER TABLE provider_payout_methods ADD CONSTRAINT fk_ppayout_provider FOREIGN KEY (provider_id) REFERENCES provider_profiles(id);

-- Services domain
ALTER TABLE pricing_types           ADD CONSTRAINT fk_ptype_category   FOREIGN KEY (category_id)       REFERENCES categories(id);
ALTER TABLE services                ADD CONSTRAINT fk_service_category FOREIGN KEY (category_id)      REFERENCES categories(id);
ALTER TABLE provider_services       ADD CONSTRAINT fk_pserv_service    FOREIGN KEY (service_id)        REFERENCES services(id);
ALTER TABLE provider_service_prices ADD CONSTRAINT fk_psp_pserv        FOREIGN KEY (provider_service_id) REFERENCES provider_services(id);
ALTER TABLE provider_service_prices ADD CONSTRAINT fk_psp_ptype        FOREIGN KEY (pricing_type_id)    REFERENCES pricing_types(id);

-- Orders domain
ALTER TABLE orders            ADD CONSTRAINT fk_order_customer      FOREIGN KEY (customer_id)      REFERENCES profiles_customer(id);
ALTER TABLE orders            ADD CONSTRAINT fk_order_provider      FOREIGN KEY (provider_id)      REFERENCES provider_profiles(id);
ALTER TABLE orders            ADD CONSTRAINT fk_order_custom_task   FOREIGN KEY (custom_task_id)   REFERENCES custom_tasks(id);
ALTER TABLE orders            ADD CONSTRAINT fk_order_task_provider FOREIGN KEY (task_provider_id) REFERENCES task_providers(id);
ALTER TABLE order_items       ADD CONSTRAINT fk_oitem_order         FOREIGN KEY (order_id)         REFERENCES orders(id);
ALTER TABLE order_items       ADD CONSTRAINT fk_oitem_service       FOREIGN KEY (service_id)       REFERENCES services(id);
ALTER TABLE order_items       ADD CONSTRAINT fk_oitem_ptype         FOREIGN KEY (pricing_type_id)  REFERENCES pricing_types(id);
ALTER TABLE order_locations   ADD CONSTRAINT fk_oloc_order          FOREIGN KEY (order_id)         REFERENCES orders(id);
ALTER TABLE order_attachments ADD CONSTRAINT fk_oattach_order       FOREIGN KEY (order_id)         REFERENCES orders(id);
ALTER TABLE order_extensions  ADD CONSTRAINT fk_oext_order          FOREIGN KEY (order_id)         REFERENCES orders(id);
ALTER TABLE provider_schedules ADD CONSTRAINT fk_psched_provider    FOREIGN KEY (provider_id)      REFERENCES provider_profiles(id);
ALTER TABLE provider_schedules ADD CONSTRAINT fk_psched_order       FOREIGN KEY (order_id)         REFERENCES orders(id);

-- Payments domain
ALTER TABLE payments ADD CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES orders(id);

-- Custom Tasks domain
ALTER TABLE task_locations ADD CONSTRAINT fk_tloc_task FOREIGN KEY (task_id) REFERENCES custom_tasks(id) ON DELETE CASCADE;
ALTER TABLE task_providers ADD CONSTRAINT fk_tprov_task     FOREIGN KEY (task_id)     REFERENCES custom_tasks(id);
ALTER TABLE task_providers ADD CONSTRAINT fk_tprov_provider FOREIGN KEY (provider_id) REFERENCES provider_profiles(id);

-- Reviews & Reports domain
ALTER TABLE reviews ADD CONSTRAINT fk_review_customer FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE reviews ADD CONSTRAINT fk_review_provider FOREIGN KEY (provider_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE reviews ADD CONSTRAINT fk_review_order    FOREIGN KEY (order_id)    REFERENCES orders(id) ON DELETE CASCADE;
ALTER TABLE reports ADD CONSTRAINT fk_report_reporter FOREIGN KEY (reporter_id) REFERENCES users(id);

-- ═══════════════════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════════════════

CREATE INDEX idx_users_email              ON users(email);
CREATE INDEX idx_users_google_id          ON users(google_id);
CREATE INDEX idx_users_phone              ON users(phone);
CREATE INDEX idx_profiles_user_id         ON profiles_customer(user_id);
CREATE INDEX idx_provider_documents_pid   ON provider_documents(provider_id);
CREATE INDEX idx_identity_verifications_pid ON identity_verifications(provider_id);
CREATE INDEX idx_user_devices_pid         ON user_devices(user_id);
CREATE INDEX idx_order_extensions_oid     ON order_extensions(order_id);
CREATE INDEX idx_task_locations_tid       ON task_locations(task_id);
CREATE INDEX idx_task_providers_pid       ON task_providers(provider_id);
CREATE INDEX idx_reports_reporter_id      ON reports(reporter_id);
CREATE INDEX idx_reports_status           ON reports(status);

CREATE INDEX idx_admin_bank_accounts_pid      ON admin_bank_accounts(provider_name);
CREATE INDEX idx_admin_ewallet_accounts_pid   ON admin_ewallet_accounts(provider_name);
CREATE INDEX idx_admin_qris_accounts_pid      ON admin_qris_accounts(provider_name);
CREATE INDEX idx_categories_name              ON categories(name);
CREATE INDEX idx_custom_tasks_customer_id     ON custom_tasks(customer_id);
CREATE INDEX idx_custom_tasks_status          ON custom_tasks(status);
CREATE INDEX idx_order_attachments_oid        ON order_attachments(order_id);
CREATE INDEX idx_order_items_oid              ON order_items(order_id);
CREATE INDEX idx_order_locations_oid          ON order_locations(order_id);
CREATE INDEX idx_orders_customer_id           ON orders(customer_id);
CREATE INDEX idx_orders_provider_id           ON orders(provider_id);
CREATE INDEX idx_orders_status                ON orders(status);
CREATE INDEX idx_payments_oid                 ON payments(order_id);
CREATE INDEX idx_pricing_types_category_id    ON pricing_types(category_id);
CREATE INDEX idx_provider_payout_methods_pid  ON provider_payout_methods(provider_id);
CREATE INDEX idx_provider_schedules_pid       ON provider_schedules(provider_id);
CREATE INDEX idx_provider_schedules_date      ON provider_schedules(work_date);
CREATE INDEX idx_provider_service_prices_psid ON provider_service_prices(provider_service_id);
CREATE INDEX idx_provider_services_pid        ON provider_services(provider_id);
CREATE INDEX idx_reviews_customer_id          ON reviews(customer_id);
CREATE INDEX idx_reviews_provider_id          ON reviews(provider_id);
CREATE INDEX idx_services_category_id         ON services(category_id);

-- PostGIS spatial index (buat manual di DB asli, PowerDesigner tidak support GIST syntax)
-- CREATE INDEX provider_locations_geo_idx ON provider_locations USING GIST(location);
