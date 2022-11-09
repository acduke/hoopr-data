rm(list = ls())
gc()
lib_path <- Sys.getenv("R_LIBS")
if (!requireNamespace('pacman', quietly = TRUE)){
  install.packages('pacman',lib=Sys.getenv("R_LIBS"), repos='http://cran.us.r-project.org')
}
suppressPackageStartupMessages(suppressMessages(library(dplyr, lib.loc=lib_path)))
suppressPackageStartupMessages(suppressMessages(library(magrittr, lib.loc=lib_path)))
suppressPackageStartupMessages(suppressMessages(library(jsonlite, lib.loc=lib_path)))
suppressPackageStartupMessages(suppressMessages(library(purrr, lib.loc=lib_path)))
suppressPackageStartupMessages(suppressMessages(library(progressr, lib.loc=lib_path)))
suppressPackageStartupMessages(suppressMessages(library(data.table, lib.loc=lib_path)))
suppressPackageStartupMessages(suppressMessages(library(qs, lib.loc=lib_path)))
suppressPackageStartupMessages(suppressMessages(library(arrow, lib.loc=lib_path)))
suppressPackageStartupMessages(suppressMessages(library(glue, lib.loc=lib_path)))
suppressPackageStartupMessages(suppressMessages(library(optparse, lib.loc=lib_path)))

option_list = list(
  make_option(c("-s", "--start_year"), action="store", default=hoopR:::most_recent_nba_season(), type='integer', help="Start year of the seasons to process"),
  make_option(c("-e", "--end_year"), action="store", default=hoopR:::most_recent_nba_season(), type='integer', help="End year of the seasons to process")
)
opt = parse_args(OptionParser(option_list=option_list))
options(stringsAsFactors = FALSE)
options(scipen = 999)
years_vec <- opt$s:opt$e
# --- compile into play_by_play_{year}.parquet ---------
nba_pbp_games <- function(y){

  cli::cli_process_start("Starting nba play_by_play parse for {y}!")
  pbp_g <- data.frame()
  pbp_list <- list.files(path = glue::glue('nba/json/final/'))
  sched <- data.table::fread(paste0('nba/schedules/csv/nba_schedule_',y,'.csv'))
  pbp_game_ids <- as.integer(gsub('.json','',pbp_list))
  pbp_list <- sched %>%
    dplyr::filter(.data$game_id %in% pbp_game_ids) %>%
    dplyr::pull("game_id")
  pbp_g <- purrr::map_dfr(pbp_list, function(x){
    pbp <- jsonlite::fromJSON(glue::glue('nba/json/final/{x}.json'))$plays
    if (length(pbp)>1) {
      pbp$game_id <- x
    }
    return(pbp)
  })
  if (nrow(pbp_g)>0 && length(pbp_g)>1) {
    pbp_g <- pbp_g %>% janitor::clean_names()
    pbp_g <- pbp_g %>%
      dplyr::mutate(
        game_id = as.integer(.data$game_id)
      )
  }
  if (!('coordinate_x' %in% colnames(pbp_g)) && length(pbp_g)>1) {
    pbp_g <- pbp_g %>%
      dplyr::mutate(
        coordinate_x = NA_real_,
        coordinate_y = NA_real_
      )
  }
  if (!('type_abbreviation' %in% colnames(pbp_g)) && length(pbp_g)>1) {
    pbp_g <- pbp_g %>%
      dplyr::mutate(
        type_abbreviation = NA_character_
      )
  }
  if (nrow(pbp_g)>1){
    pbp_g <- pbp_g %>%
      hoopR:::make_hoopR_data("ESPN NBA Play-by-Play Information from hoopR data repository",Sys.time())

    ifelse(!dir.exists(file.path("nba/pbp")), dir.create(file.path("nba/pbp")), FALSE)
    ifelse(!dir.exists(file.path("nba/pbp/csv")), dir.create(file.path("nba/pbp/csv")), FALSE)
    data.table::fwrite(pbp_g, file = paste0("nba/pbp/csv/play_by_play_", y, ".csv.gz"))

    ifelse(!dir.exists(file.path("nba/pbp/qs")), dir.create(file.path("nba/pbp/qs")), FALSE)
    qs::qsave(pbp_g, glue::glue("nba/pbp/qs/play_by_play_{y}.qs"))

    ifelse(!dir.exists(file.path("nba/pbp/rds")), dir.create(file.path("nba/pbp/rds")), FALSE)
    saveRDS(pbp_g, glue::glue("nba/pbp/rds/play_by_play_{y}.rds"))

    ifelse(!dir.exists(file.path("nba/pbp/parquet")), dir.create(file.path("nba/pbp/parquet")), FALSE)
    arrow::write_parquet(pbp_g, paste0("nba/pbp/parquet/play_by_play_",y,".parquet"))
  }

  sched <- sched %>%
    dplyr::mutate(
      game_id = as.integer(.data$id),
      status_display_clock = as.character(.data$status_display_clock)
    )
  if (nrow(pbp_g)>0) {
    sched <- sched %>%
      dplyr::mutate(
        PBP = ifelse(.data$game_id %in% unique(pbp_g$game_id), TRUE, FALSE)
      )
  } else {
    sched$PBP <- FALSE
  }
  final_sched <- dplyr::distinct(sched) %>% dplyr::arrange(desc(.data$date))
  final_sched <- final_sched %>%
    hoopR:::make_hoopR_data("ESPN NBA Schedule Information from hoopR data repository", Sys.time())
  data.table::fwrite(final_sched, paste0("nba/schedules/csv/nba_schedule_",y,".csv"))
  qs::qsave(final_sched, glue::glue('nba/schedules/qs/nba_schedule_{y}.qs'))
  saveRDS(final_sched, glue::glue('nba/schedules/rds/nba_schedule_{y}.rds'))
  arrow::write_parquet(final_sched, glue::glue('nba/schedules/parquet/nba_schedule_{y}.parquet'))
  rm(sched)
  rm(final_sched)
  rm(pbp_g)
  gc()
  cli::cli_process_done(msg_done = "Finished nba play_by_play parse for {y}!")
  return(NULL)
}

all_games <- purrr::map(years_vec, function(y){
  nba_pbp_games(y)
})


sched_list <- list.files(path = glue::glue('nba/schedules/csv/'))
sched_g <-  purrr::map_dfr(sched_list, function(x){
  sched <- data.table::fread(paste0('nba/schedules/csv/',x)) %>%
    dplyr::mutate(
      status_display_clock = as.character(.data$status_display_clock)
    )
  return(sched)
})

sched_g <- sched_g %>%
  hoopR:::make_hoopR_data("ESPN NBA Schedule Information from hoopR data repository",Sys.time())

data.table::fwrite(sched_g %>% dplyr::arrange(desc(.data$date)), 'nba_schedule_master.csv')
data.table::fwrite(sched_g %>% dplyr::filter(.data$PBP == TRUE) %>% dplyr::arrange(desc(.data$date)), 'nba/nba_games_in_data_repo.csv')
qs::qsave(sched_g %>% dplyr::arrange(desc(.data$date)), 'nba_schedule_master.qs')
qs::qsave(sched_g %>% dplyr::filter(.data$PBP == TRUE) %>% dplyr::arrange(desc(.data$date)), 'nba/nba_games_in_data_repo.qs')
arrow::write_parquet(sched_g %>% dplyr::arrange(desc(.data$date)),glue::glue('nba_schedule_master.parquet'))
arrow::write_parquet(sched_g %>% dplyr::filter(.data$PBP == TRUE) %>% dplyr::arrange(desc(.data$date)), 'nba/nba_games_in_data_repo.parquet')


rm(sched_g)
rm(sched_list)
rm(years_vec)
gc()