-- ============================================================
-- FILE: 01_setup_tables.sql
-- PURPOSE: Create all tables and load data from CSVs
-- RUN THIS FIRST
-- ============================================================

-- Drop tables if they exist (for clean re-runs)
DROP TABLE IF EXISTS securities_master;
DROP TABLE IF EXISTS bloomberg_prices;
DROP TABLE IF EXISTS internal_prices;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS gl_entries;
DROP TABLE IF EXISTS budget_vs_actuals;

-- Securities reference table
CREATE TABLE securities_master (
    security_id   TEXT PRIMARY KEY,
    security_name TEXT,
    asset_class   TEXT,
    currency      TEXT,
    exchange      TEXT
);

-- Bloomberg end-of-day prices (external source of truth)
CREATE TABLE bloomberg_prices (
    price_date   DATE,
    security_id  TEXT,
    close_price  DECIMAL(12,4),
    source       TEXT,
    PRIMARY KEY (price_date, security_id)
);

-- Internal system prices (what our system loaded)
CREATE TABLE internal_prices (
    price_date   DATE,
    security_id  TEXT,
    close_price  DECIMAL(12,4),
    loaded_at    TIMESTAMP,
    PRIMARY KEY (price_date, security_id)
);

-- Trade transactions
CREATE TABLE transactions (
    txn_id      INTEGER PRIMARY KEY,
    txn_date    DATE,
    security_id TEXT,
    txn_type    TEXT,
    quantity    INTEGER,
    price       DECIMAL(12,4),
    amount      DECIMAL(14,2),
    account_id  TEXT
);

-- General Ledger entries
CREATE TABLE gl_entries (
    gl_id      INTEGER PRIMARY KEY,
    entry_date DATE,
    account_id TEXT,
    security_id TEXT,
    debit      DECIMAL(14,2),
    credit     DECIMAL(14,2),
    description TEXT
);

-- Budget vs Actuals by department
CREATE TABLE budget_vs_actuals (
    month          TEXT,
    department     TEXT,
    budget_amount  DECIMAL(14,2),
    actual_amount  DECIMAL(14,2),
    category       TEXT
);

-- ============================================================
-- LOAD DATA (SQLite syntax using .import)
-- In PostgreSQL, use COPY instead:
--   COPY bloomberg_prices FROM '/path/to/bloomberg_prices.csv' CSV HEADER;
-- ============================================================

.mode csv
.import data/securities_master.csv securities_master
.import data/bloomberg_prices.csv bloomberg_prices
.import data/internal_prices.csv internal_prices
.import data/transactions.csv transactions
.import data/gl_entries.csv gl_entries
.import data/budget_vs_actuals.csv budget_vs_actuals

-- Quick row count check
SELECT 'securities_master' as tbl, COUNT(*) as rows FROM securities_master
UNION ALL SELECT 'bloomberg_prices', COUNT(*) FROM bloomberg_prices
UNION ALL SELECT 'internal_prices', COUNT(*) FROM internal_prices
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL SELECT 'gl_entries', COUNT(*) FROM gl_entries
UNION ALL SELECT 'budget_vs_actuals', COUNT(*) FROM budget_vs_actuals;
