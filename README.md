# query-processing

Hands On 1 for STADVDB: Investigation of Query Optimization

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (with Docker Compose v2)

## Getting Started

1. Clone the repository:

   ```bash
   git clone <repo-url>
   cd query-processing
   ```

2. Copy the example environment file and adjust values if needed:

   ```bash
   cp .env.example .env
   ```

3. Start the PostgreSQL container:

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

## About Sakila

This project uses the [Sakila](https://github.com/jOOQ/sakila) sample database -- a film-rental schema commonly used for SQL benchmarks and exercises. It is loaded into PostgreSQL on first container startup via `init-sakila.sh`.
