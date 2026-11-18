# Query optimization report

Both runs used the same laptop and PostgreSQL 18.6.

The table uses average execution times. Each write ran inside a transaction that rolled back. The result column describes the checks on the seed data. [Baseline timings](../benchmarks/results/baseline/summary.csv), [optimized timings](../benchmarks/results/optimized/summary.csv)

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---:|:---:|
| R01 | 11.050 | Parallel Seq Scan on listings, then sorts recent matches. | none (uses `idx_listings_active_category_city_posted` only) | 0.795 | 92.81% (13.90x) | ✅ |
| R02 | 5.388 | Parallel Seq Scan on listings applies location and JSON filters. | none (uses `idx_listings_active_category_city_posted` only) | 0.241 | 95.53% (22.36x) | ✅ |
| R03 | 20.749 | Parallel Seq Scan tests the title pattern, then sorts by price. | none (uses `idx_listings_active_title_trgm` only) | 0.863 | 95.84% (24.04x) | same rows (tie order) |
| R04 | 0.412 | Seq Scan on seller_ratings for one seller. The ad and user use primary keys. | none (uses `idx_seller_ratings_seller` only) | 0.090 | 78.16% (4.58x) | ✅ |
| R05 | 8.289 | Seq Scan on listings to find one seller’s ads. | none (uses `idx_listings_seller_status_listing` only) | 0.056 | 99.32% (148.02x) | ✅ |
| R06 | 65.196 | Buyer/seller OR filters joined rows. Seq Scan on chat_messages repeats for the latest message. | Split buyer and seller lookups with `UNION ALL`. Uses `idx_listings_seller_status_listing`, `idx_msgs_thread_sent`, `idx_threads_buyer`. | 0.155 | 99.76% (420.62x) | ✅ |
| R07 | 5.460 | Parallel Seq Scan on chat_messages, followed by thread and listing lookups. | none (uses `idx_msgs_unread_thread` only) | 0.816 | 85.05% (6.69x) | ✅ |
| R08 | 5.613 | Parallel Seq Scan applies the model and date filters before the median. | none (uses `idx_listings_category_model_posted` only) | 1.314 | 76.59% (4.27x) | ✅ |
| R09 | 6.305 | Parallel Seq Scan tests the location bounds, then sorts by distance. | none (uses `idx_listings_active_category_lat_lng` only) | 0.080 | 98.73% (78.81x) | ✅ |
| R10 | 5.438 | Parallel Seq Scan applies the expiry and status filters, then sorts. | none (uses `idx_listings_active_expires` only) | 0.173 | 96.82% (31.43x) | ✅ |
| R11 | 1.879 | Seq Scan on reports filters for open reports before grouping. | none (uses `idx_reports_open_listing` only) | 1.554 | 17.3% (1.21x) | ✅ |
| R12 | 34.057 | Seq Scan on listings feeds grouping by seller and day. | none | 32.422 | 4.8% (1.05x) | ✅ |
| R13 | 14.323 | Hashed NOT IN scans listings. NULL values suppress unused packages. | Use `NOT EXISTS` for the package lookup. Uses `idx_listings_boost_package`. | 0.057 | 99.6% (251.28x) | fixed - wrong result |
| R14 | 9.066 | EXTRACT on sold_at leads to a Parallel Seq Scan on listings. | Filter `sold_at` with a half-open timestamp range. Uses `idx_listings_sold_at`. | 3.570 | 60.62% (2.54x) | same rows (tie order) |
| R15 | 11.474 | Seq Scans on listings and offers feed joins and aggregation. | none | 11.504 | -0.26% (slower) | ✅ |
| R16 | 11.864 | Seq Scans on listings and favourites filter status and saved date. | none (uses `idx_listings_active_expires`, `idx_favourites_saved` only) | 3.971 | 66.53% (2.99x) | ✅ |
| R17 | 11.484 | Parallel Seq Scan on listings reads all ads for the averages. | none | 11.923 | -3.82% (slower) | ✅ |
| R18 | 36.929 | Seq Scan on listings feeds a HashAggregate over all ads. | none | 33.745 | 8.62% (1.09x) | ✅ |
| R19 | 1120.872 | Each ad runs correlated subplans. Seq Scan on chat_messages repeats. | none (uses `idx_listings_active_category_city_posted`, `idx_msgs_thread_sent` only) | 1.121 | 99.9% (999.89x) | same rows (tie order) |
| R20 | 7.511 | Casting posted_at to date leads to a Parallel Seq Scan on listings. | Filter `posted_at` with a half-open timestamp range. Uses `idx_listings_posted_listing`. | 0.861 | 88.54% (8.72x) | ✅ |
| R21 | 10.219 | Seq Scans on seller_ratings and users feed the join and aggregate. | none | 7.588 | 25.75% (1.35x) | ✅ |
| R22 | 31.330 | Seq Scan on listings, disk sort, and a deep OFFSET. | Use a keyset cursor on `(posted_at, listing_id)`. Uses `idx_listings_posted_listing`. | 0.027 | 99.91% (1160.37x) | ✅ |
| R23 | 0.023 | Already uses the unique phone index. | none | 0.022 | 4.35% (1.05x) | ✅ |
| R24 | 11.507 | Seq Scan on listings filters for active ads before grouping. | none (uses `idx_listings_active_category_city_posted` only) | 1.937 | 83.17% (5.94x) | ✅ |
| R25 | 64.155 | Seq Scans and hash joins across messages, threads, and listings before grouping. | none | 56.064 | 12.61% (1.14x) | ✅ |
| W01 | 0.789 | Direct INSERT, with no table scan. | none | 1.382 | -75.16% (slower) | same SQL |
| W02 | 9.094 | Seq Scan on listings finds the seller’s active ad with the lowest listing ID. | none (uses `idx_listings_seller_status_listing` only) | 0.393 | 95.68% (23.14x) | same SQL |
| W03 | 0.513 | Backward primary-key scan filters many threads by buyer. | none (uses `idx_threads_buyer` only) | 0.406 | 20.86% (1.26x) | same SQL |
| W04 | 18.805 | Seq Scan on listings finds expired active ads. | none (uses `idx_listings_active_expires` only) | 201.210 | -969.98% (slower) | same SQL |
| W05 | 1.435 | Offers is scanned twice for the same listing. | none (uses `idx_offers_pending_listing_price` only) | 0.308 | 78.54% (4.66x) | same SQL |
| **Total** | **1541.229** | | | **374.648** | **75.69% (4.11x)** | |

## The wrong-result query (R13)

The original query returned 0 rows. Most ads have a NULL `boost_package_id`. With a NULL in the subquery, `NOT IN` gives unknown for an unused package, so the `WHERE` drops it. `NOT EXISTS` checks for an actual match and returns 2 rows. The unused package IDs are `5` and `6`. Their rows from the seed data matched the optimized output hash. [Result check](../benchmarks/results/optimized/result_check.csv), [seed data](../seed_data.zip)

## Results are unchanged

The check compared row counts and MD5 hashes for every read before adding indexes and after applying the optimizations. It hashed each output in its original order and again after sorting the rows. [Result check](../benchmarks/results/optimized/result_check.csv)

| Outcome | Queries |
|---|---:|
| Same result | 21 |
| Same rows with different output order | 3 |
| Wrong result fixed | 1 |

Ties changed output order in R03 (price), R14 (average time to sell), R19 (chat count). Their original-order hashes differed, and their sorted hashes matched.

A self-chat would match both branches of R06 and could appear twice.

R22 uses the saved cursor for this seed-data page. Adding listings ahead of it can shift the old numbered page. A posting-time tie at the page boundary can also change which listings appear, since the cursor order breaks ties with `listing_id`.

## Before / after plans - 5 biggest improvements

Ranked by milliseconds saved. The excerpts use the third run from each raw plan.

### R19

Saved 1119.751 ms on average.

[Before](../benchmarks/results/baseline/R19.txt)

```text
Sort  (cost=1237231.08..1237231.72 rows=257 width=36) (actual time=1127.754..1127.792 rows=279.00 loops=1)
        ->  Parallel Seq Scan on listings l  (cost=0.00..5163.00 rows=107 width=20) (actual time=0.160..3.336 rows=93.00 loops=3)
        SubPlan 2
                ->  Hash Join  (cost=8.32..4785.67 rows=4 width=8) (actual time=1.717..4.037 rows=2.09 loops=279)
                      ->  Seq Scan on chat_messages m  (cost=0.00..4227.29 rows=209529 width=12) (actual time=0.000..4.213 rows=207797.36 loops=121)
Execution Time: 1127.844 ms
```

[After](../benchmarks/results/optimized/R19.txt)

```text
Sort  (cost=5399.76..5400.42 rows=264 width=36) (actual time=1.074..1.080 rows=279.00 loops=1)
  ->  Bitmap Heap Scan on listings l  (cost=10.99..5389.14 rows=264 width=36) (actual time=0.041..1.048 rows=279.00 loops=1)
        ->  Bitmap Index Scan on idx_listings_active_category_city_posted  (cost=0.00..10.93 rows=264 width=0) (actual time=0.018..0.018 rows=279.00 loops=1)
        SubPlan 2
                ->  Nested Loop  (cost=0.71..12.84 rows=4 width=8) (actual time=0.001..0.002 rows=2.09 loops=279)
                      ->  Index Only Scan using idx_msgs_thread_sent on chat_messages m  (cost=0.42..4.49 rows=4 width=12) (actual time=0.001..0.001 rows=3.67 loops=159)
                            Index Cond: (thread_id = t_1.thread_id)
Execution Time: 1.109 ms
```

The active-listings index finds matching ads. The message index finds messages by thread ID. That replaces the repeated scans of chat_messages.

### R06

Saved 65.041 ms on average.

[Before](../benchmarks/results/baseline/R06.txt)

```text
Sort  (cost=27083.36..27083.37 rows=4 width=49) (actual time=62.597..62.614 rows=13.00 loops=1)
                    Join Filter: ((t.buyer_id = 1042) OR (l.seller_id = 1042))
                    ->  Parallel Seq Scan on listings l  (cost=0.00..4788.00 rows=50000 width=24) (actual time=0.003..1.568 rows=40000.00 loops=3)
                          ->  Seq Scan on chat_threads t  (cost=0.00..980.55 rows=59855 width=12) (actual time=0.017..2.209 rows=59855.00 loops=3)
                    Sort Method: top-N heapsort  Memory: 25kB
                    ->  Seq Scan on chat_messages m  (cost=0.00..4751.11 rows=4 width=29) (actual time=2.502..4.241 rows=3.46 loops=13)
Execution Time: 62.657 ms
```

[After](../benchmarks/results/optimized/R06.txt)

```text
Sort  (cost=81.03..81.03 rows=3 width=49) (actual time=0.122..0.123 rows=13.00 loops=1)
        ->  Append  (cost=4.60..69.72 rows=3 width=20) (actual time=0.013..0.064 rows=13.00 loops=1)
                          ->  Bitmap Index Scan on idx_threads_buyer  (cost=0.00..4.30 rows=2 width=0) (actual time=0.005..0.005 rows=3.00 loops=1)
                          ->  Bitmap Index Scan on idx_listings_seller_status_listing  (cost=0.00..4.44 rows=3 width=0) (actual time=0.004..0.004 rows=9.00 loops=1)
        ->  Limit  (cost=0.42..3.75 rows=1 width=29) (actual time=0.004..0.004 rows=1.00 loops=13)
              ->  Index Scan using idx_msgs_thread_sent on chat_messages m  (cost=0.42..13.74 rows=4 width=29) (actual time=0.003..0.003 rows=1.00 loops=13)
Execution Time: 0.148 ms
```

The rewrite splits the buyer and seller lookup. The message index returns the latest message in each thread, replacing repeated message scans and per-thread sorts.

### R22

Saved 31.303 ms on average.

[Before](../benchmarks/results/baseline/R22.txt)

```text
Limit  (cost=15579.22..15579.28 rows=25 width=40) (actual time=30.140..30.142 rows=25.00 loops=1)
  ->  Sort  (cost=15454.22..15754.22 rows=120000 width=40) (actual time=27.259..29.244 rows=50025.00 loops=1)
        Sort Method: external merge  Disk: 6544kB
        ->  Seq Scan on listings  (cost=0.00..5488.00 rows=120000 width=40) (actual time=0.005..10.653 rows=120000.00 loops=1)
Execution Time: 31.286 ms
```

[After](../benchmarks/results/optimized/R22.txt)

```text
Limit  (cost=0.42..4.43 rows=25 width=40) (actual time=0.009..0.012 rows=25.00 loops=1)
  ->  Index Scan using idx_listings_posted_listing on listings  (cost=0.42..11219.69 rows=69915 width=40) (actual time=0.009..0.011 rows=25.00 loops=1)
        Index Cond: (ROW(posted_at, listing_id) < ROW('2025-11-16 07:06:36+05:30'::timestamp with time zone, 70176))
Execution Time: 0.027 ms
```

The original read and sorted the listings and skipped rows with OFFSET. The new plan reads the page from the saved cursor in index order.

### R03

Saved 19.886 ms on average.

[Before](../benchmarks/results/baseline/R03.txt)

```text
Limit  (cost=6043.66..6048.32 rows=40 width=34) (actual time=17.725..18.468 rows=40.00 loops=1)
              Sort Key: price
              ->  Parallel Seq Scan on listings  (cost=0.00..5038.00 rows=155 width=34) (actual time=0.425..16.454 rows=125.00 loops=3)
                    Filter: (((title)::text ~~* '%iphone 13%'::text) AND ((status)::text = 'ACTIVE'::text))
Execution Time: 18.485 ms
```

[After](../benchmarks/results/optimized/R03.txt)

```text
Limit  (cost=1161.79..1161.89 rows=40 width=34) (actual time=0.781..0.784 rows=40.00 loops=1)
        Sort Key: price
        ->  Bitmap Heap Scan on listings  (cost=65.07..1150.51 rows=357 width=34) (actual time=0.146..0.700 rows=375.00 loops=1)
              ->  Bitmap Index Scan on idx_listings_active_title_trgm  (cost=0.00..64.98 rows=357 width=0) (actual time=0.121..0.121 rows=375.00 loops=1)
                    Index Cond: ((title)::text ~~* '%iphone 13%'::text)
Execution Time: 0.825 ms
```

The trigram index finds active listings that match the title pattern. The price sort still runs on those matches.

### R13

Saved 14.266 ms on average.

[Before](../benchmarks/results/baseline/R13.txt)

```text
Seq Scan on boost_packages b  (cost=5788.00..5789.07 rows=3 width=24) (actual time=14.242..14.242 rows=0.00 loops=1)
  Filter: (NOT (ANY (package_id = (hashed SubPlan 1).col1)))
  SubPlan 1
    ->  Seq Scan on listings l  (cost=0.00..5488.00 rows=120000 width=2) (actual time=0.005..9.567 rows=120000.00 loops=1)
Execution Time: 14.273 ms
```

[After](../benchmarks/results/optimized/R13.txt)

```text
Nested Loop Anti Join  (cost=0.29..3.05 rows=2 width=24) (actual time=0.036..0.037 rows=2.00 loops=1)
  ->  Seq Scan on boost_packages b  (cost=0.00..1.06 rows=6 width=24) (actual time=0.003..0.003 rows=6.00 loops=1)
  ->  Index Only Scan using idx_listings_boost_package on listings l  (cost=0.29..47.76 rows=2332 width=2) (actual time=0.005..0.005 rows=0.67 loops=6)
        Index Cond: (boost_package_id = b.package_id)
Execution Time: 0.056 ms
```

The new plan probes the partial boost-package index for each package. It returns packages with no match. The original built a hashed subplan from a full listings scan.

## Write overhead

| Query | Before (ms) | After (ms) | Improvement |
|---|---:|---:|---:|
| W01 | 0.789 | 1.382 | -75.16% (slower) |
| W02 | 9.094 | 0.393 | 95.68% |
| W03 | 0.513 | 0.406 | 20.86% |
| W04 | 18.805 | 201.210 | -969.98% (slower) |
| W05 | 1.435 | 0.308 | 78.54% |

- Posting an ad (W01) took 0.593 ms longer. The insert maintains the new listing indexes.
- Marking an ad sold (W02) took 8.701 ms less. The seller/status index finds the active ad with the lowest listing ID.
- Posting a chat message (W03) took 0.107 ms less. The buyer index finds the thread. The insert maintains the new message indexes.
- The expiry job (W04) took 182.405 ms longer. The expiry index finds the rows to update. Changing the status also changes the seller/status index and which active-only indexes contain those ads.
- Accepting an offer (W05) took 1.127 ms less. The pending-offers index helps find the highest offer and the rows to update.

The optimized expiry run median was 22.577 ms. One run took 561.980 ms and pulled up the average. The expiry job runs overnight. [W04 plans](../benchmarks/results/optimized/W04.txt)

The write times add up to 30.636 ms before and 203.699 ms after. The overall time saved makes the extra cost of the slower writes acceptable for this workload.

## Index storage

| Index | Index size | Table | Table size |
|---|---:|---|---:|
| `idx_listings_active_category_city_posted` | 328 kB | `listings` | 33 MB |
| `idx_listings_active_title_trgm` | 656 kB | `listings` | 33 MB |
| `idx_listings_seller_status_listing` | 4776 kB | `listings` | 33 MB |
| `idx_listings_category_model_posted` | 4664 kB | `listings` | 33 MB |
| `idx_listings_active_category_lat_lng` | 416 kB | `listings` | 33 MB |
| `idx_listings_active_expires` | 240 kB | `listings` | 33 MB |
| `idx_listings_sold_at` | 1736 kB | `listings` | 33 MB |
| `idx_listings_posted_listing` | 3712 kB | `listings` | 33 MB |
| `idx_listings_boost_package` | 80 kB | `listings` | 33 MB |
| `idx_seller_ratings_seller` | 264 kB | `seller_ratings` | 760 kB |
| `idx_msgs_thread_sent` | 8320 kB | `chat_messages` | 16 MB |
| `idx_msgs_unread_thread` | 16 kB | `chat_messages` | 16 MB |
| `idx_threads_buyer` | 1328 kB | `chat_threads` | 3056 kB |
| `idx_favourites_saved` | 2168 kB | `favourites` | 3032 kB |
| `idx_reports_open_listing` | 48 kB | `reports` | 616 kB |
| `idx_offers_pending_listing_price` | 16 kB | `offers` | 1496 kB |

The new indexes together use 29,458,432 bytes. The indexes on `listings` use 17,006,592 bytes. The `listings` table itself is 33 MB, so all the new indexes are 84.4% of that table’s size. [Index sizes](../benchmarks/results/optimized/index_sizes.csv)

## Queries we could not speed up (much)

- R12 ran faster (34.057 to 32.422 ms). Grouping by seller and date still needs every listing.
- R15 ran slower (11.474 to 11.504 ms). The category rates need the offers across the dataset and the listings they reference.
- R17 ran slower (11.484 to 11.923 ms). Both boosted and ordinary ads contribute to the averages, so every listing is read.
- R18 ran faster (36.929 to 33.745 ms). Finding duplicates requires grouping all listings by seller, title and price. The hash aggregate spills to disk in both plans.
- R23 ran faster (0.023 to 0.022 ms). The same unique phone index handles a single-row lookup. The measured change is small in milliseconds.
- R25 ran faster (64.155 to 56.064 ms). The report still joins and groups a large share of the messages to find the earliest messages from buyers and sellers.

## Summary

Total time fell from 1541.229 to 374.648 ms, a 75.69% reduction. The biggest saving was R19, from 1120.872 to 1.121 ms.
