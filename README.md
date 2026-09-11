# query-processing

Hands On 1 for STADVDB: Investigation of Query Optimization

## Prerequisites

- [Docker Desktop](https://docs.docker.com/get-docker/) (includes Docker Compose v2)
- [Python 3](https://www.python.org/downloads/) (for generating synthetic data)
- [Git](https://git-scm.com/downloads)

## Getting Started

### 1. Clone the repository

```bash
git clone <repo-url>
cd query-processing
```

### 2. Set up environment variables

**macOS / Linux:**
```bash
cp .env.example .env
```

**Windows (PowerShell):**
```powershell
Copy-Item .env.example .env
```

### 3. Start PostgreSQL

```bash
docker compose up -d
```

On first run, the Sakila sample database will be downloaded and loaded automatically. This may take a moment.

## Connecting

| Parameter  | Value      |
|------------|------------|
| Host       | `localhost` |
| Port       | `5432`     |
| User       | `postgres` |
| Password   | see `.env` |
| Database   | `postgres` |

Example with `psql`:

```bash
psql -h localhost -p 5432 -U postgres -d postgres
```

## Stopping / Resetting

```bash
# Stop the container (data persists)
docker compose down

# Stop and delete all data (clean slate)
docker compose down -v
```

## Synthetic Data

The base Sakila dataset has 599 customers and ~16k rentals. For query optimization experiments with larger data, you can generate and load synthetic rows.

1. Generate the SQL dump:

   ```bash
   python generate_dump.py
   ```

   This creates `sakila_dump.sql` with 1,000 customers, 100k rentals, and 100k payments.

2. Load it into PostgreSQL (make sure the container is running and init has finished):

   ```bash
   docker compose exec -T postgres psql -U postgres -d postgres < sakila_dump.sql
   ```

## GenAI Usage

This project uses GenAI (Gemini) to generate the synthetic data script.

### Prompt

```prompt
Write a complete Python script named generate_dump.py that outputs a PostgreSQL-compatible SQL dump file called sakila_dump.sql for the Sakila database.

The script must fulfill the following requirements:

Volume & Scope:
- Insert 1,000 new customers (starting at customer_id 600) using realistic generic first and last names, emails, and address IDs (1–599).
- Insert 100,000 new rentals (starting at rental_id 16045) and 100,000 new payments linked strictly to those rentals.

Referential Integrity & Sequences:
- Ensure foreign keys match properly across tables.
- At the end of the script, include PostgreSQL SELECT setval(...) commands to update the auto-increment sequences for customer, rental, and payment so future manual inserts don't collide.

Realistic Data Skew:
- For customer names, use at least 50 unique first names and 50 unique last names to minimize collisions across 1,000 generated customers.
- For customer rental frequency, apply a power-law / Pareto skew using pow(random.random(), 2.5) so a small percentage of customers account for the majority of rentals.
- For rental dates, do NOT use a uniform distribution. Apply weekday weighting (higher activity on Fridays and Saturdays) and seasonal weighting (increased activity in November–December).
- For return dates, use a skewed distribution: 70% on-time (1–3 days), 20% moderately late (4–10 days), 10% very late (11–30 days).
- For payments, select from standard rental tiers ($0.99, $2.99, $4.99) and conditionally add a randomized late fee (between $1.00 and $5.00) to roughly 15% of the transactions.
- Payment dates must be correlated with rental dates: payments occur 0–3 days after the rental date, with a 5% chance of a 7–14 day delay.

Output:
- Wrap everything inside a BEGIN; and COMMIT; transaction block.
- Use a fixed random seed (e.g., seed=42) for reproducibility.
- Print a success message when the file is finished.
```

### Final Result

The script generates realistic synthetic data with:

- **100+ unique names** (100 first × 107 last) to minimize collisions across 1,000 customers
- **Seasonal rental dates** weighted toward Fridays/Saturdays and November–December
- **Skewed return dates** reflecting real-world on-time/late patterns
- **Correlated payment dates** tied to rental dates with realistic delays
- **Reproducible output** via fixed random seed

## About Sakila

This project uses the [Sakila](https://github.com/jOOQ/sakila) sample database -- a film-rental schema commonly used for SQL benchmarks and exercises. It is loaded into PostgreSQL on first container startup via `init-sakila.sh`.
