# 03 · Baseline timings (Phase 3)

## Method

Ran `./benchmarks/run_benchmark.sh olx baseline`. Each of the 30 queries was run three times with `EXPLAIN (ANALYZE, BUFFERS)`; write queries ran inside `BEGIN` and `ROLLBACK`. The three raw runs for each query are saved in [benchmarks/results/baseline/](../benchmarks/results/baseline/).

## Setup

PostgreSQL 18.6 on MacBook Pro (Mac16,1), Apple M4, 16 GB RAM, macOS 27.2; `shared_buffers=128MB`, `work_mem=4MB`, `max_parallel_workers_per_gather=2`. Fresh seed load followed by ANALYZE; no VACUUM; only automatic primary-key and unique-constraint indexes.

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Browse: active cars in Bengaluru priced ₹3–6 lakh, newest first | READ | 17.031 | 9.821 | 6.298 | 11.050 |
| R02: Car filters: diesel cars from 2018 or later with at most 60,000 km, in Pune | READ | 5.317 | 5.320 | 5.527 | 5.388 |
| R03: Search: active "iPhone 13" ads anywhere, cheapest first | READ | 23.896 | 19.867 | 18.485 | 20.749 |
| R04: Ad page: listing 100871 with its seller and the seller's average rating | READ | 0.516 | 0.366 | 0.355 | 0.412 |
| R05: "My Ads": user 1042's listings grouped by status | READ | 8.938 | 7.929 | 7.999 | 8.289 |
| R06: Chat inbox: every conversation of user 1042 (as buyer or seller) with its latest message | READ | 64.766 | 68.166 | 62.657 | 65.196 |
| R07: Chat badge: unread messages sent to user 1042 | READ | 5.770 | 5.304 | 5.307 | 5.460 |
| R08: Price guide: median asking price of iPhone 13 ads by condition (2026) | READ | 5.657 | 5.647 | 5.536 | 5.613 |
| R09: "Near me": active furniture within ~2 km of central Bengaluru (12.9716, 77.5946) | READ | 6.466 | 6.238 | 6.210 | 6.305 |
| R10: Reminder job: active ads that expire in the first 3 days of July 2026 | READ | 5.470 | 5.427 | 5.417 | 5.438 |
| R11: Moderation queue: ads with 3 or more open reports | READ | 2.069 | 1.781 | 1.786 | 1.879 |
| R12: Spam detection: users who posted 5 or more ads on the same day | READ | 33.944 | 34.381 | 33.846 | 34.057 |
| R13: Monetisation: boost packages that no ad has ever bought | READ | 14.054 | 14.643 | 14.273 | 14.323 |
| R14: Category insights: average days to sell per category for ads sold in 2026 | READ | 9.069 | 9.003 | 9.127 | 9.066 |
| R15: Marketplace health: share of offers accepted, per category | READ | 11.486 | 11.345 | 11.591 | 11.474 |
| R16: Trending: active ads saved to favourites most in the last 7 days of June 2026 | READ | 11.964 | 11.777 | 11.852 | 11.864 |
| R17: Monetisation: average views of boosted vs normal ads per category | READ | 11.534 | 11.314 | 11.604 | 11.484 |
| R18: Quality: the same seller posting the same title at the same price more than once | READ | 38.707 | 36.164 | 35.917 | 36.929 |
| R19: City report: chats and latest chat time for every active car ad in Bengaluru | READ | 1119.070 | 1115.703 | 1127.844 | 1120.872 |
| R20: Growth: new ads per day and running total, June 2026 | READ | 7.206 | 8.387 | 6.939 | 7.511 |
| R21: Trust: best-rated sellers (at least 5 ratings) | READ | 13.371 | 9.070 | 8.217 | 10.219 |
| R22: Moderation console: all ads, newest first, page 2,001 (25 per page) | READ | 32.029 | 30.674 | 31.286 | 31.330 |
| R23: Login with mobile number | READ | 0.028 | 0.021 | 0.021 | 0.023 |
| R24: Home page: active ads per top-level category (sub-categories rolled up) | READ | 11.536 | 11.334 | 11.652 | 11.507 |
| R25: Seller responsiveness: average minutes from a buyer's first message to the seller's first reply, per category (2026) | READ | 61.227 | 67.056 | 64.182 | 64.155 |
| W01: Post an ad: user 1042 sells a study table in Bengaluru | WRITE | 1.029 | 0.695 | 0.644 | 0.789 |
| W02: Mark as sold: user 1042's oldest active ad | WRITE | 9.384 | 8.982 | 8.917 | 9.094 |
| W03: Chat: user 1042 sends a message in their most recent conversation as a buyer | WRITE | 0.571 | 0.473 | 0.494 | 0.513 |
| W04: Nightly job: expire every active ad whose expiry date has passed (run at 00:00 on 1 July 2026) | WRITE | 18.369 | 20.000 | 18.047 | 18.805 |
| W05: Seller accepts the highest pending offer on listing 118642 and rejects the others | WRITE | 1.255 | 1.493 | 1.556 | 1.435 |
| **Total (sum of all 30)** | | 1551.729 | 1538.381 | 1533.586 | 1541.229 |

The slowest query was R19: City report: chats and latest chat time for every active car ad in Bengaluru at 1120.872 ms, accounting for 72.73% of the total average execution time (1541.229 ms).

## Scan type and why each query is slow or fast

| Query | Class | Avg (ms) | Scan type(s) | Why (one line) |
|---|---|---:|---|---|
| R01 | real-time | 11.050 | Seq Scan on listings | A parallel scan filters category/city/status/price (~39,940 rows removed per worker), then sorts recent results. |
| R02 | real-time | 5.388 | Seq Scan on listings | Parallel listing scan filters JSON fuel/year/mileage plus location, removing ~39,998 rows per worker. |
| R03 | real-time | 20.749 | Seq Scan on listings | Leading-wildcard ILIKE '%iphone 13%' triggers a full listing scan (~39,875 rows filtered per worker) before price sort. |
| R04 | real-time | 0.412 | Index Scan using listings_pkey on listings<br>Index Scan using users_pkey on users<br>Seq Scan on seller_ratings | Fast PK lookups via listings_pkey and users_pkey; a small seller_ratings scan removes 11,242 rows. |
| R05 | real-time | 8.289 | Seq Scan on listings | With no seller_id lookup index, it scans all 120,000 listings to find 9 ads (119,991 removed). |
| R06 | real-time | 65.196 | Seq Scan on listings<br>Seq Scan on chat_threads<br>Seq Scan on chat_messages | Buyer/seller OR join filters ~19,947 rows per worker; chat_messages is rescanned 13 times for latest messages. |
| R07 | real-time | 5.460 | Seq Scan on chat_messages<br>Index Scan using chat_threads_pkey on chat_threads<br>Index Scan using listings_pkey on listings | Parallel scan of chat_messages rejects ~104,636 rows per worker, followed by repeated thread/listing PK lookups. |
| R08 | report | 5.613 | Seq Scan on listings | Parallel full listing scan filters posted date and JSON model (~39,500 rows removed per worker), then computes median by condition. |
| R09 | real-time | 6.305 | Seq Scan on listings | Location bounds and status require a parallel listing scan (~39,998 filtered per worker) before distance sorting. |
| R10 | interactive | 5.438 | Seq Scan on listings | Parallel listing scan checks expires_at/status (~39,792 filtered per worker), followed by expires_at sort. |
| R11 | interactive | 1.879 | Seq Scan on reports<br>Index Scan using listings_pkey on listings | Scan of reports discards 7,183 non-open rows; listing PK lookups keep the result fast. |
| R12 | report | 34.057 | Seq Scan on listings | Groups all 120,000 listings by seller and posted_at::date, then discards 119,414 groups with fewer than five ads. |
| R13 | interactive | 14.323 | Seq Scan on boost_packages<br>Seq Scan on listings | A hashed NOT IN subplan reads all 120,000 listings; NULL boost_package_id makes the predicate return zero packages, incorrectly. |
| R14 | report | 9.066 | Seq Scan on listings<br>Seq Scan on categories | EXTRACT(YEAR FROM sold_at) prevents a simple date-range index condition; parallel listing scan filters ~35,282 rows per worker. |
| R15 | report | 11.474 | Seq Scan on listings<br>Seq Scan on offers<br>Seq Scan on categories | Scans listings and offers broadly, then hash-joins both to categories to aggregate accepted offers. |
| R16 | interactive | 11.864 | Seq Scan on listings<br>Seq Scan on favourites | Filters 110,040 listings and 68,383 favourites with sequential scans, then hash-joins and groups. |
| R17 | report | 11.484 | Seq Scan on listings<br>Seq Scan on categories | A parallel scan reads all 120,000 listings and hash-joins categories before grouping boosted versus ordinary ads. |
| R18 | report | 36.929 | Seq Scan on listings | A full 120,000-row listing scan and HashAggregate group by seller/title/price discards 119,976 singleton groups. |
| R19 | report | 1120.872 | Seq Scan on listings<br>Index Only Scan using chat_threads_listing_buyer_key on chat_threads<br>Seq Scan on chat_messages<br>Index Scan using chat_threads_listing_buyer_key on chat_threads | Two correlated subplans run 279 times each; repeated chat_messages sequential scans (121 loops) dominate ~1.12 s. |
| R20 | report | 7.511 | Seq Scan on listings | posted_at::date is non-sargable; a parallel scan rejects ~37,808 rows per worker, then sorts/groups for running totals. |
| R21 | report | 10.219 | Seq Scan on seller_ratings<br>Seq Scan on users | Scans 11,244 ratings and 50,000 users for a hash join, then groups by seller; no narrow FK lookup is used. |
| R22 | interactive | 31.330 | Seq Scan on listings | Reads all 120,000 listings and external-merge sorts 6,544 kB to skip OFFSET 50,000 and return 25 rows. |
| R23 | real-time | 0.023 | Index Scan using users_phone_key on users | Fast unique phone lookup through users_phone_key; one row returned without any sequential scan. |
| R24 | report | 11.507 | Seq Scan on listings<br>Seq Scan on categories | Scans listings and removes 110,040 inactive rows, then joins categories and aggregates. |
| R25 | report | 64.155 | Seq Scan on chat_messages<br>Seq Scan on chat_threads<br>Seq Scan on listings<br>Seq Scan on categories | Full scans of chat_messages, chat_threads and listings feed large hash joins and grouped response-time aggregates. |
| W01 | real-time | 0.789 | (no scan) | Direct INSERT; the execution plan has no table scan. |
| W02 | real-time | 9.094 | Seq Scan on listings<br>Index Scan using listings_pkey on listings | InitPlan scans 120,000 listings to find the seller's oldest active ad (119,999 filtered), then updates via listings_pkey. |
| W03 | real-time | 0.513 | Index Scan using chat_threads_pkey on chat_threads | Backward scan on chat_threads_pkey rejects 3,365 rows to find the most recent thread for buyer 1042. |
| W04 | batch | 18.805 | Seq Scan on listings | UPDATE scans all listings, rejects 117,744 rows and expires 2,256 qualifying ads. |
| W05 | real-time | 1.435 | Seq Scan on offers | Offers is scanned twice for the same listing; each scan filters out 19,940 rows, though the small table keeps it fast. |

## What the baseline tells us

- **Sequential scans:** 22 of 30 queries have a `Seq Scan on listings` (including parallel scans), per the benchmark `scan_nodes` column; listings contains 120,000 rows. This is not a claim that every sequential scan is inefficient.
- **Foreign-key access paths:** the baseline has only automatic PK/UNIQUE indexes, not standalone indexes for common FK filters/joins such as `listings.seller_id`, `chat_messages.thread_id`, `offers.listing_id`, `favourites.listing_id` and `seller_ratings.seller_id`. The existing `chat_threads_listing_buyer_key` unique composite index *does* support lookup by its leading `listing_id` column.
- **Non-sargable predicates:** R03 has a leading-wildcard `ILIKE '%iphone 13%'` (ordinary B-tree cannot support this pattern); R14 filters `EXTRACT(YEAR FROM sold_at)`; R20 filters `posted_at::date`. Their plans show sequential listing scans rather than index range scans.
- **Deep pagination:** R22 scans and external-merge sorts all 120,000 listings (6,544 kB disk in run 3), produces 50,025 sorted rows and skips the first 50,000 via OFFSET to return only 25.
- **Incorrect result, not just latency:** R13's `NOT IN` examines a nullable `boost_package_id` subquery. Because NULL occurs, it returns zero packages even though packages 5 and 6 were not purchased. Correctness is deferred to Phase 4.
- **Real-time target breaches:** 8 of 13 real-time queries exceed the 5 ms average target: R01 (11.050 ms), R02 (5.388 ms), R03 (20.749 ms), R05 (8.289 ms), R06 (65.196 ms), R07 (5.460 ms), R09 (6.305 ms), W02 (9.094 ms). R23 is already fast through `users_phone_key` (0.023 ms).
