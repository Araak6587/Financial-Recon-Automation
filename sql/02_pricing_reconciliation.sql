-- ============================================================
-- FILE: 02_pricing_reconciliation.sql
-- PURPOSE: Compare Bloomberg prices vs Internal system prices
--          Identify discrepancies, missing prices, outliers
-- THIS IS THE CORE OF THE BOFA PRICING OPS ROLE
-- ============================================================


-- ============================================================
-- STEP 1: FULL OUTER JOIN — Bloomberg vs Internal
-- Shows every combination: matched, missing in internal,
-- missing in Bloomberg
-- ============================================================

SELECT
    COALESCE(b.price_date, i.price_date)   AS price_date,
    COALESCE(b.security_id, i.security_id) AS security_id,
    b.close_price                           AS bloomberg_price,
    i.close_price                           AS internal_price,
    CASE
        WHEN i.close_price IS NULL THEN 'MISSING IN INTERNAL'
        WHEN b.close_price IS NULL THEN 'MISSING IN BLOOMBERG'
        ELSE 'MATCHED'
    END AS status
FROM bloomberg_prices b
LEFT JOIN internal_prices i
    ON b.price_date = i.price_date
    AND b.security_id = i.security_id

UNION ALL

SELECT
    i.price_date,
    i.security_id,
    b.close_price,
    i.close_price,
    'MISSING IN BLOOMBERG'
FROM internal_prices i
LEFT JOIN bloomberg_prices b
    ON b.price_date = i.price_date
    AND b.security_id = i.security_id
WHERE b.price_date IS NULL

ORDER BY price_date, security_id;


-- ============================================================
-- STEP 2: FIND MISSING PRICES (Internal system didn't load)
-- These need to be investigated and manually loaded
-- ============================================================

SELECT
    b.price_date,
    b.security_id,
    sm.security_name,
    sm.asset_class,
    b.close_price AS bloomberg_price,
    'MISSING - NOT LOADED IN INTERNAL SYSTEM' AS issue
FROM bloomberg_prices b
LEFT JOIN internal_prices i
    ON b.price_date = i.price_date
    AND b.security_id = i.security_id
LEFT JOIN securities_master sm
    ON b.security_id = sm.security_id
WHERE i.close_price IS NULL
ORDER BY b.price_date, b.security_id;


-- ============================================================
-- STEP 3: CALCULATE PRICE VARIANCE
-- Flag anything > 1% difference as a discrepancy
-- This is the main QA check you'd run every end of day
-- ============================================================

WITH price_comparison AS (
    SELECT
        b.price_date,
        b.security_id,
        sm.security_name,
        sm.asset_class,
        b.close_price                                          AS bloomberg_price,
        i.close_price                                          AS internal_price,
        (i.close_price - b.close_price)                        AS price_diff,
        ROUND(ABS(i.close_price - b.close_price)
              / b.close_price * 100, 4)                        AS pct_diff
    FROM bloomberg_prices b
    JOIN internal_prices i
        ON b.price_date = i.price_date
        AND b.security_id = i.security_id
    JOIN securities_master sm
        ON b.security_id = sm.security_id
)
SELECT
    price_date,
    security_id,
    security_name,
    asset_class,
    bloomberg_price,
    internal_price,
    price_diff,
    pct_diff,
    CASE
        WHEN pct_diff > 10  THEN 'CRITICAL — ESCALATE IMMEDIATELY'
        WHEN pct_diff > 5   THEN 'HIGH — REVIEW TODAY'
        WHEN pct_diff > 1   THEN 'MEDIUM — INVESTIGATE'
        ELSE                     'OK'
    END AS severity
FROM price_comparison
WHERE pct_diff > 1
ORDER BY pct_diff DESC, price_date;


-- ============================================================
-- STEP 4: DAILY SUMMARY — How many issues each day?
-- This is what you'd put in a daily ops report to management
-- ============================================================

WITH price_comparison AS (
    SELECT
        b.price_date,
        b.security_id,
        b.close_price                                AS bloomberg_price,
        i.close_price                                AS internal_price,
        CASE WHEN i.close_price IS NULL THEN 1 ELSE 0 END AS is_missing,
        CASE
            WHEN i.close_price IS NOT NULL
             AND ABS(i.close_price - b.close_price)
                 / b.close_price * 100 > 1
            THEN 1 ELSE 0
        END AS is_discrepancy,
        CASE
            WHEN i.close_price IS NOT NULL
             AND ABS(i.close_price - b.close_price)
                 / b.close_price * 100 > 10
            THEN 1 ELSE 0
        END AS is_critical
    FROM bloomberg_prices b
    LEFT JOIN internal_prices i
        ON b.price_date = i.price_date
        AND b.security_id = i.security_id
)
SELECT
    price_date,
    COUNT(*)                    AS total_securities,
    SUM(is_missing)             AS missing_prices,
    SUM(is_discrepancy)         AS price_discrepancies,
    SUM(is_critical)            AS critical_issues,
    ROUND(
        (SUM(is_missing) + SUM(is_discrepancy)) * 100.0 / COUNT(*), 2
    )                           AS error_rate_pct
FROM price_comparison
GROUP BY price_date
ORDER BY price_date;


-- ============================================================
-- STEP 5: OUTLIER DETECTION using prior day comparison
-- If a price moves > 5% vs yesterday, flag it for review
-- Even if Bloomberg and internal match, could be bad data
-- ============================================================

WITH daily_prices AS (
    SELECT
        price_date,
        security_id,
        close_price,
        LAG(close_price) OVER (
            PARTITION BY security_id
            ORDER BY price_date
        ) AS prev_close,
        LAG(price_date) OVER (
            PARTITION BY security_id
            ORDER BY price_date
        ) AS prev_date
    FROM bloomberg_prices
)
SELECT
    dp.price_date,
    dp.security_id,
    sm.security_name,
    dp.prev_close,
    dp.close_price                                          AS current_price,
    ROUND((dp.close_price - dp.prev_close)
          / dp.prev_close * 100, 2)                         AS day_over_day_chg_pct,
    CASE
        WHEN ABS((dp.close_price - dp.prev_close)
                 / dp.prev_close * 100) > 10 THEN 'CRITICAL MOVE — VERIFY SOURCE'
        WHEN ABS((dp.close_price - dp.prev_close)
                 / dp.prev_close * 100) > 5  THEN 'LARGE MOVE — REVIEW'
        ELSE 'NORMAL'
    END AS flag
FROM daily_prices dp
JOIN securities_master sm ON dp.security_id = sm.security_id
WHERE dp.prev_close IS NOT NULL
  AND ABS((dp.close_price - dp.prev_close)
          / dp.prev_close * 100) > 5
ORDER BY ABS((dp.close_price - dp.prev_close)
             / dp.prev_close * 100) DESC;
