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
    python3 scrape_mbb_schedules_threaded.py -s $i -e $i
    python3 scrape_mbb_json_threaded.py -s $i -e $i
    git pull
    git add .
    bash daily_mbb_R_processor.sh -s $i -e $i
done