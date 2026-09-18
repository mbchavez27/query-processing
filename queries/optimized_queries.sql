-- ----------------------------------------------------------------------------
-- QUERY 3: Genre Blockbusters — Movies Beating the Category Average
-- (Formal: Mandatory Correlated Subquery Benchmark Analysis)
-- ----------------------------------------------------------------------------
-- EXPLAIN (Baseline Bottleneck) Insights:
--   SubPlan 1 re-executes once per candidate film (loops=958), and each 
--   execution re-scans all 116,049 payment rows to recompute the same 
--   category average. Estimated cost reaches 466,591,825.99 with 8,405,979 
--   buffer hits and spills to temp files (read=690, written=692), with 
--   execution averaging 11,972.8ms over 5 runs.
--
-- Optimization Techniques:
--   Reformulated the correlated subquery into two uncorrelated derived tables: 
--   film_revenue aggregates the six-table join once to one row per film, and 
--   category_avg derives the genre benchmark from that result, joined back on 
--   category_id instead of re-evaluated per row.
--
-- EXPLAIN (Optimized) Insights:
--   The SubPlan node is eliminated; the CTE executes at loops=1. Payment and 
--   rental are still sequentially scanned, but once each rather than 958 times, 
--   and the benchmark is computed over the 958 aggregated film rows instead of 
--   the full fact tables. Estimated cost drops to 41,793.32 and buffer hits to 
--   2,031, with execution averaging 73.1ms over 5 runs. Note the planner still 
--   misestimates the HashAggregate at 116,055 rows against 958 actual, though 
--   this does not affect plan selection here.
--
--   Timings above are from plain execution with \timing. EXPLAIN ANALYZE reports 
--   ~22.6s for the baseline, roughly double, because per-node instrumentation is 
--   applied to every one of the SubPlan's repeated executions.
--
-- Supporting Course References:
--   • Slides 02b: Slide 26 (Reformulating Subqueries — Department/Salary pattern)
--   • Slides 02b: Slide 17 (Using EXPLAIN to inspect the query plan)
--   • Slides 02b: Slide 30 (Goal of Query Optimization — least-cost RA translation)
-- ----------------------------------------------------------------------------

-- [3A. Optimized Query — Correlated subquery reformulated as derived tables]
WITH film_revenue AS (
    SELECT fc.category_id, f.film_id, f.title, c.name AS category_name,
           SUM(p.amount) AS revenue
    FROM film f
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY fc.category_id, f.film_id, f.title, c.name
),
category_avg AS (
    SELECT category_id, AVG(revenue) AS avg_revenue
    FROM film_revenue
    GROUP BY category_id
)
SELECT fr.film_id, fr.title, fr.category_name, fr.revenue AS film_revenue
FROM film_revenue fr
JOIN category_avg ca ON fr.category_id = ca.category_id
WHERE fr.revenue > ca.avg_revenue
ORDER BY film_revenue DESC;

-- [3B. Inspect Execution Plan (EXPLAIN)]
EXPLAIN (ANALYZE, BUFFERS, COSTS, TIMING)
WITH film_revenue AS (
    SELECT fc.category_id, f.film_id, f.title, c.name AS category_name,
           SUM(p.amount) AS revenue
    FROM film f
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY fc.category_id, f.film_id, f.title, c.name
),
category_avg AS (
    SELECT category_id, AVG(revenue) AS avg_revenue
    FROM film_revenue
    GROUP BY category_id
)
SELECT fr.film_id, fr.title, fr.category_name, fr.revenue AS film_revenue
FROM film_revenue fr
JOIN category_avg ca ON fr.category_id = ca.category_id
WHERE fr.revenue > ca.avg_revenue
ORDER BY film_revenue DESC;


-- ----------------------------------------------------------------------------
-- QUERY 4: Store Staff Quarterly Sales & Workload
-- (Formal: Staff Seasonal Throughput & Collection Performance)
-- ----------------------------------------------------------------------------
-- EXPLAIN (Baseline Bottleneck) Insights:
--   The query carries no filter predicate, so both the 116,044-row rental and 
--   116,049-row payment tables are fully scanned and hash-joined on every 
--   execution, then aggregated down to only 16 output rows. Estimated cost is 
--   43,481.86 with execution averaging 111.97ms over 5 runs. The planner also 
--   misestimates the HashAggregate at 116,055 rows against 16 actual. No index 
--   can reduce this: with no predicate to filter on, every row must be read.
--
-- Optimization Techniques:
--   Denormalization via CREATE TABLE AS, precomputing the staff/quarter 
--   aggregate into staff_quarterly_summary so the totals are materialized once 
--   rather than recomputed per execution. A secondary index was then added on 
--   (staff_id, rental_year, rental_quarter), since a table built by 
--   CREATE TABLE AS inherits no indexes.
--
-- EXPLAIN (Optimized) Insights:
--   The two hash joins over the 116k-row fact tables are replaced by a 
--   sequential scan of the 16-row summary table joined to staff. Aggregation 
--   and EXTRACT() evaluation are moved out of query execution entirely. 
--   Estimated cost falls from 43,481.86 to 2.78 and buffer hits to 2, with 
--   execution averaging 0.892ms over 5 runs.
--
--   The secondary index is NOT used by the planner. Because the denormalized 
--   table occupies a single page, a sequential scan is cheaper than an index 
--   traversal. This is a concrete instance of the Slide 9 question on when 
--   indexes fail to improve execution time: an index only pays off when it 
--   allows the engine to avoid reading a significant portion of the table.
--
-- Trade-off:
--   Building the summary table costs 139.7ms, more than a single baseline run, 
--   so the gain only materializes across repeated reads (break-even at roughly 
--   two executions). The table is also stale as soon as new rentals are 
--   recorded, suiting the non-volatile analytical workload described in 
--   Slide 22 rather than live reporting.
--
-- Supporting Course References:
--   • Slides 02b: Slides 22-25 (Denormalization for non-volatile analytical data)
--   • Slides 02b: Slides 8-16 (Creating and using secondary indexes)
--   • Slides 02b: Slide 9 (When indexes do not improve execution time)
--   • Slides 02b: Slide 17 (Using EXPLAIN to inspect the query plan)
-- ----------------------------------------------------------------------------

-- [4A. Optimized Query — Denormalization (Slides 22-25) + Secondary Index (Slides 8-16)]
-- Precompute the aggregate once, following the CREATE TABLE AS pattern from Slide 25
CREATE TABLE staff_quarterly_summary AS
SELECT r.staff_id,
       EXTRACT(YEAR FROM r.rental_date)::int AS rental_year,
       EXTRACT(QUARTER FROM r.rental_date)::int AS rental_quarter,
       COUNT(r.rental_id) AS total_rentals_processed,
       SUM(p.amount) AS total_payments_collected
FROM rental r
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY r.staff_id, rental_year, rental_quarter;

-- CREATE TABLE AS produces no indexes, so add a secondary index (Slide 12)
CREATE INDEX idx_sqs_staff ON staff_quarterly_summary (staff_id, rental_year, rental_quarter);

SELECT sqs.staff_id,
       s.first_name || ' ' || s.last_name AS staff_name,
       sqs.rental_year,
       sqs.rental_quarter,
       sqs.total_rentals_processed,
       sqs.total_payments_collected
FROM staff_quarterly_summary sqs
JOIN staff s ON sqs.staff_id = s.staff_id
ORDER BY sqs.rental_year DESC, sqs.rental_quarter DESC, sqs.total_payments_collected DESC;

-- [4B. Inspect Execution Plan (EXPLAIN)]
EXPLAIN (ANALYZE, BUFFERS, COSTS, TIMING)
SELECT sqs.staff_id,
       s.first_name || ' ' || s.last_name AS staff_name,
       sqs.rental_year,
       sqs.rental_quarter,
       sqs.total_rentals_processed,
       sqs.total_payments_collected
FROM staff_quarterly_summary sqs
JOIN staff s ON sqs.staff_id = s.staff_id
ORDER BY sqs.rental_year DESC, sqs.rental_quarter DESC, sqs.total_payments_collected DESC;