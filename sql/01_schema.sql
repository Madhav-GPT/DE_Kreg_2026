-- =====================================================================
-- OLX Buy & Sell: schema rebuilt from the seed-data exports (Phase 2)
-- PostgreSQL 15+  (tested on PostgreSQL 18.6)
--
-- Rules followed in this phase:
--   * Only constraints: PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL, CHECK.
--   * No extra indexes. The only indexes are the ones PostgreSQL builds
--     automatically for PRIMARY KEY and UNIQUE constraints (listed at the end).
--   * Every constraint accepts all rows of seed_data/ (verified by loading).
--
-- ON DELETE policy (see docs/02_schema_design.md for the reasoning):
--   * Users are never hard-deleted (they are banned via is_banned), so any FK
--     that points at a user who is a *party* to someone else's data is RESTRICT.
--     Only a user's private bookmarks (favourites) CASCADE.
--   * Listings are soft-deleted (status = 'REMOVED'). If one is ever hard-deleted
--     (legal takedown), its favourites, chats and offers go with it (CASCADE),
--     but reports and ratings are evidence/reputation and block the delete (RESTRICT).
--   * Lookup tables (cities, categories, boost_packages) are RESTRICT, except
--     categories.parent_id which is SET NULL (sub-category is promoted to top level).
-- =====================================================================

DROP SCHEMA IF EXISTS olx CASCADE;
CREATE SCHEMA olx;
SET search_path TO olx;

-- ---------------------------------------------------------------------
-- cities (10 rows)
-- ---------------------------------------------------------------------
CREATE TABLE cities (
    city_id    smallint     PRIMARY KEY,
    city_name  varchar(50)  NOT NULL,
    state      varchar(50)  NOT NULL,
    CONSTRAINT cities_city_name_key UNIQUE (city_name),
    CONSTRAINT cities_name_not_blank CHECK (btrim(city_name) <> '' AND btrim(state) <> '')
);

-- ---------------------------------------------------------------------
-- categories (12 rows): two-level hierarchy, parent_id NULL = top level
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    category_id    smallint     PRIMARY KEY,
    category_name  varchar(50)  NOT NULL,
    parent_id      smallint     NULL
        REFERENCES categories (category_id) ON DELETE SET NULL,
    CONSTRAINT categories_category_name_key UNIQUE (category_name),
    CONSTRAINT categories_not_own_parent CHECK (parent_id IS NULL OR parent_id <> category_id)
);

-- ---------------------------------------------------------------------
-- boost_packages (6 rows): paid promotion products
-- ---------------------------------------------------------------------
CREATE TABLE boost_packages (
    package_id     smallint      PRIMARY KEY,
    package_name   varchar(50)   NOT NULL,
    price          numeric(8,2)  NOT NULL,
    duration_days  smallint      NOT NULL,
    CONSTRAINT boost_packages_package_name_key UNIQUE (package_name),
    CONSTRAINT boost_packages_price_positive   CHECK (price > 0),
    CONSTRAINT boost_packages_duration_range   CHECK (duration_days BETWEEN 1 AND 365)
);

-- ---------------------------------------------------------------------
-- users (50,000 rows)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id         integer       PRIMARY KEY,
    full_name       varchar(100)  NOT NULL,
    phone           varchar(10)   NOT NULL,
    email           varchar(255)  NULL,            -- optional: ~50% of users signed up with phone only
    city_id         smallint      NOT NULL REFERENCES cities (city_id) ON DELETE RESTRICT,
    phone_verified  boolean       NOT NULL DEFAULT false,
    is_banned       boolean       NOT NULL DEFAULT false,
    joined_at       timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT users_phone_key        UNIQUE (phone),
    CONSTRAINT users_email_key        UNIQUE (email),
    CONSTRAINT users_phone_format     CHECK (phone ~ '^[6-9][0-9]{9}$'),            -- Indian 10-digit mobile
    CONSTRAINT users_email_format     CHECK (email IS NULL OR email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT users_email_lowercase  CHECK (email IS NULL OR email = lower(email)), -- makes UNIQUE case-insensitive in practice
    CONSTRAINT users_name_not_blank   CHECK (btrim(full_name) <> '')
);

-- ---------------------------------------------------------------------
-- listings (120,000 rows): the ads
-- ---------------------------------------------------------------------
CREATE TABLE listings (
    listing_id        integer        PRIMARY KEY,
    seller_id         integer        NOT NULL REFERENCES users (user_id)              ON DELETE RESTRICT,
    category_id       smallint       NOT NULL REFERENCES categories (category_id)     ON DELETE RESTRICT,
    title             varchar(150)   NOT NULL,
    description       text           NULL,         -- optional free text (~20% of ads have none)
    price             numeric(12,2)  NOT NULL,     -- rupees, exact decimal (never float for money)
    is_negotiable     boolean        NOT NULL DEFAULT false,
    item_condition    varchar(10)    NOT NULL,
    attributes        jsonb          NOT NULL DEFAULT '{}'::jsonb,   -- category-specific details
    city_id           smallint       NOT NULL REFERENCES cities (city_id)             ON DELETE RESTRICT,
    locality          varchar(50)    NOT NULL,
    latitude          numeric(9,6)   NOT NULL,
    longitude         numeric(9,6)   NOT NULL,
    image_count       smallint       NOT NULL DEFAULT 0,
    view_count        integer        NOT NULL DEFAULT 0,
    boost_package_id  smallint       NULL     REFERENCES boost_packages (package_id) ON DELETE RESTRICT,
    status            varchar(10)    NOT NULL DEFAULT 'ACTIVE',
    posted_at         timestamptz    NOT NULL DEFAULT now(),
    expires_at        timestamptz    NOT NULL,
    sold_at           timestamptz    NULL,          -- set only when status = 'SOLD'
    CONSTRAINT listings_title_not_blank       CHECK (btrim(title) <> ''),
    CONSTRAINT listings_price_positive        CHECK (price > 0),
    CONSTRAINT listings_condition_valid       CHECK (item_condition IN ('NEW', 'LIKE_NEW', 'GOOD', 'FAIR')),
    CONSTRAINT listings_status_valid          CHECK (status IN ('ACTIVE', 'SOLD', 'EXPIRED', 'REMOVED')),
    CONSTRAINT listings_attributes_is_object  CHECK (jsonb_typeof(attributes) = 'object'),
    CONSTRAINT listings_latitude_india        CHECK (latitude  BETWEEN 6 AND 38),   -- India bounding box
    CONSTRAINT listings_longitude_india       CHECK (longitude BETWEEN 68 AND 98),
    CONSTRAINT listings_image_count_range     CHECK (image_count BETWEEN 0 AND 20),
    CONSTRAINT listings_view_count_nonneg     CHECK (view_count >= 0),
    CONSTRAINT listings_expiry_after_post     CHECK (expires_at > posted_at),
    CONSTRAINT listings_sold_iff_sold_at      CHECK ((status = 'SOLD') = (sold_at IS NOT NULL)),
    CONSTRAINT listings_sold_after_post       CHECK (sold_at IS NULL OR sold_at >= posted_at)
);

-- ---------------------------------------------------------------------
-- chat_threads (59,855 rows): one conversation per (ad, buyer)
-- ---------------------------------------------------------------------
CREATE TABLE chat_threads (
    thread_id   integer      PRIMARY KEY,
    listing_id  integer      NOT NULL REFERENCES listings (listing_id) ON DELETE CASCADE,
    buyer_id    integer      NOT NULL REFERENCES users (user_id)       ON DELETE RESTRICT,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT chat_threads_listing_buyer_key UNIQUE (listing_id, buyer_id)  -- no second chat about the same ad
);

-- ---------------------------------------------------------------------
-- chat_messages (209,529 rows)
-- ---------------------------------------------------------------------
CREATE TABLE chat_messages (
    message_id  integer      PRIMARY KEY,
    thread_id   integer      NOT NULL REFERENCES chat_threads (thread_id) ON DELETE CASCADE,
    sender_id   integer      NOT NULL REFERENCES users (user_id)          ON DELETE RESTRICT,
    body        text         NOT NULL,
    sent_at     timestamptz  NOT NULL DEFAULT now(),
    is_read     boolean      NOT NULL DEFAULT false,   -- a new message starts unread (W03 relies on this)
    CONSTRAINT chat_messages_body_length CHECK (btrim(body) <> '' AND length(body) <= 4000)
);

-- ---------------------------------------------------------------------
-- offers (19,943 rows): a buyer may make several offers on the same ad
-- ---------------------------------------------------------------------
CREATE TABLE offers (
    offer_id      integer        PRIMARY KEY,
    listing_id    integer        NOT NULL REFERENCES listings (listing_id) ON DELETE CASCADE,
    buyer_id      integer        NOT NULL REFERENCES users (user_id)       ON DELETE RESTRICT,
    offer_price   numeric(12,2)  NOT NULL,
    status        varchar(10)    NOT NULL DEFAULT 'PENDING',
    created_at    timestamptz    NOT NULL DEFAULT now(),
    responded_at  timestamptz    NULL,              -- empty while the seller has not answered
    CONSTRAINT offers_price_positive          CHECK (offer_price > 0),
    CONSTRAINT offers_status_valid            CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'COUNTERED')),
    CONSTRAINT offers_pending_iff_unanswered  CHECK ((status = 'PENDING') = (responded_at IS NULL)),
    CONSTRAINT offers_response_after_offer    CHECK (responded_at IS NULL OR responded_at >= created_at)
);

-- ---------------------------------------------------------------------
-- favourites (70,000 rows): M:N users <-> listings
-- ---------------------------------------------------------------------
CREATE TABLE favourites (
    user_id     integer      NOT NULL REFERENCES users (user_id)       ON DELETE CASCADE,
    listing_id  integer      NOT NULL REFERENCES listings (listing_id) ON DELETE CASCADE,
    saved_at    timestamptz  NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, listing_id)            -- an ad is saved at most once per user
);

-- ---------------------------------------------------------------------
-- reports (7,999 rows): Trust & Safety reports
-- ---------------------------------------------------------------------
CREATE TABLE reports (
    report_id    integer      PRIMARY KEY,
    listing_id   integer      NOT NULL REFERENCES listings (listing_id) ON DELETE RESTRICT,
    reporter_id  integer      NOT NULL REFERENCES users (user_id)       ON DELETE RESTRICT,
    reason       varchar(20)  NOT NULL,
    created_at   timestamptz  NOT NULL DEFAULT now(),
    status       varchar(10)  NOT NULL DEFAULT 'OPEN',
    CONSTRAINT reports_listing_reporter_key UNIQUE (listing_id, reporter_id),  -- one report per user per ad
    CONSTRAINT reports_reason_valid CHECK (reason IN ('SPAM', 'FRAUD', 'OFFENSIVE', 'WRONG_CATEGORY', 'ALREADY_SOLD')),
    CONSTRAINT reports_status_valid CHECK (status IN ('OPEN', 'ACTIONED', 'DISMISSED'))
);

-- ---------------------------------------------------------------------
-- seller_ratings (11,244 rows): rating of the seller after a deal
-- ---------------------------------------------------------------------
CREATE TABLE seller_ratings (
    rating_id   integer       PRIMARY KEY,
    seller_id   integer       NOT NULL REFERENCES users (user_id)       ON DELETE RESTRICT,
    rater_id    integer       NOT NULL REFERENCES users (user_id)       ON DELETE RESTRICT,
    listing_id  integer       NOT NULL REFERENCES listings (listing_id) ON DELETE RESTRICT,
    stars       smallint      NOT NULL,
    comment     varchar(500)  NULL,                 -- optional review text
    created_at  timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT seller_ratings_listing_rater_key UNIQUE (listing_id, rater_id),  -- same deal rated once per rater
    CONSTRAINT seller_ratings_stars_range       CHECK (stars BETWEEN 1 AND 5),
    CONSTRAINT seller_ratings_not_self          CHECK (rater_id <> seller_id)
);

-- ---------------------------------------------------------------------
-- Indexes that exist after this script (all created automatically):
--   cities_pkey, cities_city_name_key
--   categories_pkey, categories_category_name_key
--   boost_packages_pkey, boost_packages_package_name_key
--   users_pkey, users_phone_key, users_email_key
--   listings_pkey
--   chat_threads_pkey, chat_threads_listing_buyer_key
--   chat_messages_pkey
--   offers_pkey
--   favourites_pkey (user_id, listing_id)
--   reports_pkey, reports_listing_reporter_key
--   seller_ratings_pkey, seller_ratings_listing_rater_key
-- No foreign-key column has its own index yet: that is Phase 4.
-- ---------------------------------------------------------------------
