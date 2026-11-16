-- =====================================================================
-- OLX Buy & Sell: load the seed data (Phase 2)
-- Run from the project root (the folder that contains seed_data/):
--   psql -d <db> -f sql/01_schema.sql
--   psql -d <db> -f sql/02_load_data.sql
-- For the large dataset, change only the folder name seed_data -> large_data.
-- Order: parents before children so every FOREIGN KEY is satisfied.
-- =====================================================================
\set ON_ERROR_STOP on
SET search_path TO olx;

BEGIN;
-- 1. lookup tables
\copy cities         FROM 'seed_data/cities.csv'         WITH (FORMAT csv, HEADER true)
\copy categories     FROM 'seed_data/categories.csv'     WITH (FORMAT csv, HEADER true)
\copy boost_packages FROM 'seed_data/boost_packages.csv' WITH (FORMAT csv, HEADER true)
-- 2. users (-> cities)
\copy users          FROM 'seed_data/users.csv'          WITH (FORMAT csv, HEADER true)
-- 3. listings (-> users, categories, cities, boost_packages)
\copy listings       FROM 'seed_data/listings.csv'       WITH (FORMAT csv, HEADER true)
-- 4. children of listings / users
\copy chat_threads   FROM 'seed_data/chat_threads.csv'   WITH (FORMAT csv, HEADER true)
\copy chat_messages  FROM 'seed_data/chat_messages.csv'  WITH (FORMAT csv, HEADER true)
\copy offers         FROM 'seed_data/offers.csv'         WITH (FORMAT csv, HEADER true)
\copy favourites     FROM 'seed_data/favourites.csv'     WITH (FORMAT csv, HEADER true)
\copy reports        FROM 'seed_data/reports.csv'        WITH (FORMAT csv, HEADER true)
\copy seller_ratings FROM 'seed_data/seller_ratings.csv' WITH (FORMAT csv, HEADER true)
COMMIT;

ANALYZE;

-- ---------------------------------------------------------------------
-- Row counts (expected: 10, 12, 6, 50000, 120000, 59855, 209529, 19943, 70000, 7999, 11244)
-- ---------------------------------------------------------------------
SELECT 'cities' AS table_name, count(*) AS row_count FROM cities
UNION ALL SELECT 'categories',     count(*) FROM categories
UNION ALL SELECT 'boost_packages', count(*) FROM boost_packages
UNION ALL SELECT 'users',          count(*) FROM users
UNION ALL SELECT 'listings',       count(*) FROM listings
UNION ALL SELECT 'chat_threads',   count(*) FROM chat_threads
UNION ALL SELECT 'chat_messages',  count(*) FROM chat_messages
UNION ALL SELECT 'offers',         count(*) FROM offers
UNION ALL SELECT 'favourites',     count(*) FROM favourites
UNION ALL SELECT 'reports',        count(*) FROM reports
UNION ALL SELECT 'seller_ratings', count(*) FROM seller_ratings;

-- ---------------------------------------------------------------------
-- Integrity checks (cross-table rules a CHECK constraint cannot express).
-- Each returns the number of violating rows; 0 = rule holds.
-- ---------------------------------------------------------------------
-- IC1  a buyer never chats about their own ad
SELECT 'IC1 buyer chats about own ad' AS check_name, count(*) AS violations
FROM chat_threads t JOIN listings l ON l.listing_id = t.listing_id
WHERE t.buyer_id = l.seller_id
UNION ALL
-- IC2  every message sender is the thread's buyer or the ad's seller
SELECT 'IC2 sender is neither buyer nor seller', count(*)
FROM chat_messages m
JOIN chat_threads t ON t.thread_id = m.thread_id
JOIN listings l     ON l.listing_id = t.listing_id
WHERE m.sender_id NOT IN (t.buyer_id, l.seller_id)
UNION ALL
-- IC3  no message is older than its thread, no thread older than its ad
SELECT 'IC3 message before thread / thread before ad', count(*)
FROM chat_messages m
JOIN chat_threads t ON t.thread_id = m.thread_id
JOIN listings l     ON l.listing_id = t.listing_id
WHERE m.sent_at < t.created_at OR t.created_at < l.posted_at
UNION ALL
-- IC4  seller_ratings.seller_id is the listing's seller (redundant column stays consistent)
SELECT 'IC4 rating seller <> listing seller', count(*)
FROM seller_ratings r JOIN listings l ON l.listing_id = r.listing_id
WHERE r.seller_id <> l.seller_id
UNION ALL
-- IC5  only SOLD ads are rated, and never before the sale
SELECT 'IC5 rating on unsold ad / before sale', count(*)
FROM seller_ratings r JOIN listings l ON l.listing_id = r.listing_id
WHERE l.status <> 'SOLD' OR r.created_at < l.sold_at
UNION ALL
-- IC6  a seller never makes an offer on their own ad
SELECT 'IC6 offer on own ad', count(*)
FROM offers o JOIN listings l ON l.listing_id = o.listing_id
WHERE o.buyer_id = l.seller_id
UNION ALL
-- IC7  a seller never reports their own ad
SELECT 'IC7 report on own ad', count(*)
FROM reports r JOIN listings l ON l.listing_id = r.listing_id
WHERE r.reporter_id = l.seller_id
UNION ALL
-- IC8  every rater actually chatted with the seller about that ad
SELECT 'IC8 rater never chatted about the ad', count(*)
FROM seller_ratings r
WHERE NOT EXISTS (SELECT 1 FROM chat_threads t WHERE t.listing_id = r.listing_id AND t.buyer_id = r.rater_id)
UNION ALL
-- IC9  (data problem) a user saves their own ad to favourites
SELECT 'IC9 favourite on own ad (data problem)', count(*)
FROM favourites f JOIN listings l ON l.listing_id = f.listing_id
WHERE f.user_id = l.seller_id
UNION ALL
-- IC10 (data problem) ad posted before the seller's account was created
SELECT 'IC10 ad posted before seller joined (data problem)', count(*)
FROM listings l JOIN users u ON u.user_id = l.seller_id
WHERE l.posted_at < u.joined_at
UNION ALL
-- IC11 (data problem) more than one ACCEPTED offer on the same ad
SELECT 'IC11 ads with >1 accepted offer (data problem)', count(*)
FROM (SELECT listing_id FROM offers WHERE status = 'ACCEPTED' GROUP BY listing_id HAVING count(*) > 1) x
UNION ALL
-- IC12 (data problem) banned users who still have ACTIVE ads
SELECT 'IC12 active ads of banned sellers (data problem)', count(*)
FROM listings l JOIN users u ON u.user_id = l.seller_id
WHERE u.is_banned AND l.status = 'ACTIVE'
UNION ALL
-- IC13 (stale data) ACTIVE ads already past expiry on 2026-07-01 (W04 fixes these)
SELECT 'IC13 active but already expired at 2026-07-01', count(*)
FROM listings
WHERE status = 'ACTIVE' AND expires_at < '2026-07-01 00:00:00+05:30';
