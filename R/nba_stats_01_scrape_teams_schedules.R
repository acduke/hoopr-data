rm(list = ls())
gcol <- gc()
lib_path <- Sys.getenv("R_LIBS")
if (!requireNamespace('pacman', quietly = TRUE)) {
  install.packages('pacman', lib = Sys.getenv("R_LIBS"), repos = 'http://cran.us.r-project.org')
}
suppressWarnings(suppressMessages(library(dplyr, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(magrittr, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(jsonlite, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(purrr, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(progressr, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(stringr, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(data.table, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(qs, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(arrow, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(glue, lib.loc = lib_path)))
suppressPackageStartupMessages(suppressMessages(library(optparse, lib.loc = lib_path)))

source('R/utils.R')

option_list = list(
  make_option(c("-s", "--start_year"), 
              action = "store", 
              default = hoopR:::most_recent_nba_season(), 
              type = 'integer', 
              help = "Start year of the seasons to process"),
  make_option(c("-e", "--end_year"), 
              action = "store", 
              default = hoopR:::most_recent_nba_season(), 
              type = 'integer', 
              help = "End year of the seasons to process"),
  make_option(c("-r", "--rescrape"), 
              action = "store", 
              default = FALSE,
              type = "logical", 
              help = "Rescrape the raw JSON files from web api")
)
opt = parse_args(OptionParser(option_list = option_list))
options(stringsAsFactors = FALSE)
options(scipen = 999)
years_vec <- (opt$s - 1):(opt$e - 1)
rescrape <- opt$r

proxies_df <- get_proxy_ips()

seasons_vec <- purrr::map(years_vec, function(x){ hoopR::year_to_season(x) }) %>% 
  unlist()


schedules_df <- purrr::map_dfr(1:length(seasons_vec), function(x){
  cli::cli_progress_step(msg = "Downloading {seasons_vec[[x]]} NBA Stats schedule",
                         msg_done = "Downloaded {seasons_vec[[x]]} NBA Stats schedule!")
  
  completed_sched <- hoopR::nba_schedule(season = seasons_vec[[x]], proxy = select_proxy(proxies = proxies_df)) %>%
    dplyr::mutate(
      season = seasons_vec[[x]])
  
  completed_sched <- completed_sched %>% 
    hoopR:::make_hoopR_data("NBA Stats Schedule from hoopR data repository", Sys.time())
  
  ifelse(!dir.exists(file.path("nba_stats/schedules")), dir.create(file.path("nba_stats/schedules")), FALSE)
  ifelse(!dir.exists(file.path("nba_stats/schedules/csv")), dir.create(file.path("nba_stats/schedules/csv")), FALSE)
  data.table::fwrite(completed_sched, paste0('nba_stats/schedules/csv/schedule_', seasons_vec[[x]],'.csv'))
  
  ifelse(!dir.exists(file.path("nba_stats/schedules/rds")), dir.create(file.path("nba_stats/schedules/rds")), FALSE)
  saveRDS(completed_sched, paste0('nba_stats/schedules/rds/schedule_', seasons_vec[[x]],'.rds'))
  
  ifelse(!dir.exists(file.path("nba_stats/schedules/parquet")), dir.create(file.path("nba_stats/schedules/parquet")), FALSE)
  arrow::write_parquet(completed_sched, paste0('nba_stats/schedules/parquet/schedule_', seasons_vec[[x]],'.parquet'))
  
  return(completed_sched)
})


cli::cli_progress_message("")