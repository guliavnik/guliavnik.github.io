-- Яндекс Книги: метрики и проверка гипотезы
-- Илья Гуляев

-- 1. Расчёт MAU авторов
SELECT 
    main_author_name,
    COUNT(DISTINCT puid) AS MAU 
FROM bookmate.audition
LEFT JOIN bookmate.content USING(main_content_id)
LEFT JOIN bookmate.author USING(main_author_id)
WHERE DATE_TRUNC('month', msk_business_dt_str::DATE) = '2024-11-01'
GROUP BY main_author_name
ORDER BY MAU DESC
limit 3

-- 2. Расчёт MAU произведений
SELECT 
    main_content_name,
    published_topic_title_list,
    main_author_name,
    COUNT(DISTINCT puid) AS MAU 
FROM bookmate.audition
LEFT JOIN bookmate.content USING(main_content_id)
LEFT JOIN bookmate.author USING(main_author_id)
WHERE DATE_TRUNC('month', msk_business_dt_str::DATE) = '2024-11-01'
GROUP BY main_content_name, published_topic_title_list, main_author_name
ORDER BY MAU DESC
limit 3

-- 3. Расчёт Retention Rate
   WITH active_users AS (
    -- Шаг 1: Выделяем когорту пользователей, активных 2 декабря
    SELECT DISTINCT 
        puid
    FROM bookmate.audition
    WHERE msk_business_dt_str::DATE = '2024-12-02'
),

daily_retention AS (
    -- Шаг 2: Смотрим активность этих же пользователей в последующие дни
    SELECT 
        (p.msk_business_dt_str::DATE - '2024-12-02'::DATE) AS day_since_install,
        COUNT(DISTINCT p.puid) AS retained_users
    FROM bookmate.audition AS p
    -- INNER JOIN оставит только тех, кто входит в нашу когорту от 2 декабря
    INNER JOIN active_users AS a ON p.puid = a.puid
    WHERE p.msk_business_dt_str::DATE >= '2024-12-02'
    GROUP BY 1
)

-- Шаг 3: Финальный расчет Retention Rate с оконной функцией
SELECT 
    day_since_install,
    retained_users,
    ROUND(
        1.0 * retained_users / MAX(retained_users) OVER (), 
        2
    ) AS retention_rate
FROM daily_retention
ORDER BY day_since_install ASC;

-- 4. Расчёт LTV
WITH user_monthly_activity AS (
    -- Шаг 1: Определяем уникальные месяцы активности для каждого пользователя
    SELECT 
        puid,
        usage_geo_id_name AS city,
        DATE_TRUNC('month', msk_business_dt_str::DATE) AS activity_month
    FROM bookmate.audition
    LEFT JOIN bookmate.geo  USING(usage_geo_id)
    -- Ограничиваем выборку нужными городами
    WHERE usage_geo_id_name IN ('Москва', 'Санкт-Петербург')
    GROUP BY 1, 2, 3
),

user_revenue AS (
    -- Шаг 2: Считаем общий доход по каждому пользователю
    -- (количество активных месяцев * 399 руб)
    SELECT 
        puid,
        city,
        COUNT(activity_month) * 399 AS total_user_income
    FROM user_monthly_activity
    GROUP BY 1, 2
)

-- Шаг 3: Финальный расчет среднего LTV по городам
SELECT 
    city,
    COUNT(puid) AS total_users,
    ROUND(SUM(total_user_income) * 1.0 / COUNT(puid), 2) AS ltv
FROM user_revenue
GROUP BY city;

-- 5. Расчёт средней выручки прослушанного часа — аналог среднего чека
SELECT 
    DATE_TRUNC('month', msk_business_dt_str::DATE)::DATE AS month,
    COUNT(DISTINCT puid) AS mau,
    ROUND(SUM(hours), 2) AS hours,
    ROUND((COUNT(DISTINCT puid) * 399.0) / SUM(hours), 2) AS avg_hour_rev
FROM bookmate.audition
WHERE msk_business_dt_str::DATE BETWEEN '2024-09-01' AND '2024-11-30'
GROUP BY 1
ORDER BY 1;

-- 6. Для начала с помощью SQL приведите исходные данные из таблиц к такому виду, который будет пригодным для проверки гипотезы в Python. Отберите пользователей только из Москвы и Санкт-Петербурга и выведите их активность, то есть сумму часов.
SELECT usage_geo_id_name AS city,
puid,
SUM(hours) AS hours
FROM bookmate.audition
LEFT JOIN bookmate.geo USING(usage_geo_id)
WHERE usage_geo_id_name = 'Москва' or usage_geo_id_name = 'Санкт-Петербург'
GROUP BY 1, 2

