-- Мобильная игра: диагностика продуктовых метрик
-- Илья Гуляев

-- 1. Напишите SQL-запрос для получения датасета. Столбцы назовите так же, как в ожидаемом результате.
WITH first_month as (SELECT
   device_id,
   MIN(DATE_TRUNC('month', time))::date AS first_activity_month
FROM mines.events
WHERE
   event_name = 'app_start'
GROUP BY device_id
),

all_month as (SELECT
   device_id,
   country_code,
   platform,
   traffic_type,
   DATE_TRUNC('month', time)::date AS all_activity_month
FROM mines.users
LEFT JOIN mines.events USING(device_id)
WHERE
   event_name = 'app_start'
GROUP BY 1, 2, 3, 4, 5
)
SELECT   first_month.device_id,
         first_activity_month,
         all_activity_month,
         platform,
         country_code,
         traffic_type
FROM first_month
LEFT JOIN all_month ON first_month.device_id = all_month.device_id
ORDER BY 1, 3
