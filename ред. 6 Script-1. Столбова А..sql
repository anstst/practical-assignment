-- Автор: Столбова Анастасия
-- Дата: 22/01/26

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT (id) AS total_users,
SUM (payer) AS paying_users,
ROUND(AVG (payer),4) AS share_users
from fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT race,
SUM (payer) AS paying_race_count,
COUNT (*) AS total_race_count,
ROUND (AVG (payer),4) AS share_per_race
FROM fantasy.users
JOIN fantasy.race ON users.race_id=race.race_id
GROUP BY race, race.race_id
ORDER BY share_per_race DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT (amount) AS total_purchases,
SUM (amount) AS total_sum,
MIN (amount) AS min_purchase,
MAX (amount) AS max_purchase,
ROUND (AVG (amount)) AS avg_purchase,
ROUND (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)) AS median_amount,
ROUND (STDDEV (amount)) AS stand_dev
FROM fantasy.events
WHERE amount > 0;

-- 2.2: Аномальные нулевые покупки:
SELECT 
	COUNT (CASE WHEN amount = 0 THEN 1 END) AS zero_purchase_count,
	COUNT (amount) AS total_purchases,
	ROUND (COUNT (CASE WHEN amount = 0 THEN 1 END)*100.0/ COUNT (amount), 2) AS share_zero_purchase
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
	SELECT 
    game_items,
    COUNT(*) AS total_sales,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fantasy.events WHERE amount > 0), 2) AS sales_share,
    ROUND(COUNT(DISTINCT e.id) * 100.0 /(SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0),2) AS buyers_share
FROM fantasy.events AS  e
JOIN fantasy.items AS i ON e.item_code = i.item_code
WHERE e.amount > 0
GROUP BY game_items
ORDER BY buyers_share DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH all_players AS (
    SELECT 
    u.race_id,
    r.race,
    COUNT(u.id) AS total_players
    FROM fantasy.users AS u
    INNER JOIN fantasy.race AS r USING(race_id)
    GROUP BY u.race_id, r.race
),
purchase_stats AS (
    SELECT 
    u.race_id,
    r.race,
    COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) AS paying_players, -- количество платящих игроков
    COUNT(DISTINCT u.id) AS players_with_purchases, -- количество игроков совершивших покупки
    COUNT(*) AS total_purchases, -- общее количество покупок
    SUM(e.amount) AS total_spent -- общая сумма покупок
    FROM fantasy.events AS e
    INNER JOIN fantasy.users AS u USING(id)
    INNER JOIN fantasy.race AS  r USING(race_id)
    WHERE e.amount > 0
    GROUP BY u.race_id, r.race
)
SELECT
	ap.race_id,
    ap.race,
    ap.total_players, -- общее количество зарегистрированных игроков
    ps.players_with_purchases, -- кол-во игроков которые совершают внутриигровые покупки
    ROUND ((ps.players_with_purchases*100.0/ap.total_players):: NUMERIC,2) AS payers_share, -- доля игроков которые совершают покупки от общего кол-ва зарег. игроков
    ROUND((ps.paying_players * 100.0 / ps.players_with_purchases)::NUMERIC, 2) AS players_with_purchases_percent, -- доля платящих игроков среди игроков, которые совершили покупки
    ROUND((ps.total_purchases::NUMERIC / ps.players_with_purchases), 2) AS avg_purchases_per_player, -- среднее кол-во покупок на одного игрока с покупками
    ROUND((ps.total_spent::NUMERIC / ps.total_purchases), 2) AS avg_amount_per_purchase, -- средняя стоимость одной покупки на одного игрока, совершившего внутриигровые покупки
    ROUND((ps.total_spent::NUMERIC / ps.players_with_purchases), 2) AS avg_amount_per_player -- средняя сумма покупок на одного игрока с покупками
FROM all_players AS ap
LEFT JOIN purchase_stats AS ps USING(race_id, race)
ORDER BY avg_amount_per_player DESC;







