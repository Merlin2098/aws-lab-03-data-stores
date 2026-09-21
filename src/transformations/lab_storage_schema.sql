CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100),
    city VARCHAR(100),
    segment VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    order_date DATE,
    status VARCHAR(30),
    total_amount DECIMAL(12, 2),
    FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);
