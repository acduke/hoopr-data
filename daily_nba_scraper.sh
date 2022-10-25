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
python scrape_nba_schedules.py -s $START_YEAR -e $END_YEAR
python scrape_nba_json.py -s $START_YEAR -e $END_YEAR
git pull
git add .
Rscript R/espn_nba_01_pbp_creation.R -s $START_YEAR -e $END_YEAR
Rscript R/espn_nba_02_team_box_creation.R -s $START_YEAR -e $END_YEAR
Rscript R/espn_nba_03_player_box_creation.R -s $START_YEAR -e $END_YEAR
git pull
git add nba/ nba_schedule_master.csv nba_schedule_master.parquet