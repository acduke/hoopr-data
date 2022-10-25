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
python scrape_mbb_schedules.py -s $START_YEAR -e $END_YEAR
python scrape_mbb_json.py -s $START_YEAR -e $END_YEAR
git pull
git add .
Rscript R/espn_mbb_01_pbp_creation.R -s $START_YEAR -e $END_YEAR
Rscript R/espn_mbb_02_team_box_creation.R -s $START_YEAR -e $END_YEAR
Rscript R/espn_mbb_03_player_box_creation.R -s $START_YEAR -e $END_YEAR
git pull
git add mbb/ mbb_schedule_master.csv mbb_schedule_master.parquet