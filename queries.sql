Select * from plays;

-- Query to select win probability for every play, sorted by week
-- For Bills' plays (posteam = 'BUF'), use wp; for opponents, use def_wp (Bills' win prob from defensive view)
SELECT
    game_id,
    play_id,
    week,
    posteam,
    CASE
        WHEN posteam = 'BUF' THEN wp
        ELSE def_wp
    END AS bills_win_probability
FROM plays
ORDER BY week, CAST(play_id AS REAL);

-- Query to calculate game excitement score based on closeness to 50% and win probability swings
-- Excitement = 60% weight on closeness to 50%, 40% on total swings
WITH play_wp AS (
    SELECT
        game_id,
        week,
        home_team,
        away_team,
        game_date,
        play_id,
        CASE
            WHEN posteam = 'BUF' THEN wp
            ELSE def_wp
        END AS bills_wp
    FROM plays
),
wp_with_lag AS (
    SELECT
        game_id,
        week,
        home_team,
        away_team,
        bills_wp,
        LAG(bills_wp) OVER (PARTITION BY game_id ORDER BY game_date, CAST(play_id AS REAL)) AS prev_wp
    FROM play_wp
),
game_stats AS (
    SELECT
        game_id,
        week,
        home_team,
        away_team,
        COUNT(*) AS num_plays,
        AVG(ABS(bills_wp - 0.5)) AS avg_dev_from_50,
        SUM(ABS(bills_wp - COALESCE(prev_wp, bills_wp))) AS total_swing
    FROM wp_with_lag
    GROUP BY game_id, week, home_team, away_team
)
SELECT
    game_id,
    week,
    home_team,
    away_team,
    ROUND(
        (1 - (avg_dev_from_50 / 0.5)) * 60 + 
        MIN(1, (total_swing / (num_plays - 1)) * 10) * 40
    , 1) AS excitement_grade
FROM game_stats
ORDER BY week, game_id;

