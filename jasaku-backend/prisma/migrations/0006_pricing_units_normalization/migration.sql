-- Migration: Normalize pricing_units — service-level pivot tables
-- Date: 2026-07-22
-- Changes:
--   1. Deduplicate pricing_units (merge 2x "per hari" into 1 universal)
--   2. Add description to pricing_units
--   3. Add new universal pricing units
--   4. Remove category_id from pricing_units
--   5. Create service_pricing_units pivot
--   6. Create service_contract_types pivot

BEGIN;

-- ============================================================
-- STEP 1: Add description column to pricing_units
-- ============================================================
ALTER TABLE pricing_units ADD COLUMN IF NOT EXISTS description TEXT;

-- ============================================================
-- STEP 2: Merge duplicate "per hari" pricing units
-- ============================================================
-- Both categories had their own "per hari". Merge to one universal.

-- Redirect Kelistrikan "per hari" refs to Bangunan "per hari"
UPDATE provider_service_prices
SET pricing_unit_id = '179db86c-fe8a-46aa-a09f-90090ad364f9'
WHERE pricing_unit_id = '17b0f2e0-0181-45b9-876a-0ade97b895e1';

-- Delete the duplicate
DELETE FROM pricing_units WHERE id = '17b0f2e0-0181-45b9-876a-0ade97b895e1';

-- ============================================================
-- STEP 3: Clean up existing pricing units (add description, fix names)
-- ============================================================
UPDATE pricing_units SET
    name = 'per_hari',
    unit = 'hari',
    description = 'Tarif per hari kerja'
WHERE id = '179db86c-fe8a-46aa-a09f-90090ad364f9';

UPDATE pricing_units SET
    name = 'per_titik',
    unit = 'titik',
    description = 'Tarif per titik (stop kontak, MCB, dll)'
WHERE id = 'eda28017-1df8-4169-865a-88f24fd277a8';

UPDATE pricing_units SET
    name = 'per_kunjungan',
    unit = 'kunjungan',
    description = 'Tarif per kunjungan/service call'
WHERE id = '8f4ebe4c-44a5-4381-97c3-de7ebd7a91ab';

-- ============================================================
-- STEP 4: Add new universal pricing units
-- ============================================================
INSERT INTO pricing_units (id, name, unit, description) VALUES
    (gen_random_uuid(), 'per_meter_persegi', 'm²', 'Tarif per meter persegi luas area'),
    (gen_random_uuid(), 'per_meter_panjang', 'm', 'Tarif per meter panjang'),
    (gen_random_uuid(), 'per_unit', 'unit', 'Tarif per unit item'),
    (gen_random_uuid(), 'per_jam', 'jam', 'Tarif per jam kerja')
ON CONFLICT DO NOTHING;

-- ============================================================
-- STEP 5: Remove category_id from pricing_units
-- ============================================================
ALTER TABLE pricing_units DROP COLUMN IF EXISTS category_id;

-- ============================================================
-- STEP 6: Create service_pricing_units pivot table
-- ============================================================
CREATE TABLE IF NOT EXISTS service_pricing_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    pricing_unit_id UUID NOT NULL REFERENCES pricing_units(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(service_id, pricing_unit_id)
);

-- ============================================================
-- STEP 7: Create service_contract_types pivot table
-- ============================================================
CREATE TABLE IF NOT EXISTS service_contract_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    contract_type_id UUID NOT NULL REFERENCES contract_types(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(service_id, contract_type_id)
);

-- ============================================================
-- STEP 8: Seed service_pricing_units
-- ============================================================

-- Kelistrikan services
-- Pemasangan MCB
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT '284db2ef-9824-4bfd-90e3-f88675d3811b', id FROM pricing_units WHERE name = 'per_hari';
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT '284db2ef-9824-4bfd-90e3-f88675d3811b', id FROM pricing_units WHERE name = 'per_titik';
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT '284db2ef-9824-4bfd-90e3-f88675d3811b', id FROM pricing_units WHERE name = 'per_kunjungan';

-- Pemasangan Stopkontak
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT 'f7fe454c-82e8-4b22-b078-4d22317c10a7', id FROM pricing_units WHERE name = 'per_hari';
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT 'f7fe454c-82e8-4b22-b078-4d22317c10a7', id FROM pricing_units WHERE name = 'per_titik';
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT 'f7fe454c-82e8-4b22-b078-4d22317c10a7', id FROM pricing_units WHERE name = 'per_kunjungan';

-- Perbaikan Bangunan services
-- Cat Dinding
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT 'ff4a47d0-fa7e-4e21-9ac1-ea296316fd12', id FROM pricing_units WHERE name = 'per_hari';
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT 'ff4a47d0-fa7e-4e21-9ac1-ea296316fd12', id FROM pricing_units WHERE name = 'per_meter_persegi';

-- Pemasangan dan Perbaikan Plafon
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT 'a4654dc6-6721-4c1a-8cfd-cc8039df4d8b', id FROM pricing_units WHERE name = 'per_hari';
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT 'a4654dc6-6721-4c1a-8cfd-cc8039df4d8b', id FROM pricing_units WHERE name = 'per_meter_persegi';

-- Pemasangan Keramik
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT 'ff0d4fae-6c4e-4fac-b86f-572b31a787f6', id FROM pricing_units WHERE name = 'per_hari';
INSERT INTO service_pricing_units (service_id, pricing_unit_id)
SELECT 'ff0d4fae-6c4e-4fac-b86f-572b31a787f6', id FROM pricing_units WHERE name = 'per_meter_persegi';

-- ============================================================
-- STEP 9: Seed service_contract_types (Bangunan only)
-- ============================================================
INSERT INTO service_contract_types (service_id, contract_type_id)
SELECT 'ff4a47d0-fa7e-4e21-9ac1-ea296316fd12', id FROM contract_types WHERE name = 'Harian';
INSERT INTO service_contract_types (service_id, contract_type_id)
SELECT 'ff4a47d0-fa7e-4e21-9ac1-ea296316fd12', id FROM contract_types WHERE name = 'Borongan';

INSERT INTO service_contract_types (service_id, contract_type_id)
SELECT 'a4654dc6-6721-4c1a-8cfd-cc8039df4d8b', id FROM contract_types WHERE name = 'Harian';
INSERT INTO service_contract_types (service_id, contract_type_id)
SELECT 'a4654dc6-6721-4c1a-8cfd-cc8039df4d8b', id FROM contract_types WHERE name = 'Borongan';

INSERT INTO service_contract_types (service_id, contract_type_id)
SELECT 'ff0d4fae-6c4e-4fac-b86f-572b31a787f6', id FROM contract_types WHERE name = 'Harian';
INSERT INTO service_contract_types (service_id, contract_type_id)
SELECT 'ff0d4fae-6c4e-4fac-b86f-572b31a787f6', id FROM contract_types WHERE name = 'Borongan';

COMMIT;
