# 🏏 RCB IPL Strategy — Advanced SQL Analytics Project

> **A comprehensive data-driven analysis of Royal Challengers Bangalore's IPL performance using advanced SQL techniques, performance optimization, and strategic insights for team management.**

---

## 📋 Project Overview

This repository contains a complete end-to-end SQL analytics solution for the **RCB IPL Strategy** case study. The project demonstrates proficiency in complex SQL querying, database optimization, statistical analysis, and translating data into actionable cricket strategy recommendations.

**Submission:** Newton School — SQL IPL Analysis (Submission 02)

---

## 🎯 Key Highlights

| Metric | Achievement |
|--------|-------------|
| **Total Queries** | 26 (15 Objective + 11 Subjective) |
| **Tables Analyzed** | 12+ core IPL tables |
| **Optimization Layer** | 27 strategic indexes with idempotent creation |
| **Advanced SQL Features** | CTEs, Window Functions, DENSE_RANK, LAG, STDDEV_POP, Conditional Aggregation |
| **Bug Fixes Documented** | 5+ critical logic corrections with explanations |
| **Visualization Strategy** | Defined for every analytical question |

---

## 🗂️ Repository Structure

```
├── IPL-fallback.sql           # Complete production-ready SQL solution (1,654 lines)
├── Tasks-IPL-RCB-CLEAN-02.docx  # Original task requirements & expected outputs
├── IPL Data Analysis - RCB.key    # Keynote presentation with 14+ visual slides
└── GITHUB_POST.md             # This file
```

---

## 🔧 Technical Deep Dive

### 1. Performance Optimization Layer

The solution opens with a **re-runnable optimization layer** that creates 27 strategic indexes on foreign keys and filter columns — reducing full-table scans across all 54+ analytical statements.

```sql
-- Example: Idempotent index creation procedure
CREATE PROCEDURE add_idx_if_missing(IN p_table VARCHAR(64), IN p_index VARCHAR(64), IN p_cols VARCHAR(255))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS 
                   WHERE TABLE_SCHEMA = 'ipl' AND TABLE_NAME = p_table AND INDEX_NAME = p_index) THEN
        SET @ddl = CONCAT('CREATE INDEX `', p_index, '` ON `', p_table, '` (', p_cols, ')');
        PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    END IF;
END
```

**Indexes cover:** Ball-by-ball access paths (Striker, Bowler, Team, Over), Matches filters (Season, Venue, Winner, Teams), Player dimensions, and Player_Match lookups.

---

### 2. Objective Questions (O1–O15)

| # | Question | Key Techniques |
|---|----------|----------------|
| **O1** | Column dtypes via Information Schema | `INFORMATION_SCHEMA.COLUMNS` |
| **O2** | RCB Season 1 total runs (with extras) | **Separate CTEs** for batting runs & extras — avoids silent data loss from inner joins |
| **O3** | Players >25 years in 2014 | `TIMESTAMPDIFF(YEAR, DOB, Match_Date)` |
| **O4** | RCB wins in 2013 | Multi-table joins with Season/Team |
| **O5** | Top 10 strike rates (last 4 seasons) | CTE for dynamic season window + strike rate calc |
| **O6** | Avg runs per batsman (all seasons) | `COUNT(DISTINCT Match_Id)` for match-level avg |
| **O7** | Avg wickets per bowler | Excludes run-outs/retired hurt (`Kind_Out NOT IN (3,5,9)`) |
| **O8** | All-rounders above dual thresholds | 5-CTE pipeline: runs, wickets, matches, averages, thresholds |
| **O9** | RCB venue-wise W/L record | `rcb_record` table with single RCB ID resolution |
| **O10** | Bowling style impact on wickets | Join `Bowling_Style` dimension, filter credited dismissals |
| **O11** | Season-over-season performance status | **Fixed CASE logic** — original had duplicated `runs_vs_prev` checks |
| **O12** | Extended KPIs (win%, boundary%, top scorers) | Multiple independent analytical queries |
| **O13** | Bowler avg wickets per venue + ranking | `DENSE_RANK()` partitioned by venue |
| **O14** | Consistent performers across seasons | `STDDEV_POP()` + `ROW_NUMBER()` for best/worst season |
| **O15** | Venue-specific player suitability | 60-ball minimum filter, strike rate by venue |

---

### 3. Subjective Questions (S1–S11)

| # | Business Question | Analytical Approach |
|---|-------------------|---------------------|
| **S1** | Toss decision impact on match result | Baseline toss-win%, decision split (bat/field), venue × decision matrix |
| **S2** | Best-fit players for RCB | Last 3 seasons: batting (SR + runs) & bowling (wickets/ball) with minimum sample filters |
| **S3** | Player selection parameters | Total runs, venue-wise SR, batting average, death-over economy |
| **S4** | Versatile all-rounders | Dual-threshold CTEs: ≥500 runs & ≥20 wickets, 100-ball minimums each |
| **S5** | Player morale/performance influence | Captain win%, team win% with player, clutch (death overs + chase + MoM) |
| **S6** | Mega auction strategy | Retention (RCB win contributors, MoMs, all-rounders) + League-wide targets (impact diff) |
| **S7** | High-scoring match factors | Venue scoring patterns, seasonal trends (powerplay/death), team performance at high-scoring venues |
| **S8** | Home-ground advantage for RCB | Home vs Away win%, toss decision at home (Chinnaswamy) |
| **S9** | RCB trophy drought analysis | Season win trends, star-player dependency (% of team runs), home/away split |
| **S10** | Open-ended problem framing | 5-phase framework: Objectives → Data Prep → Performance Analysis → Auction Strategy → Predictive Modeling |
| **S11** | Data correction: Delhi Capitals → Daredevils | Schema verification: no `Opponent_Team` column exists; team names in `Team.Team_Name` |

---

## 🐛 Critical Bug Fixes Documented

The solution explicitly identifies and corrects **5+ logic errors** from the original template:

| Query | Original Bug | Fix Applied |
|-------|--------------|-------------|
| **O2** | Merging batting + extras CTEs drops extras on non-batting balls | Kept separate CTEs; `FULL OUTER` logic via separate aggregation |
| **O11** | CASE statement checked `runs_vs_prev` twice; `wkts_vs_prev` never consulted | Rewrote CASE with proper NULL-first check, then dual-condition branches |
| **S7-P3** | `COUNT(*)` counted ball-rows, not matches — inflated denominators 200x | Pre-aggregated per `(match, team)` then joined; genuine match counts |
| **S10** | Correlated subqueries per match row (N+1 problem) | Pre-aggregated `match_runs` & `match_stats` CTEs, single joins |
| **S11** | Premise assumed `Opponent_Team` column in Matches | Verified schema: team names only in `Team` table; no update needed |

---

## 📊 Visualization Strategy

Every analytical question includes a **defined visualization approach**:

- **Dot/Strip Plots** — Player-venue strike rates (O15, S5)
- **Grouped Bar Charts** — Toss decision × venue win% (S1)
- **Scatter Plots** — Runs vs Wickets for all-rounder identification (S4)
- **Line Charts** — Seasonal scoring trends, powerplay vs death rates (S7)
- **Heatmaps** — Venue × Team win percentages (S7, S8)
- **Waterfall Charts** — Season-over-season performance deltas (O11, S9)

---

## 🛠️ Tech Stack

- **Database:** MySQL 8.0+ (CTEs, Window Functions, `DENSE_RANK`, `LAG`, `STDDEV_POP`)
- **Schema:** 12-table IPL relational model (Ball_by_Ball, Batsman_Scored, Extra_Runs, Wicket_Taken, Matches, Player, Team, Season, Venue, Player_Match, Out_Type, Bowling_Style, Country, Toss_Decision)
- **Presentation:** Apple Keynote (14+ slides with charts & insights)

---

## 🚀 How to Run

```sql
-- 1. Ensure database 'ipl' exists with all 12 tables loaded
-- 2. Execute the optimization layer (idempotent — safe to re-run)
SOURCE IPL-fallback.sql;

-- 3. Run individual questions by copying query blocks
--    Each question is clearly delimited with comments
```

---

## 💡 Key Insights for RCB Management

1. **Star Dependency** — Top 3 batsmen contribute disproportionate % of team runs (validated via S9)
2. **Home Advantage** — Quantified win% differential at Chinnaswamy vs away (S8)
3. **All-Rounder Gap** — Few players meet dual thresholds; auction should target this profile (S4)
4. **Death Bowling** — Economy rates in overs 16–20 correlate strongly with match wins (S3, S7)
5. **Toss Strategy** — Venue-specific bat/field decisions show measurable impact (S1)
6. **Retention Core** — Data identifies 5–7 players with proven impact in RCB wins (S6)

---

## 📄 License

This project is submitted as academic coursework for **Newton School — SQL IPL Analysis**. All IPL data used is for educational purposes only.

---

## 🤝 Connect

**Kartik Singh**  
*Data Analyst | SQL | Sports Analytics*  
[GitHub](https://github.com/kartiksingh) • [LinkedIn](https://linkedin.com/in/kartiksingh)

---

> *"In God we trust. All others must bring data."* — W. Edwards Deming