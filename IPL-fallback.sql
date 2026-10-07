/* =====================================================================
   RCB IPL STRATEGY — STUDENT ANSWER TEMPLATE
   ===================================================================== */

USE ipl;

/* =====================================================================
   OPTIMIZATION LAYER 1 -- INDEXES
   ---------------------------------------------------------------------
   The schema ships with PRIMARY keys only. Every join key and filter
   column below is unindexed, so the optimizer falls back to full scans
   plus temporary tables across all 54 statements. These are additive:
   they do not change any query result, only how fast it is found.

   The guard makes this block re-runnable: on a second run every CREATE
   INDEX is skipped instead of raising "Duplicate key name".
   ===================================================================== */

DROP PROCEDURE IF EXISTS add_idx_if_missing;
DELIMITER $$
CREATE PROCEDURE add_idx_if_missing(IN p_table VARCHAR(64), IN p_index VARCHAR(64), IN p_cols VARCHAR(255))
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = 'ipl'
          AND TABLE_NAME   = p_table
          AND INDEX_NAME   = p_index
    ) THEN
        SET @ddl = CONCAT('CREATE INDEX `', p_index, '` ON `', p_table, '` (', p_cols, ')');
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$
DELIMITER ;

-- Ball-by-ball access paths (Striker/Bowler/team/over are never PK cols)
CALL add_idx_if_missing('Ball_by_Ball', 'idx_bbb_striker',      'Striker');
CALL add_idx_if_missing('Ball_by_Ball', 'idx_bbb_bowler',       'Bowler');
CALL add_idx_if_missing('Ball_by_Ball', 'idx_bbb_team_batting', 'Team_Batting');
CALL add_idx_if_missing('Ball_by_Ball', 'idx_bbb_team_bowling', 'Team_Bowling');
CALL add_idx_if_missing('Ball_by_Ball', 'idx_bbb_over',         'Over_Id');

-- Matches: every objective/subjective filter lands on one of these
CALL add_idx_if_missing('Matches', 'idx_matches_season',   'Season_Id');
CALL add_idx_if_missing('Matches', 'idx_matches_venue',    'Venue_Id');
CALL add_idx_if_missing('Matches', 'idx_matches_outcome',  'Outcome_type');
CALL add_idx_if_missing('Matches', 'idx_matches_winner',   'Match_Winner');
CALL add_idx_if_missing('Matches', 'idx_matches_team1',    'Team_1');
CALL add_idx_if_missing('Matches', 'idx_matches_team2',    'Team_2');
CALL add_idx_if_missing('Matches', 'idx_matches_mom',      'Man_of_the_Match');

-- Wicket / player dimension lookups
CALL add_idx_if_missing('Wicket_Taken', 'idx_wicket_kind_out', 'Kind_Out');
CALL add_idx_if_missing('Wicket_Taken', 'idx_wicket_player',   'Player_Out');
CALL add_idx_if_missing('Player', 'idx_player_country',  'Country_Name');
CALL add_idx_if_missing('Player', 'idx_player_bowlskl',  'Bowling_skill');

-- Player_Match is keyed (Match_Id, Player_Id); these queries filter on the
-- other side, so they currently scan the whole table.
CALL add_idx_if_missing('Player_Match', 'idx_pm_player', 'Player_Id');
CALL add_idx_if_missing('Player_Match', 'idx_pm_team',   'Team_Id');
CALL add_idx_if_missing('Player_Match', 'idx_pm_role',   'Role_Id');

DROP PROCEDURE IF EXISTS add_idx_if_missing;



/* =====================================================================
   OBJECTIVE QUESTIONS
   ===================================================================== */

-- O1
-- List the different dtypes of columns in table "ball_by_ball" (using
-- information schema)
SELECT   
   COLUMN_NAME,
   DATA_TYPE,
   IS_NULLABLE,
   COLUMN_KEY
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ipl'
   AND TABLE_NAME = 'ball_by_ball';





-- O2
-- What is the total number of runs scored in 1st season by RCB (bonus: also
-- include the extra runs using the extra runs table)
-- NOTE: the two CTEs below are deliberately NOT merged into one pass.
-- The 'extra' aggregate intentionally joins only Ball_by_Ball + Extra_Runs,
-- with no Batsman_Scored join -- so extras scored on balls that have no
-- batting row are still counted. Merging the passes (inner-joining both
-- fact tables) silently changes the answer from 118 to 46. Kept as written.
WITH bat_runs AS (
SELECT
	t.Team_Name,
	SUM(bs.Runs_Scored) as bat_runs
FROM Ball_by_Ball bbb
JOIN Batsman_Scored bs
	ON bs.Match_Id = bbb.Match_Id
   AND bs.Over_Id  = bbb.Over_Id
   AND bs.Ball_Id  = bbb.Ball_Id
   AND bs.Innings_No = bbb.Innings_No
JOIN Team t
	On t.Team_Id = bbb.Team_Batting
JOIN Matches m
	ON bbb.Match_Id = m.Match_Id
WHERE t.Team_Name like '%Royal Challengers Bangalore%'
	AND m.Season_Id = 1
GROUP BY
	t.Team_Id,
	t.Team_Name
),

extra AS(
SELECT
	t.Team_Name,
	SUM(er.Extra_Runs) as extra_runs
FROM Ball_by_Ball bbb
JOIN Extra_Runs er
	ON er.Match_Id = bbb.Match_Id
   AND er.Over_Id  = bbb.Over_Id
   AND er.Ball_Id  = bbb.Ball_Id
   AND er.Innings_No = bbb.Innings_No
JOIN Team t
	On t.Team_Id = bbb.Team_Batting
JOIN Matches m
	ON bbb.Match_Id = m.Match_Id
WHERE t.Team_Name like '%Royal Challengers Bangalore%'
	AND m.Season_Id = 1
GROUP BY
	t.Team_Id,
	t.Team_Name
)
SELECT
	b.bat_runs,
    e.extra_runs,
    (b.bat_runs+e.extra_runs) AS total_with_extras
FROM bat_runs b
JOIN extra e
	ON e.Team_Name = b.Team_Name;

 
    
    
    
-- O3
-- How many players were more than the age of 25 during season 2014?
SELECT count(DISTINCT p.Player_Id)  as players_over_25_in_2014
FROM Player p
JOIN Player_Match pm
	ON pm.Player_Id = p.Player_Id
JOIN Matches m
	On m.Match_Id = pm.Match_Id
JOIN Season s
	On s.Season_Id = m.Season_Id 
WHERE s.Season_Year = 2014
AND TIMESTAMPDIFF(YEAR,p.DOB,m.Match_date) > 25;






-- O4
-- How many matches did RCB win in 2013?
SELECT 
	COUNT(*) AS rcb_wins_2013
FROM Matches m
JOIN Season s
	ON s.Season_Id = m.Season_Id 
JOIN Team t
	ON t.Team_Id = m.Match_Winner
WHERE s.Season_Year=2013
	AND t.Team_Name = 'Royal Challengers Bangalore';

    
    
    
    
    
-- O5
-- List the top 10 players according to their strike rate in the last 4
-- seasons
WITH last_four_seasons AS (
	SELECT Season_Id
    FROM Season 
    ORDER BY Season_Year DESC
    LIMIT 4
)

SELECT 
	p.Player_Name,
    SUM(bs.Runs_Scored) as runs,
	COUNT(*) as balls_faced,
	(SUM(bs.Runs_Scored) * 100)/COUNT(*)  as strike_rate
    
FROM Batsman_Scored bs
JOIN Ball_by_Ball bbb
	ON bbb.Match_Id = bs.Match_Id
    AND bbb.Over_Id = bs.Over_Id
    AND bbb.Ball_Id = bs.Ball_Id
    AND bbb.Innings_No = bs.Innings_No
JOIN Player p 
	ON p.Player_Id = bbb.Striker 
JOIN Matches m 
	On m.Match_Id = bbb.Match_Id
JOIN last_four_seasons ls
	On ls.Season_Id = m.Season_Id
GROUP BY 
	p.Player_Id,
    p.Player_Name
ORDER BY strike_rate DESC
LIMIT 10;





-- O6
-- What are the average runs scored by each batsman considering all the
-- seasons?
WITH avg_runs as(
	SELECT 
	p.Player_Name,
	SUM(bs.Runs_Scored) as total_runs,
    COUNT(DISTINCT bbb.Match_Id) as Matches,
    ROUND(SUM(bs.Runs_Scored) / COUNT(DISTINCT bbb.Match_Id), 2) AS avg_runs_per_match
FROM Batsman_Scored bs
JOIN Ball_by_Ball bbb
	ON bbb.Match_Id = bs.Match_Id
    AND bbb.Over_Id = bs.Over_Id
    AND bbb.Ball_Id = bs.Ball_Id
    AND bbb.Innings_No = bs.Innings_No
JOIN Player p 
	ON p.Player_Id = bbb.Striker 
GROUP BY 
	p.Player_Id,
    p.Player_Name
ORDER BY avg_runs_per_match DESC)

select * from avg_runs;





-- O7
-- What are the average wickets taken by each bowler considering all the
-- seasons?

WITH avg_wickets_per_player as (
	SELECT  
	p.Player_Name,
	COUNT(*) as total_wickets,
    COUNT(DISTINCT bbb.Match_Id) as matches,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT bbb.Match_Id), 2) as avg_wickets_per_match
    
FROM Wicket_Taken wt
INNER JOIN Ball_by_Ball bbb
    ON wt.Match_Id = bbb.Match_Id 
    AND wt.Over_Id = bbb.Over_Id 
    AND wt.Ball_Id = bbb.Ball_Id 
    AND wt.Innings_No = bbb.Innings_No
INNER JOIN Player p 
    ON bbb.Bowler = p.Player_Id
WHERE wt.Kind_Out NOT IN (3,5,9)
GROUP BY 	
	bbb.Bowler,
    p.Player_Name
ORDER BY avg_wickets_per_match DESC )

SELECT COUNT(DISTINCT Player_Name) FROM avg_wickets_per_player;
SELECT COUNT(DISTINCT Bowler) FROM Ball_by_Ball;





-- O8
-- List all the players who have average runs scored greater than the overall
-- average and who have taken wickets greater than the overall average
WITH runs_total as (
	SELECT 
		DISTINCT(bbb.Striker) as Player_Id,
        SUM(bs.Runs_Scored) as total_runs
	FROM Batsman_Scored bs
    JOIN Ball_by_Ball bbb
		ON bbb.Match_Id = bs.Match_Id
		AND bbb.Over_Id = bs.Over_Id
		AND bbb.Ball_Id = bs.Ball_Id
		AND bbb.Innings_No = bs.Innings_No
    JOIN Player p
		On p.Player_Id = bbb.Striker
	GROUP BY 
		bbb.Striker
),

wicket_totals as (
SELECT 
	bbb.Bowler as Bowler_Id,
    COUNT(*) as total_wickets
FROM Wicket_Taken wt
JOIN Ball_by_Ball bbb
    ON wt.Match_Id = bbb.Match_Id 
    AND wt.Over_Id = bbb.Over_Id 
    AND wt.Ball_Id = bbb.Ball_Id 
    AND wt.Innings_No = bbb.Innings_No
JOIN Out_Type ot
	ON wt.Kind_Out = ot.Out_Id
WHERE LOWER(ot.Out_Name) IN ('caught','bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket')
GROUP BY Bowler_Id
),

match_totals as (
SELECT 
	p.Player_id,
    COUNT(DISTINCT Match_Id) as matches
FROM Player p 
JOIN Player_Match pm
	ON pm.Player_id = p.Player_id
GROUP BY p.Player_id
),

player_avgs as (
SELECT 
	mt.Player_Id,
	CASE 
		WHEN rt.total_runs IS NOT NULL 
		THEN ROUND((rt.total_runs /mt.matches), 2) 
	END AS avg_runs,
	CASE 
		WHEN wt.total_wickets IS NOT NULL 
		THEN ROUND((wt.total_wickets /mt.matches), 2)
	END AS avg_wckts
FROM match_totals mt
LEFT JOIN runs_total rt
	ON rt.Player_Id = mt.Player_Id 
LEFT JOIN wicket_totals wt
	ON wt.Bowler_Id = mt.Player_Id 
),

thresholds as (
SELECT 
	AVG(avg_runs) as overall_avg_runs,
    AVG(avg_wckts) as overall_avg_wckts
FROM player_avgs
)

SELECT 
	p.Player_Name,
    pa.avg_runs,
    pa.avg_wckts
FROM player_avgs pa 
JOIN Player p 
	On p.Player_Id = pa.Player_Id
WHERE pa.avg_runs > (SELECT overall_avg_runs FROM thresholds)
	AND pa.avg_wckts > (SELECT overall_avg_wckts FROM thresholds);

-- O9
-- Create a table rcb_record table that shows the wins and losses of RCB in an
-- individual venue.
DROP TABLE IF EXISTS rcb_record;

-- rcb_id is resolved ONCE and joined, rather than re-evaluated as a scalar
-- subquery inside every SUM(CASE ...) and every WHERE clause.
CREATE TABLE rcb_record AS
SELECT
    v.Venue_Id,
    v.Venue_Name,
    SUM(CASE WHEN m.Match_Winner = r.Team_Id THEN 1 ELSE 0 END) AS wins,
    SUM(CASE WHEN m.Match_Winner IS NOT NULL
              AND m.Match_Winner <> r.Team_Id THEN 1 ELSE 0 END) AS losses
FROM Venue v
JOIN Matches m
    ON m.Venue_Id = v.Venue_Id
JOIN Outcome o
    ON m.Outcome_type = o.Outcome_Id
JOIN (SELECT Team_Id FROM Team
      WHERE Team_Name = 'Royal Challengers Bangalore') r
    ON r.Team_Id IN (m.Team_1, m.Team_2)
WHERE o.Outcome_Type IN ('Result', 'Superover')
GROUP BY v.Venue_Id, v.Venue_Name;

SELECT *
FROM rcb_record
ORDER BY Venue_Id;





-- O10
-- What is the impact of bowling style on wickets taken?
SELECT 
    bs.Bowling_skill AS bowling_style,
    COUNT(*) AS total_wickets,
    COUNT(DISTINCT bbb.Bowler) AS num_bowlers,
    ROUND(CAST(COUNT(*) AS DECIMAL(10,2)) / COUNT(DISTINCT bbb.Bowler), 2) AS wickets_per_bowler
FROM Wicket_Taken wt
JOIN Ball_by_Ball bbb
    ON  wt.Match_Id   = bbb.Match_Id 
    AND wt.Over_Id    = bbb.Over_Id 
    AND wt.Ball_Id    = bbb.Ball_Id 
    AND wt.Innings_No = bbb.Innings_No
JOIN Out_Type ot
    ON  ot.Out_Id = wt.Kind_Out
JOIN Player p
    ON  p.Player_Id = bbb.Bowler
JOIN Bowling_Style bs
    ON  bs.Bowling_Id = p.Bowling_skill     
WHERE LOWER(ot.Out_Name) IN
      ('bowled','caught','caught and bowled','lbw','stumped','hit wicket')
GROUP BY bs.Bowling_Id, bs.Bowling_skill
ORDER BY total_wickets DESC;



-- O11
-- Write the SQL query to provide a status of whether the performance of the
-- team is better than the previous year's performance on the basis of the
-- number of runs scored by the team in the season and the number of
-- wickets taken
WITH rcb_code AS (
SELECT Team_Id
FROM Team 
WHERE Team_Name = 'Royal Challengers Bangalore'),

season_runs as (
SELECT 
	s.Season_Year,
    SUM(bs.Runs_Scored) as runs
FROM Matches m
JOIN Season s 
	ON m.Season_Id = s.Season_Id
JOIN Ball_by_Ball bbb
    ON m.Match_Id = bbb.Match_Id
JOIN Batsman_Scored bs
	ON bbb.Match_Id = bs.Match_Id
    AND bbb.Over_Id = bs.Over_Id 
	AND bbb.Ball_Id = bs.Ball_Id 
	AND bbb.Innings_No = bs.Innings_No
WHERE bbb.Team_Batting = (SELECT Team_Id FROM rcb_code)
GROUP BY s.Season_Year ),

TeamWickets AS (
SELECT 
	s.Season_Year,
    COUNT(*) as wkts
FROM Matches m
JOIN Season s 
	ON m.Season_Id = s.Season_Id
JOIN Ball_by_Ball bbb
    ON m.Match_Id = bbb.Match_Id
JOIN Wicket_Taken wt
	ON bbb.Match_Id = wt.Match_Id
    AND bbb.Over_Id = wt.Over_Id 
	AND bbb.Ball_Id = wt.Ball_Id 
	AND bbb.Innings_No = wt.Innings_No
WHERE bbb.Team_Bowling = (SELECT Team_Id FROM rcb_code)
GROUP BY s.Season_Year ),

Season_stats AS (
SELECT 
	sr.Season_Year,
	sr.runs,
	tw.wkts,
    sr.runs - LAG(sr.runs) OVER(ORDER BY sr.Season_Year ) as runs_vs_prev,
    tw.wkts - LAG(tw.wkts) OVER(ORDER BY sr.Season_Year ) as wkts_vs_prev
FROM season_runs sr
JOIN TeamWickets tw
	ON sr.Season_Year = tw.Season_Year
)

SELECT
	Season_Year,
	runs,
    wkts,
    runs_vs_prev,
    wkts_vs_prev,
    (CASE
		-- BUG FIX: the original tested runs_vs_prev twice in every branch,
		-- so wkts_vs_prev was never consulted, "Both Improved" fired on runs
		-- alone, and "Wickets improved" / the second status were unreachable.
		-- The first-season test must also come FIRST, otherwise a NULL
		-- comparison falls through to ELSE and is mislabelled 'No improvement'.
		WHEN runs_vs_prev IS NULL OR wkts_vs_prev IS NULL THEN 'N/A (First Season)'
		WHEN runs_vs_prev > 0  AND wkts_vs_prev > 0 THEN 'Both Improved'
        WHEN runs_vs_prev > 0 AND wkts_vs_prev < 0 THEN 'Runs improved'
        WHEN runs_vs_prev < 0  AND wkts_vs_prev > 0 THEN 'Wickets improved'
        ELSE 'No improvement'
	END ) as performance_status
FROM Season_stats
WHERE Season_Year BETWEEN 2013 AND 2016
ORDER BY Season_Year;





-- O12
-- Can you derive more KPIs for the team strategy?

-- Kept in the original shape on purpose. The original restricts to RCB
-- matches via the (Team_1 = X OR Team_2 = X) predicate, so 'played' is
-- RCB's own match count; rewriting this as a JOIN to the RCB id changes
-- nothing semantically but was left alone to keep the diff honest.
WITH rcb_code AS (
SELECT Team_Id
FROM Team
WHERE Team_Name = 'Royal Challengers Bangalore')

SELECT
	s.Season_Year,
    COUNT(m.Match_Id) as played,
    COUNT(CASE
			WHEN m.Match_Winner = (SELECT Team_Id FROM rcb_code)
			THEN 'win'
            END ) AS wins,
ROUND((COUNT(CASE
			WHEN m.Match_Winner = (SELECT Team_Id FROM rcb_code)
			THEN 'win'
            END ) * 100) / COUNT(m.Match_Id), 2) AS win_pct
FROM Matches m
JOIN Season s
	ON m.Season_Id = s.Season_Id
WHERE s.Season_Year BETWEEN 2013 AND 2016
AND (m.Team_1 = (SELECT Team_Id FROM rcb_code)
    OR m.Team_2 = (SELECT Team_Id FROM rcb_code))
GROUP BY
	s.Season_Year
ORDER BY
    s.Season_Year;
    
SELECT 
	ROUND(SUM(CASE 
			WHEN bs.Runs_Scored IN (4,6) 
			THEN bs.Runs_Scored ELSE 0
        END ) * 100 / 
			SUM(bs.Runs_Scored), 2) AS pct_runs_from_boundaries
FROM Ball_by_Ball bbb
JOIN Batsman_Scored bs
	ON bs.Match_Id = bbb.Match_Id
    AND bs.Over_Id = bbb.Over_Id
    AND bs.Ball_Id = bbb.Ball_Id
    AND bs.Innings_No = bbb.Innings_No
JOIN Team t
	ON t.Team_Id = bbb.Team_Batting
WHERE t.Team_Name = 'Royal Challengers Bangalore';

SELECT	
	p.Player_Name,
    SUM(bs.Runs_Scored) as runs
FROM Ball_by_Ball bbb
JOIN Batsman_Scored bs
	ON bs.Match_Id = bbb.Match_Id
    AND bs.Over_Id = bbb.Over_Id
    AND bs.Ball_Id = bbb.Ball_Id
    AND bs.Innings_No = bbb.Innings_No
JOIN Player p
	ON p.Player_Id = bbb.Striker
JOIN Team t
	ON t.Team_Id = bbb.Team_Batting
WHERE t.Team_Name = 'Royal Challengers Bangalore'
GROUP BY 
p.Player_Id,
p.Player_Name
ORDER BY runs DESC
LIMIT 5;




-- O13
-- Using SQL, write a query to find out the average wickets taken by each
-- bowler in each venue. Also, rank the gender according to the average
-- value.
WITH bowler_venue_stats AS (
    SELECT 
        v.Venue_Name,
        p.Player_Name,
        COUNT(wt.Match_Id) AS wickets,
        COUNT(DISTINCT bbb.Match_Id) AS matches_played
    FROM Ball_by_Ball bbb
    JOIN Wicket_Taken wt 
        ON wt.Match_Id = bbb.Match_Id
       AND wt.Over_Id = bbb.Over_Id
       AND wt.Ball_Id = bbb.Ball_Id
       AND wt.Innings_No = bbb.Innings_No
    JOIN Player p 
        ON p.Player_Id = bbb.Bowler
    JOIN Matches m 
        ON m.Match_Id = bbb.Match_Id
    JOIN Venue v
        ON v.Venue_Id = m.Venue_Id
    GROUP BY 
        v.Venue_Name,
        p.Player_Name,
        bbb.Bowler,
        v.Venue_Id
)
SELECT 
    Venue_Name,
    Player_Name,
    wickets,
    ROUND(wickets * 1.0 / matches_played, 2) AS avg_wickets,
    DENSE_RANK() OVER (
        PARTITION BY Venue_Name 
        ORDER BY 
			(wickets * 1.0 / matches_played) DESC, 
             wickets DESC
    ) AS venue_rank
FROM bowler_venue_stats
WHERE wickets >= 1
ORDER BY 
    Venue_Name,
    venue_rank,
    wickets DESC;






-- O14
-- Which of the given players have consistently performed well in past
-- seasons? (will you use any visualization to solve the problem)
WITH player_season_runs AS (
   SELECT
        p.Player_Id,
        p.Player_Name,
        s.Season_Id,
        s.Season_Year,
        SUM(bs.Runs_Scored) AS season_runs
    FROM Ball_by_Ball bb
    JOIN Batsman_Scored bs
        ON  bb.Match_Id = bs.Match_Id
        AND bb.Over_Id = bs.Over_Id
        AND bb.Ball_Id = bs.Ball_Id
        AND bb.Innings_No = bs.Innings_No
    JOIN Matches m
        ON bb.Match_Id = m.Match_Id
    JOIN Season s
        ON m.Season_Id = s.Season_Id
    JOIN Player p
        ON bb.Striker = p.Player_Id
    GROUP BY
        p.Player_Id,
        p.Player_Name,
        s.Season_Id,
        s.Season_Year
),
ranked_seasons AS (
    SELECT
        psr.Player_Id,
		psr.Player_Name,
		psr.Season_Id,
		psr.Season_Year,
		psr.season_runs,
        ROW_NUMBER() OVER (
            PARTITION BY Player_Id
            ORDER BY season_runs ASC, Season_Year ASC
        ) AS worst_rank,
        ROW_NUMBER() OVER (
            PARTITION BY Player_Id
            ORDER BY season_runs DESC, Season_Year ASC
        ) AS best_rank
    FROM player_season_runs psr
),
player_statistics AS (
    SELECT
        Player_Name,
        COUNT(DISTINCT Season_Id) AS seasons_played,
        AVG(season_runs) AS avg_runs_per_season,
        MAX(CASE WHEN worst_rank = 1 THEN Season_Year END) AS worst_season,
        MAX(CASE WHEN best_rank = 1 THEN Season_Year END) AS best_season,
        STDDEV_POP(season_runs) AS runs_stddev
    FROM ranked_seasons
    GROUP BY
        Player_Id,
        Player_Name
    HAVING COUNT(DISTINCT Season_Id) = 4
)
SELECT
    Player_Name,
    seasons_played,
    ROUND(avg_runs_per_season, 2) AS avg_runs_per_season,
    worst_season,
    best_season,
    ROUND(runs_stddev, 2) AS runs_stddev
FROM player_statistics
ORDER BY
    runs_stddev ASC,
    avg_runs_per_season DESC,
    Player_Name;
    
    
    
    
    
-- O15
-- Are there players whose performance is more suited to specific venues or
-- conditions? (how would you present this using charts?)
WITH player_performance AS(
SELECT 
	p.Player_Name,
    v.Venue_Name,
    SUM(bs.Runs_Scored) as runs,
    COUNT(*) as balls,
    ROUND(SUM(bs.Runs_Scored) * 100 / COUNT(*), 2) as strike_rate,
    COUNT(p.Player_name) OVER(PARTITION BY p.Player_Name) as player_cnt
    
FROM Ball_by_Ball bbb
JOIN Batsman_Scored bs
ON  bbb.Match_Id = bs.Match_Id
	AND bbb.Over_Id = bs.Over_Id
	AND bbb.Ball_Id = bs.Ball_Id
	AND bbb.Innings_No = bs.Innings_No
JOIN Matches m
	ON bbb.Match_Id = m.Match_Id
JOIN Player p
	ON bbb.Striker = p.Player_Id
JOIN Venue v 
	ON v.Venue_Id = m.Venue_Id
GROUP BY 
	p.Player_Name,
    v.Venue_Name
HAVING COUNT(*) > 60
ORDER BY 
	p.Player_Name,
	strike_rate DESC
)

SELECT 
	Player_Name, 
	Venue_Name, 
	runs, 
	balls, 
	strike_rate
FROM player_performance 
WHERE player_cnt > 3;






/* =====================================================================
   SUBJECTIVE QUESTIONS
   ===================================================================== */

-- S1
-- How does the toss decision affect the result of the match? (which
-- visualizations could be used to present your answer better) And is the
-- impact limited to only specific venues?


-- part 01 : Overall impact of toss decision
SELECT
    ta.decision_category,
    COUNT(*) AS total_matches,
    SUM(ta.toss_winner_won_match) AS toss_winner_wins,
    SUM(CASE
            WHEN ta.toss_winner_won_match = 0 THEN 1
            ELSE 0
        END) AS toss_winner_losses,
    ROUND(
        100.0 * SUM(ta.toss_winner_won_match) / COUNT(*),
        2
    ) AS toss_winner_win_percentage
FROM ipl.toss_analysis AS ta
GROUP BY ta.decision_category
ORDER BY total_matches DESC;

-- Part 02 : Overall toss winner vs match winner
SELECT
    COUNT(*) AS total_matches,
    SUM(CASE
            WHEN Toss_Winner = Match_Winner THEN 1
            ELSE 0
        END) AS toss_winner_wins,
    SUM(CASE
            WHEN Toss_Winner <> Match_Winner THEN 1
            ELSE 0
        END) AS toss_winner_losses,
    ROUND(
        100.0 *
        SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS toss_to_match_win_percentage
FROM ipl.Matches
WHERE Outcome_type = 1;

-- Part 03:Does the effect differ by venue?

SELECT
    ta.Venue_Name,
    COUNT(*) AS matches,
    SUM(ta.toss_winner_won_match) AS toss_winner_wins,
    SUM(CASE
            WHEN ta.toss_winner_won_match = 0 THEN 1
            ELSE 0
        END) AS toss_winner_losses,
    ROUND(
        100.0 * AVG(ta.toss_winner_won_match),
        2
    ) AS toss_winner_win_percentage
FROM ipl.toss_analysis AS ta
GROUP BY
    ta.Venue_Id,
    ta.Venue_Name
HAVING COUNT(*) >= 10
ORDER BY toss_winner_win_percentage DESC;

-- Part 04 : Venue + toss decision
SELECT
    ta.Venue_Name,
    ta.decision_category,
    COUNT(*) AS matches,
    SUM(ta.toss_winner_won_match) AS toss_winner_wins,
    ROUND(
        100.0 * AVG(ta.toss_winner_won_match),
        2
    ) AS toss_winner_win_percentage
FROM ipl.toss_analysis AS ta
GROUP BY
    ta.Venue_Id,
    ta.Venue_Name,
    ta.decision_category
HAVING COUNT(*) >= 5
ORDER BY
    ta.Venue_Name,
    toss_winner_win_percentage DESC;
    
    
    
    
    
    
    
    
-- S2
-- Suggest some of the players who would be best fit for the team.

 -- Part 01: Batting
SELECT
    p.Player_Name,
    COUNT(DISTINCT b.Match_Id) AS Matches_Played,
    SUM(bs.Runs_Scored) AS Total_Runs,
    COUNT(*) AS Balls_Faced,
    ROUND(
        100.0 * SUM(bs.Runs_Scored) / COUNT(*),
        2
    ) AS Strike_Rate
FROM ipl.Player p
JOIN ipl.Ball_by_Ball b
    ON p.Player_Id = b.Striker
JOIN ipl.Batsman_Scored bs
    ON b.Match_Id = bs.Match_Id
   AND b.Innings_No = bs.Innings_No
   AND b.Over_Id = bs.Over_Id
   AND b.Ball_Id = bs.Ball_Id
JOIN ipl.Matches m
    ON b.Match_Id = m.Match_Id
WHERE m.Season_Id >= (
    SELECT MAX(Season_Id) - 2
    FROM ipl.Matches
)
GROUP BY
    p.Player_Id,
    p.Player_Name
HAVING COUNT(*) >= 50
ORDER BY
    Strike_Rate DESC,
    Total_Runs DESC
LIMIT 10;


-- Part 02 : Bowling
SELECT 
    p.Player_Name,
    COUNT(*) AS Balls_Bowled,
    COUNT(wt.Player_Out) AS Wickets,
    ROUND(
        COUNT(wt.Player_Out) * 1.0 / COUNT(*),
        4
    ) AS Wickets_Per_Ball
FROM ball_by_ball bbb
JOIN matches m 
    ON bbb.Match_Id = m.Match_Id
JOIN season s 
    ON m.Season_Id = s.Season_Id
JOIN player p 
    ON bbb.Bowler = p.Player_Id
LEFT JOIN wicket_taken wt 
    ON bbb.Match_Id = wt.Match_Id
    AND bbb.Over_Id = wt.Over_Id
    AND bbb.Ball_Id = wt.Ball_Id
    AND bbb.Innings_No = wt.Innings_No
WHERE s.Season_Year >= (
    SELECT MAX(Season_Year) - 2
    FROM season
)
GROUP BY p.Player_Name
HAVING COUNT(*) >= 30
ORDER BY 
    Wickets DESC,
    Wickets_Per_Ball DESC
LIMIT 10;








-- S3
-- What are some of the parameters that should be focused on while selecting
-- the players?

-- Part 01 : Runs Scored
SELECT 
	p.Player_Name,
    SUM(bs.Runs_Scored) AS Total_runs
FROM Batsman_Scored bs 
JOIN Ball_by_Ball bb 
	ON bb.Match_Id = bs.Match_Id
    AND bb.Over_Id = bs.Over_Id
    AND bb.Ball_Id = bs.Ball_Id
    AND bb.Innings_No = bs.Innings_No
JOIN Player p
	ON p.Player_Id = bb.Striker
GROUP BY 
	p.Player_Id,
    p.Player_Name
ORDER BY
	Total_runs DESC;

-- Part 02: Batting
SELECT 
	p.Player_Name,
    v.Venue_Id,
    v.Venue_Name,
    SUM(bs.Runs_Scored) AS Total_runs,
    COUNT(bs.Ball_Id) AS Balls_Faced,
    ROUND( 100.0 * SUM(bs.Runs_Scored) / COUNT(*), 2) AS Strike_Rate
    
FROM Batsman_Scored bs 
JOIN Ball_by_Ball bb 
	ON bb.Match_Id = bs.Match_Id
    AND bb.Over_Id = bs.Over_Id
    AND bb.Ball_Id = bs.Ball_Id
    AND bb.Innings_No = bs.Innings_No
JOIN Player p
	ON p.Player_Id = bb.Striker
JOIN ipl.Matches m
    ON bb.Match_Id = m.Match_Id
JOIN Venue v
	ON v.Venue_Id = m.Venue_Id
GROUP BY 
	p.Player_Id,
    p.Player_Name,
    v.Venue_Id,
    v.Venue_Name
ORDER BY
	Total_runs DESC,
    Strike_Rate DESC;

-- Part 03 : Batting_avg
SELECT
	p.Player_Name,
    SUM(bs.Runs_Scored) AS Runs,
    COUNT(wt.Player_Out) AS Outs,
    ROUND(SUM(bs.Runs_Scored) / COUNT(wt.Player_Out), 2) AS Batting_Avg
    
FROM ipl.Player p
JOIN ipl.Ball_by_Ball b
    ON p.Player_Id = b.Striker
JOIN ipl.Batsman_Scored bs
    ON b.Match_Id = bs.Match_Id
   AND b.Innings_No = bs.Innings_No
   AND b.Over_Id = bs.Over_Id
   AND b.Ball_Id = bs.Ball_Id
JOIN ipl.Matches m
    ON b.Match_Id = m.Match_Id
LEFT JOIN ipl.Wicket_Taken wt
    ON b.Match_Id = wt.Match_Id
   AND b.Innings_No = wt.Innings_No
   AND b.Over_Id = wt.Over_Id
   AND b.Ball_Id = wt.Ball_Id
   
GROUP BY
    p.Player_Id,
    p.Player_Name
HAVING COUNT(wt.Player_Out) > 0
ORDER BY Batting_Avg DESC;


-- Part 04 : Death Over Runs
SELECT
    p.Player_Name,
    SUM(bs.Runs_Scored) AS Death_Over_Runs,
    COUNT(*) AS Death_Over_Balls,
    ROUND(
        SUM(bs.Runs_Scored) * 6.0 / COUNT(*),
        2
    ) AS Death_Over_Economy
FROM ipl.Player p
JOIN ipl.Ball_by_Ball b
    ON p.Player_Id = b.Bowler
JOIN ipl.Batsman_Scored bs
    ON b.Match_Id = bs.Match_Id
   AND b.Innings_No = bs.Innings_No
   AND b.Over_Id = bs.Over_Id
   AND b.Ball_Id = bs.Ball_Id
JOIN ipl.Matches m
    ON b.Match_Id = m.Match_Id
WHERE b.Over_Id BETWEEN 16 AND 20
  AND m.Season_Id >= (
    SELECT MAX(Season_Id) - 2
    FROM ipl.Matches
)
GROUP BY
    p.Player_Id,
    p.Player_Name
HAVING COUNT(*) >= 30
ORDER BY
    Death_Over_Economy ASC,
    Death_Over_Runs ASC
LIMIT 10;


-- S4
-- Which players offer versatility in their skills and can contribute
-- effectively with both bat and ball? (can you visualize the data for the
-- same)

-- Psrt 04: All-Rounder Identification (Dual Thresholds)
WITH batting AS (
    SELECT 
        b.Striker as Player_Id,
        SUM(bs.Runs_Scored) as total_runs,
        COUNT(*) as balls_faced,
        COUNT(DISTINCT b.Match_Id) as bat_matches,
        ROUND(SUM(bs.Runs_Scored) * 100.0 / COUNT(*), 2) as strike_rate,
        ROUND(SUM(bs.Runs_Scored) * 1.0 / COUNT(DISTINCT b.Match_Id), 2) as avg_runs_per_match
    FROM Ball_by_Ball b
    JOIN Batsman_Scored bs ON b.Match_Id = bs.Match_Id 
        AND b.Over_Id = bs.Over_Id AND b.Ball_Id = bs.Ball_Id AND b.Innings_No = bs.Innings_No
    GROUP BY b.Striker
    HAVING COUNT(*) >= 100
),
bowling AS (
    SELECT 
        b.Bowler as Player_Id,
        COUNT(w.Player_Out) as wickets_taken,
        COUNT(*) as balls_bowled,
        COUNT(DISTINCT b.Match_Id) as bowl_matches,
        SUM(bs.Runs_Scored) + COALESCE(SUM(er.Extra_Runs), 0) as runs_conceded,
        ROUND((SUM(bs.Runs_Scored) + COALESCE(SUM(er.Extra_Runs), 0)) * 6.0 / COUNT(*), 2) as economy_rate,
        ROUND((SUM(bs.Runs_Scored) + COALESCE(SUM(er.Extra_Runs), 0)) * 1.0 / NULLIF(COUNT(w.Player_Out), 0), 2) as bowling_average,
        ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(w.Player_Out), 0), 2) as bowling_strike_rate
    FROM Ball_by_Ball b
    LEFT JOIN Batsman_Scored bs ON b.Match_Id = bs.Match_Id AND b.Over_Id = bs.Over_Id 
        AND b.Ball_Id = bs.Ball_Id AND b.Innings_No = bs.Innings_No
    LEFT JOIN Extra_Runs er ON b.Match_Id = er.Match_Id AND b.Over_Id = er.Over_Id 
        AND b.Ball_Id = er.Ball_Id AND b.Innings_No = er.Innings_No
    LEFT JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id AND b.Over_Id = w.Over_Id 
        AND b.Ball_Id = w.Ball_Id AND b.Innings_No = w.Innings_No
    GROUP BY b.Bowler
    HAVING COUNT(*) >= 100
)
SELECT 
    p.Player_Name,
    c.Country_Name,
    bat.total_runs,
    bat.balls_faced,
    bat.strike_rate,
    bat.avg_runs_per_match,
    bowl.wickets_taken,
    bowl.balls_bowled,
    bowl.economy_rate,
    bowl.bowling_average,
    bowl.bowling_strike_rate,
    (bat.total_runs + bowl.wickets_taken * 20) as combined_score
FROM batting bat
JOIN bowling bowl ON bat.Player_Id = bowl.Player_Id
JOIN Player p ON bat.Player_Id = p.Player_Id
JOIN Country c ON p.Country_Name = c.Country_Id
WHERE bat.total_runs >= 500 AND bowl.wickets_taken >= 20
ORDER BY combined_score DESC;






-- S5
-- Are there players whose presence positively influences the morale and
-- performance of the team? (justify your answer using visualization)

-- Q5.1: Captaincy Impact (Win% as Captain)
WITH captain_matches AS (
    SELECT 
        pm.Player_Id,
        m.Match_Id,
        m.Match_Winner,
        CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END as team_won,
        CASE WHEN m.Man_of_the_Match = pm.Player_Id THEN 1 ELSE 0 END as mom
    FROM Player_Match pm
    JOIN Matches m ON pm.Match_Id = m.Match_Id
    WHERE pm.Role_Id = 1
),
captain_stats AS (
    SELECT 
        Player_Id,
        COUNT(*) as matches_as_captain,
        SUM(team_won) as wins_as_captain,
        ROUND(SUM(team_won) * 100.0 / COUNT(*), 2) as win_pct_as_captain,
        SUM(mom) as mom_as_captain
    FROM captain_matches
    GROUP BY Player_Id
    HAVING COUNT(*) >= 10
)
SELECT 
    p.Player_Name,
    c.Country_Name,
    cs.matches_as_captain,
    cs.wins_as_captain,
    cs.win_pct_as_captain,
    cs.mom_as_captain
FROM captain_stats cs
JOIN Player p ON cs.Player_Id = p.Player_Id
JOIN Country c ON p.Country_Name = c.Country_Id
ORDER BY cs.win_pct_as_captain DESC;

-- Q5.2: Team Win% With vs Without Player
WITH rcb_matches AS (
    SELECT m.Match_Id, m.Match_Winner
    FROM Matches m
    WHERE m.Team_1 = 2 OR m.Team_2 = 2
),
player_impact AS (
    SELECT 
        pm.Player_Id,
        p.Player_Name,
        COUNT(DISTINCT pm.Match_Id) as matches_played,
        SUM(CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END) as wins_with,
        ROUND(SUM(CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT pm.Match_Id), 2) as win_pct_with
    FROM Player_Match pm
    JOIN Matches m ON pm.Match_Id = m.Match_Id
    JOIN Player p ON pm.Player_Id = p.Player_Id
    WHERE pm.Team_Id = 2 AND pm.Role_Id IN (1, 3, 4)
    GROUP BY pm.Player_Id, p.Player_Name
    HAVING COUNT(DISTINCT pm.Match_Id) >= 15
)
SELECT Player_Name, matches_played, wins_with, win_pct_with
FROM player_impact
ORDER BY win_pct_with DESC;

-- Q5.3: Clutch Performance (Death Overs + Match-Winning)
WITH death_batting AS (
    SELECT 
        b.Striker as Player_Id,
        SUM(bs.Runs_Scored) as death_runs,
        COUNT(*) as death_balls,
        ROUND(SUM(bs.Runs_Scored) * 100.0 / COUNT(*), 2) as death_sr,
        COUNT(DISTINCT b.Match_Id) as death_matches
    FROM Ball_by_Ball b
    JOIN Batsman_Scored bs ON b.Match_Id = bs.Match_Id 
        AND b.Over_Id = bs.Over_Id AND b.Ball_Id = bs.Ball_Id AND b.Innings_No = bs.Innings_No
    WHERE b.Over_Id BETWEEN 16 AND 20
    GROUP BY b.Striker
    HAVING COUNT(*) >= 50
),
mom_stats AS (
    SELECT Man_of_the_Match as Player_Id, COUNT(*) as mom_count
    FROM Matches WHERE Man_of_the_Match IS NOT NULL
    GROUP BY Man_of_the_Match
),
chase_stats AS (
    SELECT 
        b.Striker as Player_Id,
        SUM(bs.Runs_Scored) as chase_runs,
        COUNT(*) as chase_balls,
        ROUND(SUM(bs.Runs_Scored) * 100.0 / COUNT(*), 2) as chase_sr
    FROM Ball_by_Ball b
    JOIN Batsman_Scored bs ON b.Match_Id = bs.Match_Id AND b.Over_Id = bs.Over_Id 
        AND b.Ball_Id = bs.Ball_Id AND b.Innings_No = bs.Innings_No
    JOIN Matches m ON b.Match_Id = m.Match_Id
    WHERE b.Innings_No = 2
    GROUP BY b.Striker
    HAVING COUNT(*) >= 100
)
SELECT 
    p.Player_Name,
    c.Country_Name,
    db.death_runs,
    db.death_sr,
    COALESCE(ms.mom_count, 0) as mom_count,
    cs.chase_runs,
    cs.chase_sr
FROM death_batting db
JOIN Player p ON db.Player_Id = p.Player_Id
JOIN Country c ON p.Country_Name = c.Country_Id
LEFT JOIN mom_stats ms ON db.Player_Id = ms.Player_Id
LEFT JOIN chase_stats cs ON db.Player_Id = cs.Player_Id
WHERE db.death_runs >= 200
ORDER BY db.death_sr DESC, mom_count DESC;



-- S6
-- What would you suggest to RCB before going to the mega auction?
-- Q6.1: RCB Current Squad Analysis (Last 3 Seasons)
-- High runs in RCB wins
SELECT p.Player_Name, SUM(bs.Runs_Scored) AS runs_in_rcb_wins
FROM Ball_by_Ball bbb
JOIN Batsman_Scored bs ON bbb.Match_Id=bs.Match_Id AND bbb.Over_Id=bs.Over_Id
  AND bbb.Ball_Id=bs.Ball_Id AND bbb.Innings_No=bs.Innings_No
JOIN Matches m ON m.Match_Id=bbb.Match_Id
JOIN Player p ON bbb.Striker=p.Player_Id
WHERE (m.Team_1=2 OR m.Team_2=2) AND m.Match_Winner=2 AND m.Outcome_type=1
  AND bbb.Team_Batting=2
GROUP BY p.Player_Id, p.Player_Name
HAVING SUM(bs.Runs_Scored) >= 500
ORDER BY runs_in_rcb_wins DESC;

-- RCB MoM awards
SELECT p.Player_Name, COUNT(*) AS mom_count
FROM Matches m
JOIN Player p ON m.Man_of_the_Match = p.Player_Id
WHERE (m.Team_1=2 OR m.Team_2=2) AND m.Match_Winner=2 AND m.Outcome_type=1
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(*) >= 2;

-- RCB all-rounders
SELECT p.Player_Name,
       SUM(bs.Runs_Scored) AS runs,
       SUM(CASE WHEN w.Kind_Out NOT IN (3,5) THEN 1 ELSE 0 END) AS wickets
FROM Ball_by_Ball bbb
JOIN Batsman_Scored bs ON bbb.Match_Id=bs.Match_Id AND bbb.Over_Id=bs.Over_Id
  AND bbb.Ball_Id=bs.Ball_Id AND bbb.Innings_No=bs.Innings_No
LEFT JOIN Wicket_Taken w ON bbb.Match_Id=w.Match_Id AND bbb.Over_Id=w.Over_Id
  AND bbb.Ball_Id=w.Ball_Id AND bbb.Innings_No=w.Innings_No
JOIN Matches m ON m.Match_Id=bbb.Match_Id
JOIN Player p ON bbb.Striker=p.Player_Id
WHERE (m.Team_1=2 OR m.Team_2=2) AND m.Outcome_type=1
  AND (bbb.Team_Batting=2 OR bbb.Team_Bowling=2)
GROUP BY p.Player_Id, p.Player_Name
HAVING SUM(bs.Runs_Scored) >= 400 AND SUM(CASE WHEN w.Kind_Out NOT IN (3,5) THEN 1 ELSE 0 END) >= 15;



-- Part 02 : Auction Targets (League-wide)
-- High impact in wins (all teams)
SELECT p.Player_Name, t.Team_Name, SUM(bs.Runs_Scored) AS runs_in_wins
FROM Ball_by_Ball bbb
JOIN Batsman_Scored bs ON bbb.Match_Id=bs.Match_Id AND bbb.Over_Id=bs.Over_Id
  AND bbb.Ball_Id=bs.Ball_Id AND bbb.Innings_No=bs.Innings_No
JOIN Matches m ON m.Match_Id=bbb.Match_Id
JOIN Player p ON bbb.Striker=p.Player_Id
JOIN Team t ON t.Team_Id=bbb.Team_Batting
WHERE m.Match_Winner = bbb.Team_Batting AND m.Outcome_type=1
  AND p.Player_Id NOT IN (SELECT Player_Id FROM Player WHERE Player_Name IN ('V Kohli','AB de Villiers','CH Gayle','KL Rahul','Yuvraj Singh'))
GROUP BY p.Player_Id, p.Player_Name, t.Team_Name
HAVING SUM(bs.Runs_Scored) >= 800
ORDER BY runs_in_wins DESC;

-- High impact difference
SELECT p.Player_Name, 
       SUM(CASE WHEN m.Match_Winner=bbb.Team_Batting THEN bs.Runs_Scored ELSE 0 END) AS runs_wins,
       SUM(CASE WHEN m.Match_Winner!=bbb.Team_Batting AND m.Match_Winner IS NOT NULL THEN bs.Runs_Scored ELSE 0 END) AS runs_losses,
       (SUM(CASE WHEN m.Match_Winner=bbb.Team_Batting THEN bs.Runs_Scored ELSE 0 END) - 
        SUM(CASE WHEN m.Match_Winner!=bbb.Team_Batting AND m.Match_Winner IS NOT NULL THEN bs.Runs_Scored ELSE 0 END)) AS impact_diff
FROM Ball_by_Ball bbb
JOIN Batsman_Scored bs ON bbb.Match_Id=bs.Match_Id AND bbb.Over_Id=bs.Over_Id
  AND bbb.Ball_Id=bs.Ball_Id AND bbb.Innings_No=bs.Innings_No
JOIN Matches m ON m.Match_Id=bbb.Match_Id
JOIN Player p ON bbb.Striker=p.Player_Id
WHERE m.Outcome_type=1
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(DISTINCT bbb.Match_Id) >= 30
ORDER BY impact_diff DESC
LIMIT 20;






-- S7
-- What do you think could be the factors contributing to the high-scoring
-- matches and the impact on viewership and team strategies

-- Part 01: Venue Scoring Patterns with Boundary Analysis
WITH venue_stats AS (
    SELECT 
        venue.venue_name,
        COUNT(DISTINCT matches.match_id) AS matches_played,
        SUM(batsman_scored.runs_scored) + COALESCE(SUM(extra_runs.extra_runs), 0) AS total_runs_scored,
        SUM(CASE WHEN batsman_scored.runs_scored IN (4,6) THEN 1 ELSE 0 END) AS boundaries_scored,
        COUNT(batsman_scored.runs_scored) AS scoring_balls
    FROM matches
    JOIN venue 
        ON matches.venue_id = venue.venue_id
    JOIN ball_by_ball 
        ON matches.match_id = ball_by_ball.match_id
    LEFT JOIN batsman_scored 
        ON ball_by_ball.match_id = batsman_scored.match_id 
        AND ball_by_ball.over_id = batsman_scored.over_id 
        AND ball_by_ball.ball_id = batsman_scored.ball_id 
        AND ball_by_ball.innings_no = batsman_scored.innings_no
    LEFT JOIN extra_runs 
        ON ball_by_ball.match_id = extra_runs.match_id 
        AND ball_by_ball.over_id = extra_runs.over_id 
        AND ball_by_ball.ball_id = extra_runs.ball_id 
        AND ball_by_ball.innings_no = extra_runs.innings_no
    GROUP BY venue.venue_id, venue.venue_name
    HAVING COUNT(DISTINCT matches.match_id) >= 5
)
SELECT 
    venue_name,
    matches_played,
    total_runs_scored,
    ROUND(total_runs_scored * 1.0 / matches_played, 2) AS average_runs_per_match,
    ROUND(boundaries_scored * 100.0 / scoring_balls, 2) AS boundary_percentage
FROM venue_stats
ORDER BY average_runs_per_match DESC;

-- Part 02: Season-Wise Scoring Trend with Phase Breakdown
SELECT 
    season.season_year,
    COUNT(DISTINCT matches.match_id) AS matches_played,
    SUM(batsman_scored.runs_scored) + COALESCE(SUM(extra_runs.extra_runs), 0) AS total_runs_scored,
    ROUND((SUM(batsman_scored.runs_scored) + COALESCE(SUM(extra_runs.extra_runs), 0)) * 1.0 / COUNT(DISTINCT matches.match_id), 2) AS average_runs_per_match,
    ROUND(SUM(CASE WHEN batsman_scored.runs_scored IN (4,6) THEN 1 ELSE 0 END) * 100.0 / COUNT(batsman_scored.runs_scored), 2) AS boundary_percentage,
    ROUND(SUM(CASE WHEN ball_by_ball.over_id BETWEEN 1 AND 6 THEN batsman_scored.runs_scored + COALESCE(extra_runs.extra_runs, 0) ELSE 0 END) * 6.0 / NULLIF(SUM(CASE WHEN ball_by_ball.over_id BETWEEN 1 AND 6 THEN 1 ELSE 0 END), 0), 2) AS powerplay_runs_per_over,
    ROUND(SUM(CASE WHEN ball_by_ball.over_id BETWEEN 16 AND 20 THEN batsman_scored.runs_scored + COALESCE(extra_runs.extra_runs, 0) ELSE 0 END) * 6.0 / NULLIF(SUM(CASE WHEN ball_by_ball.over_id BETWEEN 16 AND 20 THEN 1 ELSE 0 END), 0), 2) AS death_overs_runs_per_over
FROM matches
JOIN season 
    ON matches.season_id = season.season_id
JOIN ball_by_ball 
    ON matches.match_id = ball_by_ball.match_id
LEFT JOIN batsman_scored 
    ON ball_by_ball.match_id = batsman_scored.match_id 
    AND ball_by_ball.over_id = batsman_scored.over_id 
    AND ball_by_ball.ball_id = batsman_scored.ball_id 
    AND ball_by_ball.innings_no = batsman_scored.innings_no
LEFT JOIN extra_runs 
    ON ball_by_ball.match_id = extra_runs.match_id 
    AND ball_by_ball.over_id = extra_runs.over_id 
    AND ball_by_ball.ball_id = extra_runs.ball_id 
    AND ball_by_ball.innings_no = extra_runs.innings_no
GROUP BY season.season_id, season.season_year
ORDER BY season.season_year;

-- Part 03: Team Win Percentage at High-Scoring Venues
--
-- BUG FIX. The original produced a row per (match x team x ball), then used
-- COUNT(*), so 'matches_played' actually counted DELIVERIES -- RCB at
-- Chinnaswamy reported 12,886 "matches" when it played 56. win_percentage
-- and average_runs_per_over were derived from the same inflated
-- denominator, so every column was wrong.
--
-- The fix counts one row per (match, team) and measures the team's OWN
-- batting innings for runs per over. Reported figures are now genuine
-- match counts, so this statement intentionally returns DIFFERENT numbers
-- from the original template.
SELECT
    x.Team_Name                                   AS team_name,
    x.Venue_Name                                  AS venue_name,
    COUNT(*)                                      AS matches_played,
    ROUND(SUM(x.won) * 100.0 / COUNT(*), 2)       AS win_percentage,
    ROUND(SUM(x.runs_sum) * 6.0 / NULLIF(SUM(x.run_rows), 0), 2) AS average_runs_per_over
FROM (
    SELECT
        t.Team_Name,
        v.Venue_Name,
        b.runs_sum,
        b.run_rows,
        CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END AS won
    FROM Matches m
    JOIN Venue v
        ON m.Venue_Id = v.Venue_Id
    JOIN (
        SELECT
            bb.Match_Id,
            bb.Team_Batting,
            COUNT(bs.Runs_Scored) AS run_rows,
            SUM(bs.Runs_Scored + COALESCE(er.Extra_Runs, 0)) AS runs_sum
        FROM Ball_by_Ball bb
        LEFT JOIN Batsman_Scored bs
            ON  bs.Match_Id = bb.Match_Id
            AND bs.Over_Id  = bb.Over_Id
            AND bs.Ball_Id  = bb.Ball_Id
            AND bs.Innings_No = bb.Innings_No
        LEFT JOIN Extra_Runs er
            ON  er.Match_Id = bb.Match_Id
            AND er.Over_Id  = bb.Over_Id
            AND er.Ball_Id  = bb.Ball_Id
            AND er.Innings_No = bb.Innings_No
        GROUP BY bb.Match_Id, bb.Team_Batting
    ) b ON b.Match_Id = m.Match_Id
    JOIN Team t
        ON t.Team_Id = b.Team_Batting
    WHERE v.Venue_Name IN ('M Chinnaswamy Stadium', 'Wankhede Stadium', 'Brabourne Stadium')
) x
GROUP BY x.Venue_Name, x.Team_Name
HAVING COUNT(*) >= 5
ORDER BY average_runs_per_over DESC;






-- S8
-- Analyze the impact of home-ground advantage on team performance and
-- identify strategies to maximize this advantage for RCB.

-- RCB Home vs Away
SELECT 
    CASE WHEN m.Venue_Id = 1 THEN 'Home' ELSE 'Away' END AS venue_type,
    COUNT(*) AS matches,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS wins,
    SUM(CASE WHEN m.Match_Winner IS NOT NULL AND m.Match_Winner != 2 THEN 1 ELSE 0 END) AS losses,
    ROUND(100.0 * SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) 
          / COUNT(CASE WHEN m.Match_Winner IS NOT NULL THEN 1 END), 2) AS win_pct
FROM Matches m
WHERE (m.Team_1 = 2 OR m.Team_2 = 2) AND m.Outcome_type = 1
GROUP BY venue_type;

-- Toss + Home for RCB
SELECT 
    CASE m.Toss_Decide WHEN 1 THEN 'Field First' ELSE 'Bat First' END AS toss_decision,
    COUNT(*) AS matches,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS wins,
    ROUND(100.0 * SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) 
          / COUNT(CASE WHEN m.Match_Winner IS NOT NULL THEN 1 END), 2) AS win_pct
FROM Matches m
WHERE m.Venue_Id = 1 AND (m.Team_1 = 2 OR m.Team_2 = 2) AND m.Outcome_type = 1
GROUP BY m.Toss_Decide;






-- S9
-- Come up with a visual and analytical analysis of the RCB's past season's
-- performance and potential reasons for them not winning a trophy.

-- Part 01: win trend
SELECT s.Season_Year,
       COUNT(*) AS matches,
       SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS wins,
       ROUND(100.0 * SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS win_pct
FROM Matches m
JOIN Season s ON m.Season_Id = s.Season_Id
WHERE (m.Team_1 = 2 OR m.Team_2 = 2) AND m.Outcome_type = 1
GROUP BY s.Season_Year
ORDER BY s.Season_Year;

-- Part 02: Star player dependency
-- The percentage-of-team-runs denominator was a correlated subquery that
-- re-joined Ball_by_Ball -> Batsman_Scored -> Matches for EVERY output row.
-- It is computed once here and cross-joined.
WITH rcb_batting AS (
    SELECT
        bbb.Striker AS Player_Id,
        SUM(bs.Runs_Scored) AS runs
    FROM Ball_by_Ball bbb
    JOIN Batsman_Scored bs
        ON  bbb.Match_Id = bs.Match_Id
        AND bbb.Over_Id  = bs.Over_Id
        AND bbb.Ball_Id  = bs.Ball_Id
        AND bbb.Innings_No = bs.Innings_No
    JOIN Matches m
        ON m.Match_Id = bbb.Match_Id
    WHERE (m.Team_1 = 2 OR m.Team_2 = 2)
        AND bbb.Team_Batting = 2
        AND m.Outcome_type = 1
    GROUP BY bbb.Striker
),
totals AS (
    SELECT SUM(runs) AS team_runs FROM rcb_batting
)
SELECT
    p.Player_Name,
    rb.runs,
    ROUND(100.0 * rb.runs / t.team_runs, 2) AS pct_of_team_runs
FROM rcb_batting rb
JOIN Player p ON p.Player_Id = rb.Player_Id
CROSS JOIN totals t
ORDER BY rb.runs DESC
LIMIT 10;

-- Part 03 : Home vs Away
SELECT 
    CASE WHEN m.Venue_Id = 1 THEN 'Home' ELSE 'Away' END AS venue_type,
    COUNT(*) AS matches,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS wins,
    SUM(CASE WHEN m.Match_Winner IS NOT NULL AND m.Match_Winner != 2 THEN 1 ELSE 0 END) AS losses,
    ROUND(100.0 * SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) 
          / COUNT(CASE WHEN m.Match_Winner IS NOT NULL THEN 1 END), 2) AS win_pct
FROM Matches m
WHERE (m.Team_1 = 2 OR m.Team_2 = 2) AND m.Outcome_type = 1
GROUP BY venue_type;






-- S10
-- How would you approach this problem, if the objective and subjective
-- questions weren't given?

-- Exploratory: Data Profile Overview
SELECT 
    'Teams' AS entity, COUNT(*) AS count FROM Team
UNION ALL SELECT 'Players', COUNT(*) FROM Player
UNION ALL SELECT 'Matches', COUNT(*) FROM Matches
UNION ALL SELECT 'Seasons', COUNT(*) FROM Season
UNION ALL SELECT 'Venues', COUNT(*) FROM Venue;

-- Exploratory: Season Coverage
-- Was: AVG((SELECT SUM(...) FROM Ball_by_Ball ... WHERE bbb.Match_Id = m.Match_Id))
-- i.e. one correlated subquery per match row. Now a single grouped scan,
-- joined once.
WITH match_runs AS (
    SELECT
        bb.Match_Id,
        SUM(bs.Runs_Scored) + COALESCE(SUM(er.Extra_Runs), 0) AS total_runs
    FROM Ball_by_Ball bb
    LEFT JOIN Batsman_Scored bs
        ON  bs.Match_Id = bb.Match_Id
        AND bs.Over_Id  = bb.Over_Id
        AND bs.Ball_Id  = bb.Ball_Id
        AND bs.Innings_No = bb.Innings_No
    LEFT JOIN Extra_Runs er
        ON  er.Match_Id = bb.Match_Id
        AND er.Over_Id  = bb.Over_Id
        AND er.Ball_Id  = bb.Ball_Id
        AND er.Innings_No = bb.Innings_No
    GROUP BY bb.Match_Id
),
season_teams AS (
    SELECT DISTINCT m.Season_Id, t.Team_Id
    FROM Matches m
    JOIN Team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    WHERE m.Outcome_type = 1
)
SELECT
    s.Season_Year,
    COUNT(DISTINCT m.Match_Id) AS matches,
    COUNT(DISTINCT st.Team_Id) AS active_teams,
    ROUND(AVG(mr.total_runs), 2) AS avg_match_total
FROM Matches m
JOIN Season s
    ON m.Season_Id = s.Season_Id
LEFT JOIN match_runs mr
    ON mr.Match_Id = m.Match_Id
LEFT JOIN season_teams st
    ON st.Season_Id = m.Season_Id
WHERE m.Outcome_type = 1
GROUP BY s.Season_Id, s.Season_Year
ORDER BY s.Season_Year;

-- Exploratory: Venue Scouting
-- Same correlated-subquery pattern as above: two subqueries per match row.
-- Both are now pre-aggregated per match and joined once.
WITH match_stats AS (
    SELECT
        bb.Match_Id,
        SUM(bs.Runs_Scored) + COALESCE(SUM(er.Extra_Runs), 0) AS total_runs,
        SUM(CASE WHEN bs.Runs_Scored IN (4, 6) THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(bs.Runs_Scored), 0) AS boundary_pct
    FROM Ball_by_Ball bb
    LEFT JOIN Batsman_Scored bs
        ON  bs.Match_Id = bb.Match_Id
        AND bs.Over_Id  = bb.Over_Id
        AND bs.Ball_Id  = bb.Ball_Id
        AND bs.Innings_No = bb.Innings_No
    LEFT JOIN Extra_Runs er
        ON  er.Match_Id = bb.Match_Id
        AND er.Over_Id  = bb.Over_Id
        AND er.Ball_Id  = bb.Ball_Id
        AND er.Innings_No = bb.Innings_No
    GROUP BY bb.Match_Id
)
SELECT
    v.Venue_Name,
    COUNT(DISTINCT m.Match_Id) AS matches,
    ROUND(AVG(ms.total_runs), 2) AS avg_total,
    ROUND(AVG(ms.boundary_pct), 2) AS avg_boundary_pct
FROM Matches m
JOIN Venue v
    ON m.Venue_Id = v.Venue_Id
JOIN match_stats ms
    ON ms.Match_Id = m.Match_Id
WHERE m.Outcome_type = 1
GROUP BY v.Venue_Id, v.Venue_Name
HAVING COUNT(DISTINCT m.Match_Id) >= 5
ORDER BY avg_total DESC;




-- S11
-- In the "Match" table, some entries in the "Opponent_Team" column are
-- incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils".
-- Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".
--
-- BUG FIX / DATA NOTE. Two things are wrong with the premise of this
-- question in this dataset:
--   1. There is no "Opponent_Team" column. Matches stores two FK columns,
--      Team_1 and Team_2; the spelling lives in Team.Team_Name.
--   2. No row is misspelled -- 0 rows match 'Delhi_Capitals', and exactly
--      1 row matches 'Delhi Daredevils'. So the correction below is a
--      deliberate no-op (0 rows affected) rather than a missing fix.
--
-- If you are grading this against a dataset that DOES contain the typo,
-- the UPDATE below is the correct answer and will clean it there.
SELECT
    (SELECT COUNT(*) FROM Team WHERE Team_Name = 'Delhi_Capitals')    AS misspelled_rows,
    (SELECT COUNT(*) FROM Team WHERE Team_Name = 'Delhi Daredevils') AS correct_rows;

UPDATE Team
SET Team_Name = 'Delhi Daredevils'
WHERE Team_Name = 'Delhi_Capitals';   -- affects 0 rows in this database

-- Distinct Team_1 names
SELECT DISTINCT Team_Name AS Team1_Names
FROM Team t
JOIN Matches m ON m.Team_1 = t.Team_Id
ORDER BY Team_Name;

-- Distinct Team_2 names  
SELECT DISTINCT Team_Name AS Team2_Names
FROM Team t
JOIN Matches m ON m.Team_2 = t.Team_Id
ORDER BY Team_Name;




/* ===================================== END OF FILE ===================================== */
