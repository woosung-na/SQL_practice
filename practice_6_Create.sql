-- 00_setup_seed.sql (PostgreSQL, 간단 버전)
DROP SCHEMA IF EXISTS mini CASCADE;
CREATE SCHEMA mini;
SET search_path = mini, public;

CREATE TABLE customer(
  customer_id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE product(
  product_id BIGSERIAL PRIMARY KEY,
  sku TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  price NUMERIC(12,2) NOT NULL CHECK (price>=0),
  stock_qty INT NOT NULL DEFAULT 100 CHECK (stock_qty>=0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE product_price_scd(
  scd_id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES product(product_id),
  price NUMERIC(12,2) NOT NULL,
  valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_to   TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31',
  is_current BOOLEAN NOT NULL DEFAULT true
);
CREATE INDEX ON product_price_scd(product_id, is_current);

CREATE TABLE orders(
  order_id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES customer(customer_id),
  order_ts TIMESTAMPTZ NOT NULL DEFAULT now(),
  subtotal NUMERIC(14,2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  discount_amt NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE order_item(
  order_item_id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(order_id),
  product_id BIGINT NOT NULL REFERENCES product(product_id),
  qty INT NOT NULL CHECK (qty>0),
  unit_price NUMERIC(12,2) NOT NULL,
  line_total NUMERIC(14,2) NOT NULL
);

-- seed: 500 customers, 100 products, 1000 orders (avg 2 items)
INSERT INTO customer(name,email,created_at)
SELECT 'Customer '||g, 'c'||g||'@example.com', now() - (g||' days')::interval
FROM generate_series(1,500) g;

INSERT INTO product(sku,name,category,price,stock_qty)
SELECT 'SKU-'||g, 'Product '||g,
       CASE g%4 WHEN 0 THEN 'Electronics' WHEN 1 THEN 'Home' WHEN 2 THEN 'Sports' ELSE 'Toys' END,
       (10 + (g%50))::numeric(12,2),
       100 + (g%10)
FROM generate_series(1,100) g;

INSERT INTO product_price_scd(product_id,price) SELECT product_id, price FROM product;

DO $$
DECLARE i int; o_id bigint; p int; q int; v_price numeric; c int;
BEGIN
  FOR i IN 1..1000 LOOP
    c := (random()*499 + 1)::int;
    INSERT INTO orders(customer_id) VALUES (c) RETURNING order_id INTO o_id;
    -- 2 items
    p := (random()*99 + 1)::int;
    SELECT price INTO v_price FROM product WHERE product_id = p;
    q := 1 + (random()*2)::int;
    INSERT INTO order_item(order_id, product_id, qty, unit_price, line_total)
    VALUES (o_id, p, q, v_price, q*v_price);
    p := (random()*99 + 1)::int;
    SELECT price INTO v_price FROM product WHERE product_id = p;
    q := 1 + (random()*2)::int;
    INSERT INTO order_item(order_id, product_id, qty, unit_price, line_total)
    VALUES (o_id, p, q, v_price, q*v_price);
    UPDATE orders SET subtotal=(SELECT sum(line_total) FROM order_item WHERE order_id=o_id),
                      total_amount=subtotal
    WHERE order_id=o_id;
  END LOOP;
END $$;

ALTER TABLE product ADD COLUMN IF NOT EXISTS prev_category TEXT;