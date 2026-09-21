-- ============================================================================
-- STADVDB HO 01: DATABASE POST-LOAD INTEGRITY & SCALE VALIDATION SUITE
-- Database: PostgreSQL 15 (Sakila Dataset with 100k Synthetic Scaling Data)
-- Reference: Report Section 1 — Database Post-Load Integrity & Scale Verification
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Table Volume Verification
-- Target Criteria:
--   - Reference table 'customer' >= 1,000 descriptive rows (Target: 1,599)
--   - Event table 'rental' >= 100,000 event rows (Target: 116,044)
--   - Event table 'payment' >= 100,000 event rows (Target: 116,049)
--   - Base catalog tables remain intact: 'film' = 1,000, 'inventory' = 4,581
-- ----------------------------------------------------------------------------
SELECT 'customer' AS table_name, COUNT(*) AS row_count, 1599 AS expected_count, 
       CASE WHEN COUNT(*) = 1599 THEN 'PASS' ELSE 'FAIL' END AS status 
FROM customer
UNION ALL
SELECT 'rental', COUNT(*), 116044, 
       CASE WHEN COUNT(*) = 116044 THEN 'PASS' ELSE 'FAIL' END 
FROM rental
UNION ALL
SELECT 'payment', COUNT(*), 116049, 
       CASE WHEN COUNT(*) = 116049 THEN 'PASS' ELSE 'FAIL' END 
FROM payment
UNION ALL
SELECT 'film', COUNT(*), 1000, 
       CASE WHEN COUNT(*) = 1000 THEN 'PASS' ELSE 'FAIL' END 
FROM film
UNION ALL
SELECT 'inventory', COUNT(*), 4581, 
       CASE WHEN COUNT(*) = 4581 THEN 'PASS' ELSE 'FAIL' END 
FROM inventory;


-- ----------------------------------------------------------------------------
-- 2. Foreign Key Referential Integrity & Zero-Orphan Validation
-- Ensures all synthetic foreign key pointers resolve cleanly to valid parent rows.
-- Target: 0 orphaned rows across all relationships.
-- ----------------------------------------------------------------------------
SELECT 'Orphaned Rentals (Invalid Customer)' AS integrity_check, COUNT(*) AS orphan_count,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM rental r
LEFT JOIN customer c ON r.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'Orphaned Rentals (Invalid Inventory)', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM rental r
LEFT JOIN inventory i ON r.inventory_id = i.inventory_id
WHERE i.inventory_id IS NULL
UNION ALL
SELECT 'Orphaned Payments (Invalid Rental)', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM payment p
LEFT JOIN rental r ON p.rental_id = r.rental_id
WHERE r.rental_id IS NULL
UNION ALL
SELECT 'Orphaned Payments (Invalid Customer)', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM payment p
LEFT JOIN customer c ON p.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- ----------------------------------------------------------------------------
-- 3. Sakila Address Table Gap Validation
-- Sakila contains known primary key address gaps at ID 257 and 518.
-- Validates that synthetic customer generator did not violate these gaps.
-- Target: 0 records.
-- ----------------------------------------------------------------------------
SELECT 'Customer Address Gap Check (IDs 257, 518)' AS gap_check,
       COUNT(*) AS violation_count,
       CASE WHEN COUNT(*) = 0 THEN 'PASS (No gap violations)' ELSE 'FAIL' END AS status
FROM customer
WHERE address_id IN (257, 518);


-- ----------------------------------------------------------------------------
-- 4. Customer Pareto Skew Empirical Verification
-- Report §1.3 specifies pow(rng.random(), 2.5) Pareto skew.
-- This query computes the concentration of rentals among the top frequent customers.
-- ----------------------------------------------------------------------------
WITH customer_rental_counts AS (
    SELECT customer_id, COUNT(*) AS rental_count,
           NTILE(10) OVER (ORDER BY COUNT(*) DESC) AS decile
    FROM rental
    GROUP BY customer_id
)
SELECT decile AS customer_decile,
       COUNT(customer_id) AS customer_count,
       SUM(rental_count) AS total_rentals,
       ROUND(SUM(rental_count) * 100.0 / (SELECT COUNT(*) FROM rental), 2) AS pct_share_of_rentals
FROM customer_rental_counts
GROUP BY decile
ORDER BY decile;


-- ----------------------------------------------------------------------------
-- 5. Auto-Increment Sequence Synchronization
-- Validates that sequences were properly set to max values, preventing PK collision.
-- ----------------------------------------------------------------------------
SELECT 'customer_customer_id_seq' AS sequence_name,
       last_value,
       (SELECT MAX(customer_id) FROM customer) AS max_id,
       CASE WHEN last_value >= (SELECT MAX(customer_id) FROM customer) THEN 'SYNCHRONIZED' ELSE 'DESYNCHRONIZED' END AS status
FROM customer_customer_id_seq
UNION ALL
SELECT 'rental_rental_id_seq',
       last_value,
       (SELECT MAX(rental_id) FROM rental),
       CASE WHEN last_value >= (SELECT MAX(rental_id) FROM rental) THEN 'SYNCHRONIZED' ELSE 'DESYNCHRONIZED' END
FROM rental_rental_id_seq
UNION ALL
SELECT 'payment_payment_id_seq',
       last_value,
       (SELECT MAX(payment_id) FROM payment),
       CASE WHEN last_value >= (SELECT MAX(payment_id) FROM payment) THEN 'SYNCHRONIZED' ELSE 'DESYNCHRONIZED' END
FROM payment_payment_id_seq;
