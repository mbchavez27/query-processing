import random
from datetime import datetime, timedelta

FIRST_NAMES = [
    'James', 'Mary', 'Robert', 'Patricia', 'John', 'Jennifer', 'Michael', 'Linda',
    'David', 'Elizabeth', 'William', 'Barbara', 'Richard', 'Susan', 'Joseph', 'Jessica',
    'Thomas', 'Sarah', 'Charles', 'Karen', 'Christopher', 'Lisa', 'Daniel', 'Nancy',
    'Matthew', 'Betty', 'Anthony', 'Margaret', 'Mark', 'Sandra', 'Donald', 'Ashley',
    'Steven', 'Kimberly', 'Paul', 'Emily', 'Andrew', 'Donna', 'Joshua', 'Michelle',
    'Kenneth', 'Dorothy', 'Kevin', 'Carol', 'Brian', 'Amanda', 'George', 'Melissa',
    'Timothy', 'Deborah', 'Ronald', 'Stephanie', 'Edward', 'Rebecca', 'Jason', 'Sharon',
    'Jeffrey', 'Laura', 'Ryan', 'Cynthia', 'Jacob', 'Kathleen', 'Gary', 'Amy',
    'Nicholas', 'Angela', 'Eric', 'Shirley', 'Jonathan', 'Anna', 'Stephen', 'Brenda',
    'Larry', 'Pamela', 'Justin', 'Emma', 'Scott', 'Nicole', 'Brandon', 'Helen',
    'Benjamin', 'Samantha', 'Samuel', 'Katherine', 'Raymond', 'Christine', 'Gregory', 'Debra',
    'Frank', 'Rachel', 'Alexander', 'Carolyn', 'Patrick', 'Janet', 'Jack', 'Catherine',
    'Dennis', 'Maria', 'Jerry', 'Heather', 'Tyler', 'Diane', 'Aaron', 'Ruth',
    'Jose', 'Julie', 'Adam', 'Olivia', 'Nathan', 'Joyce', 'Henry', 'Virginia',
]

LAST_NAMES = [
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
    'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson',
    'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Perez', 'Thompson',
    'White', 'Harris', 'Sanchez', 'Clark', 'Ramirez', 'Lewis', 'Robinson', 'Walker',
    'Young', 'Allen', 'King', 'Wright', 'Scott', 'Torres', 'Nguyen', 'Hill',
    'Flores', 'Green', 'Adams', 'Nelson', 'Baker', 'Hall', 'Rivera', 'Campbell',
    'Mitchell', 'Carter', 'Roberts', 'Gomez', 'Phillips', 'Evans', 'Turner', 'Diaz',
    'Parker', 'Cruz', 'Edwards', 'Collins', 'Reyes', 'Stewart', 'Morris', 'Morales',
    'Murphy', 'Cook', 'Rogers', 'Gutierrez', 'Ortiz', 'Morgan', 'Cooper', 'Peterson',
    'Bailey', 'Reed', 'Kelly', 'Howard', 'Ramos', 'Kim', 'Cox', 'Ward',
    'Richardson', 'Watson', 'Brooks', 'Chavez', 'Wood', 'James', 'Bennett', 'Gray',
    'Mendoza', 'Ruiz', 'Hughes', 'Price', 'Alvarez', 'Castillo', 'Sanders', 'Patel',
    'Myers', 'Long', 'Ross', 'Foster', 'Jimenez', 'Powell', 'Jenkins', 'Perry',
    'Russell', 'Sullivan', 'Bell', 'Coleman', 'Butler', 'Henderson', 'Barnes', 'Gonzales',
]

STATIC_REFERENCE_TIMESTAMP = datetime(2026, 9, 1, 12, 0, 0)


def weighted_weekday_date(reference_date, rng):
    """Shift a random date to land on Friday/Saturday ~30% of the time."""
    candidate = reference_date
    if rng.random() < 0.30:
        days_to_fri = (4 - candidate.weekday()) % 7
        days_to_sat = (5 - candidate.weekday()) % 7
        candidate = candidate + timedelta(days=min(days_to_fri, days_to_sat))
    return candidate


def seasonal_month_weight(month):
    """Return a weight multiplier for a given month. Nov-Dec get a boost."""
    weights = {
        1: 0.8, 2: 0.75, 3: 0.85, 4: 0.9, 5: 0.95, 6: 1.0,
        7: 1.05, 8: 1.0, 9: 0.95, 10: 0.9, 11: 1.2, 12: 1.3,
    }
    return weights.get(month, 1.0)


def generate_seasonal_date(base_date, rng):
    """Generate a date weighted toward weekends and Nov-Dec."""
    for _ in range(20):
        candidate = base_date - timedelta(days=rng.uniform(0, 365))
        weight = seasonal_month_weight(candidate.month)
        if rng.random() < weight / 1.3:
            return weighted_weekday_date(candidate, rng)
    return weighted_weekday_date(base_date - timedelta(days=rng.uniform(0, 365)), rng)


def generate_return_date(rental_date, rng):
    """Return date: 70% on-time, 20% moderately late, 10% very late."""
    roll = rng.random()
    if roll < 0.70:
        days = rng.randint(1, 3)
    elif roll < 0.90:
        days = rng.randint(4, 10)
    else:
        days = rng.randint(11, 30)
    return rental_date + timedelta(days=days)


def generate_sql_dump(
    filename="sakila_dump.sql",
    num_customers=1000,
    num_rentals=100000,
    seed=42,
    reference_date=STATIC_REFERENCE_TIMESTAMP,
):
    """
    Generate synthetic data adhering to the Pareto distribution, temporal skew,
    and referential integrity constraints. Uses a dedicated random.Random(seed)
    instance and a static reference date to ensure bit-for-bit reproducibility.
    """
    rng = random.Random(seed)

    start_customer_id = 600
    start_rental_id = 16050

    with open(filename, "w", encoding="utf-8") as f:
        f.write("-- ==========================================================\n")
        f.write("-- Synthetic Data Dump generated for Sakila Database\n")
        f.write(f"-- Reference Date: {reference_date.strftime('%Y-%m-%d %H:%M:%S')} (Static Epoch)\n")
        f.write(f"-- Seed: {seed} (Deterministic PRNG)\n")
        f.write("-- ==========================================================\n")
        f.write("BEGIN;\n\n")

        # 1. Generate Customers
        f.write("-- 1. Inserting customers (1,000 synthetic records: IDs 600-1599)\n")
        valid_address_ids = [a for a in range(1, 600) if a not in (257, 518)]
        for i in range(num_customers):
            c_id = start_customer_id + i
            store_id = rng.randint(1, 2)
            fname = rng.choice(FIRST_NAMES)
            lname = rng.choice(LAST_NAMES)
            email = f"{fname.lower()}.{lname.lower()}{c_id}@example.com"
            address_id = rng.choice(valid_address_ids)
            active = 'true' if rng.random() > 0.05 else 'false'
            create_date = reference_date - timedelta(days=rng.uniform(1, 365))

            f.write(
                f"INSERT INTO customer (customer_id, store_id, first_name, last_name, email, address_id, activebool, create_date) "
                f"VALUES ({c_id}, {store_id}, '{fname}', '{lname}', '{email}', {address_id}, {active}, '{create_date.strftime('%Y-%m-%d')}');\n"
            )

        # 2. Generate Rentals & Buffer for Strictly Linked Payments
        f.write("\n-- 2. Inserting rentals (100,000 synthetic records: IDs 16050-116049)\n")
        rentals_buffer = []
        for i in range(num_rentals):
            r_id = start_rental_id + i
            c_id = int(start_customer_id + (pow(rng.random(), 2.5) * (num_customers - 1)))
            inv_id = rng.randint(1, 4581)
            staff_id = rng.randint(1, 2)

            rental_date = generate_seasonal_date(reference_date, rng)
            return_date = generate_return_date(rental_date, rng)

            rentals_buffer.append((r_id, c_id, staff_id, rental_date))

            f.write(
                f"INSERT INTO rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id) "
                f"VALUES ({r_id}, '{rental_date.strftime('%Y-%m-%d %H:%M:%S')}', {inv_id}, {c_id}, '{return_date.strftime('%Y-%m-%d %H:%M:%S')}', {staff_id});\n"
            )

        # 3. Generate Payments (strictly correlated with rental records)
        f.write("\n-- 3. Inserting payments (100,000 synthetic records: strictly linked to rentals)\n")
        tier_prices = [0.99, 2.99, 4.99]
        for r_id, c_id, staff_id, rental_date in rentals_buffer:
            base_price = rng.choice(tier_prices)
            late_fee = round(rng.uniform(1, 5), 2) if rng.random() > 0.85 else 0.0
            amount = round(base_price + late_fee, 2)

            # Payment within 0-3 days of rental; 5% chance of 7-14 day delay
            if rng.random() < 0.05:
                payment_delay = rng.randint(7, 14)
            else:
                payment_delay = rng.randint(0, 3)

            payment_date = rental_date + timedelta(days=payment_delay)

            f.write(
                f"INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date) "
                f"VALUES ({c_id}, {staff_id}, {r_id}, {amount}, '{payment_date.strftime('%Y-%m-%d %H:%M:%S')}');\n"
            )

        # 4. Fix PostgreSQL Sequences
        f.write("\n-- 4. Resetting Auto-Increment Sequences\n")
        f.write("SELECT setval('customer_customer_id_seq', (SELECT MAX(customer_id) FROM customer));\n")
        f.write("SELECT setval('rental_rental_id_seq', (SELECT MAX(rental_id) FROM rental));\n")
        f.write("SELECT setval('payment_payment_id_seq', (SELECT COALESCE(MAX(payment_id), 1) FROM payment));\n")

        f.write("COMMIT;\n")

    print(f"Deterministic dump file '{filename}' generated successfully!")


if __name__ == "__main__":
    generate_sql_dump()