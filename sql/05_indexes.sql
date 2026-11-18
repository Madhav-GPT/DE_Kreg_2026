set search_path to olx;

create extension if not exists pg_trgm with schema olx;

-- R01, R02, R19, R24: active rows only. category and city are equals, then newest first
create index if not exists idx_listings_active_category_city_posted
  on listings (category_id, city_id, posted_at desc) where status = 'ACTIVE';

-- R03: GIN trigram is for ILIKE with text at both ends
create index if not exists idx_listings_active_title_trgm
  on listings using gin (title gin_trgm_ops) where status = 'ACTIVE';

-- R05 + W02: find a sellers ads fast. seller_id first since its always =
create index if not exists idx_listings_seller_status_listing
  on listings (seller_id, status, listing_id) include (view_count);

-- R08: category and model narrow it before the date order
create index if not exists idx_listings_category_model_posted
  on listings (category_id, (attributes ->> 'model'), posted_at);

-- R09: active furniture search uses category then latitude and longitude ranges
create index if not exists idx_listings_active_category_lat_lng
  on listings (category_id, latitude, longitude) where status = 'ACTIVE';

-- R10 + W04: active expiry dates are checked as a range
create index if not exists idx_listings_active_expires
  on listings (expires_at) where status = 'ACTIVE';

-- R14: sold_at is a date range after the rewrite, include the grouped columns
create index if not exists idx_listings_sold_at
  on listings (sold_at) include (category_id, posted_at) where status = 'SOLD';

-- R20 and R22: posted date and id match the report order and keyset cursor
create index if not exists idx_listings_posted_listing
  on listings (posted_at desc, listing_id desc);

-- R13: only rows with a package matter for the NOT EXISTS lookup
create index if not exists idx_listings_boost_package
  on listings (boost_package_id) where boost_package_id is not null;

-- R04 + R21: ratings are looked up by seller, stars can stay in the index
create index if not exists idx_seller_ratings_seller
  on seller_ratings (seller_id) include (stars);

-- R06, R19, R25: latest message is by thread then sent time
create index if not exists idx_msgs_thread_sent
  on chat_messages (thread_id, sent_at desc) include (sender_id);

-- R07: unread badge only needs the unread messages for a thread
create index if not exists idx_msgs_unread_thread
  on chat_messages (thread_id) where not is_read;

-- R06, R07 + W03: buyer is the equality check for their threads
create index if not exists idx_threads_buyer
  on chat_threads (buyer_id, thread_id);

-- R16: favourites are filtered by date and return listing ids
create index if not exists idx_favourites_saved
  on favourites (saved_at) include (listing_id);

-- R11: open reports are grouped by listing and need the reason too
create index if not exists idx_reports_open_listing
  on reports (listing_id) include (reason) where status = 'OPEN';

-- W05: pending offers for one listing are sorted by price then id
create index if not exists idx_offers_pending_listing_price
  on offers (listing_id, offer_price desc, offer_id) where status = 'PENDING';

vacuum analyze;
