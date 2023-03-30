#!/bin/bash
while getopts s:e:r: flag
do
    case "${flag}" in
        s) START_YEAR=${OPTARG};;
        e) END_YEAR=${OPTARG};;
        r) RESCRAPE=${OPTARG};;
    esac
done
git pull
git add .
Rscript R/nba_stats_01_scrape_teams_schedules.R -s $START_YEAR -e $END_YEAR -r $RESCRAPE
Rscript R/nba_stats_02_scrape_pbp.R -s $START_YEAR -e $END_YEAR -r $RESCRAPE
git pull
git add nba_stats/* nba_stats_schedule_master.csv nba_stats_schedule_master.parquet
git pull
git commit -m "NBA Stats API Play-by-Play and Schedules update (Start: $START_YEAR End: $END_YEAR)" || echo "No changes to commit"
git pull
git push