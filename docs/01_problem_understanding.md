# 01 · Problem understanding

OLX India is a used-goods marketplace. Sellers post **ads (listings)** in a category, with a price, condition, photos, location and category-specific details. Ads stay live for 30 days unless they are sold or removed, and sellers can pay for **boost packages**. Buyers chat, make offers, save favourites, report ads and rate sellers. The database has no documented schema and seven teams report problems.

| # | What the business needs (our words) | Stakeholder affected | Queries | Class |
|---|---|---|---|---|
| **P1** | Buyers filter by category, city, price, car details (fuel, year, km), free-text title and "near me" distance, and expect results instantly. Slow pages make buyers leave. | Buyers | R01, R02, R03, R09 | **Customer-facing / real-time** |
| **P2** | Sellers open an ad page (ad, seller, rating), see "My Ads" by status, post new ads and mark ads sold. Each is one click and must feel instant. | Sellers (and buyers on the ad page) | R04, R05, W01, W02 | **Customer-facing / real-time** |
| **P3** | The chat inbox (latest message per conversation), the unread badge (shown on every page) and sending a message must be fast, even for very active users. | Buyers and sellers in chat | R06, R07, W03 | **Customer-facing / real-time** |
| **P4** | Trust & Safety must find ads with many open reports, users posting spam bursts, duplicate ads, and page through all ads in the console. Tools are interactive, but fraud must be caught quickly. | Moderation / Trust & Safety | R11, R12, R18, R22 | Interactive tools (R11, R22) + **reporting** (R12, R18) |
| **P5** | Monetisation wants to know which boost packages were never bought, and how boosted ads perform against normal ads. The "never bought" report is **always empty, which is a wrong result**, not just a slow query. | Monetisation (boosts) | R13, R17 | **Reporting / analytics** (correctness bug in R13) |
| **P6** | Category managers need a price guide (median price), time to sell, offer acceptance rate and seller reply time per category. These read large parts of the data and currently time out. | Category managers | R08, R14, R15, R25 | **Reporting / analytics** |
| **P7** | Growth needs daily-ads and running-total reports, trending ads, best sellers, city reports and the home-page category counts. Platform needs the expiry reminder job, the login lookup and the nightly expiry job to keep working when ads grow **20×**. | Growth, platform, support (login) | R10, R16, R19, R20, R21, R23, R24, W04, W05 | Mixed: R23, W05 **real-time**; R10, R16 interactive; R19–R21, R24 **reporting**; W04 **batch** |

**Performance classes we will use later (README §5.2):**
real-time / user-facing < 5 ms (R01–R07, R09, R23, W01–W03, W05) · interactive tools < 250 ms (R10, R11, R13, R16, R22) · reports < 5 s (R08, R12, R14, R15, R17–R21, R24, R25) · batch < 1 s (W04).

## Assumptions

1. The seed export is a **snapshot taken at 00:00 IST on 1 July 2026**. Ads were posted between 1 Jan 2025 and 30 Jun 2026, and every write query (W01–W05) uses timestamps on 1 July 2026.
2. All timestamps are Indian Standard Time (`+05:30`), so they are stored as `timestamptz`. Money is in rupees, stored as an exact `numeric` value.
3. Users and listings are **soft-deleted**: users are banned (`is_banned`) and ads get `status = 'REMOVED'`. Hard deletes are rare admin actions, which is why most foreign keys are `RESTRICT`.
4. An ad normally lives 30 days. About 2% of ads have a longer expiry (60–570 days), which we read as renewed or relisted ads, so only `expires_at > posted_at` is enforced.
5. One chat thread exists per (ad, buyer). A buyer may send **several offers** on the same ad (counter-offers). A rating belongs to one deal, so a rater can rate a given ad only once.
6. "Real-time" means a single user waits on the page, so the query must use an index and touch only a few rows. "Reporting" can scan, but must finish within seconds at 20× the data.
7. The query results must not change when we optimise (Phase 4), except for the R13 bug, which we fix and explain separately.
