-- Migration: Remove pricing_types.description and add order_items FK
-- Safe to run: uses IF EXISTS / IF NOT EXISTS guards

-- 1. Drop description column from pricing_types (unused field)
ALTER TABLE pricing_types DROP COLUMN IF EXISTS description;

-- 2. Add FK constraint from order_items.pricing_type_id to pricing_types.id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_item_pricing_type'
    ) THEN
        ALTER TABLE order_items
            ADD CONSTRAINT fk_order_item_pricing_type
            FOREIGN KEY (pricing_type_id) REFERENCES pricing_types(id)
            ON DELETE NO ACTION ON UPDATE NO ACTION;
    END IF;
END $$;
