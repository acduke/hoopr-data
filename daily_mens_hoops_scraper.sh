#!/bin/bash
while getopts s:e:r: flag
do
    case "${flag}" in
        s) START_YEAR=${OPTARG};;
        e) END_YEAR=${OPTARG};;
        r) RESCRAPE=${OPTARG};;
    esac
done
bash daily_nba_scraper.sh -s $START_YEAR -e $END_YEAR
bash daily_mbb_scraper.sh -s $START_YEAR -e $END_YEAR
git pull
git commit -m "NBA and MBB Play-by-Play and Schedules update" || echo "No changes to commit"
git pull
git push