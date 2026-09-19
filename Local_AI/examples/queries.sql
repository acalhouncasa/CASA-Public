-- Synthetic demo queries. Not PHI.

SELECT site_code, SUM(encounters) AS encounters
FROM monthly_encounters
GROUP BY site_code
ORDER BY encounters DESC;

SELECT month, SUM(encounters) AS encounters, SUM(no_shows) AS no_shows
FROM monthly_encounters
GROUP BY month
ORDER BY month;

SELECT site_code, month,
       ROUND(100.0 * no_shows / encounters, 1) AS no_show_pct
FROM monthly_encounters
WHERE encounters > 0
ORDER BY no_show_pct DESC;
