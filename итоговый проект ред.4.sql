/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 *
 * Автор:Столбова Анастасия
 * Дата:14.02.2026
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),

-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
pre_count as (
SELECT 
CASE 
    WHEN c.city_id IN (
            SELECT city_id FROM real_estate.city WHERE city = 'Санкт-Петербург'
        ) THEN 'Санкт-Петербург'
    ELSE 'ЛенОбл'
END AS category,
CASE 
	WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
	WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'до трех месяцев'
	WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
	WHEN a.days_exposition > 180 THEN 'более полугода'
	WHEN a.days_exposition IS NULL OR a.days_exposition = 0 THEN 'non category'
	ELSE 'non category'
END AS exposition_category,
a.last_price::numeric/total_area::numeric AS rub_per_meter,
total_area::numeric AS area,
f.rooms,
f.balcony,
f.floor,
a.id
FROM real_estate.advertisement AS a
JOIN real_estate.flats AS f ON a.id=f.id
JOIN real_estate.city AS c ON f.city_id = c.city_id
JOIN real_estate.type AS t ON f.type_id = t.type_id
WHERE f.id IN (SELECT id FROM filtered_id)
AND t.type = 'город' -- добавила фильтрацю по городам
AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
)

SELECT category,
pc.exposition_category,
COUNT(pc.id) AS total_adv,
ROUND (avg(rub_per_meter),2) AS price_per_meter,
ROUND(AVG (area::numeric),2) AS avg_area,
PERCENTILE_CONT (0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
PERCENTILE_CONT (0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
PERCENTILE_CONT (0.5) WITHIN GROUP (ORDER BY floor) AS median_floor
FROM pre_count AS pc
GROUP BY category, exposition_category
ORDER BY category, exposition_category, total_adv DESC;


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
months_data AS (
    SELECT
        EXTRACT(MONTH FROM a.first_day_exposition) AS publication_month,
        EXTRACT(MONTH FROM a.first_day_exposition + ROUND(a.days_exposition)::INT * INTERVAL '1 day') AS removal_month,
        a.last_price,
        f.total_area,
        c.city
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    JOIN real_estate.city AS c ON f.city_id = c.city_id
    JOIN real_estate.type AS t ON f.type_id = t.type_id
    JOIN filtered_id AS fl ON a.id = fl.id
    WHERE EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
    AND t.type = 'город'), -- добавила фильтрацю по городам

publication_stats AS (
    SELECT 
        publication_month,
        'publication' AS period_type,
        COUNT(*) AS ads_count,
        ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS avg_price_per_sqm,
        ROUND(AVG(total_area::numeric), 2) AS avg_total_area
    FROM months_data
    WHERE publication_month BETWEEN 1 AND 12
    GROUP BY publication_month),

removal_stats AS (
    SELECT 
        removal_month,
        'removal' AS period_type,
        COUNT(*) AS ads_count,
        ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS avg_price_per_sqm,
        ROUND(AVG(total_area::numeric), 2) AS avg_total_area
    FROM months_data
    WHERE removal_month BETWEEN 1 AND 12
    GROUP BY removal_month)
SELECT 
    publication_month,
    period_type,
    ads_count,
    avg_price_per_sqm,
    avg_total_area
FROM publication_stats
UNION ALL
SELECT 
    removal_month,
    period_type,
    ads_count,
    avg_price_per_sqm,
    avg_total_area
FROM removal_stats
ORDER BY period_type, publication_month;