--------------------------------------------------------------
-- Q1) 지난 한 달간 실제 팔린 총 금액 보기 (paid+shipped+delivered)
CREATE INDEX idx_orders_ts_status_covering 
ON orders (order_ts, order_status) 
INCLUDE (order_id);

CREATE INDEX idx_order_items_join_covering 
ON order_items (order_id) 
INCLUDE (line_total);

ANALYZE orders;
ANALYZE order_items;

explain analyze
select o.order_status, trunc(sum(oi.line_total), 0) 총_금액
from orders o 
	join order_items oi on o.order_id = oi.order_id
where o.order_status in ('paid', 'shipped', 'delivered')
 and o.order_ts >= current_date - interval '30days'
group by o.order_status;

--------------------------------------------------------------
-- Q2) 월별로 몇 개 주문이 있었고, 얼마 벌었는지, 주문당 평균 금액은 얼마인지
-- 1. 세션 레벨에서 Hash Join 비활성화 (Merge Join 강제)
SET enable_hashjoin = OFF;

explain analyze
select to_char(o.order_ts,'yyyy-mm') 월, 
	count(o.order_id) 주문_개수, 
	trunc(sum(oi.line_total),0) 매출액, 
	trunc(sum(oi.line_total)/count(o.order_id),2) 주문당_평균_금액 
from orders o
	join order_items oi on o.order_id = oi.order_id
where o.order_status in ('paid', 'shipped', 'delivered')
group by 1
order by 1;

-- 3. 테스트 후 원상복구
SET enable_hashjoin = ON;

-- 기존 뷰 삭제 (있다면)
DROP MATERIALIZED VIEW IF EXISTS mv_daily_gmv;
-- 1. MV 생성 (핵심: order_status별로, count와 sum을 미리 계산)
CREATE MATERIALIZED VIEW mv_daily_gmv AS
SELECT 
    date_trunc('day', o.order_ts)::date AS day,
    o.order_status,
    COUNT(o.order_id) AS daily_count,      -- 주문 건수 (Q2 AOV 계산용)
    SUM(oi.line_total) AS daily_revenue    -- 매출액 (Q1, Q2 공용)
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status IN ('paid', 'shipped', 'delivered') -- 유효 매출만 저장
GROUP BY 1, 2;

-- 2. 인덱스 생성 (필수: 조회 속도 가속)
CREATE INDEX idx_mv_daily_day ON mv_daily_gmv(day);

EXPLAIN ANALYZE
SELECT 
    to_char(day, 'yyyy-mm') AS 월,
    SUM(daily_count) AS 주문_개수,
    TRUNC(SUM(daily_revenue), 0) AS 매출액,
    -- 0 나누기 방지 처리
    TRUNC(SUM(daily_revenue) / NULLIF(SUM(daily_count), 0), 2) AS 주문당_평균_금액
FROM mv_daily_gmv
GROUP BY 1
ORDER BY 1;

--------------------------------------------------------------
-- Q3) 최근 90일 카테고리 Top10
-- 상품 등록일 기준 검색을 위한 인덱스
CREATE INDEX idx_products_created_at ON products(created_at);
EXPLAIN ANALYZE
select c.category_name 카테고리, count(c.category_id) 개수
from categories c
	join products p on c.category_id = p.category_id
where p.created_at >= current_date - interval '90days'
group by c.category_name
order by 2 desc
limit 10;

--------------------------------------------------------------
-- Q4) 제품별 누적매출 RANK() Top20
-- 1. 제품별 매출 집계를 위한 커버링 인덱스
CREATE INDEX idx_order_items_product_sales 
ON order_items(product_id) 
INCLUDE (line_total);
-- 2. 통계 갱신
ANALYZE order_items;

EXPLAIN ANALYZE
select p.product_name 제품명, 
	trunc(sum(oi.line_total), 0) 누적_매출, 
	rank() over (order by sum(oi.line_total) desc) 순위
from products p
	join order_items oi on p.product_id = oi.product_id 
group by p.product_id
limit 20;

EXPLAIN ANALYZE
SELECT 
    p.product_name,
    sales.total_sales,
    sales.rnk
FROM (
    -- 1. 먼저 집계하고 순위 매기기 (인덱스만 사용)
    SELECT 
        product_id, 
        SUM(line_total) AS total_sales,
        RANK() OVER (ORDER BY SUM(line_total) DESC) AS rnk
    FROM order_items
    GROUP BY product_id
    LIMIT 20 -- Top 20만 남김
) sales
JOIN products p ON sales.product_id = p.product_id -- 2. 여기서 딱 20번만 조인
ORDER BY sales.rnk;
-- MV
CREATE MATERIALIZED VIEW mv_product_sales_rank AS
SELECT 
    product_id,
    SUM(line_total) AS total_sales
FROM order_items
GROUP BY product_id;

CREATE INDEX idx_mv_sales_rank ON mv_product_sales_rank(total_sales DESC);
--------------------------------------------------------------
-- Q5) 고객이 얼마나 최근에, 얼마나 자주, 얼마나 많이 샀는지 (최근성/빈도/금액)
EXPLAIN analyze
select c.customer_id 고객_ID, 
	to_char(max(o.order_ts),'yyyy-mm-dd') 주문_일자, 
	count(distinct(o.order_id)) 주문_횟수,
	count(oi.order_item_id) 주문_개수,
	trunc(sum(oi.line_total), 0) 주문_금액
from customers c
	join orders o on c.customer_id = o.customer_id
	join order_items oi on o.order_id = oi.order_id
group by c.customer_id
order by 2, 3, 5 desc;
CREATE INDEX IF NOT EXISTS idx_orders_customer_rfm 
ON orders (customer_id, order_id, order_ts);
ANALYZE orders;

EXPLAIN ANALYZE
WITH rfm_stats AS (
    -- 1. [핵심] 고객별 RFM을 먼저 계산 (고객 정보 없이 ID만 사용)
    SELECT 
        o.customer_id,
        MAX(o.order_ts) AS last_order_date,    -- Recency
        COUNT(DISTINCT o.order_id) AS frequency, -- Frequency
        SUM(oi.line_total) AS monetary         -- Monetary
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
-- 2. 가벼워진 통계 데이터(3,000건)에 고객 정보만 살짝 조인
SELECT 
    c.full_name,
    rfm.last_order_date,
    rfm.frequency,
    rfm.monetary
FROM rfm_stats rfm
JOIN customers c ON rfm.customer_id = c.customer_id
ORDER BY rfm.monetary DESC; -- 보통 매출 높은 순으로 봄

-- MV 생성
CREATE MATERIALIZED VIEW mv_customer_rfm AS
SELECT 
    o.customer_id,
    MAX(o.order_ts) AS last_order_date,    -- Recency
    COUNT(DISTINCT o.order_id) AS frequency, -- Frequency
    SUM(oi.line_total) AS monetary         -- Monetary
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.customer_id;

-- 조회 가속을 위한 인덱스 (Monetary 순 정렬 등)
CREATE UNIQUE INDEX idx_mv_rfm_customer ON mv_customer_rfm(customer_id);
CREATE INDEX idx_mv_rfm_monetary ON mv_customer_rfm(monetary DESC);

EXPLAIN ANALYZE
SELECT 
    c.full_name,
    rfm.last_order_date,
    rfm.frequency,
    rfm.monetary
FROM mv_customer_rfm rfm
JOIN customers c ON rfm.customer_id = c.customer_id
ORDER BY rfm.monetary DESC;
--------------------------------------------------------------
-- Q6) 첫 구매 후 30일 내 재구매율
EXPLAIN ANALYZE
select
	count(customer_id) 전체_고객수,
	sum(case when term then 1 else 0 end) 재구매_인원,
	trunc(sum(case when term then 1 else 0 end)::numeric
	/ count(customer_id)::numeric,2) 재구매율
from (
	with pay_list as 
	(
	-- 결제가 완료된 데이터만 필터링
		select 
			o.customer_id,
			p.paid_at paid_ts,
			row_number() over (partition by o.customer_id order by p.paid_at) purchase_seq,
			LEAD(p.paid_at) OVER (PARTITION BY o.customer_id ORDER BY p.paid_at) as next_paid_at
		from orders o
			join payments p on o.order_id = p.order_id
	)
	select 
		customer_id, 
		to_char(paid_ts, 'yyyy-mm-dd') 첫_구매일자, 
		to_char(next_paid_at, 'yyyy-mm-dd') 다음_구매일자,
		next_paid_at - paid_ts <= interval '30days' as term	
	from pay_list
	where purchase_seq = 1 and next_paid_at is not null
);

-- 1. 기존 뷰가 있다면 삭제
DROP MATERIALIZED VIEW IF EXISTS mv_purchase_log;

-- 2. 구매 이력 요약 MV 생성 (수정됨)
CREATE MATERIALIZED VIEW mv_purchase_log AS
SELECT 
    o.customer_id,
    p.paid_at,
    -- 윈도우 함수: 다음 구매일(LEAD)과 구매 순서(ROW_NUMBER) 미리 계산
    LEAD(p.paid_at) OVER (PARTITION BY o.customer_id ORDER BY p.paid_at) AS next_paid_at,
    ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY p.paid_at) AS purchase_seq
FROM orders o
JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status IN ('paid', 'shipped', 'delivered'); -- p.status 대신 o.order_status 사용

-- 3. 인덱스 생성 (필수)
CREATE INDEX idx_mv_purchase_log_seq 
ON mv_purchase_log(purchase_seq)
INCLUDE (paid_at, next_paid_at);

-- 4. 통계 갱신
ANALYZE mv_purchase_log;

EXPLAIN ANALYZE
SELECT 
    COUNT(CASE WHEN next_paid_at - paid_at <= INTERVAL '30 days' THEN 1 END)::FLOAT 
    / NULLIF(COUNT(*), 0) AS retention_rate
FROM mv_purchase_log
WHERE purchase_seq = 1; -- 첫 구매 고객만 필터링

--------------------------------------------------------------
-- Q7) 재고가 임계치보다 낮은 상품 찾아내기 (곧 품절될 위험이 있는 상품은?)
EXPLAIN ANALYZE
select p.product_id 상품_ID, p.product_name 상품명, i.qty_on_hand 상품수
from inventory i
	join products p on p.product_id = i.product_id
where i.qty_on_hand <= i.reorder_point;

-- 1. 두 컬럼의 차이값을 미리 계산해서 정렬해두는 인덱스
CREATE INDEX idx_inventory_low_stock 
ON inventory ((qty_on_hand - reorder_point));

-- 2. 통계 갱신
ANALYZE inventory;

EXPLAIN ANALYZE
SELECT 
    p.product_name,
    i.qty_on_hand,
    i.reorder_point
FROM inventory i
JOIN products p ON i.product_id = p.product_id
-- [핵심] 인덱스와 동일한 형태의 수식으로 조건 변경
WHERE (i.qty_on_hand - i.reorder_point) <= 0;

--------------------------------------------------------------
-- Q8) 리뷰 4.5 이상 & 50 개 이상 효자상품 (리뷰가 많고 평가도 좋은 효자상품 찾기)
EXPLAIN ANALYZE
with filter_review as
(
	select 
		r.product_id,
		p.product_name,
		avg(r.rating) as avg_review, 
		count(r.review_id) as cnt_review
		from reviews r
			join products p on r.product_id = p.product_id
		group by 1, 2
)
select product_id, product_name 상품명, trunc(avg_review, 2) 리뷰, cnt_review 리뷰_수
from filter_review
where cnt_review >= 50;

-- 리뷰 개수를 세기 위한 커버링 인덱스 역할
CREATE INDEX idx_reviews_product_id ON reviews(product_id);

-- 통계 갱신
ANALYZE reviews;

EXPLAIN ANALYZE
SELECT 
    p.product_name,
    r.review_count
FROM products p
JOIN (
    -- 1. [핵심] 먼저 집계하고 필터링 (Index Only Scan 유도)
    SELECT 
        product_id, 
        COUNT(*) as review_count
    FROM reviews
    GROUP BY product_id
    HAVING COUNT(*) >= 50
) r ON p.product_id = r.product_id; -- 2. 살아남은 소수만 조인

--------------------------------------------------------------
-- Q9) 쿠폰 사용 영향 (쿠폰을 쓴 주문과 안 쓴 주문의 평균 주문 금액 비교)
-- 쿠폰 null 인 값 평균값 + 쿠폰 not null 평균값 필터링
EXPLAIN ANALYZE
select
	trunc(not_null_amount,2) 쿠폰_쓴_평균_주문_금액,
	trunc(null_amount,2) 쿠폰_안_쓴_평균_주문_금액	
from 
	(select avg(oi.line_total) null_amount
		from orders o
			join order_items oi on o.order_id = oi.order_id
		where o.coupon_code is null), 
	(select avg(oi.line_total) not_null_amount
		from orders o
			join order_items oi on o.order_id = oi.order_id
		where o.coupon_code is not null);

EXPLAIN ANALYZE
SELECT 
    -- 쿠폰 없는 그룹
    COUNT(CASE WHEN o.coupon_code IS NULL THEN 1 END) AS no_coupon_orders,
    SUM(CASE WHEN o.coupon_code IS NULL THEN oi.line_total END) AS no_coupon_sales,
    -- 쿠폰 있는 그룹
    COUNT(CASE WHEN o.coupon_code IS NOT NULL THEN 1 END) AS coupon_orders,
    SUM(CASE WHEN o.coupon_code IS NOT NULL THEN oi.line_total END) AS coupon_sales
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id;

--------------------------------------------------------------
-- Q10) 상위 1% 고객의 최근 60일 매출
EXPLAIN ANALYZE
with filter_customer as
(
	select c.customer_id, sum(line_total) as total_cost, ntile(100) over (order by sum(line_total) desc) as tile
	from customers c
		join orders o on c.customer_id = o.customer_id
		join order_items oi on o.order_id = oi.order_id
	where o.order_ts >= current_date - interval '60days'
	group by 1
)
select customer_id 고객_ID, total_cost 매출, tile 상위_퍼센트
from filter_customer
where tile = 1
order by 2 desc;

EXPLAIN ANALYZE
WITH vip_ranks AS (
    -- 1. [핵심] 고객 정보 없이 ID와 매출만으로 랭킹 산정 (가벼움)
    SELECT 
        o.customer_id,
        SUM(oi.line_total) AS total_spend,
        NTILE(100) OVER (ORDER BY SUM(oi.line_total) DESC) AS tile
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_ts >= CURRENT_DATE - INTERVAL '60 days' -- 60일 지난 확정 매출
    GROUP BY o.customer_id
)
SELECT 
    c.full_name,
    v.total_spend
FROM vip_ranks v
JOIN customers c ON v.customer_id = c.customer_id -- 2. [지연 조인] VIP 30명만 조인
WHERE v.tile = 1;

-- 1. 장기 우수 고객 MV 생성
CREATE MATERIALIZED VIEW mv_top_vips AS
SELECT 
    o.customer_id,
    SUM(oi.line_total) AS total_spend,
    NTILE(100) OVER (ORDER BY SUM(oi.line_total) DESC) AS tile
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_ts <= CURRENT_DATE - INTERVAL '60 days'
GROUP BY o.customer_id;

-- 2. 조회를 위한 인덱스
CREATE INDEX idx_mv_vips_tile ON mv_top_vips(tile);

EXPLAIN ANALYZE
SELECT 
    c.full_name,
    v.total_spend
FROM mv_top_vips v
JOIN customers c ON v.customer_id = c.customer_id
WHERE v.tile = 1; -- 인덱스로 0.1ms 만에 추출

--------------------------------------------------------------
-- Q11) 0으로 나누어도 에러 안 나는 나눗셈 함수 써보기 → 안전하게 평균 계산하기 (0으로 나누기 방지)
EXPLAIN ANALYZE
select
	trunc(sum(oi.line_total)/nullif(count(distinct o.order_id),0)) as 평균_금액
from orders o
	join order_items oi on o.order_id = oi.order_id;

CREATE MATERIALIZED VIEW mv_grand_total AS
SELECT SUM(line_total) AS total_revenue
FROM order_items;

-- 조회
EXPLAIN ANALYZE
SELECT total_revenue FROM mv_grand_total; 
-- (결과: 0.01ms, 단 REFRESH 전까지 값 고정)









