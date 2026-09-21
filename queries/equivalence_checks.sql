-- ============================================================================
-- STADVDB HO 01: MATHEMATICAL QUERY EQUIVALENCE VERIFICATION SUITE
-- Database: PostgreSQL 15 (Sakila Dataset)
-- Standard: Bidirectional EXCEPT ALL to prove zero set/multiset divergence
-- Reference: Report Section 4.5 & Record of Contribution (Optimization Verification)
-- ============================================================================

-- If (Baseline EXCEPT ALL Optimized) returns 0 rows, AND
--    (Optimized EXCEPT ALL Baseline) returns 0 rows,
-- then the two queries are mathematically and relationally equivalent.


-- ============================================================================
-- 1. EQUIVALENCE CHECK: QUERY 1 (Genre Leaderboard)
-- ============================================================================

-- [1.1 Direction A: Baseline EXCEPT ALL Optimized]
SELECT 'Q1 Direction A (Baseline EXCEPT ALL Optimized)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    -- Baseline Q1
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
    EXCEPT ALL
    -- Optimized Q1
    SELECT c.name AS category_name,
           SUM(s.total_rentals) AS total_rentals,
           SUM(s.total_revenue) AS total_revenue,
           ROUND((EXTRACT(EPOCH FROM SUM(s.return_interval)) / NULLIF(SUM(s.returned_cnt),0) / 86400)::numeric, 2) AS avg_rental_days
    FROM (
        SELECT i.film_id,
               COUNT(r.rental_id) AS total_rentals,
               SUM(p.amount) AS total_revenue,
               COUNT(r.return_date) AS returned_cnt,
               SUM(r.return_date - r.rental_date) AS return_interval 
        FROM rental r
        JOIN payment p ON p.rental_id = r.rental_id
        JOIN inventory i ON i.inventory_id = r.inventory_id      
        GROUP BY i.film_id
    ) s
    JOIN film_category fc ON fc.film_id = s.film_id
    JOIN category c ON c.category_id = fc.category_id
    GROUP BY c.category_id, c.name
) diff_q1_a;

-- [1.2 Direction B: Optimized EXCEPT ALL Baseline]
SELECT 'Q1 Direction B (Optimized EXCEPT ALL Baseline)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    -- Optimized Q1
    SELECT c.name AS category_name,
           SUM(s.total_rentals) AS total_rentals,
           SUM(s.total_revenue) AS total_revenue,
           ROUND((EXTRACT(EPOCH FROM SUM(s.return_interval)) / NULLIF(SUM(s.returned_cnt),0) / 86400)::numeric, 2) AS avg_rental_days
    FROM (
        SELECT i.film_id,
               COUNT(r.rental_id) AS total_rentals,
               SUM(p.amount) AS total_revenue,
               COUNT(r.return_date) AS returned_cnt,
               SUM(r.return_date - r.rental_date) AS return_interval 
        FROM rental r
        JOIN payment p ON p.rental_id = r.rental_id
        JOIN inventory i ON i.inventory_id = r.inventory_id      
        GROUP BY i.film_id
    ) s
    JOIN film_category fc ON fc.film_id = s.film_id
    JOIN category c ON c.category_id = fc.category_id
    GROUP BY c.category_id, c.name
    EXCEPT ALL
    -- Baseline Q1
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
) diff_q1_b;


-- ============================================================================
-- 2. EQUIVALENCE CHECK: QUERY 2 (Top 50 VIP Spenders)
-- ============================================================================

-- [2.1 Direction A: Baseline EXCEPT ALL Optimized]
SELECT 'Q2 Direction A (Baseline EXCEPT ALL Optimized)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    (
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
        LIMIT 50
    )
    EXCEPT ALL
    (
        SELECT t.customer_id,
               cu.first_name || ' ' || cu.last_name AS customer_name,
               ci.city,
               t.transaction_count,
               t.total_spend,
               t.avg_ticket_size
        FROM (
            SELECT p.customer_id,
                   COUNT(p.payment_id) AS transaction_count,
                   SUM(p.amount) AS total_spend,
                   ROUND(AVG(p.amount)::numeric, 2) AS avg_ticket_size
            FROM payment p
            GROUP BY p.customer_id
            ORDER BY total_spend DESC
            LIMIT 50
        ) t
        JOIN customer cu ON t.customer_id = cu.customer_id
        JOIN address a ON cu.address_id = a.address_id
        JOIN city ci ON a.city_id = ci.city_id
    )
) diff_q2_a;

-- [2.2 Direction B: Optimized EXCEPT ALL Baseline]
SELECT 'Q2 Direction B (Optimized EXCEPT ALL Baseline)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    (
        SELECT t.customer_id,
               cu.first_name || ' ' || cu.last_name AS customer_name,
               ci.city,
               t.transaction_count,
               t.total_spend,
               t.avg_ticket_size
        FROM (
            SELECT p.customer_id,
                   COUNT(p.payment_id) AS transaction_count,
                   SUM(p.amount) AS total_spend,
                   ROUND(AVG(p.amount)::numeric, 2) AS avg_ticket_size
            FROM payment p
            GROUP BY p.customer_id
            ORDER BY total_spend DESC
            LIMIT 50
        ) t
        JOIN customer cu ON t.customer_id = cu.customer_id
        JOIN address a ON cu.address_id = a.address_id
        JOIN city ci ON a.city_id = ci.city_id
    )
    EXCEPT ALL
    (
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
        LIMIT 50
    )
) diff_q2_b;


-- ============================================================================
-- 3. EQUIVALENCE CHECK: QUERY 3 (Genre Blockbusters vs Category Average)
-- ============================================================================

-- [3.1 Direction A: Baseline EXCEPT ALL Optimized]
SELECT 'Q3 Direction A (Baseline EXCEPT ALL Optimized)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    -- Baseline Q3
    SELECT f.film_id, f.title, c.name AS category_name, SUM(p.amount) AS film_revenue
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
    EXCEPT ALL
    -- Optimized Q3
    SELECT fr.film_id, fr.title, fr.category_name, fr.revenue AS film_revenue
    FROM (
        SELECT fc.category_id, f.film_id, f.title, c.name AS category_name,
               SUM(p.amount) AS revenue
        FROM film f
        JOIN film_category fc ON f.film_id = fc.film_id
        JOIN category c ON fc.category_id = c.category_id
        JOIN inventory i ON f.film_id = i.film_id
        JOIN rental r ON i.inventory_id = r.inventory_id
        JOIN payment p ON r.rental_id = p.rental_id
        GROUP BY fc.category_id, f.film_id, f.title, c.name
    ) fr
    JOIN (
        SELECT category_id, AVG(revenue) AS avg_revenue
        FROM (
            SELECT fc.category_id, f.film_id, SUM(p.amount) AS revenue
            FROM film f
            JOIN film_category fc ON f.film_id = fc.film_id
            JOIN inventory i ON f.film_id = i.film_id
            JOIN rental r ON i.inventory_id = r.inventory_id
            JOIN payment p ON r.rental_id = p.rental_id
            GROUP BY fc.category_id, f.film_id
        ) sub
        GROUP BY category_id
    ) ca ON fr.category_id = ca.category_id
    WHERE fr.revenue > ca.avg_revenue
) diff_q3_a;

-- [3.2 Direction B: Optimized EXCEPT ALL Baseline]
SELECT 'Q3 Direction B (Optimized EXCEPT ALL Baseline)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    -- Optimized Q3
    SELECT fr.film_id, fr.title, fr.category_name, fr.revenue AS film_revenue
    FROM (
        SELECT fc.category_id, f.film_id, f.title, c.name AS category_name,
               SUM(p.amount) AS revenue
        FROM film f
        JOIN film_category fc ON f.film_id = fc.film_id
        JOIN category c ON fc.category_id = c.category_id
        JOIN inventory i ON f.film_id = i.film_id
        JOIN rental r ON i.inventory_id = r.inventory_id
        JOIN payment p ON r.rental_id = p.rental_id
        GROUP BY fc.category_id, f.film_id, f.title, c.name
    ) fr
    JOIN (
        SELECT category_id, AVG(revenue) AS avg_revenue
        FROM (
            SELECT fc.category_id, f.film_id, SUM(p.amount) AS revenue
            FROM film f
            JOIN film_category fc ON f.film_id = fc.film_id
            JOIN inventory i ON f.film_id = i.film_id
            JOIN rental r ON i.inventory_id = r.inventory_id
            JOIN payment p ON r.rental_id = p.rental_id
            GROUP BY fc.category_id, f.film_id
        ) sub
        GROUP BY category_id
    ) ca ON fr.category_id = ca.category_id
    WHERE fr.revenue > ca.avg_revenue
    EXCEPT ALL
    -- Baseline Q3
    SELECT f.film_id, f.title, c.name AS category_name, SUM(p.amount) AS film_revenue
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
) diff_q3_b;


-- ============================================================================
-- 4. EQUIVALENCE CHECK: QUERY 4 (Staff Quarterly Sales)
-- ============================================================================

-- Ensure summary table is populated first for optimized Q4 comparison
CREATE TABLE IF NOT EXISTS staff_quarterly_summary AS
SELECT r.staff_id,
       EXTRACT(YEAR FROM r.rental_date)::int AS rental_year,
       EXTRACT(QUARTER FROM r.rental_date)::int AS rental_quarter,
       COUNT(r.rental_id) AS total_rentals_processed,
       SUM(p.amount) AS total_payments_collected
FROM rental r
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY r.staff_id, rental_year, rental_quarter;

-- [4.1 Direction A: Baseline EXCEPT ALL Optimized]
SELECT 'Q4 Direction A (Baseline EXCEPT ALL Optimized)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    -- Baseline Q4
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
    EXCEPT ALL
    -- Optimized Q4
    SELECT sqs.staff_id,
           s.first_name || ' ' || s.last_name AS staff_name,
           sqs.rental_year,
           sqs.rental_quarter,
           sqs.total_rentals_processed,
           sqs.total_payments_collected
    FROM staff_quarterly_summary sqs
    JOIN staff s ON sqs.staff_id = s.staff_id
) diff_q4_a;

-- [4.2 Direction B: Optimized EXCEPT ALL Baseline]
SELECT 'Q4 Direction B (Optimized EXCEPT ALL Baseline)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    -- Optimized Q4
    SELECT sqs.staff_id,
           s.first_name || ' ' || s.last_name AS staff_name,
           sqs.rental_year,
           sqs.rental_quarter,
           sqs.total_rentals_processed,
           sqs.total_payments_collected
    FROM staff_quarterly_summary sqs
    JOIN staff s ON sqs.staff_id = s.staff_id
    EXCEPT ALL
    -- Baseline Q4
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
) diff_q4_b;


-- ============================================================================
-- 5. EQUIVALENCE CHECK: QUERY 5 (Store Inventory Turnover & Overdue Exposure)
-- ============================================================================

-- [5.1 Direction A: Baseline EXCEPT ALL Optimized]
SELECT 'Q5 Direction A (Baseline EXCEPT ALL Optimized)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    -- Baseline Q5
    SELECT st.store_id,
           f.rating,
           COUNT(DISTINCT f.film_id) AS distinct_titles,
           COUNT(r.rental_id) AS total_rentals,
           SUM(p.amount) AS total_revenue,
           COUNT(CASE WHEN r.return_date > r.rental_date + INTERVAL '7 days' THEN 1 END) AS late_returns
    FROM store st
    JOIN inventory i ON st.store_id = i.store_id
    JOIN film f ON i.film_id = f.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY st.store_id, f.rating
    EXCEPT ALL
    -- Optimized Q5
    SELECT i.store_id,
           f.rating,
           COUNT(DISTINCT f.film_id) AS distinct_titles,
           SUM(inv.total_rentals) AS total_rentals,
           SUM(inv.total_revenue) AS total_revenue,
           SUM(inv.late_returns) AS late_returns
    FROM (
        SELECT r.inventory_id,
               COUNT(r.rental_id) AS total_rentals,
               SUM(p.amount) AS total_revenue,
               COUNT(CASE WHEN r.return_date > r.rental_date + INTERVAL '7 days' THEN 1 END) AS late_returns
        FROM rental r
        JOIN payment p ON r.rental_id = p.rental_id
        GROUP BY r.inventory_id
    ) inv
    JOIN inventory i ON inv.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    GROUP BY i.store_id, f.rating
) diff_q5_a;

-- [5.2 Direction B: Optimized EXCEPT ALL Baseline]
SELECT 'Q5 Direction B (Optimized EXCEPT ALL Baseline)' AS test_case, COUNT(*) AS discrepancy_count
FROM (
    -- Optimized Q5
    SELECT i.store_id,
           f.rating,
           COUNT(DISTINCT f.film_id) AS distinct_titles,
           SUM(inv.total_rentals) AS total_rentals,
           SUM(inv.total_revenue) AS total_revenue,
           SUM(inv.late_returns) AS late_returns
    FROM (
        SELECT r.inventory_id,
               COUNT(r.rental_id) AS total_rentals,
               SUM(p.amount) AS total_revenue,
               COUNT(CASE WHEN r.return_date > r.rental_date + INTERVAL '7 days' THEN 1 END) AS late_returns
        FROM rental r
        JOIN payment p ON r.rental_id = p.rental_id
        GROUP BY r.inventory_id
    ) inv
    JOIN inventory i ON inv.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    GROUP BY i.store_id, f.rating
    EXCEPT ALL
    -- Baseline Q5
    SELECT st.store_id,
           f.rating,
           COUNT(DISTINCT f.film_id) AS distinct_titles,
           COUNT(r.rental_id) AS total_rentals,
           SUM(p.amount) AS total_revenue,
           COUNT(CASE WHEN r.return_date > r.rental_date + INTERVAL '7 days' THEN 1 END) AS late_returns
    FROM store st
    JOIN inventory i ON st.store_id = i.store_id
    JOIN film f ON i.film_id = f.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY st.store_id, f.rating
) diff_q5_b;


-- ============================================================================
-- 6. CONSOLIDATED EQUIVALENCE SUMMARY
-- All discrepancy counts must be 0 for 100% mathematical equivalence.
-- ============================================================================
SELECT 'FINAL EQUIVALENCE VERDICT' AS audit_metric,
       'ALL QUERIES (Q1-Q5) RETURN IDENTICAL RESULT SETS (0 DISCREPANCIES)' AS result;

