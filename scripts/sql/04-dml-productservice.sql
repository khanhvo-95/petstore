-- =============================================
-- DML Script for PetStore Product Service
-- Seed data for products, categories, and tags
-- =============================================

-- Insert Product Categories
INSERT INTO petstore.product_categories (id, name) VALUES (1, 'Dog Toy') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.product_categories (id, name) VALUES (2, 'Dog Food') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.product_categories (id, name) VALUES (3, 'Cat Toy') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.product_categories (id, name) VALUES (4, 'Cat Food') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.product_categories (id, name) VALUES (5, 'Fish Toy') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.product_categories (id, name) VALUES (6, 'Fish Food') ON CONFLICT (id) DO NOTHING;

-- Insert Product Tags
INSERT INTO petstore.product_tags_ref (id, name) VALUES (1, 'small') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.product_tags_ref (id, name) VALUES (2, 'large') ON CONFLICT (id) DO NOTHING;

-- Insert Products
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (1, 1, 'Ball', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-toys/ball.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (2, 1, 'Ball Launcher', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-toys/ball-launcher.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (3, 1, 'Plush Lamb', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-toys/plush-lamb.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (4, 1, 'Plush Moose', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-toys/plush-moose.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (5, 2, 'Large Breed Dry Food', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-food/large-dog.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (6, 2, 'Small Breed Dry Food', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-food/small-dog.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (7, 3, 'Mouse', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-toys/mouse.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (8, 3, 'Scratcher', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-toys/scratcher.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (9, 4, 'All Sizes Cat Dry Food', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-food/cat.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (10, 5, 'Mangrove Ornament', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/fish-toys/mangrove.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.products (id, category_id, name, photo_url, status) VALUES (11, 6, 'All Sizes Fish Food', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/fish-food/fish.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;

-- Insert Product-Tag associations
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (1, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (1, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (2, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (3, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (3, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (4, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (4, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (5, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (6, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (7, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (7, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (8, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (8, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (9, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (9, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (10, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (10, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (11, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.product_tag_map (product_id, tag_id) VALUES (11, 2) ON CONFLICT DO NOTHING;

-- Reset sequences
SELECT setval('petstore.product_categories_id_seq', (SELECT MAX(id) FROM petstore.product_categories));
SELECT setval('petstore.product_tags_ref_id_seq', (SELECT MAX(id) FROM petstore.product_tags_ref));
SELECT setval('petstore.products_id_seq', (SELECT MAX(id) FROM petstore.products));
