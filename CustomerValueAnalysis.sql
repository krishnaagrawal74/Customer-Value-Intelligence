CREATE DATABASE CustomerValue;
GO

use CustomerValue

EXEC sp_rename 'dbo.engineered_dataset', 'customers';

UPDATE customers
SET frequency_of_purchases = 'Bi-Weekly'
WHERE frequency_of_purchases = 'Fortnightly';

UPDATE customers
SET frequency_of_purchases = 'Quarterly'
WHERE frequency_of_purchases = 'Every 3 Months';


select count(*) from customers
--Section A — Customer Value Analysis
--Query A1: Customer Pyramid
--Business Question: What separates high-value customers from low-value customers?

SELECT
    value_tier,
    COUNT(*) AS customers,
    ROUND(AVG(Purchase_Amount_USD),2) AS avg_spend,
    ROUND(AVG(previous_purchases),1) AS avg_previous_purchases,
    ROUND(AVG(loyalty_score),3) AS avg_loyalty
FROM customers
GROUP BY value_tier
ORDER BY
CASE value_tier
    WHEN 'Premium' THEN 1
    WHEN 'High' THEN 2
    WHEN 'Medium' THEN 3
    WHEN 'Low' THEN 4
END;

------------------------------------------------------------------------
--Query A2: Who populates each value tier?
--Business Question: Are premium customers organic or discount driven?

SELECT
    value_tier,
    promo_persona,
    COUNT(*) AS customers,
    ROUND(AVG(loyalty_score),3) AS avg_loyalty,
    ROUND(AVG(promo_dependency_score),3) AS avg_dependency
FROM customers
GROUP BY value_tier, promo_persona
ORDER BY
    CASE value_tier
        WHEN 'Premium' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Low' THEN 4
    END,
    CASE promo_persona
        WHEN 'Organic' THEN 1
        WHEN 'Subscriber' THEN 2
        WHEN 'Promo_Opportunist' THEN 3
    END;
------------------------------------------------------------------------

--Section B — Loyalty vs Discount Dependence
--This directly answers Key Question 1.
--Query B1: Loyalty by Persona

SELECT
    promo_persona,
    COUNT(*) AS customers,
    ROUND(AVG(loyalty_score),3) AS avg_loyalty,
    ROUND(AVG(previous_purchases),1) AS avg_tenure,
    ROUND(AVG(purchase_frequency_score),1) AS avg_frequency
FROM customers
GROUP BY promo_persona
ORDER BY avg_loyalty DESC;
------------------------------------------------------------------------

--Query B2: Promo Dependency Bands
--Business Question: Which customers are genuinely loyal and which are discount dependent?

WITH DependencyBands AS
(
    SELECT
        CASE
            WHEN promo_dependency_score = 0 THEN 'Organic'
            WHEN promo_dependency_score < 0.35 THEN 'Low Dependency'
            WHEN promo_dependency_score < 0.65 THEN 'Moderate Dependency'
            ELSE 'High Dependency'
        END AS dependency_band,
        loyalty_score
    FROM customers
)

SELECT
    dependency_band,
    COUNT(*) AS customers,
    ROUND(AVG(loyalty_score),3) AS avg_loyalty
FROM DependencyBands
GROUP BY dependency_band
ORDER BY
CASE dependency_band
    WHEN 'Organic' THEN 1
    WHEN 'Low Dependency' THEN 2
    WHEN 'Moderate Dependency' THEN 3
    WHEN 'High Dependency' THEN 4
END;
------------------------------------------------------------------------

-- Section C — Repeat Purchase Drivers
-- Query C1: Frequency × Tenure Matrix
-- Business Question:
-- Which behavioral patterns predict high customer value?

SELECT
    tenure_tier,
    frequency_of_purchases,

    COUNT(*) AS customers,

    ROUND(AVG(loyalty_score),3) AS avg_loyalty,

    ROUND(AVG(previous_purchases),1) AS avg_tenure,

    ROUND(
        100.0 *
        SUM(CASE
                WHEN value_tier = 'Premium' THEN 1
                ELSE 0
            END)
        / COUNT(*),
        1
    ) AS premium_pct

FROM customers

GROUP BY
    tenure_tier,
    frequency_of_purchases

ORDER BY
    premium_pct DESC,
    CASE tenure_tier
        WHEN 'Loyal' THEN 1
        WHEN 'Established' THEN 2
        WHEN 'Growing' THEN 3
        WHEN 'New' THEN 4
    END,
    CASE frequency_of_purchases
        WHEN 'Weekly' THEN 1
        WHEN 'Bi-Weekly' THEN 2
        WHEN 'Monthly' THEN 3
        WHEN 'Quarterly' THEN 4
        WHEN 'Annually' THEN 5
    END;
------------------------------------------------------------------------

--Query C2: Satisfaction vs Loyalty
SELECT
    satisfaction_flag,

    ROUND(AVG(loyalty_score),3) AS avg_loyalty,

    ROUND(AVG(previous_purchases),1) AS avg_tenure

FROM customers
GROUP BY satisfaction_flag;

--Business Question: Does satisfaction predict loyalty?
------------------------------------------------------------------------

--Section D — Category & Season Analysis: This answers the actual problem statement.

--Query D1: Category Retention Funnel

SELECT
    category,

    ROUND(AVG(previous_purchases),1)
        AS avg_previous_purchases,

    ROUND(AVG(loyalty_score),3)
        AS avg_loyalty

FROM customers
GROUP BY category
ORDER BY avg_previous_purchases DESC;
------------------------------------------------------------------------

--Query D2: Season Analysis

SELECT
    season,

    ROUND(AVG(previous_purchases),1)
        AS avg_previous_purchases,

    ROUND(AVG(loyalty_score),3)
        AS avg_loyalty

FROM customers
GROUP BY season
ORDER BY avg_previous_purchases DESC;

--Business Question: Which categories and seasons create repeat customers?
------------------------------------------------------------------------

--Section E — Geography Analysis
--This answers: Which geographies signal organic demand versus discount-driven volume?

--Query E1: Geography Opportunity Map
SELECT
    location,

    COUNT(*) AS customers,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN promo_persona='Organic'
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),1
    ) AS organic_pct,

    ROUND(AVG(loyalty_score),3)
        AS avg_loyalty,

    ROUND(AVG(promo_dependency_score),3)
        AS avg_dependency

FROM customers
GROUP BY location
ORDER BY avg_loyalty DESC;
------------------------------------------------------------------------

-- Query E2: Underleveraged Markets
-- Business Question: Which markets deserve more investment?

SELECT
    location,
    COUNT(*) AS customers,
    ROUND(AVG(Purchase_Amount_USD),2) AS avg_spend,
    ROUND(AVG(loyalty_score),3) AS avg_loyalty

FROM customers

GROUP BY location

HAVING
    AVG(Purchase_Amount_USD) > 60
    AND AVG(loyalty_score) > 0.15

ORDER BY
    avg_spend DESC;
------------------------------------------------------------------------

--Section F — Ideal Customer Profile

--This answers Key Question 5.

--Query F1: Ideal Customer
SELECT
    age_group,
    gender,
    category,

    COUNT(*) AS customers,

    ROUND(AVG(loyalty_score),3)
        AS avg_loyalty

FROM customers

WHERE
    value_tier='Premium'
    AND promo_persona='Organic'

GROUP BY
    age_group,
    gender,
    category

ORDER BY avg_loyalty DESC;

------------------------------------------------------------------------

--Section G — Promotion Sunset Strategy
--This answers Key Question 4.

--Query G1: Discount Removal Candidates

SELECT
    tenure_tier,
    frequency_of_purchases,

    COUNT(*) AS customers,

    ROUND(AVG(loyalty_score),3)
        AS avg_loyalty,

    ROUND(AVG(promo_dependency_score),3)
        AS avg_dependency

FROM customers

WHERE promo_persona='Subscriber'

GROUP BY
    tenure_tier,
    frequency_of_purchases

ORDER BY avg_loyalty DESC;