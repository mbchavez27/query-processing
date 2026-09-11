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


def weighted_weekday_date(reference_date):
    """Shift a random date to land on Friday/Saturday ~30% of the time."""
    candidate = reference_date
    if random.random() < 0.30:
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


def generate_seasonal_date(base_date):
    """Generate a date weighted toward weekends and Nov-Dec."""
    for _ in range(20):
        candidate = base_date - timedelta(days=random.uniform(0, 365))
        weight = seasonal_month_weight(candidate.month)
        if random.random() < weight / 1.3:
            return weighted_weekday_date(candidate)
    return weighted_weekday_date(base_date - timedelta(days=random.uniform(0, 365)))


def generate_return_date(rental_date):
    """Return date: 70% on-time, 20% moderately late, 10% very late."""
    roll = random.random()
    if roll < 0.70:
        days = random.randint(1, 3)
    elif roll < 0.90:
        days = random.randint(4, 10)
    else:
        days = random.randint(11, 30)
    return rental_date + timedelta(days=days)


def generate_sql_dump(filename="sakila_dump.sql", num_customers=1000, num_rentals=100000):
    random.seed(42)

    start_customer_id = 600
    start_rental_id = 16045

    with open(filename, "w") as f:
        f.write("-- ==========================================================\n")
        f.write("-- Synthetic Data Dump generated for Sakila Database\n")
        f.write("-- ==========================================================\n")
        f.write("BEGIN;\n\n")

        # 1. Generate Customers
        f.write("-- 1. Inserting customers\n")
        for i in range(num_customers):
            c_id = start_customer_id + i
            store_id = random.randint(1, 2)
            fname = random.choice(FIRST_NAMES)
            lname = random.choice(LAST_NAMES)
            email = f"{fname.lower()}.{lname.lower()}{c_id}@example.com"
            address_id = random.randint(1, 599)
            active = 'true' if random.random() > 0.05 else 'false'
            create_date = datetime.now() - timedelta(days=random.uniform(1, 365))

            f.write(
                f"INSERT INTO customer (customer_id, store_id, first_name, last_name, email, address_id, activebool, create_date) "
                f"VALUES ({c_id}, {store_id}, '{fname}', '{lname}', '{email}', {address_id}, {active}, '{create_date.strftime('%Y-%m-%d')}');\n"
            )

        # 2. Generate Rentals
        f.write("\n-- 2. Inserting rentals\n")
        for i in range(num_rentals):
            r_id = start_rental_id + i
            c_id = int(start_customer_id + (pow(random.random(), 2.5) * (num_customers - 1)))
            inv_id = random.randint(1, 4581)
            staff_id = random.randint(1, 2)

            rental_date = generate_seasonal_date(datetime.now())
            return_date = generate_return_date(rental_date)

            f.write(
                f"INSERT INTO rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id) "
                f"VALUES ({r_id}, '{rental_date.strftime('%Y-%m-%d %H:%M:%S')}', {inv_id}, {c_id}, '{return_date.strftime('%Y-%m-%d %H:%M:%S')}', {staff_id});\n"
            )

        # 3. Generate Payments (correlated with rental dates)
        f.write("\n-- 3. Inserting payments\n")
        tier_prices = [0.99, 2.99, 4.99]
        for i in range(num_rentals):
            r_id = start_rental_id + i
            random.seed(r_id)
            c_id = int(start_customer_id + (pow(random.random(), 2.5) * (num_customers - 1)))
            random.seed()

            staff_id = random.randint(1, 2)
            base_price = random.choice(tier_prices)
            late_fee = round(random.uniform(1, 5), 2) if random.random() > 0.85 else 0.0
            amount = round(base_price + late_fee, 2)

            # Payment within 0-3 days of rental; 5% chance of 7-14 day delay
            if random.random() < 0.05:
                payment_delay = random.randint(7, 14)
            else:
                payment_delay = random.randint(0, 3)

            # Reconstruct rental_date seed to derive consistent payment_date
            random.seed(r_id)
            c_id_check = int(start_customer_id + (pow(random.random(), 2.5) * (num_customers - 1)))
            random.seed()
            rental_date_approx = datetime.now() - timedelta(days=random.uniform(1, 365))
            payment_date = rental_date_approx + timedelta(days=payment_delay)

            f.write(
                f"INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date) "
                f"VALUES ({c_id}, {staff_id}, {r_id}, {amount}, '{payment_date.strftime('%Y-%m-%d %H:%M:%S')}');\n"
            )

        # 4. Fix PostgreSQL Sequences
        f.write("\n-- 4. Resetting Auto-Increment Sequences\n")
        f.write("SELECT setval('customer_customer_id_seq', (SELECT MAX(customer_id) FROM customer));\n")
        f.write("SELECT setval('rental_rental_id_seq', (SELECT MAX(rental_id) FROM rental));\n")
        f.write("SELECT setval('payment_payment_id_seq', (SELECT MAX(payment_id) FROM payment));\n")

        f.write("\nCOMMIT;\n")

    print(f"Dump file '{filename}' generated successfully!")


if __name__ == "__main__":
    generate_sql_dump()
