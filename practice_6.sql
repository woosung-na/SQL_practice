-- 1-1 금액(amount)의 10%를 세금으로 계산하는 간단 함수
create or replace function fn_vat(amount numeric)
returns numeric
language plpgsql
as $$
begin
	return amount * 0.1;
end;
$$;

select name, price, fn_vat(price)
from product
limit 5;
------------------------------------------------------------
-- 1-2 고객 등급별 할인율 반환 함수
create or replace function fn_vat_grade(grade text)
returns numeric
language plpgsql
as $$
begin
	return case
		when grade = 'VIP' then 0.07
		when grade = 'GOLD' then 0.03
		else 0.00
	end;
end;
$$;

select name, 'VIP' 등급, fn_vat_grade('VIP')
from customer
limit 5;
------------------------------------------------------------
-- 1-3 JSON 매개변수 기반 주문 생성 프로시저
create or replace procedure sp_create_order(
	p_customer_id int,
	p_item jsonb
	)
language plpgsql
as $$
declare
	v_order_id int;
	v_item jsonb;
	v_product_id int;
	v_qty int;
	v_current_price numeric;
	v_current_stock int;
	v_subtotal numeric := 0;
begin
	-- 주문 헤더 order 테이블에 생성
	insert into orders (customer_id, total_amount)
	values (p_customer_id, 0)
	returning order_id into v_order_id;
	
	-- json 배열 순회 + 아이템 등록
	for v_item in select * from jsonb_array_elements(p_item)
	loop
		v_product_id := (v_item->>'p_id')::int;
		v_qty := (v_item->>'qty')::int;
	
		-- 현재 가격, 재고 확인
		select price, stock_qty into v_current_price, v_current_stock
		from product
		where product_id = v_product_id
		for update;
		
		-- 예외 발생 로직
		if v_current_stock < v_qty then
			raise exception '재고 부족: 상풍ID %, 현재고 %, 요청량 %', 
							v_product_id, v_current_stock, v_qty;
		end if;
		
		-- 재고 차감
		update product
		set stock_qty = stock_qty - v_qty, updated_at = now()
		where product_id = v_product_id;
		
		-- 주문 상세 등록
		insert into order_item (order_id, product_id, qty, unit_price, line_total)
		values (v_order_id, v_product_id, v_qty, v_current_price, v_qty * v_current_price);
		
		v_subtotal := v_subtotal + (v_qty * v_current_price);
	end loop;
	
	raise notice '주문 성공: 주문 번호 %', v_order_id;
	
exception
	when others then
		-- 에러 발생 시 rollback
		raise notice '주문 실패: 트랜잭션 롤백 / 에러: %', sqlerrm;
		rollback;
		raise; 
end;
$$;

-- 상품 1번과 2번을 각각 2개, 1개씩 주문
CALL sp_create_order(1, '[{"p_id": 1, "qty": 2}, {"p_id": 2, "qty": 1}]'::jsonb);
-- 결과 확인
SELECT * FROM orders ORDER BY order_id DESC LIMIT 1;
SELECT * FROM order_item WHERE order_id = (SELECT max(order_id) FROM mini.orders);
-- 재고보다 큰 수량 요청
CALL sp_create_order(1, '[{"p_id": 3, "qty": 9999}]'::jsonb);

------------------------------------------------------------
-- 2-1 가격 변경 감지 트리거 함수
create or replace function fn_trg_product_price_scd()
returns trigger
language plpgsql
as $$
begin
	-- 카테고리 변경 시 4-3 내용 추가
	if (old.category <> new.category) then
		new.prev_category = old.category;
	end if;
	-- 가격 변경 시
	if (old.price <> new.price) then
		-- Type 2 구성. 이전 버전 종료, 유효 시점 정의
		update product_price_scd
		set is_current = false, valid_to = now()
		where product_id = old.product_id
		and is_current = true;

		-- 새로운 가격 추가 
		insert into product_price_scd (product_id, price, valid_from)
		values (new.product_id, new.price, now());
	end if;
		
	return new;
end;
$$;

-- 2-2 product 테이블에 트리거 연결
create trigger trg_after_product_price_update
after update of price on product
for each row
execute function fn_trg_product_price_scd();

-- 2-3 가격 수정 테스트 및 이력 적재 확인
update product
set price = 30.00
where product_id = 1; 

select *
from product_price_scd
where product_id = 1
order by valid_from desc;
-- 3-1 READ COMMITTED: 비반복 읽기(Non-repeatable read) 확인
-- session A
begin;
set transaction isolation level read committed;
select price 
from product
where product_id = 1;
-- 3-2 REPEATABLE READ: 팬텀 리드(Phantom Read) 발생 여부 확인
commit;
begin;
set transaction isolation level REPEATABLE READ;
select count(*)
from customer;
commit;
-- 4-1 Type 1: 카테고리 단순 업데이트 및 데이터 유실 확인
select product_id, category
from product
where product_id = 1;

update product
set category = 'home'
where product_id = 1;
-- 4-2 Type 2: 특정 시점(As-of) 기준 가격 조회 쿼리 작성
select product_id, price, valid_from, valid_to
from product_price_scd
where product_id = 1;
-- 4-3 Type 3: prev_category 활용 직전 데이터 보존 확인
create trigger trg_before_product_category_update
before update of category on product
for each row
execute function fn_trg_product_price_scd();

update product
set category = 'home'
where product_id = 1;

select product_id, category, prev_category
from product
where product_id = 1;
