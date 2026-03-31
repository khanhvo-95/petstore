-- =============================================
-- DDL Script for PetStore Pet Service
-- Azure Database for PostgreSQL
-- =============================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS petstore;

-- Categories table
CREATE TABLE IF NOT EXISTS petstore.categories (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL
);

-- Tags table
CREATE TABLE IF NOT EXISTS petstore.tags (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL
);

-- Pets table
CREATE TABLE IF NOT EXISTS petstore.pets (
    id          BIGSERIAL PRIMARY KEY,
    category_id BIGINT REFERENCES petstore.categories(id),
    name        VARCHAR(255) NOT NULL,
    photo_url   VARCHAR(500) NOT NULL,
    status      VARCHAR(50) NOT NULL DEFAULT 'available'
);

-- Pet-Tag join table (many-to-many)
CREATE TABLE IF NOT EXISTS petstore.pet_tags (
    pet_id      BIGINT NOT NULL REFERENCES petstore.pets(id) ON DELETE CASCADE,
    tag_id      BIGINT NOT NULL REFERENCES petstore.tags(id) ON DELETE CASCADE,
    PRIMARY KEY (pet_id, tag_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pets_status ON petstore.pets(status);
CREATE INDEX IF NOT EXISTS idx_pets_category ON petstore.pets(category_id);
