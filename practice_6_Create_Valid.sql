SELECT 
    (SELECT COUNT(*) FROM customer) AS customer_count,
    (SELECT COUNT(*) FROM product) AS product_count,
    (SELECT COUNT(*) FROM orders) AS orders_count,
    (SELECT COUNT(*) FROM order_item) AS order_item_count,
    (SELECT COUNT(*) FROM product_price_scd) AS scd_history_count;

-- 주문(orders)의 total_amount와 주문 상세(order_item)의 합계가 다른 건이 있는지 조회
-- 결과가 0건이어야 정상입니다.
SELECT 
    o.order_id, 
    o.total_amount, 
    SUM(oi.line_total) AS calculated_sum
FROM orders o
JOIN order_item oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
HAVING o.total_amount <> SUM(oi.line_total);

-- prev_category 컬럼이 존재하는지 확인
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'product' AND column_name = 'prev_category';

-- 주문과 상품 정보가 잘 조인되는지 확인
SELECT 
    o.order_id, 
    c.name AS customer_name, 
    p.name AS product_name, 
    oi.qty, 
    oi.line_total,
    o.order_ts
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
JOIN order_item oi ON o.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
LIMIT 5;