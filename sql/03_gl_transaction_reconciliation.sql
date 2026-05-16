-- ============================================================
-- FILE: 03_gl_transaction_reconciliation.sql
-- PURPOSE: Reconcile GL entries against transactions
--          Catch posting errors, missing entries, mismatches
-- ============================================================


-- ============================================================
-- STEP 1: DAILY TRANSACTION TOTALS by account
-- Sum up what transactions say happened each day
-- ============================================================

SELECT
    txn_date,
    account_id,
    COUNT(*)                        AS trade_count,
    SUM(CASE WHEN txn_type = 'BUY'  THEN amount ELSE 0 END)  AS total_buys,
    SUM(CASE WHEN txn_type = 'SELL' THEN amount ELSE 0 END)  AS total_sells,
    SUM(CASE WHEN txn_type IN ('DIVIDEND','COUPON') THEN amount ELSE 0 END) AS income,
    SUM(amount)                     AS net_flow
FROM transactions
GROUP BY txn_date, account_id
ORDER BY txn_date, account_id;


-- ============================================================
-- STEP 2: DAILY GL TOTALS by account
-- Sum up what the GL says was posted each day
-- ============================================================

SELECT
    entry_date,
    account_id,
    COUNT(*)                        AS gl_entry_count,
    SUM(debit)                      AS total_debits,
    SUM(credit)                     AS total_credits,
    SUM(debit) - SUM(credit)        AS net_gl_flow
FROM gl_entries
GROUP BY entry_date, account_id
ORDER BY entry_date, account_id;


-- ============================================================
-- STEP 3: CORE RECON — Transaction totals vs GL totals
-- This finds the breaks — where GL doesn't match trades
-- ============================================================

WITH txn_summary AS (
    SELECT
        txn_date        AS recon_date,
        account_id,
        SUM(amount)     AS txn_net_flow
    FROM transactions
    GROUP BY txn_date, account_id
),
gl_summary AS (
    SELECT
        entry_date      AS recon_date,
        account_id,
        SUM(debit) - SUM(credit) AS gl_net_flow
    FROM gl_entries
    GROUP BY entry_date, account_id
)
SELECT
    COALESCE(t.recon_date, g.recon_date)    AS recon_date,
    COALESCE(t.account_id, g.account_id)    AS account_id,
    ROUND(t.txn_net_flow, 2)                AS txn_net_flow,
    ROUND(g.gl_net_flow, 2)                 AS gl_net_flow,
    ROUND(t.txn_net_flow - g.gl_net_flow, 2) AS break_amount,
    CASE
        WHEN t.txn_net_flow IS NULL                                THEN 'NO TRANSACTIONS FOUND'
        WHEN g.gl_net_flow IS NULL                                 THEN 'NO GL ENTRIES FOUND'
        WHEN ABS(t.txn_net_flow - g.gl_net_flow) < 0.01           THEN 'RECONCILED'
        WHEN ABS(t.txn_net_flow - g.gl_net_flow) > 10000          THEN 'CRITICAL BREAK'
        ELSE                                                            'BREAK — INVESTIGATE'
    END AS recon_status
FROM txn_summary t
FULL OUTER JOIN gl_summary g
    ON t.recon_date = g.recon_date
    AND t.account_id = g.account_id
ORDER BY recon_date, account_id;


-- ============================================================
-- STEP 4: SUMMARY — How many breaks, total break amount
-- What you'd report up in a daily ops email
-- ============================================================

WITH txn_summary AS (
    SELECT txn_date AS recon_date, account_id, SUM(amount) AS txn_net_flow
    FROM transactions GROUP BY txn_date, account_id
),
gl_summary AS (
    SELECT entry_date AS recon_date, account_id, SUM(debit) - SUM(credit) AS gl_net_flow
    FROM gl_entries GROUP BY entry_date, account_id
),
recon AS (
    SELECT
        COALESCE(t.recon_date, g.recon_date) AS recon_date,
        t.txn_net_flow,
        g.gl_net_flow,
        ABS(COALESCE(t.txn_net_flow,0) - COALESCE(g.gl_net_flow,0)) AS break_amt,
        CASE
            WHEN ABS(COALESCE(t.txn_net_flow,0) - COALESCE(g.gl_net_flow,0)) < 0.01 THEN 'RECONCILED'
            ELSE 'BREAK'
        END AS status
    FROM txn_summary t
    FULL OUTER JOIN gl_summary g
        ON t.recon_date = g.recon_date AND t.account_id = g.account_id
)
SELECT
    recon_date,
    COUNT(*)                            AS total_accounts,
    SUM(CASE WHEN status = 'RECONCILED' THEN 1 ELSE 0 END) AS reconciled,
    SUM(CASE WHEN status = 'BREAK' THEN 1 ELSE 0 END)      AS breaks,
    ROUND(SUM(CASE WHEN status = 'BREAK' THEN break_amt ELSE 0 END), 2) AS total_break_amount
FROM recon
GROUP BY recon_date
ORDER BY recon_date;


-- ============================================================
-- STEP 5: AGING ANALYSIS — How old are unresolved breaks?
-- Ops teams track this — old breaks = bigger risk
-- ============================================================

WITH txn_summary AS (
    SELECT txn_date AS recon_date, account_id, SUM(amount) AS txn_net_flow
    FROM transactions GROUP BY txn_date, account_id
),
gl_summary AS (
    SELECT entry_date AS recon_date, account_id, SUM(debit) - SUM(credit) AS gl_net_flow
    FROM gl_entries GROUP BY entry_date, account_id
)
SELECT
    t.recon_date,
    t.account_id,
    ROUND(t.txn_net_flow, 2)                     AS txn_net_flow,
    ROUND(g.gl_net_flow, 2)                       AS gl_net_flow,
    ROUND(t.txn_net_flow - g.gl_net_flow, 2)      AS break_amount,
    JULIANDAY('2025-03-20') - JULIANDAY(t.recon_date) AS days_outstanding,
    CASE
        WHEN JULIANDAY('2025-03-20') - JULIANDAY(t.recon_date) > 5 THEN 'AGED — ESCALATE'
        WHEN JULIANDAY('2025-03-20') - JULIANDAY(t.recon_date) > 2 THEN 'AGING — PRIORITY'
        ELSE 'RECENT'
    END AS aging_status
FROM txn_summary t
JOIN gl_summary g
    ON t.recon_date = g.recon_date
    AND t.account_id = g.account_id
WHERE ABS(t.txn_net_flow - g.gl_net_flow) > 0.01
ORDER BY days_outstanding DESC, ABS(t.txn_net_flow - g.gl_net_flow) DESC;
