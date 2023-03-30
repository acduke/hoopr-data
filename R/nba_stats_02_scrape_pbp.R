rm(list = ls())
gcol <- gc()
lib_path <- Sys.getenv("R_LIBS")
if (!requireNamespace('pacman', quietly = TRUE)) {
  install.packages('pacman', lib = Sys.getenv("R_LIBS"), repos = 'http://cran.us.r-project.org')
}
suppressPackageStartupMessages(suppressMessages(library(dplyr, lib.loc = lib_path)))
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
opt <- parse_args(OptionParser(option_list = option_list))
options(stringsAsFactors = FALSE)
options(scipen = 999)
years_vec <- (opt$s - 1):(opt$e - 1)
rescrape <- opt$r

proxies_df <- get_proxy_ips()


seasons_vec <- unlist(purrr::map(years_vec, function(x){hoopR::year_to_season(x)}))


nba_stats_pbp_games <- function(season){


  schedules_df <- data.table::fread(paste0("nba_stats/schedules/csv/schedule_", season, ".csv")) %>%
    dplyr::filter(.data$game_status == 3)

  ifelse(!dir.exists(file.path("nba_stats/json")), dir.create("nba_stats/json"), FALSE)
  pbp_list <- list.files(path = "nba_stats/json")

  if (length(pbp_list) > 0) {
    pbp_list <- as.integer(stringr::str_extract(pbp_list, "\\d+"))
    pbp_list <- gsub('.json', '', pbp_list)
    pbp_list <- lapply(pbp_list, function(x){hoopR:::pad_id(x)})
  }

  if (rescrape == FALSE) {
    schedules_year <- schedules_df %>%
      dplyr::filter(.data$season == season,
                    !(.data$game_id %in% pbp_list))
  } else {
    schedules_year <- schedules_df
  }

  games_list <- unique(schedules_year$game_id)

  if (length(games_list) > 0) {

    cli::cli_progress_step(msg = "Downloading {season} NBA Stats pbps ({length(games_list)} games)",
                           msg_done = "Downloaded {season} NBA Stats pbps!")

    future::plan("multisession")
    nba_pbp_stats <- furrr::future_map_dfr(1:length(games_list), function(x) {

      df <- hoopR::nba_pbp(game_id = games_list[x], proxy = select_proxy(proxies = proxies_df))
      jsonlite::write_json(df, path = paste0("nba_stats/json/", hoopR:::pad_id(games_list[x]), ".json"))
      Sys.sleep(1)

    },
    .options = furrr::furrr_options(seed = TRUE))
  } else {
    print(glue::glue("Skipping {season} season, {length(games_list)} completed games left to scrape"))
  }

}
cli::cli_progress_step("Downloading {opt$s - 1}-{substr(opt$s,3,4)} to {opt$e -1}-{substr(opt$e,3,4)} seasons of NBA Stats play-by-play data",
                       msg_done = "Downloaded {opt$s - 1}-{substr(opt$s,3,4)} to {opt$e -1}-{substr(opt$e,3,4)} seasons of NBA Stats play-by-play data")

all_games <- purrr::map(seasons_vec, function(y){
  nba_stats_pbp_games(y)
})

cli::cli_progress_message("")