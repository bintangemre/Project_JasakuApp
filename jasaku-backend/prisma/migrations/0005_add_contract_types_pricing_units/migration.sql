-- Migration: Split pricing_types into contract_types + pricing_units
-- Date: 2026-07-22
-- Description: 
--   1. Create contract_types table (Harian, Borongan)
--   2. Create pricing_units table (Per Titik, Per Kunjungan)
--   3. Add new columns to provider_service_prices and order_items
--   4. Migrate existing data
--   5. Drop old pricing_types table

BEGIN;

-- ============================================================
-- STEP 1: Create contract_types table
-- ============================================================
CREATE TABLE IF NOT EXISTS contract_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Seed data: Harian dan Borongan
INSERT INTO contract_types (id, name, description) VALUES
    ('a1111111-1111-1111-1111-111111111111', 'Harian', 'Pekerjaan dikerjakan per hari'),
    ('a2222222-2222-2222-2222-222222222222', 'Borongan', 'Pekerjaan dikerjakan secara borongan/lump sum')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- STEP 2: Create pricing_units table
-- ============================================================
CREATE TABLE IF NOT EXISTS pricing_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL,
    unit VARCHAR(50),
    category_id UUID REFERENCES categories(id) ON DELETE NO ACTION,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Seed data: Per Titik dan Per Kunjungan (untuk Kelistrikan)
-- Kita perlu category_id dari kategori Kelistrikan, jadi pakai subquery
INSERT INTO pricing_units (id, name, unit, category_id)
SELECT 
    gen_random_uuid(),
    'Per Titik',
    'titik',
    c.id
FROM categories c
WHERE c.name ILIKE '%kelistrikan%'
ON CONFLICT DO NOTHING;

INSERT INTO pricing_units (id, name, unit, category_id)
SELECT 
    gen_random_uuid(),
    'Per Kunjungan',
    'kunjungan',
    c.id
FROM categories c
WHERE c.name ILIKE '%kelistrikan%'
ON CONFLICT DO NOTHING;

-- ============================================================
-- STEP 3: Add new columns to provider_service_prices
-- ============================================================
-- Add pricing_unit_id column
ALTER TABLE provider_service_prices 
ADD COLUMN IF NOT EXISTS pricing_unit_id UUID;

-- Add contract_type_id column (nullable, only for bangunan)
ALTER TABLE provider_service_prices 
ADD COLUMN IF NOT EXISTS contract_type_id UUID;

-- Add price_with_material column (nullable, only for kelistrikan)
ALTER TABLE provider_service_prices 
ADD COLUMN IF NOT EXISTS price_with_material DECIMAL(12,2);

-- Add plus_material column
ALTER TABLE provider_service_prices 
ADD COLUMN IF NOT EXISTS plus_material BOOLEAN DEFAULT FALSE;

-- ============================================================
-- STEP 4: Add new columns to order_items
-- ============================================================
-- Add pricing_unit_id column
ALTER TABLE order_items 
ADD COLUMN IF NOT EXISTS pricing_unit_id UUID;

-- Add contract_type_id column (nullable, only for bangunan)
ALTER TABLE order_items 
ADD COLUMN IF NOT EXISTS contract_type_id UUID;

-- Add with_material column
ALTER TABLE order_items 
ADD COLUMN IF NOT EXISTS with_material BOOLEAN DEFAULT FALSE;

-- ============================================================
-- STEP 5: Migrate existing data
-- Map old pricing_types to new pricing_units
-- ============================================================

-- First, let's create a mapping from old pricing_types to new pricing_units
-- We need to handle the case where pricing_types might have different names

-- For provider_service_prices: map pricing_type_id to pricing_unit_id
UPDATE provider_service_prices psp
SET pricing_unit_id = pu.id
FROM pricing_units pu
JOIN categories c ON pu.category_id = c.id
WHERE pu.name = 'Per Titik' 
  AND psp.pricing_type_id IN (
      SELECT pt.id FROM pricing_types pt 
      WHERE pt.name ILIKE '%titik%'
  );

UPDATE provider_service_prices psp
SET pricing_unit_id = pu.id
FROM pricing_units pu
JOIN categories c ON pu.category_id = c.id
WHERE pu.name = 'Per Kunjungan'
  AND psp.pricing_type_id IN (
      SELECT pt.id FROM pricing_types pt 
      WHERE pt.name ILIKE '%kunjungan%'
  );

-- For any remaining pricing_types that don't match, create generic pricing_units
-- This is a fallback for any pricing types we haven't mapped
DO $$
DECLARE
    pt RECORD;
    new_pu_id UUID;
BEGIN
    FOR pt IN 
        SELECT pt_inner.id, pt_inner.name, pt_inner.default_unit, pt_inner.category_id
        FROM pricing_types pt_inner
        WHERE NOT EXISTS (
            SELECT 1 FROM provider_service_prices psp 
            WHERE psp.pricing_unit_id IS NOT NULL 
            AND psp.pricing_type_id = pt_inner.id
        )
    LOOP
        -- Create a new pricing_unit for this unmapped pricing_type
        INSERT INTO pricing_units (name, unit, category_id)
        VALUES (pt.name, pt.default_unit, pt.category_id)
        ON CONFLICT DO NOTHING
        RETURNING id INTO new_pu_id;
        
        -- Update provider_service_prices to use the new pricing_unit_id
        UPDATE provider_service_prices 
        SET pricing_unit_id = new_pu_id
        WHERE pricing_type_id = pt.id AND pricing_unit_id IS NULL;
    END LOOP;
END $$;

-- For order_items: map pricing_type_id to pricing_unit_id
UPDATE order_items oi
SET pricing_unit_id = psp.pricing_unit_id
FROM provider_service_prices psp
WHERE oi.pricing_type_id = psp.pricing_type_id
  AND oi.pricing_unit_id IS NULL;

-- Fallback: if order_items still has NULL pricing_unit_id, try to map from pricing_types directly
UPDATE order_items oi
SET pricing_unit_id = pu.id
FROM pricing_units pu
WHERE oi.pricing_unit_id IS NULL
  AND oi.pricing_type_id IN (
      SELECT pt.id FROM pricing_types pt
  )
  AND pu.name ILIKE '%' || (SELECT name FROM pricing_types pt WHERE pt.id = oi.pricing_type_id) || '%';

-- ============================================================
-- STEP 6: Add NOT NULL constraints after data migration
-- ============================================================

-- Make pricing_unit_id NOT NULL in provider_service_prices
ALTER TABLE provider_service_prices 
ALTER COLUMN pricing_unit_id SET NOT NULL;

-- Make pricing_unit_id NOT NULL in order_items
ALTER TABLE order_items 
ALTER COLUMN pricing_unit_id SET NOT NULL;

-- ============================================================
-- STEP 7: Add foreign key constraints
-- ============================================================

-- provider_service_prices -> pricing_units
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_price_pricing_unit'
    ) THEN
        ALTER TABLE provider_service_prices
            ADD CONSTRAINT fk_price_pricing_unit
            FOREIGN KEY (pricing_unit_id) REFERENCES pricing_units(id)
            ON DELETE NO ACTION ON UPDATE NO ACTION;
    END IF;
END $$;

-- provider_service_prices -> contract_types
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_price_contract_type'
    ) THEN
        ALTER TABLE provider_service_prices
            ADD CONSTRAINT fk_price_contract_type
            FOREIGN KEY (contract_type_id) REFERENCES contract_types(id)
            ON DELETE NO ACTION ON UPDATE NO ACTION;
    END IF;
END $$;

-- order_items -> pricing_units
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_item_pricing_unit'
    ) THEN
        ALTER TABLE order_items
            ADD CONSTRAINT fk_order_item_pricing_unit
            FOREIGN KEY (pricing_unit_id) REFERENCES pricing_units(id)
            ON DELETE NO ACTION ON UPDATE NO ACTION;
    END IF;
END $$;

-- order_items -> contract_types
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_item_contract_type'
    ) THEN
        ALTER TABLE order_items
            ADD CONSTRAINT fk_order_item_contract_type
            FOREIGN KEY (contract_type_id) REFERENCES contract_types(id)
            ON DELETE NO ACTION ON UPDATE NO ACTION;
    END IF;
END $$;

-- ============================================================
-- STEP 8: Drop old foreign keys and columns
-- ============================================================

-- Drop old FK constraints from provider_service_prices
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_price_type'
    ) THEN
        ALTER TABLE provider_service_prices DROP CONSTRAINT IF EXISTS fk_price_type;
    END IF;
END $$;

-- Drop old FK constraint from order_items
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_item_pricing_type'
    ) THEN
        ALTER TABLE order_items DROP CONSTRAINT IF EXISTS fk_order_item_pricing_type;
    END IF;
END $$;

-- Drop old pricing_type_id columns
ALTER TABLE provider_service_prices DROP COLUMN IF EXISTS pricing_type_id;
ALTER TABLE order_items DROP COLUMN IF EXISTS pricing_type_id;

-- ============================================================
-- STEP 9: Drop old pricing_types table
-- ============================================================
DROP TABLE IF EXISTS pricing_types CASCADE;

COMMIT;
