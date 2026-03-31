-- =============================================
-- DDL Script for PetStore Product Service
-- Azure Database for PostgreSQL
-- =============================================

-- Create schema (idempotent)
CREATE SCHEMA IF NOT EXISTS petstore;

-- Product Categories table
CREATE TABLE IF NOT EXISTS petstore.product_categories (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL
);

-- Product Tags table
CREATE TABLE IF NOT EXISTS petstore.product_tags_ref (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL
);

-- Products table
CREATE TABLE IF NOT EXISTS petstore.products (
    id          BIGSERIAL PRIMARY KEY,
    category_id BIGINT REFERENCES petstore.product_categories(id),
    name        VARCHAR(255) NOT NULL,
    photo_url   VARCHAR(500) NOT NULL,
    status      VARCHAR(50) NOT NULL DEFAULT 'available'
);

-- Product-Tag join table (many-to-many)
CREATE TABLE IF NOT EXISTS petstore.product_tag_map (
    product_id  BIGINT NOT NULL REFERENCES petstore.products(id) ON DELETE CASCADE,
    tag_id      BIGINT NOT NULL REFERENCES petstore.product_tags_ref(id) ON DELETE CASCADE,
    PRIMARY KEY (product_id, tag_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_products_status ON petstore.products(status);
CREATE INDEX IF NOT EXISTS idx_products_category ON petstore.products(category_id);
