-- Доставка еды: расчёт бизнес-метрик
-- Илья Гуляев

-- 1. **Задача 1. Расчёт DAU**
SELECT
    log_date,
    COUNT(DISTINCT user_id) AS DAU
FROM analytics_events
JOIN cities USING (city_id)
WHERE log_date <= '2021-06-30' AND log_date >= '2021-05-01' AND event = 'order' AND city_name = 'Саранск'
GROUP BY log_date
ORDER BY log_date
limit 10

-- 2. **Задача 2. Расчёт Conversion Rate**
SELECT DISTINCT log_date,
                ROUND((COUNT(DISTINCT user_id) filter (WHERE event = 'order'))/COUNT(DISTINCT user_id)::numeric,2) AS CR
FROM analytics_events
JOIN cities USING (city_id)
WHERE log_date <= '2021-06-30' AND log_date >= '2021-05-01' AND city_name = 'Саранск'
GROUP BY log_date
ORDER BY log_date
limit 10
    

-- 3. **Задача 3. Расчёт среднего чека**
WITH orders AS
    (SELECT *,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE event = 'order' -- Важно оставить только заказы
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')

SELECT 
    DATE_TRUNC('month', log_date)::date AS "Месяц",
    COUNT(distinct order_id) AS "Количество заказов", -- Считаем количество транзакций
    ROUND(SUM(commission_revenue)::numeric, 2) AS "Сумма комиссии",
    ROUND((SUM(commission_revenue) / COUNT(distinct order_id))::numeric, 2) AS "Средний чек"
FROM orders
GROUP BY 1 -- Группировка по первому столбцу (Месяцу)
ORDER BY 1 -- Сортировка по номеру месяца

-- 4. **Задача 4. Расчёт LTV ресторанов**
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')

SELECT 
    rest_id,
    chain AS "Название сети",
    type AS "Тип кухни",
    ROUND(SUM (commission_revenue::numeric),2) AS LTV
FROM orders
JOIN partners USING (rest_id, city_id)
GROUP BY 1, 2, 3
ORDER BY LTV DESC
LIMIT 3

-- 5. **Задача 5. Расчёт LTV ресторанов — самые популярные блюда**
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            analytics_events.object_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'), 

-- Рассчитываем два ресторана с наибольшим LTV 
top_ltv_restaurants AS
    (SELECT orders.rest_id,
            chain,
            type,
            ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
     FROM orders
     JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id
     GROUP BY 1, 2, 3
     ORDER BY LTV DESC
     LIMIT 2)

SELECT
    chain AS "Название сети",
    name AS "Название блюда",
    spicy,
    fish,
    meat,
    ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
FROM top_ltv_restaurants
LEFT JOIN orders USING (rest_id)
LEFT JOIN dishes ON orders.object_id = dishes.object_id
GROUP BY 1, 2, 3, 4, 5
ORDER BY 6 DESC
LIMIT 5

-- 6. **Задача 6. Расчёт Retention Rate**
-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),

-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events 
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),

daily_retention AS (
SELECT n.user_id,
       first_date,
       log_date::date - first_date::date AS day_since_install
FROM new_users n
JOIN active_users a
on n.user_id = a.user_id
WHERE log_date >= first_date)

SELECT
day_since_install,
COUNT(DISTINCT user_id) AS retained_users,
    -- Вместо MAX(COUNT(...)) используем подзапрос для получения общего кол-ва новых юзеров
    ROUND(
        COUNT(DISTINCT user_id)::numeric / 
        (SELECT COUNT(DISTINCT user_id) FROM new_users), 
    2) AS retention_rate 
FROM daily_retention
WHERE day_since_install <= 7
GROUP BY day_since_install
ORDER BY day_since_install


-- 7. **Задача 7. Сравнение Retention Rate по месяцам**
-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),

-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),

-- Соединяем таблицы с новыми и активными пользователями
daily_retention AS
    (SELECT new_users.user_id,
            first_date,
            log_date::date - first_date::date AS day_since_install
     FROM new_users
     JOIN active_users ON new_users.user_id = active_users.user_id
     AND log_date >= first_date)

SELECT
    DATE_TRUNC('month', first_date)::date AS "Месяц",
    day_since_install,
    COUNT(DISTINCT user_id) AS retained_users,
ROUND(
        1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY DATE_TRUNC('month', first_date)::date), 
    2) AS retention_rate
FROM daily_retention
WHERE day_since_install <= 7
GROUP BY Месяц, day_since_install
ORDER BY Месяц, day_since_install
