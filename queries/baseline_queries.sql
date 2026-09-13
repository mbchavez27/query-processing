-- ============================================================================
-- STADVDB HO 01: BASELINE ANALYTICAL QUERIES & EXPLAIN SUITE
-- Database: PostgreSQL 15 (Sakila Dataset with 100,000 Rentals & Payments)
-- Task 1: SQL Queries + Baseline EXPLAIN Diagnostics
-- ============================================================================


-- ----------------------------------------------------------------------------
-- QUERY 1: Genre Leaderboard — Revenue & Return Speed
-- (Formal: Film Category Commercial Performance & Velocity)
-- ----------------------------------------------------------------------------
-- The Business Question:
--   Which movie genres bring in the most money, and how fast do customers 
--   bring those DVDs back?
--
-- Significance:
--   Helps store managers restock popular, fast-moving genres (like Action)
--   and phase out low-earning, slow-moving genres.
--
-- Tables Joined (6 Tables in a Chain):
--   category -> film_category -> film -> inventory -> rental -> payment
--
-- EXPLAIN (Baseline Bottleneck) Insights:
--   Slow sequential scans (Seq Scan) across 100,000 rentals and payments 
--   because there are no secondary indexes on the foreign keys.
--
-- Supporting Course References:
--   • HO 01 Spec: Section A.3.B & B.2 (6-table join; exceeds >= 3 tables requirement)
--   • Slides 02b: Slides 8–12 (Creating Secondary Indexes on Foreign Key Joins)
--   • Ex 03: Criterion A-3 (Automatic vs. Custom Secondary Indexes)
-- ----------------------------------------------------------------------------

-- [1A. Run Query (Raw Results)]
SELECT c.name AS category_name,
       COUNT(r.rental_id) AS total_rentals,
       SUM(p.amount) AS total_revenue,
       ROUND(AVG(EXTRACT(EPOCH FROM (r.return_date - r.rental_date))/86400)::numeric, 2) AS avg_rental_days
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN film f ON fc.film_id = f.film_id
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY c.category_id, c.name
ORDER BY total_revenue DESC;

-- [1B. Inspect Execution Plan (EXPLAIN)]
EXPLAIN (ANALYZE, BUFFERS, COSTS, TIMING)
SELECT c.name AS category_name,
       COUNT(r.rental_id) AS total_rentals,
       SUM(p.amount) AS total_revenue,
       ROUND(AVG(EXTRACT(EPOCH FROM (r.return_date - r.rental_date))/86400)::numeric, 2) AS avg_rental_days
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN film f ON fc.film_id = f.film_id
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY c.category_id, c.name
ORDER BY total_revenue DESC;


-- ----------------------------------------------------------------------------
-- QUERY 2: Top 50 VIP Spenders by City
-- (Formal: Customer Lifetime Value & Geographic Cohorts)
-- ----------------------------------------------------------------------------
-- The Business Question:
--   Who are our top 50 biggest-spending customers, how many times have they 
--   rented, and which cities do they live in?
--
-- Significance:
--   Allows marketing to reward high-value VIP customers with loyalty perks 
--   and target cities with the highest concentration of big spenders.
--
-- Tables Joined (4 Tables in a Fork):
--   customer -> address -> city (Geography)
--   customer -> payment         (100,000 Transaction records)
--
-- EXPLAIN (Baseline Bottleneck) Insights:
--   The database must scan all 100,000 payments, calculate lifetime totals 
--   for all 1,000 customers, and sort the entire list just to keep the top 50.
--
-- Supporting Course References:
--   • HO 01 Spec: Section A.3.D (Customer behavior & payment pattern analysis)
--   • Slides 02: Slide 28 (Linear Scan Cost: b_r blocks) & Slide 32 (Cost of Sorting)
--   • Ex 03: Criterion A-5 (Optimizing GROUP BY and ORDER BY to avoid filesort)
-- ----------------------------------------------------------------------------

-- [2A. Run Query (Raw Results)]
SELECT cu.customer_id,
       cu.first_name || ' ' || cu.last_name AS customer_name,
       ci.city,
       COUNT(p.payment_id) AS transaction_count,
       SUM(p.amount) AS total_spend,
       ROUND(AVG(p.amount)::numeric, 2) AS avg_ticket_size
FROM customer cu
JOIN address a ON cu.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
JOIN payment p ON cu.customer_id = p.customer_id
GROUP BY cu.customer_id, customer_name, ci.city
ORDER BY total_spend DESC
LIMIT 50;

-- [2B. Inspect Execution Plan (EXPLAIN)]
EXPLAIN (ANALYZE, BUFFERS, COSTS, TIMING)
SELECT cu.customer_id,
       cu.first_name || ' ' || cu.last_name AS customer_name,
       ci.city,
       COUNT(p.payment_id) AS transaction_count,
       SUM(p.amount) AS total_spend,
       ROUND(AVG(p.amount)::numeric, 2) AS avg_ticket_size
FROM customer cu
JOIN address a ON cu.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
JOIN payment p ON cu.customer_id = p.customer_id
GROUP BY cu.customer_id, customer_name, ci.city
ORDER BY total_spend DESC
LIMIT 50;


-- ----------------------------------------------------------------------------
-- QUERY 3: Genre Blockbusters — Movies Beating the Category Average
-- (Formal: Mandatory Correlated Subquery Benchmark Analysis)
-- ----------------------------------------------------------------------------
-- The Business Question:
--   Which individual movies generated more revenue than the benchmark average 
--   of all films within their EXACT same genre?
--
-- Significance:
--   Provides a fair comparison (comparing Action films against Action films, 
--   not against Documentaries) to decide which film licenses to renew.
--
-- Tables Joined (6 Tables + Dependent Subquery):
--   film -> film_category -> category -> inventory -> rental -> payment
--
-- EXPLAIN (Baseline Bottleneck) Insights:
--   Correlated Subquery: The subquery re-calculates the genre average over 
--   and over for every single candidate film in an O(N^2) loop, causing 
--   a massive execution delay (SubPlan with high loop counts).
--
-- Supporting Course References:
--   • HO 01 Spec: Section A.3.C (Mandatory Correlated Subquery requirement)
--   • Slides 02b: Slide 26 (Reformulating Subqueries: Department/Salary Benchmark pattern)
--   • Ex 03: Part B, Q1 (Nested Loop Join & Subquery evaluation complexity)
-- ----------------------------------------------------------------------------

-- [3A. Run Query (Raw Results)]
SELECT f.film_id, 
       f.title, 
       c.name AS category_name, 
       SUM(p.amount) AS film_revenue
FROM film f
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY f.film_id, f.title, c.name, fc.category_id
HAVING SUM(p.amount) > (
    -- Correlated Subquery: re-runs for every film in the outer query!
    SELECT AVG(cat_totals.rev)
    FROM (
        SELECT f2.film_id, SUM(p2.amount) AS rev
        FROM film f2
        JOIN film_category fc2 ON f2.film_id = fc2.film_id
        JOIN inventory i2 ON f2.film_id = i2.film_id
        JOIN rental r2 ON i2.inventory_id = r2.inventory_id
        JOIN payment p2 ON r2.rental_id = p2.rental_id
        WHERE fc2.category_id = fc.category_id -- Outer link!
        GROUP BY f2.film_id
    ) cat_totals
)
ORDER BY film_revenue DESC;

-- [3B. Inspect Execution Plan (EXPLAIN)]
EXPLAIN (ANALYZE, BUFFERS, COSTS, TIMING)
SELECT f.film_id, 
       f.title, 
       c.name AS category_name, 
       SUM(p.amount) AS film_revenue
FROM film f
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY f.film_id, f.title, c.name, fc.category_id
HAVING SUM(p.amount) > (
    SELECT AVG(cat_totals.rev)
    FROM (
        SELECT f2.film_id, SUM(p2.amount) AS rev
        FROM film f2
        JOIN film_category fc2 ON f2.film_id = fc2.film_id
        JOIN inventory i2 ON f2.film_id = i2.film_id
        JOIN rental r2 ON i2.inventory_id = r2.inventory_id
        JOIN payment p2 ON r2.rental_id = p2.rental_id
        WHERE fc2.category_id = fc.category_id
        GROUP BY f2.film_id
    ) cat_totals
)
ORDER BY film_revenue DESC;


-- ----------------------------------------------------------------------------
-- QUERY 4: Store Staff Quarterly Sales & Workload
-- (Formal: Staff Seasonal Throughput & Collection Performance)
-- ----------------------------------------------------------------------------
-- The Business Question:
--   How many rentals did each store clerk process and how much money did 
--   they collect in each calendar quarter (every 3 months)?
--
-- Significance:
--   Helps managers award quarterly staff bonuses, spot cashier errors, 
--   and see if stores need more staff during busy holiday quarters.
--
-- Tables Joined (3 Tables):
--   staff -> rental -> payment (Joins across 100,000 transaction rows)
--
-- EXPLAIN (Baseline Bottleneck) Insights:
--   Joining two 100,000-row tables plus using date math (EXTRACT YEAR / QUARTER) 
--   which prevents standard B+ tree index lookups (non-sargable functions).
--
-- Supporting Course References:
--   • HO 01 Spec: Section A.3.D (Staff store productivity & throughput analysis)
--   • Slides 02b: Slide 15 (When Indexes Fail / Non-sargable expressions)
--   • Ex 03: Criterion A-4 (Why indexes fail to improve speed on function calls)
-- ----------------------------------------------------------------------------

-- [4A. Run Query (Raw Results)]
SELECT s.staff_id,
       s.first_name || ' ' || s.last_name AS staff_name,
       EXTRACT(YEAR FROM r.rental_date)::int AS rental_year,
       EXTRACT(QUARTER FROM r.rental_date)::int AS rental_quarter,
       COUNT(r.rental_id) AS total_rentals_processed,
       SUM(p.amount) AS total_payments_collected
FROM staff s
JOIN rental r ON s.staff_id = r.staff_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY s.staff_id, staff_name, rental_year, rental_quarter
ORDER BY rental_year DESC, rental_quarter DESC, total_payments_collected DESC;

-- [4B. Inspect Execution Plan (EXPLAIN)]
EXPLAIN (ANALYZE, BUFFERS, COSTS, TIMING)
SELECT s.staff_id,
       s.first_name || ' ' || s.last_name AS staff_name,
       EXTRACT(YEAR FROM r.rental_date)::int AS rental_year,
       EXTRACT(QUARTER FROM r.rental_date)::int AS rental_quarter,
       COUNT(r.rental_id) AS total_rentals_processed,
       SUM(p.amount) AS total_payments_collected
FROM staff s
JOIN rental r ON s.staff_id = r.staff_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY s.staff_id, staff_name, rental_year, rental_quarter
ORDER BY rental_year DESC, rental_quarter DESC, total_payments_collected DESC;
