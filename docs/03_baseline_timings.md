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
