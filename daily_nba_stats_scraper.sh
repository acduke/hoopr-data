#!/bin/bash
while getopts s:e:r: flag
do
    case "${flag}" in
        s) START_YEAR=${OPTARG};;
        e) END_YEAR=${OPTARG};;
        r) RESCRAPE=${OPTARG};;
    esac
done
for i in $(seq "${START_YEAR}" "${END_YEAR}")
do
    echo "$i"
    git pull
    git add .
    Rscript R/nba_stats_01_scrape_schedules.R -s $i -e $i -r $RESCRAPE
    Rscript R/nba_stats_02_scrape_pbp.R -s $i -e $i -r $RESCRAPE
    git pull
    git add nba_stats/* >> /dev/null 
    git pull
    git commit -m "NBA Stats Play-by-Play and Schedules update (Start: $i End: $i)" || echo "No changes to commit" >> /dev/null 
    git pull
    git push >> /dev/null 
done