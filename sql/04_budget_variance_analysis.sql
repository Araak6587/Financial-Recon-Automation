-- ============================================================
-- FILE: 04_budget_variance_analysis.sql
-- PURPOSE: Budget vs Actual analysis, variance identification,
--          trend analysis by department and category
-- MAPS TO: Northern Trust $57M expense story
-- ============================================================


-- ============================================================
-- STEP 1: BASIC VARIANCE — Budget vs Actual by dept/month
-- Favorable = under budget, Unfavorable = over budget
-- ============================================================

SELECT
    month,
    department,
    category,
    ROUND(budget_amount, 2)                             AS budget,
    ROUND(actual_amount, 2)                             AS actual,
    ROUND(actual_amount - budget_amount, 2)             AS variance_amount,
    ROUND((actual_amount - budget_amount)
          / budget_amount * 100, 1)                     AS variance_pct,
    CASE
        WHEN actual_amount <= budget_amount             THEN 'Favorable'
        ELSE                                                 'Unfavorable'
    END AS variance_type,
    CASE
        WHEN ABS((actual_amount - budget_amount)
                 / budget_amount * 100) > 15            THEN 'MATERIAL — EXPLAIN'
        WHEN ABS((actual_amount - budget_amount)
                 / budget_amount * 100) > 5             THEN 'NOTABLE'
        ELSE                                                 'Within tolerance'
    END AS materiality
FROM budget_vs_actuals
ORDER BY ABS(actual_amount - budget_amount) DESC;


-- ============================================================
-- STEP 2: DEPARTMENT ROLLUP — Total variance per dept
-- Which departments are the biggest overspenders?
-- ============================================================

SELECT
    month,
    department,
    ROUND(SUM(budget_amount), 2)                        AS total_budget,
    ROUND(SUM(actual_amount), 2)                        AS total_actual,
    ROUND(SUM(actual_amount - budget_amount), 2)        AS total_variance,
    ROUND(SUM(actual_amount - budget_amount)
          / SUM(budget_amount) * 100, 1)                AS variance_pct,
    SUM(CASE WHEN actual_amount > budget_amount
             THEN 1 ELSE 0 END)                         AS categories_over_budget,
    SUM(CASE WHEN actual_amount <= budget_amount
             THEN 1 ELSE 0 END)                         AS categories_under_budget
FROM budget_vs_actuals
GROUP BY month, department
ORDER BY month, SUM(actual_amount - budget_amount) DESC;


-- ============================================================
-- STEP 3: YTD CUMULATIVE SPEND vs BUDGET
-- Track cumulative spend — are we on pace to blow the budget?
-- ============================================================

WITH monthly_totals AS (
    SELECT
        month,
        department,
        SUM(budget_amount) AS monthly_budget,
        SUM(actual_amount) AS monthly_actual
    FROM budget_vs_actuals
    GROUP BY month, department
)
SELECT
    month,
    department,
    ROUND(monthly_budget, 2)                            AS monthly_budget,
    ROUND(monthly_actual, 2)                            AS monthly_actual,
    ROUND(SUM(monthly_budget) OVER (
        PARTITION BY department
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2)                                               AS ytd_budget,
    ROUND(SUM(monthly_actual) OVER (
        PARTITION BY department
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2)                                               AS ytd_actual,
    ROUND(SUM(monthly_actual) OVER (
        PARTITION BY department
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) - SUM(monthly_budget) OVER (
        PARTITION BY department
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2)                                               AS ytd_variance
FROM monthly_totals
ORDER BY department, month;


-- ============================================================
-- STEP 4: CATEGORY ANALYSIS — Which spend categories drive variance?
-- The "10% inefficiency" story lives here
-- ============================================================

SELECT
    category,
    ROUND(SUM(budget_amount), 2)                        AS total_budget,
    ROUND(SUM(actual_amount), 2)                        AS total_actual,
    ROUND(SUM(actual_amount - budget_amount), 2)        AS total_variance,
    ROUND(SUM(actual_amount - budget_amount)
          / SUM(budget_amount) * 100, 1)                AS variance_pct,
    COUNT(DISTINCT department)                           AS departments_affected,
    SUM(CASE WHEN actual_amount > budget_amount * 1.10
             THEN 1 ELSE 0 END)                         AS instances_over_10pct
FROM budget_vs_actuals
GROUP BY category
ORDER BY ABS(SUM(actual_amount - budget_amount)) DESC;


-- ============================================================
-- STEP 5: MONTH OVER MONTH TREND
-- Is overspending getting better or worse over time?
-- ============================================================

WITH monthly_summary AS (
    SELECT
        month,
        SUM(budget_amount)  AS total_budget,
        SUM(actual_amount)  AS total_actual,
        SUM(actual_amount - budget_amount) AS total_variance
    FROM budget_vs_actuals
    GROUP BY month
)
SELECT
    month,
    ROUND(total_budget, 2)                              AS total_budget,
    ROUND(total_actual, 2)                              AS total_actual,
    ROUND(total_variance, 2)                            AS variance,
    ROUND(total_variance / total_budget * 100, 1)       AS variance_pct,
    ROUND(total_variance - LAG(total_variance) OVER (
        ORDER BY month
    ), 2)                                               AS variance_change_vs_prior_month,
    CASE
        WHEN total_variance - LAG(total_variance) OVER (ORDER BY month) < 0
        THEN 'Improving'
        WHEN total_variance - LAG(total_variance) OVER (ORDER BY month) > 0
        THEN 'Worsening'
        ELSE 'Stable'
    END AS trend
FROM monthly_summary
ORDER BY month;
