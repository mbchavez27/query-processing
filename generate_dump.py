import random
from datetime import datetime, timedelta

def generate_sql_dump(filename="sakila_dump.sql", num_customers=1000, num_rentals=100000):
    # Standard generic names for the dataset
    first_names = ['James', 'Mary', 'Robert', 'Patricia', 'John', 'Jennifer', 'Michael', 'Linda', 'David', 'Elizabeth', 'William', 'Barbara', 'Richard', 'Susan', 'Joseph']
    last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson']
    
    # Base Sakila data has 599 customers and 16044 rentals. We start IDs after those.
    start_customer_id = 600
    start_rental_id = 16045
    
    with open(filename, "w") as f:
        f.write("-- ==========================================================\n")
        f.write("-- Synthetic Data Dump generated for Sakila Database\n")
        f.write("-- ==========================================================\n")
        f.write("BEGIN;\n\n")
        
        # 1. Generate 1,000 Customers
        f.write("-- 1. Inserting 1,000 customers\n")
        for i in range(num_customers):
            c_id = start_customer_id + i
            store_id = random.randint(1, 2)
            fname = random.choice(first_names)
            lname = random.choice(last_names)
            email = f"{fname.lower()}.{lname.lower()}{c_id}@example.com"
            address_id = random.randint(1, 599)
            active = 'true' if random.random() > 0.05 else 'false'
            create_date = datetime.now() - timedelta(days=random.uniform(1, 365))
            
            f.write(f"INSERT INTO customer (customer_id, store_id, first_name, last_name, email, address_id, activebool, create_date) "
                    f"VALUES ({c_id}, {store_id}, '{fname}', '{lname}', '{email}', {address_id}, {active}, '{create_date.strftime('%Y-%m-%d')}');\n")

        # 2. Generate 100,000 Rentals
        f.write("\n-- 2. Inserting 100,000 rentals\n")
        for i in range(num_rentals):
            r_id = start_rental_id + i
            # Skewed distribution: a small group of customers rent frequently
            c_id = int(start_customer_id + (pow(random.random(), 2.5) * (num_customers - 1)))
            inv_id = random.randint(1, 4581)
            staff_id = random.randint(1, 2)
            
            days_ago = random.uniform(1, 365)
            rental_date = datetime.now() - timedelta(days=days_ago)
            return_date = rental_date + timedelta(days=random.uniform(1, 10))
            
            f.write(f"INSERT INTO rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id) "
                    f"VALUES ({r_id}, '{rental_date.strftime('%Y-%m-%d %H:%M:%S')}', {inv_id}, {c_id}, '{return_date.strftime('%Y-%m-%d %H:%M:%S')}', {staff_id});\n")

        # 3. Generate 100,000 Payments
        f.write("\n-- 3. Inserting 100,000 payments\n")
        tier_prices = [0.99, 2.99, 4.99]
        for i in range(num_rentals):
            r_id = start_rental_id + i
            # Must match the customer who made the rental
            random.seed(r_id) 
            c_id = int(start_customer_id + (pow(random.random(), 2.5) * (num_customers - 1)))
            random.seed() # Reset seed for randomizing other values
            
            staff_id = random.randint(1, 2)
            base_price = random.choice(tier_prices)
            late_fee = round(random.uniform(1, 5), 2) if random.random() > 0.85 else 0.0
            amount = round(base_price + late_fee, 2)
            payment_date = datetime.now() - timedelta(days=random.uniform(1, 360))
            
            f.write(f"INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date) "
                    f"VALUES ({c_id}, {staff_id}, {r_id}, {amount}, '{payment_date.strftime('%Y-%m-%d %H:%M:%S')}');\n")

        # 4. Fix PostgreSQL Sequences
        f.write("\n-- 4. Resetting Auto-Increment Sequences\n")
        f.write("SELECT setval('customer_customer_id_seq', (SELECT MAX(customer_id) FROM customer));\n")
        f.write("SELECT setval('rental_rental_id_seq', (SELECT MAX(rental_id) FROM rental));\n")
        f.write("SELECT setval('payment_payment_id_seq', (SELECT MAX(payment_id) FROM payment));\n")

        f.write("\nCOMMIT;\n")
        
    print(f"Dump file '{filename}' generated successfully! File size: ~35MB.")

if __name__ == "__main__":
    generate_sql_dump()