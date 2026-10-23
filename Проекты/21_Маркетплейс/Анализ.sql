-- Маркетплейс: продуктовые метрики и A/B-тест
-- Илья Гуляев

-- 1. Задание 1. Сбор данных о пользователях
SELECT
    user_id,
    registration_date,
    user_params ->> 'age' AS age,
    user_params ->> 'gender' AS gender,
    user_params ->> 'region' AS region,
    user_params ->> 'acq_channel' AS acq_channel,
    user_params ->> 'buyer_segment' AS buyer_segment,
    DATE_TRUNC('week', registration_date)::date AS cohort_week,
    DATE_TRUNC('month', registration_date)::date AS cohort_month
FROM pa_graduate.users
WHERE registration_date >= '2024-01-01'
  AND registration_date < '2025-01-01'
ORDER BY registration_date
LIMIT 100;

-- 2. Задание 2\. Сбор данных о событиях
SELECT
    e.event_id,
    e.user_id,
    e.timestamp AS event_date,
    e.event_type,
    e.event_params ->> 'os' AS os,
    e.event_params ->> 'device' AS device,
    p.product_name,
    DATE_TRUNC('week', e.timestamp)::date AS event_week,
    DATE_TRUNC('month', e.timestamp)::date AS event_month
FROM pa_graduate.events AS e
LEFT JOIN pa_graduate.product_dict AS p
    ON e.product_id = p.product_id
WHERE e.timestamp >= TIMESTAMP '2024-01-01 00:00:00'
  AND e.timestamp < TIMESTAMP '2025-01-01 00:00:00'
ORDER BY e.timestamp
LIMIT 100;

-- 3. Задание 3\. Сбор данных о заказах
SELECT
    o.order_id,
    o.user_id,
    o.order_date,
    p.product_name,
    o.quantity,
    o.unit_price,
    o.total_price,
    p.category_name,
    DATE_TRUNC('week', o.order_date)::date AS order_week,
    DATE_TRUNC('month', o.order_date)::date AS order_month
FROM pa_graduate.orders AS o
JOIN pa_graduate.product_dict AS p
    ON o.product_id = p.product_id
WHERE o.order_date >= TIMESTAMP '2024-01-01 00:00:00'
  AND o.order_date < TIMESTAMP '2025-01-01 00:00:00'
ORDER BY o.order_date
LIMIT 100;
