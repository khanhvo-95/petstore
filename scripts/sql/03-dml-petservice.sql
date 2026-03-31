-- =============================================
-- DML Script for PetStore Pet Service
-- Seed data for pets, categories, and tags
-- =============================================

-- Insert Categories
INSERT INTO petstore.categories (id, name) VALUES (1, 'Dog') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.categories (id, name) VALUES (2, 'Cat') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.categories (id, name) VALUES (3, 'Fish') ON CONFLICT (id) DO NOTHING;

-- Insert Tags
INSERT INTO petstore.tags (id, name) VALUES (1, 'doggie') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.tags (id, name) VALUES (2, 'large') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.tags (id, name) VALUES (3, 'small') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.tags (id, name) VALUES (4, 'kittie') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.tags (id, name) VALUES (5, 'fishy') ON CONFLICT (id) DO NOTHING;

-- Insert Dogs
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (1, 1, 'Afador', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/afador.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (2, 1, 'American Bulldog', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/american-bulldog.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (3, 1, 'Australian Retriever', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/australian-retriever.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (4, 1, 'Australian Shepherd', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/australian-shepherd.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (5, 1, 'Basset Hound', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/basset-hound.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (6, 1, 'Beagle', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/beagle.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (7, 1, 'Border Terrier', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/border-terrier.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (8, 1, 'Boston Terrier', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/boston-terrier.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (9, 1, 'Bulldog', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/bulldog.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (10, 1, 'Bullmastiff', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/bullmastiff.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (11, 1, 'Chihuahua', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/chihuahua.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (12, 1, 'Cocker Spaniel', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/cocker-spaniel.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (13, 1, 'German Sheperd', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/german-shepherd.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (14, 1, 'Labrador Retriever', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/labrador-retriever.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (15, 1, 'Pomeranian', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/pomeranian.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (16, 1, 'Pug', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/pug.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (17, 1, 'Rottweiler', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/rottweiler.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (18, 1, 'Shetland Sheepdog', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/shetland-sheepdog.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (19, 1, 'Shih Tzu', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/shih-tzu.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (20, 1, 'Toy Fox Terrier', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/dog-breeds/toy-fox-terrier.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;

-- Insert Cats
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (21, 2, 'Abyssinian', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/abyssinian.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (22, 2, 'American Bobtail', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/american-bobtail.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (23, 2, 'American Shorthair', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/american-shorthair.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (24, 2, 'Balinese', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/balinese.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (25, 2, 'Birman', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/birman.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (26, 2, 'Bombay', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/bombay.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (27, 2, 'British Shorthair', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/british-shorthair.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (28, 2, 'Burmilla', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/burmilla.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (29, 2, 'Chartreux', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/chartreux.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (30, 2, 'Cornish Rex', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/cat-breeds/cornish-rex.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;

-- Insert Fish
INSERT INTO petstore.pets (id, category_id, name, photo_url, status) VALUES (31, 3, 'Goldfish', 'https://raw.githubusercontent.com/chtrembl/staticcontent/master/fish-breeds/goldfish.jpg?raw=true', 'available') ON CONFLICT (id) DO NOTHING;

-- Insert Pet-Tag associations
-- Dogs get tags: doggie + large/small
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (1, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (1, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (2, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (2, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (3, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (3, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (4, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (4, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (5, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (5, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (6, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (6, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (7, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (7, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (8, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (8, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (9, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (9, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (10, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (10, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (11, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (11, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (12, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (12, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (13, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (13, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (14, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (14, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (15, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (15, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (16, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (16, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (17, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (17, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (18, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (18, 2) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (19, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (19, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (20, 1) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (20, 3) ON CONFLICT DO NOTHING;

-- Cats get tags: kittie + small
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (21, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (21, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (22, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (22, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (23, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (23, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (24, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (24, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (25, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (25, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (26, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (26, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (27, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (27, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (28, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (28, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (29, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (29, 3) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (30, 4) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (30, 3) ON CONFLICT DO NOTHING;

-- Fish get tags: fishy + small
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (31, 5) ON CONFLICT DO NOTHING;
INSERT INTO petstore.pet_tags (pet_id, tag_id) VALUES (31, 3) ON CONFLICT DO NOTHING;

-- Reset sequences
SELECT setval('petstore.categories_id_seq', (SELECT MAX(id) FROM petstore.categories));
SELECT setval('petstore.tags_id_seq', (SELECT MAX(id) FROM petstore.tags));
SELECT setval('petstore.pets_id_seq', (SELECT MAX(id) FROM petstore.pets));
