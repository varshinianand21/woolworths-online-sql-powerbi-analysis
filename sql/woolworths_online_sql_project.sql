/* =====================================================================
   Woolworths Online Melbourne
   Customer Loyalty & Fulfilment Performance Analysis
   Tool: MySQL 8.4   |   Data: simulated case-study data, Jan 2024 – Dec 2025

   This one file does the whole project from start to finish:
     Part 1  Load the raw data
     Part 2  Clean the data
     Part 3  Analyse it in 8 steps
     Part 4  Create views for my Power BI dashboard

   It starts fresh every time, so I can run the whole file again
   whenever I want and always get the same results.

   Before running: the 7 CSV files must be in the folder shown by
   SHOW VARIABLES LIKE 'secure_file_priv';
   (on my computer: C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/)
   ===================================================================== */


/* =====================================================================
   PART 1: LOADING THE RAW DATA
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS woolworths_online;
USE woolworths_online;

-- Switching off foreign key checks so I can drop the old tables in any order
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS customer_feedback, deliveries, order_items, orders, orders_dedup, products, stores, customers;
SET FOREIGN_KEY_CHECKS = 1;

-- Creating empty tables with the right data types
CREATE TABLE customers (
    customer_id               VARCHAR(10),
    signup_date               DATE,
    suburb                    VARCHAR(60),
    postcode                  INT,
    region                    VARCHAR(20),
    age_band                  VARCHAR(10),
    everyday_rewards_member   CHAR(1),
    delivery_unlimited_member CHAR(1)
);

CREATE TABLE stores (
    store_id     VARCHAR(5),
    store_name   VARCHAR(80),
    region       VARCHAR(20),
    store_format VARCHAR(20)
);

CREATE TABLE products (
    product_id   VARCHAR(10),
    product_name VARCHAR(100),
    department   VARCHAR(40),
    brand_type   VARCHAR(30),
    unit_price   DECIMAL(8,2)
);

-- No primary keys yet: I add them after cleaning, because the raw data has duplicates
CREATE TABLE orders (
    order_id                 VARCHAR(10),
    customer_id              VARCHAR(10),
    store_id                 VARCHAR(5),
    order_datetime           DATETIME,
    fulfilment_type          VARCHAR(30),
    order_status             VARCHAR(20),
    basket_value_aud         DECIMAL(10,2),
    delivery_fee_aud         DECIMAL(6,2),
    promo_code               VARCHAR(20),
    rewards_points_earned    INT,
    rewards_dollars_redeemed DECIMAL(6,2)
);

CREATE TABLE order_items (
    order_id              VARCHAR(10),
    product_id            VARCHAR(10),
    quantity              INT,
    unit_price_aud        DECIMAL(8,2),
    discount_aud          DECIMAL(8,2),
    pick_status           VARCHAR(20),
    substitute_product_id VARCHAR(10)
);

CREATE TABLE deliveries (
    order_id        VARCHAR(10),
    window_start    DATETIME,
    window_end      DATETIME,
    delivered_at    DATETIME,
    delivery_status VARCHAR(20),
    minutes_late    INT
);

CREATE TABLE customer_feedback (
    order_id         VARCHAR(10),
    feedback_date    DATE,
    rating           INT,
    complaint_reason VARCHAR(40),
    refund_aud       DECIMAL(8,2)
);

-- Loading each CSV file into its table
-- NULLIF turns empty cells into proper NULLs instead of blank text or 0

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/customers.csv' INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(customer_id, signup_date, @suburb, postcode, region, age_band, everyday_rewards_member, delivery_unlimited_member)
SET suburb = NULLIF(@suburb,'');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/stores.csv' INTO TABLE stores
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/products.csv' INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/orders.csv' INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, customer_id, store_id, order_datetime, fulfilment_type, order_status,
 basket_value_aud, delivery_fee_aud, @promo, rewards_points_earned, rewards_dollars_redeemed)
SET promo_code = NULLIF(@promo,'');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/order_items.csv' INTO TABLE order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, product_id, quantity, unit_price_aud, discount_aud, pick_status, @sub)
SET substitute_product_id = NULLIF(@sub,'');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/deliveries.csv' INTO TABLE deliveries
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, @ws, @we, @da, delivery_status, @ml)
SET window_start = NULLIF(@ws,''), window_end = NULLIF(@we,''),
    delivered_at = NULLIF(@da,''), minutes_late = NULLIF(@ml,'');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/customer_feedback.csv' INTO TABLE customer_feedback
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, feedback_date, rating, @reason, refund_aud)
SET complaint_reason = NULLIF(@reason,'');

-- Checking every table loaded fully
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'stores', COUNT(*) FROM stores
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'deliveries', COUNT(*) FROM deliveries
UNION ALL SELECT 'customer_feedback', COUNT(*) FROM customer_feedback;


-- Turning off safe update mode so I can update whole columns during cleaning
SET SQL_SAFE_UPDATES = 0;


/* =====================================================================
   PART 2: DATA CLEANING
   My rule: first look at the problem, then fix it, then check the fix.
   ===================================================================== */

-- ---------- 1.1 Duplicate orders ----------

-- Checking if any order_id appears more than once
SELECT order_id, COUNT(*) AS times_appearing
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY times_appearing DESC;

-- Counting how many extra rows there are in total
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_rows
FROM orders;

-- The duplicates are exact copies, so I rebuild the table with one copy of each row
DROP TABLE IF EXISTS orders_dedup;
CREATE TABLE orders_dedup AS
SELECT DISTINCT * FROM orders;

-- Replacing the old table with the clean one
DROP TABLE orders;
RENAME TABLE orders_dedup TO orders;

-- Checking the fix worked (should be 0)
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_rows_remaining
FROM orders;


-- ---------- 1.2 Inconsistent fulfilment types ----------

-- A normal GROUP BY shows only 3 types because MySQL ignores upper/lower case
SELECT fulfilment_type, COUNT(*) AS orders
FROM orders
GROUP BY fulfilment_type;

-- Using BINARY to compare exactly, which shows the hidden messy spellings
SELECT BINARY fulfilment_type AS exact_value, COUNT(*) AS orders
FROM orders
GROUP BY BINARY fulfilment_type;

-- Standardising every spelling to one clean version
UPDATE orders
SET fulfilment_type = CASE LOWER(fulfilment_type)
                        WHEN 'home delivery'  THEN 'Home Delivery'
                        WHEN 'pick up'        THEN 'Pick up'
                        WHEN 'direct to boot' THEN 'Direct to Boot'
                        ELSE fulfilment_type
                      END;

-- Checking the fix worked (should be 3 rows)
SELECT BINARY fulfilment_type AS exact_value, COUNT(*) AS orders
FROM orders
GROUP BY BINARY fulfilment_type;


-- ---------- 1.3 Suburb names ----------

-- Finding suburbs typed in all capitals
SELECT suburb, COUNT(*) AS customers
FROM customers
WHERE BINARY suburb = BINARY UPPER(suburb)
GROUP BY suburb;

-- Making a list of the correct spellings to use as a lookup
DROP TEMPORARY TABLE IF EXISTS suburb_lookup;
CREATE TEMPORARY TABLE suburb_lookup AS
SELECT DISTINCT suburb AS proper_name
FROM customers
WHERE suburb IS NOT NULL
  AND BINARY suburb <> BINARY UPPER(suburb);

-- Replacing the capital-letter versions with the correct spelling
UPDATE customers c
JOIN suburb_lookup s ON UPPER(c.suburb) = UPPER(s.proper_name)
SET c.suburb = s.proper_name
WHERE BINARY c.suburb = BINARY UPPER(c.suburb);

-- Counting customers with no suburb
SELECT COUNT(*) AS missing_suburb
FROM customers
WHERE suburb IS NULL;

-- Checking if any postcode belongs to more than one suburb
-- (if it does, I can't use the postcode to fill in the suburb)
SELECT postcode, COUNT(DISTINCT suburb) AS suburbs_in_postcode
FROM customers
WHERE suburb IS NOT NULL
GROUP BY postcode
HAVING COUNT(DISTINCT suburb) > 1;

-- Making a postcode-to-suburb lookup, only for postcodes with one suburb
DROP TEMPORARY TABLE IF EXISTS postcode_lookup;
CREATE TEMPORARY TABLE postcode_lookup AS
SELECT postcode, MIN(suburb) AS suburb
FROM customers
WHERE suburb IS NOT NULL
GROUP BY postcode
HAVING COUNT(DISTINCT suburb) = 1;

-- Filling in missing suburbs using the postcode
UPDATE customers c
JOIN postcode_lookup p ON c.postcode = p.postcode
SET c.suburb = p.suburb
WHERE c.suburb IS NULL;

-- Labelling the rest as Unknown instead of guessing
UPDATE customers
SET suburb = 'Unknown'
WHERE suburb IS NULL;

SELECT COUNT(*) AS still_unknown FROM customers WHERE suburb = 'Unknown';


-- ---------- 1.4 Sanity checks (all should be 0) ----------

-- Checking for missing or negative values in important columns
SELECT
    SUM(customer_id IS NULL)      AS null_customer,
    SUM(order_datetime IS NULL)   AS null_datetime,
    SUM(basket_value_aud IS NULL) AS null_basket,
    SUM(basket_value_aud < 0)     AS negative_basket
FROM orders;

-- Checking every order belongs to a real customer
SELECT COUNT(*) AS orphan_orders
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Checking every order line belongs to a real product
SELECT COUNT(*) AS orphan_items
FROM order_items i
LEFT JOIN products p ON i.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Checking all ratings are between 1 and 5
SELECT COUNT(*) AS bad_ratings
FROM customer_feedback
WHERE rating NOT BETWEEN 1 AND 5;


-- ---------- 1.5 Keys and indexes ----------
-- I add these after cleaning, because the raw data had duplicates
-- that would have broken these rules.

-- Primary keys: each row must be unique
ALTER TABLE customers         ADD PRIMARY KEY (customer_id);
ALTER TABLE stores            ADD PRIMARY KEY (store_id);
ALTER TABLE products          ADD PRIMARY KEY (product_id);
ALTER TABLE orders            ADD PRIMARY KEY (order_id);
ALTER TABLE order_items       ADD PRIMARY KEY (order_id, product_id);
ALTER TABLE deliveries        ADD PRIMARY KEY (order_id);
ALTER TABLE customer_feedback ADD PRIMARY KEY (order_id);

-- Foreign keys: links between tables must point to real records
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    ADD CONSTRAINT fk_orders_store    FOREIGN KEY (store_id)    REFERENCES stores(store_id);
ALTER TABLE order_items
    ADD CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    ADD CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id);
ALTER TABLE deliveries
    ADD CONSTRAINT fk_deliveries_order FOREIGN KEY (order_id) REFERENCES orders(order_id);
ALTER TABLE customer_feedback
    ADD CONSTRAINT fk_feedback_order FOREIGN KEY (order_id) REFERENCES orders(order_id);

-- Indexes to make my joins faster on the big tables
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_datetime);
CREATE INDEX idx_items_product        ON order_items (product_id);


/* =====================================================================
   PART 3: ANALYSIS
   Revenue = basket value of completed orders (after discounts,
   not including delivery fees).
   ===================================================================== */

-- ---------- STEP 1: Exploring the database ----------

-- Listing all my tables and their size
SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = 'woolworths_online';

-- Listing every column and its data type
SELECT table_name, column_name, data_type, column_key
FROM information_schema.columns
WHERE table_schema = 'woolworths_online'
ORDER BY table_name, ordinal_position;


-- ---------- STEP 2: Exploring the categories ----------

-- Customers by region
SELECT region, COUNT(*) AS customers
FROM customers GROUP BY region ORDER BY customers DESC;

-- Products by department and brand type
SELECT department, brand_type, COUNT(*) AS products
FROM products GROUP BY department, brand_type ORDER BY department;

-- Orders by fulfilment type
SELECT fulfilment_type, COUNT(*) AS orders
FROM orders GROUP BY fulfilment_type;

-- Customers by membership type
SELECT everyday_rewards_member, delivery_unlimited_member, COUNT(*) AS customers
FROM customers
GROUP BY everyday_rewards_member, delivery_unlimited_member;


-- ---------- STEP 3: Looking at dates and trends ----------

-- First and last order date
SELECT MIN(order_datetime) AS first_order,
       MAX(order_datetime) AS last_order,
       TIMESTAMPDIFF(MONTH, MIN(order_datetime), MAX(order_datetime)) AS months_covered
FROM orders;

-- Monthly orders and revenue, with growth compared to last month
-- (LAG gets the previous month's revenue so I can calculate growth)
WITH monthly AS (
    SELECT DATE_FORMAT(order_datetime, '%Y-%m') AS order_month,
           COUNT(*)                             AS orders,
           ROUND(SUM(basket_value_aud), 0)      AS revenue
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY order_month
)
SELECT order_month,
       orders,
       revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
                 / LAG(revenue) OVER (ORDER BY order_month), 1) AS revenue_mom_growth_pct
FROM monthly
ORDER BY order_month;

-- Orders by day of the week
SELECT DAYNAME(order_datetime) AS day_of_week,
       COUNT(*) AS orders
FROM orders
GROUP BY day_of_week, DAYOFWEEK(order_datetime)
ORDER BY DAYOFWEEK(order_datetime);

-- Orders by hour of the day
SELECT HOUR(order_datetime) AS order_hour,
       COUNT(*) AS orders
FROM orders
GROUP BY order_hour
ORDER BY order_hour;


-- ---------- STEP 4: Key business numbers (KPIs) ----------

-- Main KPIs in one query
SELECT
    COUNT(*)                                            AS total_orders,
    SUM(order_status = 'Completed')                     AS completed_orders,
    ROUND(100 * AVG(order_status = 'Cancelled'), 1)     AS cancellation_rate_pct,
    COUNT(DISTINCT customer_id)                         AS active_customers,
    ROUND(SUM(CASE WHEN order_status = 'Completed' THEN basket_value_aud END), 0) AS total_revenue,
    ROUND(AVG(CASE WHEN order_status = 'Completed' THEN basket_value_aud END), 2) AS avg_basket_value,
    ROUND(SUM(delivery_fee_aud), 0)                     AS delivery_fee_revenue
FROM orders;

-- Average number of products per order
SELECT ROUND(COUNT(*) / COUNT(DISTINCT order_id), 1) AS avg_lines_per_order
FROM order_items;

-- Average rating and total refunds
SELECT ROUND(AVG(rating), 2) AS avg_rating,
       ROUND(SUM(refund_aud), 0) AS total_refunds_aud,
       SUM(refund_aud > 0)       AS orders_refunded
FROM customer_feedback;


-- ---------- STEP 5: Comparing groups ----------
-- I total each customer first, then compare the groups,
-- so customers who order a lot don't skew the averages.

-- Everyday Rewards members vs non-members
WITH customer_totals AS (
    SELECT c.customer_id,
           c.everyday_rewards_member,
           COUNT(o.order_id)       AS orders,
           SUM(o.basket_value_aud) AS revenue
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id, c.everyday_rewards_member
)
SELECT everyday_rewards_member,
       COUNT(*)                             AS customers,
       ROUND(AVG(orders), 1)                AS avg_orders_per_customer,
       ROUND(SUM(revenue) / SUM(orders), 2) AS avg_basket_value,
       ROUND(AVG(revenue), 0)               AS avg_revenue_per_customer
FROM customer_totals
GROUP BY everyday_rewards_member;

-- Delivery Unlimited subscribers vs non-subscribers
WITH customer_totals AS (
    SELECT c.customer_id,
           c.delivery_unlimited_member,
           COUNT(o.order_id)       AS orders,
           SUM(o.basket_value_aud) AS revenue
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id, c.delivery_unlimited_member
)
SELECT delivery_unlimited_member,
       COUNT(*)                             AS customers,
       ROUND(AVG(orders), 1)                AS avg_orders_per_customer,
       ROUND(SUM(revenue) / SUM(orders), 2) AS avg_basket_value,
       ROUND(AVG(revenue), 0)               AS avg_revenue_per_customer
FROM customer_totals
GROUP BY delivery_unlimited_member;

-- Revenue by region
SELECT c.region,
       COUNT(*)                          AS orders,
       ROUND(SUM(o.basket_value_aud), 0) AS revenue,
       ROUND(AVG(o.basket_value_aud), 2) AS avg_basket
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.region
ORDER BY revenue DESC;

-- Home Delivery vs Pick up vs Direct to Boot
SELECT fulfilment_type,
       COUNT(*)                        AS orders,
       ROUND(AVG(basket_value_aud), 2) AS avg_basket,
       ROUND(AVG(delivery_fee_aud), 2) AS avg_fee
FROM orders
WHERE order_status = 'Completed'
GROUP BY fulfilment_type;


-- ---------- STEP 6: Ranking ----------
-- Line revenue = quantity x price minus discount (unavailable items not counted)

-- Ranking departments by revenue
SELECT p.department,
       ROUND(SUM(i.quantity * i.unit_price_aud - i.discount_aud), 0) AS revenue,
       RANK() OVER (ORDER BY SUM(i.quantity * i.unit_price_aud - i.discount_aud) DESC) AS revenue_rank
FROM order_items i
JOIN products p ON p.product_id = i.product_id
JOIN orders   o ON o.order_id   = i.order_id
WHERE i.pick_status <> 'Unavailable'
  AND o.order_status = 'Completed'
GROUP BY p.department;

-- Top 10 products by revenue
SELECT p.product_name, p.department,
       ROUND(SUM(i.quantity * i.unit_price_aud - i.discount_aud), 0) AS revenue
FROM order_items i
JOIN products p ON p.product_id = i.product_id
JOIN orders   o ON o.order_id   = i.order_id
WHERE i.pick_status <> 'Unavailable'
  AND o.order_status = 'Completed'
GROUP BY p.product_id, p.product_name, p.department
ORDER BY revenue DESC
LIMIT 10;

-- Ranking stores by revenue
SELECT s.store_name, s.region,
       COUNT(*)                          AS orders,
       ROUND(SUM(o.basket_value_aud), 0) AS revenue,
       DENSE_RANK() OVER (ORDER BY SUM(o.basket_value_aud) DESC) AS store_rank
FROM orders o
JOIN stores s ON s.store_id = o.store_id
WHERE o.order_status = 'Completed'
GROUP BY s.store_id, s.store_name, s.region;

-- Top 3 customers in each region
-- (PARTITION BY restarts the ranking for each region)
WITH customer_revenue AS (
    SELECT c.customer_id, c.region,
           ROUND(SUM(o.basket_value_aud), 0) AS revenue,
           ROW_NUMBER() OVER (PARTITION BY c.region
                              ORDER BY SUM(o.basket_value_aud) DESC) AS rank_in_region
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id, c.region
)
SELECT * FROM customer_revenue
WHERE rank_in_region <= 3
ORDER BY region, rank_in_region;


-- ---------- STEP 7: Share of total and changes over time ----------

-- Each department's share of total revenue
-- (SUM() OVER () gives me the grand total on every row)
WITH dept AS (
    SELECT p.department,
           SUM(i.quantity * i.unit_price_aud - i.discount_aud) AS revenue
    FROM order_items i
    JOIN products p ON p.product_id = i.product_id
    WHERE i.pick_status <> 'Unavailable'
    GROUP BY p.department
)
SELECT department,
       ROUND(revenue, 0) AS revenue,
       ROUND(100 * revenue / SUM(revenue) OVER (), 1) AS pct_of_total
FROM dept
ORDER BY revenue DESC;

-- Fulfilment type share in each quarter (is Direct to Boot growing?)
WITH q AS (
    SELECT CONCAT(YEAR(order_datetime), '-Q', QUARTER(order_datetime)) AS yr_quarter,
           fulfilment_type,
           COUNT(*) AS orders
    FROM orders
    GROUP BY yr_quarter, fulfilment_type
)
SELECT yr_quarter, fulfilment_type, orders,
       ROUND(100 * orders / SUM(orders) OVER (PARTITION BY yr_quarter), 1) AS pct_of_quarter
FROM q
ORDER BY yr_quarter, fulfilment_type;

-- Own-brand share of units each quarter (are shoppers switching to cheaper brands?)
-- I leave out Fruit & Veg because it has no own-brand products
SELECT CONCAT(YEAR(o.order_datetime), '-Q', QUARTER(o.order_datetime)) AS yr_quarter,
       ROUND(100 * SUM(CASE WHEN p.brand_type = 'Woolworths Own Brand' THEN i.quantity END)
                 / SUM(i.quantity), 1) AS own_brand_unit_share_pct
FROM order_items i
JOIN products p ON p.product_id = i.product_id
JOIN orders   o ON o.order_id   = i.order_id
WHERE p.department <> 'Fruit & Veg'
GROUP BY yr_quarter
ORDER BY yr_quarter;


-- ---------- STEP 8: Operations, customer retention and segments ----------

-- 8a. Substitution and out-of-stock rate by department
SELECT p.department,
       COUNT(*) AS order_lines,
       ROUND(100 * AVG(i.pick_status = 'Substituted'), 1) AS substitution_rate_pct,
       ROUND(100 * AVG(i.pick_status = 'Unavailable'), 1) AS unavailable_rate_pct
FROM order_items i
JOIN products p ON p.product_id = i.product_id
GROUP BY p.department
ORDER BY substitution_rate_pct DESC;

-- 8b. Late delivery rate by region
SELECT c.region,
       COUNT(*) AS home_deliveries,
       ROUND(100 * AVG(d.delivery_status = 'Late'), 1) AS late_rate_pct,
       ROUND(AVG(CASE WHEN d.delivery_status = 'Late' THEN d.minutes_late END), 0) AS avg_minutes_late
FROM deliveries d
JOIN orders    o ON o.order_id    = d.order_id
JOIN customers c ON c.customer_id = o.customer_id
WHERE d.delivery_status <> 'Cancelled'
GROUP BY c.region
ORDER BY late_rate_pct DESC;

-- Late delivery rate by day and time (checking if Sunday evening is worse)
SELECT DAYNAME(o.order_datetime) AS order_day,
       CASE WHEN HOUR(o.order_datetime) >= 16 THEN 'After 4pm' ELSE 'Before 4pm' END AS time_of_day,
       COUNT(*) AS deliveries,
       ROUND(100 * AVG(d.delivery_status = 'Late'), 1) AS late_rate_pct
FROM deliveries d
JOIN orders o ON o.order_id = d.order_id
WHERE d.delivery_status <> 'Cancelled'
GROUP BY order_day, DAYOFWEEK(o.order_datetime), time_of_day
ORDER BY DAYOFWEEK(o.order_datetime), time_of_day;

-- 8c. Ratings and refunds for each complaint type
SELECT COALESCE(complaint_reason, 'No complaint') AS complaint_reason,
       COUNT(*)                  AS feedback_count,
       ROUND(AVG(rating), 2)     AS avg_rating,
       ROUND(SUM(refund_aud), 0) AS refunds_aud
FROM customer_feedback
GROUP BY complaint_reason
ORDER BY feedback_count DESC;

-- 8d. Do customers come back after a bad experience?
-- LEAD finds each customer's next order date.
-- I count it as a reorder if they ordered again within 60 days.
-- I leave out orders after 1 Nov 2025 because they haven't had 60 days yet.
WITH order_sequence AS (
    SELECT o.order_id,
           o.customer_id,
           o.order_datetime,
           LEAD(o.order_datetime) OVER (PARTITION BY o.customer_id
                                        ORDER BY o.order_datetime) AS next_order_datetime
    FROM orders o
),
experience AS (
    SELECT s.order_id,
           s.order_datetime,
           s.next_order_datetime,
           CASE
               WHEN f.complaint_reason = 'Poor substitution' THEN 'Poor substitution'
               WHEN f.complaint_reason = 'Late delivery'     THEN 'Late delivery'
               WHEN f.complaint_reason = 'Missing item'      THEN 'Missing item'
               WHEN f.complaint_reason IS NOT NULL           THEN 'Other complaint'
               ELSE 'No complaint'
           END AS experience_type
    FROM order_sequence s
    JOIN customer_feedback f ON f.order_id = s.order_id
    WHERE s.order_datetime < '2025-11-01'
)
SELECT experience_type,
       COUNT(*) AS orders,
       ROUND(100 * AVG(next_order_datetime IS NOT NULL
                       AND DATEDIFF(next_order_datetime, order_datetime) <= 60), 1) AS reorder_within_60d_pct
FROM experience
GROUP BY experience_type
ORDER BY reorder_within_60d_pct;

-- 8e. Do customers who used a first-order promo come back?
-- ROW_NUMBER = 1 gives me each customer's first order
WITH first_orders AS (
    SELECT o.customer_id, o.promo_code,
           ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.order_datetime) AS order_number
    FROM orders o
),
order_counts AS (
    SELECT customer_id, COUNT(*) AS total_orders
    FROM orders
    GROUP BY customer_id
)
SELECT CASE WHEN f.promo_code = 'FIRSTORDER' THEN 'Used first-order promo'
            ELSE 'No promo' END AS acquisition_type,
       COUNT(*) AS customers,
       ROUND(100 * AVG(oc.total_orders > 1), 1) AS made_second_order_pct,
       ROUND(AVG(oc.total_orders), 1)          AS avg_lifetime_orders
FROM first_orders f
JOIN order_counts oc ON oc.customer_id = f.customer_id
WHERE f.order_number = 1
GROUP BY acquisition_type;

-- 8f. RFM customer segments
-- R = how recently they ordered, F = how often, M = how much they spent
-- NTILE(5) splits customers into 5 equal groups, 5 being the best
-- I use 31 Dec 2025 (end of the data) as the analysis date
WITH rfm_base AS (
    SELECT customer_id,
           DATEDIFF('2025-12-31', MAX(order_datetime)) AS recency_days,
           COUNT(*)                                    AS frequency,
           SUM(basket_value_aud)                       AS monetary
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(5) OVER (ORDER BY frequency)         AS f_score,
           NTILE(5) OVER (ORDER BY monetary)          AS m_score
    FROM rfm_base
),
segments AS (
    SELECT *,
           CASE
               WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
               WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
               WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
               WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
               WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
               ELSE 'Needs Attention'
           END AS segment
    FROM rfm_scores
)
SELECT segment,
       COUNT(*)                       AS customers,
       ROUND(AVG(recency_days), 0)    AS avg_days_since_last_order,
       ROUND(AVG(frequency), 1)       AS avg_orders,
       ROUND(AVG(monetary), 0)        AS avg_spend,
       ROUND(100 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_of_revenue
FROM segments
GROUP BY segment
ORDER BY avg_spend DESC;


/* =====================================================================
   PART 4: VIEWS FOR POWER BI
   A view is a saved query that works like a table.
   I connect Power BI to these so my dashboard uses the cleaned data.
   ===================================================================== */

-- One row per order, with customer, store, delivery and feedback details
-- (LEFT JOIN because not every order is a delivery or has feedback)
CREATE OR REPLACE VIEW vw_orders AS
SELECT o.order_id,
       o.customer_id,
       DATE(o.order_datetime)        AS order_date,
       HOUR(o.order_datetime)        AS order_hour,
       DAYNAME(o.order_datetime)     AS order_day,
       o.fulfilment_type,
       o.order_status,
       o.basket_value_aud,
       o.delivery_fee_aud,
       o.promo_code,
       c.region,
       c.suburb,
       c.age_band,
       c.everyday_rewards_member,
       c.delivery_unlimited_member,
       s.store_name,
       d.delivery_status,
       d.minutes_late,
       f.rating,
       f.complaint_reason,
       f.refund_aud
FROM orders o
JOIN customers c              ON c.customer_id = o.customer_id
JOIN stores s                 ON s.store_id    = o.store_id
LEFT JOIN deliveries d        ON d.order_id    = o.order_id
LEFT JOIN customer_feedback f ON f.order_id    = o.order_id;

-- One row per product in each order, with product details and line revenue
CREATE OR REPLACE VIEW vw_order_lines AS
SELECT i.order_id,
       DATE(o.order_datetime) AS order_date,
       p.product_name,
       p.department,
       p.brand_type,
       i.quantity,
       i.unit_price_aud,
       i.discount_aud,
       CASE WHEN i.pick_status = 'Unavailable' THEN 0
            ELSE i.quantity * i.unit_price_aud - i.discount_aud END AS line_revenue,
       i.pick_status
FROM order_items i
JOIN products p ON p.product_id = i.product_id
JOIN orders   o ON o.order_id   = i.order_id;

-- One row per customer, with their RFM scores and segment
CREATE OR REPLACE VIEW vw_customer_segments AS
WITH rfm_base AS (
    SELECT customer_id,
           DATEDIFF('2025-12-31', MAX(order_datetime)) AS recency_days,
           COUNT(*)              AS frequency,
           SUM(basket_value_aud) AS monetary
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(5) OVER (ORDER BY frequency)         AS f_score,
           NTILE(5) OVER (ORDER BY monetary)          AS m_score
    FROM rfm_base
)
SELECT r.*,
       c.region,
       c.everyday_rewards_member,
       c.delivery_unlimited_member,
       CASE
           WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
           WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
           WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
           WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
           WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
           ELSE 'Needs Attention'
       END AS segment
FROM rfm_scores r
JOIN customers c ON c.customer_id = r.customer_id;

-- Quick check that the views work
SELECT * FROM vw_orders LIMIT 10;
SELECT * FROM vw_order_lines LIMIT 10;
SELECT segment, COUNT(*) FROM vw_customer_segments GROUP BY segment;

-- Turning safe update mode back on
SET SQL_SAFE_UPDATES = 1;