# Query optimization report

Times are the average execution time across the recorded runs. For writes, the benchmark rolled back each run. The before and after plans format actual row counts differently, and several queries with the same scan types ran slower. The measured changes may include differences between benchmark runs. [Baseline timings](../benchmarks/results/baseline/summary.csv), [optimized timings](../benchmarks/results/optimized/summary.csv)

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---:|:---:|
| R01 | 11.050 | Parallel Seq Scan on listings, then sorts recent matches. | none (uses `idx_listings_active_category_city_posted` only) | 1.036 | 90.62% (10.67x) | ✅ |
| R02 | 5.388 | Parallel Seq Scan on listings applies location and JSON filters. | none (uses `idx_listings_active_category_city_posted` only) | 0.611 | 88.66% (8.82x) | ✅ |
| R03 | 20.749 | Parallel Seq Scan tests the title pattern, then sorts by price. | none (uses `idx_listings_active_title_trgm` only) | 1.929 | 90.7% (10.76x) | same rows (tie order) |
| R04 | 0.412 | Seq Scan on seller_ratings for one seller. The ad and user use primary keys. | none (uses `idx_seller_ratings_seller` only) | 0.180 | 56.31% (2.29x) | ✅ |
| R05 | 8.289 | Seq Scan on listings to find one seller’s ads. | none (uses `idx_listings_seller_status_listing` only) | 0.186 | 97.76% (44.56x) | ✅ |
| R06 | 65.196 | Buyer/seller OR filters joined rows. Seq Scan on chat_messages repeats for the latest message. | Split buyer and seller lookups with `UNION ALL`. Uses `idx_listings_seller_status_listing`, `idx_msgs_thread_sent`, `idx_threads_buyer`. | 0.520 | 99.2% (125.38x) | ✅ |
| R07 | 5.460 | Parallel Seq Scan on chat_messages, followed by thread and listing lookups. | none (uses `idx_msgs_unread_thread` only) | 2.567 | 52.99% (2.13x) | ✅ |
| R08 | 5.613 | Parallel Seq Scan applies the model and date filters before the median. | none (uses `idx_listings_category_model_posted` only) | 4.122 | 26.56% (1.36x) | ✅ |
| R09 | 6.305 | Parallel Seq Scan tests the location bounds, then sorts by distance. | none (uses `idx_listings_active_category_lat_lng` only) | 0.187 | 97.03% (33.72x) | ✅ |
| R10 | 5.438 | Parallel Seq Scan applies the expiry and status filters, then sorts. | none (uses `idx_listings_active_expires` only) | 0.494 | 90.92% (11.01x) | ✅ |
| R11 | 1.879 | Seq Scan on reports filters for open reports before grouping. | none (uses `idx_reports_open_listing` only) | 5.360 | -185.26% (slower) | ✅ |
| R12 | 34.057 | Seq Scan on listings feeds grouping by seller and day. | none | 92.095 | -170.41% (slower) | ✅ |
| R13 | 14.323 | Hashed NOT IN scans listings. NULL values suppress unused packages. | Use `NOT EXISTS` for the package lookup. Uses `idx_listings_boost_package`. | 0.136 | 99.05% (105.32x) | fixed - wrong result |
| R14 | 9.066 | EXTRACT on sold_at leads to a Parallel Seq Scan on listings. | Filter `sold_at` with a half-open timestamp range. Uses `idx_listings_sold_at`. | 10.276 | -13.35% (slower) | same rows (tie order) |
| R15 | 11.474 | Seq Scans on listings and offers feed joins and aggregation. | none | 23.360 | -103.59% (slower) | ✅ |
| R16 | 11.864 | Seq Scans on listings and favourites filter status and saved date. | none (uses `idx_listings_active_expires`, `idx_favourites_saved` only) | 9.060 | 23.63% (1.31x) | ✅ |
| R17 | 11.484 | Parallel Seq Scan on listings reads all ads for the averages. | none | 24.894 | -116.77% (slower) | ✅ |
| R18 | 36.929 | Seq Scan on listings feeds a HashAggregate over all ads. | none | 95.212 | -157.82% (slower) | ✅ |
| R19 | 1120.872 | Each ad runs correlated subplans. Seq Scan on chat_messages repeats. | none (uses `idx_listings_active_category_city_posted`, `idx_msgs_thread_sent` only) | 2.224 | 99.8% (503.99x) | same rows (tie order) |
| R20 | 7.511 | Casting posted_at to date leads to a Parallel Seq Scan on listings. | Filter `posted_at` with a half-open timestamp range. Uses `idx_listings_posted_listing`. | 2.567 | 65.82% (2.93x) | ✅ |
| R21 | 10.219 | Seq Scans on seller_ratings and users feed the join and aggregate. | none | 21.631 | -111.67% (slower) | ✅ |
| R22 | 31.330 | Seq Scan on listings, disk sort, and a deep OFFSET. | Use a keyset cursor on `(posted_at, listing_id)`. Uses `idx_listings_posted_listing`. | 0.088 | 99.72% (356.02x) | ✅ |
| R23 | 0.023 | Already uses the unique phone index. | none | 0.058 | -152.17% (slower) | ✅ |
| R24 | 11.507 | Seq Scan on listings filters inactive ads before grouping. | none (uses `idx_listings_active_category_city_posted` only) | 6.392 | 44.45% (1.80x) | ✅ |
| R25 | 64.155 | Seq Scans and hash joins across messages, threads, and listings before grouping. | none (uses `idx_msgs_thread_sent` only) | 77.938 | -21.48% (slower) | ✅ |
| W01 | 0.789 | Direct INSERT, with no table scan. | none | 3.163 | -300.89% (slower) | same SQL |
| W02 | 9.094 | Seq Scan on listings finds the seller’s active ad with the lowest listing ID. | none (uses `idx_listings_seller_status_listing` only) | 1.095 | 87.96% (8.31x) | same SQL |
| W03 | 0.513 | Backward primary-key scan filters many threads by buyer. | none (uses `idx_threads_buyer` only) | 1.283 | -150.1% (slower) | same SQL |
| W04 | 18.805 | Seq Scan on listings finds expired active ads. | none (uses `idx_listings_active_expires` only) | 67.392 | -258.37% (slower) | same SQL |
| W05 | 1.435 | Offers is scanned twice for the same listing. | none (uses `idx_offers_pending_listing_price` only) | 0.543 | 62.16% (2.64x) | same SQL |
| **Total** | **1541.229** | | | **456.599** | **70.37% (3.38x)** | |

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

R06 matched on the seed data. A self-chat would match both inbox branches and could appear twice.

R22 matched the page in the seed data. The saved cursor continues from a specific listing. Adding listings ahead of it can shift the old numbered page. A posting-time tie at the page boundary can also change which listings appear, since the cursor order breaks ties with `listing_id`.

## Before / after plans - 5 biggest improvements

Ranked by milliseconds saved. The excerpts use the third run from each raw plan.

### R19

Saved 1118.648 ms on average.

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
Sort  (cost=5639.12..5639.81 rows=276 width=36) (actual time=2.058..2.069 rows=279 loops=1)
  ->  Bitmap Heap Scan on listings l  (cost=11.11..5627.93 rows=276 width=36) (actual time=0.078..1.998 rows=279 loops=1)
        ->  Bitmap Index Scan on idx_listings_active_category_city_posted  (cost=0.00..11.04 rows=276 width=0) (actual time=0.036..0.036 rows=279 loops=1)
        SubPlan 2
                ->  Nested Loop  (cost=0.71..12.84 rows=4 width=8) (actual time=0.002..0.003 rows=2 loops=279)
                      ->  Index Only Scan using idx_msgs_thread_sent on chat_messages m  (cost=0.42..4.49 rows=4 width=12) (actual time=0.003..0.003 rows=4 loops=159)
                            Index Cond: (thread_id = t_1.thread_id)
Execution Time: 2.124 ms
```

The SQL stayed the same. The active-listings index finds matching ads, and the message index lets the second subplan look up each thread's messages directly. The original subplan kept scanning `chat_messages`.

### R06

Saved 64.676 ms on average.

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
Sort  (cost=81.03..81.04 rows=3 width=49) (actual time=0.364..0.366 rows=13 loops=1)
        ->  Append  (cost=4.60..69.72 rows=3 width=20) (actual time=0.036..0.193 rows=13 loops=1)
                          ->  Bitmap Index Scan on idx_threads_buyer  (cost=0.00..4.30 rows=2 width=0) (actual time=0.011..0.012 rows=3 loops=1)
                          ->  Bitmap Index Scan on idx_listings_seller_status_listing  (cost=0.00..4.44 rows=3 width=0) (actual time=0.015..0.015 rows=9 loops=1)
        ->  Limit  (cost=0.42..3.75 rows=1 width=29) (actual time=0.010..0.010 rows=1 loops=13)
              ->  Index Scan using idx_msgs_thread_sent on chat_messages m  (cost=0.42..13.74 rows=4 width=29) (actual time=0.009..0.009 rows=1 loops=13)
Execution Time: 0.465 ms
```

The buyer and seller branches each find their threads with an index. For each thread the message index returns the latest message directly, replacing the repeated full message scans and per-thread sorts.

### R22

Saved 31.242 ms on average.

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
Limit  (cost=0.42..4.44 rows=25 width=40) (actual time=0.024..0.034 rows=25 loops=1)
  ->  Index Scan using idx_listings_posted_listing on listings  (cost=0.42..11299.16 rows=70136 width=40) (actual time=0.023..0.031 rows=25 loops=1)
        Index Cond: (ROW(posted_at, listing_id) < ROW('2025-11-16 07:06:36+05:30'::timestamp with time zone, 70176))
Execution Time: 0.074 ms
```

The original read and sorted the listings and skipped rows with `OFFSET`. The index gives the new query the right order starting at the saved cursor, so it can stop at the page limit.

### R03

Saved 18.820 ms on average.

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
Limit  (cost=1234.30..1234.40 rows=40 width=34) (actual time=1.570..1.574 rows=40 loops=1)
        Sort Key: price
        ->  Bitmap Heap Scan on listings  (cost=65.09..1222.13 rows=385 width=34) (actual time=0.395..1.394 rows=375 loops=1)
              ->  Bitmap Index Scan on idx_listings_active_title_trgm  (cost=0.00..64.99 rows=385 width=0) (actual time=0.314..0.314 rows=375 loops=1)
                    Index Cond: ((title)::text ~~* '%iphone 13%'::text)
Execution Time: 1.657 ms
```

The trigram index finds active listings that match the title pattern. The price sort still runs on those matches.

### R13

Saved 14.187 ms on average.

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
Nested Loop Anti Join  (cost=0.29..3.12 rows=2 width=24) (actual time=0.093..0.094 rows=2 loops=1)
  ->  Seq Scan on boost_packages b  (cost=0.00..1.06 rows=6 width=24) (actual time=0.004..0.005 rows=6 loops=1)
  ->  Index Only Scan using idx_listings_boost_package on listings l  (cost=0.29..64.86 rows=2377 width=2) (actual time=0.014..0.014 rows=1 loops=6)
        Index Cond: (boost_package_id = b.package_id)
Execution Time: 0.130 ms
```

The anti join probes the partial boost-package index for each package and returns the packages with no match. The baseline built a hashed subplan from a full listings scan.

## Write overhead

| Query | Before (ms) | After (ms) | Improvement |
|---|---:|---:|---:|
| W01 | 0.789 | 3.163 | -300.89% (slower) |
| W02 | 9.094 | 1.095 | 87.96% |
| W03 | 0.513 | 1.283 | -150.1% (slower) |
| W04 | 18.805 | 67.392 | -258.37% (slower) |
| W05 | 1.435 | 0.543 | 62.16% |

Posting an ad (W01) took 2.374 ms longer. The insert now has more listing indexes to maintain.
Posting a chat message (W03) also got slower. It maintains the additional message indexes, and the foreign-key checks took longer in the optimized plan.
The expiry job (W04) found the rows faster through the expiry index. Updating them still took longer overall. Expiring an ad also changes the seller/status index and its membership in the active-only indexes.
W02 finds the seller’s active ad with the lowest listing ID faster with the seller/status index. W05 uses the pending-offers index to find both the highest offer and the rows to update.
The write times add up to 30.636 ms before and 73.476 ms after. The measured read savings make this acceptable for the tested workload. The nightly expiry job pays most of the extra write cost.

## Index storage

| Index | Index size | Table | Table size |
|---|---:|---|---:|
| `idx_listings_active_category_city_posted` | 328 kB | `listings` | 35 MB |
| `idx_listings_active_title_trgm` | 664 kB | `listings` | 35 MB |
| `idx_listings_seller_status_listing` | 4944 kB | `listings` | 35 MB |
| `idx_listings_category_model_posted` | 4664 kB | `listings` | 35 MB |
| `idx_listings_active_category_lat_lng` | 416 kB | `listings` | 35 MB |
| `idx_listings_active_expires` | 240 kB | `listings` | 35 MB |
| `idx_listings_sold_at` | 1736 kB | `listings` | 35 MB |
| `idx_listings_posted_listing` | 3712 kB | `listings` | 35 MB |
| `idx_listings_boost_package` | 88 kB | `listings` | 35 MB |
| `idx_seller_ratings_seller` | 264 kB | `seller_ratings` | 760 kB |
| `idx_msgs_thread_sent` | 8320 kB | `chat_messages` | 16 MB |
| `idx_msgs_unread_thread` | 16 kB | `chat_messages` | 16 MB |
| `idx_threads_buyer` | 1328 kB | `chat_threads` | 3056 kB |
| `idx_favourites_saved` | 2168 kB | `favourites` | 3032 kB |
| `idx_reports_open_listing` | 48 kB | `reports` | 616 kB |
| `idx_offers_pending_listing_price` | 16 kB | `offers` | 1536 kB |

The new indexes together use 29,646,848 bytes. The indexes on `listings` use 17,195,008 bytes. The `listings` table itself is 35 MB, so all the new indexes are 80.6% of that table’s size. [Index sizes](../benchmarks/results/optimized/index_sizes.csv)

## Queries we could not speed up (much)

- R11 ran slower in the optimized benchmark (1.879 to 5.360 ms). The open-report index reads fewer pages. The plan still looks up listings by primary key before sorting and grouping the reports.
- R12 ran slower in the optimized benchmark (34.057 to 92.095 ms). Grouping by seller and date still needs every listing.
- R14 ran slower in the optimized benchmark (9.066 to 10.276 ms). The index finds the sold ads by date. The query still computes and averages the time to sell for all ads in the range.
- R15 ran slower in the optimized benchmark (11.474 to 23.360 ms). The category rates need the offers across the dataset and the listings they reference.
- R17 ran slower in the optimized benchmark (11.484 to 24.894 ms). Both boosted and ordinary ads contribute to the averages, so every listing is read.
- R18 ran slower in the optimized benchmark (36.929 to 95.212 ms). Finding duplicates requires grouping all listings by seller, title and price. The hash aggregate spills to disk in both plans.
- R21 ran slower in the optimized benchmark (10.219 to 21.631 ms). The planner still scans and joins ratings and users before ranking sellers.
- R23 ran slower in the optimized benchmark (0.023 to 0.058 ms). The same unique phone index handles a single-row lookup. The measured change is small in milliseconds.
- R25 ran slower in the optimized benchmark (64.155 to 77.938 ms). The message index scan still reads almost the entire index, and the report groups qualifying messages to find the first message and first reply.

## Summary

Total time fell from 1541.229 to 456.599 ms, a 70.37% reduction. The biggest saving was R19, from 1120.872 to 2.224 ms.
