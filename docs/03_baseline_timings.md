# 03 · Baseline timings (Phase 3)

All 30 queries from `queries/workload_30.sql` were run **unchanged** with `./benchmarks/run_benchmark.sh olx baseline`. Each query ran 3 times with `EXPLAIN (ANALYZE, BUFFERS)`. Write queries ran inside `BEGIN … ROLLBACK`. Every number below is copied by script from the `Execution Time` lines in [`benchmarks/results/baseline/`](../benchmarks/results/baseline/) (raw plans `R01.txt` … `W05.txt`, and [`summary.csv`](../benchmarks/results/baseline/summary.csv)).

**Setup:** PostgreSQL 18.6 on an Apple M4 laptop (16 GB RAM, macOS). Default server settings (`shared_buffers = 128MB`, `work_mem = 4MB`, `max_parallel_workers_per_gather = 2`). The database was created with `sql/01_schema.sql` and loaded with `sql/02_load_data.sql` (which ends with `ANALYZE`). No VACUUM, and **no indexes except the automatic PK/UNIQUE ones**. Run 1 is the first execution after loading (slightly colder cache), as the method requires.

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Browse: active cars in Bengaluru priced ₹3–6 lakh, newest first | READ | 8.387 | 6.967 | 6.188 | 7.181 |
| R02: Car filters: diesel cars from 2018 or later with at most 60,000 km, in Pune | READ | 5.542 | 5.153 | 5.998 | 5.564 |
| R03: Search: active "iPhone 13" ads anywhere, cheapest first | READ | 19.563 | 19.204 | 20.297 | 19.688 |
| R04: Ad page: listing 100871 with its seller and the seller's average rating | READ | 0.591 | 0.371 | 0.411 | 0.458 |
| R05: "My Ads": user 1042's listings grouped by status | READ | 8.804 | 8.417 | 8.298 | 8.506 |
| R06: Chat inbox: every conversation of user 1042 (as buyer or seller) with its latest message | READ | 92.698 | 81.313 | 78.413 | 84.141 |
| R07: Chat badge: unread messages sent to user 1042 | READ | 4.986 | 4.957 | 5.575 | 5.173 |
| R08: Price guide: median asking price of iPhone 13 ads by condition (2026) | READ | 5.823 | 5.404 | 5.353 | 5.527 |
| R09: "Near me": active furniture within ~2 km of central Bengaluru (12.9716, 77.5946) | READ | 6.266 | 6.118 | 6.287 | 6.224 |
| R10: Reminder job: active ads that expire in the first 3 days of July 2026 | READ | 5.303 | 5.280 | 5.182 | 5.255 |
| R11: Moderation queue: ads with 3 or more open reports | READ | 2.135 | 1.788 | 1.675 | 1.866 |
| R12: Spam detection: users who posted 5 or more ads on the same day | READ | 33.121 | 32.301 | 33.113 | 32.845 |
| R13: Monetisation: boost packages that no ad has ever bought | READ | 13.119 | 13.157 | 13.621 | 13.299 |
| R14: Category insights: average days to sell per category for ads sold in 2026 | READ | 8.204 | 8.222 | 8.136 | 8.187 |
| R15: Marketplace health: share of offers accepted, per category | READ | 10.900 | 10.902 | 11.028 | 10.943 |
| R16: Trending: active ads saved to favourites most in the last 7 days of June 2026 | READ | 11.342 | 10.956 | 10.958 | 11.085 |
| R17: Monetisation: average views of boosted vs normal ads per category | READ | 11.125 | 11.105 | 11.130 | 11.120 |
| R18: Quality: the same seller posting the same title at the same price more than once | READ | 32.827 | 33.260 | 32.591 | 32.893 |
| R19: City report: chats and latest chat time for every active car ad in Bengaluru | READ | 1105.979 | 1097.713 | 1101.094 | 1101.595 |
| R20: Growth: new ads per day and running total, June 2026 | READ | 7.072 | 6.910 | 6.887 | 6.956 |
| R21: Trust: best-rated sellers (at least 5 ratings) | READ | 8.021 | 7.780 | 7.786 | 7.862 |
| R22: Moderation console: all ads, newest first, page 2,001 (25 per page) | READ | 30.118 | 29.120 | 31.180 | 30.139 |
| R23: Login with mobile number | READ | 0.025 | 0.019 | 0.018 | 0.021 |
| R24: Home page: active ads per top-level category (sub-categories rolled up) | READ | 10.548 | 10.561 | 10.885 | 10.665 |
| R25: Seller responsiveness: average minutes from a buyer's first message to the seller's first reply, per category (2026) | READ | 55.234 | 56.815 | 55.969 | 56.006 |
| W01: Post an ad: user 1042 sells a study table in Bengaluru | WRITE | 0.641 | 0.600 | 0.570 | 0.604 |
| W02: Mark as sold: user 1042's oldest active ad | WRITE | 8.249 | 8.287 | 8.202 | 8.246 |
| W03: Chat: user 1042 sends a message in their most recent conversation as a buyer | WRITE | 0.505 | 0.478 | 0.460 | 0.481 |
| W04: Nightly job: expire every active ad whose expiry date has passed (run at 00:00 on 1 July 2026) | WRITE | 17.248 | 17.027 | 16.421 | 16.899 |
| W05: Seller accepts the highest pending offer on listing 118642 and rejects the others | WRITE | 1.125 | 1.038 | 1.050 | 1.071 |
| **Total (sum of all 30)** | | **1525.501** | **1501.223** | **1504.776** | **1510.500** |

R19 alone takes **1102 ms of the 1510 ms total (73%)**. This is the query the brief warns is "noticeably longer". The other 29 queries add up to 409 ms.

## Scan type and why it is slow or fast

Scan nodes are the `scan_nodes` column of `summary.csv` (taken from the last run's plan). The class is the target group from README §5.2.

| Query | Class | Avg (ms) | Scan type(s) in the plan | Why |
|---|---|---:|---|---|
| R01 | real-time | 7.181 | Seq Scan on listings | All 120,000 ads are read and filtered down to the active Bengaluru cars in the price band, then a top-N sort picks 40. There is no index on category/city/status. |
| R02 | real-time | 5.564 | Seq Scan on listings | Same full scan as R01. The JSON filters (`fuel`, `year`, `km_driven`) can only be checked row by row. |
| R03 | real-time | 19.688 | Seq Scan on listings | `ILIKE '%iphone 13%'` has a leading wildcard, so a B-tree cannot help. Every title is pattern-matched (the most expensive per-row filter in the workload). |
| R04 | real-time | 0.458 | Index Scan using listings_pkey on listings<br>Index Scan using users_pkey on users<br>Seq Scan on seller_ratings | Fast: primary-key lookups on `listings` and `users`. But the rating subquery scans all 11k `seller_ratings`, because `seller_id` has no index, so it grows with the table. |
| R05 | real-time | 8.506 | Seq Scan on listings | The whole table is scanned to find the few ads of one seller. There is no index on `seller_id`. |
| R06 | real-time | 84.141 | Seq Scan on chat_threads<br>Seq Scan on listings<br>Seq Scan on chat_messages | The `OR` across two tables (`t.buyer_id` / `l.seller_id`) forces a hash join of all 59,855 threads with all 120,000 listings. Then, for each of the 13 threads, all 209,529 messages are scanned to find the latest one (no index on `chat_messages.thread_id`). |
| R07 | real-time | 5.173 | Seq Scan on chat_messages<br>Index Scan using chat_threads_pkey on chat_threads<br>Index Scan using listings_pkey on listings | All 209,529 messages are scanned (in parallel) to find the 258 unread ones, followed by PK lookups. Fast only because unread messages are rare. |
| R08 | report | 5.527 | Seq Scan on listings | Full scan. `attributes ->> 'model'` is computed for every Mobiles row. |
| R09 | real-time | 6.224 | Seq Scan on listings | Full scan. The latitude/longitude bounding box has no index, so the distance formula is applied after filtering every row. |
| R10 | interactive | 5.255 | Seq Scan on listings | Full scan. There is no index on `expires_at`, so all ads are checked for the 3-day window. |
| R11 | interactive | 1.866 | Seq Scan on reports<br>Index Scan using listings_pkey on listings | Small table: a seq scan of 7,999 reports, keeping 816 OPEN ones, then PK lookups into listings. Grows linearly with reports. |
| R12 | report | 32.845 | Seq Scan on listings | Full scan plus a hash aggregate over every (seller, day) pair. This must read the whole table by definition. |
| R13 | interactive | 13.299 | Seq Scan on boost_packages<br>Seq Scan on listings | Full scan of 120k `boost_package_id` values into a hashed subplan. **It also returns 0 rows, which is wrong:** `NOT IN` against a list that contains NULLs is never TRUE (Phase 4). |
| R14 | report | 8.187 | Seq Scan on listings<br>Seq Scan on categories | Full scan. `EXTRACT(YEAR FROM sold_at) = 2026` wraps the column in a function, so no index could be used even if one existed (not sargable). |
| R15 | report | 10.943 | Seq Scan on listings<br>Seq Scan on offers<br>Seq Scan on categories | Seq scans of all offers and all listings, hash-joined. An aggregate over every offer, so most of the data must be read. |
| R16 | interactive | 11.085 | Seq Scan on listings<br>Seq Scan on favourites | Seq scan of favourites (no index on `saved_at`) and of all listings to keep the ACTIVE ones, then hash join and sort. |
| R17 | report | 11.120 | Seq Scan on listings<br>Seq Scan on categories | Full scan and aggregate over all listings. Every ad is needed, so it can only be made cheaper, not avoided. |
| R18 | report | 32.893 | Seq Scan on listings | Full scan plus a hash aggregate on (seller, title, price) over every ad. |
| R19 | report | 1101.595 | Seq Scan on listings<br>Index Only Scan using chat_threads_listing_buyer_key on chat_threads<br>Seq Scan on chat_messages<br>Index Scan using chat_threads_listing_buyer_key on chat_threads | **The slow query.** For each of the 279 active Bengaluru car ads, a correlated subquery hash-joins the *entire* 209,529-row `chat_messages` table (no index on `thread_id`). That means 120 full scans of the biggest table. |
| R20 | report | 6.956 | Seq Scan on listings | `posted_at::date BETWEEN …` casts the column, which is not sargable, so the whole table is scanned. |
| R21 | report | 7.862 | Seq Scan on seller_ratings<br>Seq Scan on users | Seq scans of `seller_ratings` and `users` with a hash aggregate. The tables are small today. |
| R22 | interactive | 30.139 | Seq Scan on listings | The whole table is read and **sorted on disk** (external merge, 6.5 MB) just to skip 50,000 rows and return 25. |
| R23 | real-time | 0.021 | Index Scan using users_phone_key on users | Already optimal: an Index Scan on `users_phone_key`, the index created automatically by the UNIQUE(phone) constraint. |
| R24 | report | 10.665 | Seq Scan on listings<br>Seq Scan on categories | Full scan to find the 9,960 ACTIVE ads, then a hash join to categories and parents. |
| R25 | report | 56.006 | Seq Scan on chat_messages<br>Seq Scan on chat_threads<br>Seq Scan on listings<br>Seq Scan on categories | Hash joins of all 209,529 messages, the 23,530 threads from 2026 and all 120,000 listings, grouped per thread. It reads a large share of three tables. |
| W01 | real-time | 0.604 | (no scan) | A single INSERT. Only the PK index is updated and the 4 FK triggers run, so it is fast. |
| W02 | real-time | 8.246 | Seq Scan on listings<br>Index Scan using listings_pkey on listings | Full scan to find `min(listing_id)` of seller 1042's active ads, then a PK update. |
| W03 | real-time | 0.481 | Index Scan using chat_threads_pkey on chat_threads | Scans `chat_threads_pkey` backwards until it meets a thread of buyer 1042 (3,365 rows skipped), then INSERT plus 2 FK checks. |
| W04 | batch | 16.899 | Seq Scan on listings | Full scan to find the 2,256 stale ACTIVE ads, then updates them (new row versions). |
| W05 | real-time | 1.071 | Seq Scan on offers | Two seq scans of all 19,943 offers: one for the highest pending offer, one for the UPDATE. |

## What the baseline tells us

- **22 of 30 queries do a Seq Scan on `listings`** (120,000 rows, about 5–12 ms each). Only the PK/UNIQUE indexes exist, and no query filters by `listing_id` except R04 and W02.
- **No foreign-key column is indexed.** The worst cases are `chat_messages.thread_id` (R06 and R19 scan 209k messages *per thread / per ad*), plus `listings.seller_id` (R05, W02), `seller_ratings.seller_id` (R04, R21), `chat_threads.buyer_id` (R06, W03) and `offers.listing_id` (W05).
- **Non-sargable predicates:** `EXTRACT(YEAR FROM sold_at)` (R14), `posted_at::date` (R20), `ILIKE '%…%'` (R03) and the `OR` across two tables (R06, R07) prevent index use even once indexes exist. These need a rewrite or a special index type.
- **`OFFSET 50000`** (R22) sorts the whole table on disk to throw away 50,000 rows.
- **Wrong result:** R13 returns no rows although packages 5 and 6 were never bought. That is a NULL problem, not a speed problem (fixed in Phase 4).
- Real-time queries that are already over the 5 ms target on just 120k ads: R01, R02, R03, R05, R06, R07, R08 (report), R09, W02. At 20× data they will be about 20× slower, because a seq scan grows linearly.
