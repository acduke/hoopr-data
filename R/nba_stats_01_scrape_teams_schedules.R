pacman::p_load("dplyr","purrr","stringr","data.table", "qs","arrow")
source('R/utils.R')


years_vec <- 1996:(hoopR:::most_recent_nba_season() - 1)

seasons_vec <- purrr::map(years_vec, function(x){ hoopR::year_to_season(x) }) %>% 
  unlist()


proxies_df <- get_proxy_ips()

schedules_df <- purrr::map_dfr(1:length(seasons_vec), function(x){
  season_pull <- seasons_vec[[x]]

  completed_sched <- hoopR::nba_schedule(season = seasons_vec[[x]], proxy = select_proxy(proxies = proxies_df)) %>%
    dplyr::mutate(
      Season = seasons_vec[[x]])
  
  data.table::fwrite(completed_sched,paste0('nba_stats/schedules/csv/schedule_',seasons_vec[[x]],'.csv'))
  saveRDS(completed_sched,paste0('nba_stats/schedules/rds/schedule_',seasons_vec[[x]],'.rds'))
  qs::qsave(completed_sched,paste0('nba_stats/schedules/qs/schedule_',seasons_vec[[x]],'.qs'))
  arrow::write_parquet(completed_sched, paste0('nba_stats/schedules/parquet/schedule_',seasons_vec[[x]],'.parquet'))
  Sys.sleep(2.5)
  return(completed_sched)
})


sched_list <- list.files(path = glue::glue('nba_stats/schedules/csv'))

master_schedules_df <- purrr::map_dfr(sched_list, function(x){
  sched <- data.table::fread(paste0('nba_stats/schedules/csv/',x))
  return(sched)
})
data.table::fwrite(master_schedules_df,'nba_stats_schedule_master.csv')
saveRDS(master_schedules_df,'nba_stats_schedule_master.rds')
qs::qsave(master_schedules_df,'nba_stats_schedule_master.qs')
arrow::write_parquet(master_schedules_df, 'nba_stats_schedule_master.parquet')