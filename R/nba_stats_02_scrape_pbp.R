pacman::p_load("dplyr","purrr","stringr","data.table", "qs","arrow", "progressr")
source('R/utils.R')

years_vec <- 2022
schedules_df <- data.table::fread("nba_stats_schedule_master.csv") %>% 
  dplyr::filter(.data$game_status == 3)

seasons_vec <- unlist(purrr::map(years_vec, function(x){hoopR::year_to_season(x)})) 

proxies_df <- get_proxy_ips()
rescrape <- FALSE
year_json_scrape <- function(seasons_vec){
  
  for (i in 1:length(seasons_vec)) {
    print(seasons_vec[[i]])
    ifelse(!dir.exists(file.path(paste0("nba_stats/", years_vec[[i]]))), dir.create(paste0("nba_stats/", years_vec[[i]])), FALSE)
    
    pbp_list <- as.integer(stringr::str_extract(list.files(path = glue::glue('nba_stats/', years_vec[[i]])), "\\d+"))
    pbp_list <- gsub('.json', '', pbp_list)
    
    if (rescrape == FALSE) {
      schedules_year <- schedules_df %>% 
        dplyr::filter(.data$Season == seasons_vec[[i]],
                      !(.data$game_id %in% pbp_list))
    }
    yr <- years_vec[[i]]
    games_list <- unique(schedules_year$game_id)
    print(length(games_list))
    if (length(games_list) > 0) {
      future::plan("multisession")
      nba_pbp_stats <- furrr::future_map_dfr(1:length(games_list), function(x){
        df <- hoopR::nba_pbp(game_id = games_list[x], proxy = select_proxy(proxies = proxies_df))
        jsonlite::write_json(df, path = paste0("nba_stats/", yr, "/", games_list[x], ".json"))
        Sys.sleep(1)
        # if (x %% 200 == 0) {
        #   Sys.sleep(60)
        # }
      })
    } else {
      print(glue::glue("Skipping {yr}, {length(games_list)} completed games left to scrape"))
    }
  }
}

year_json_scrape(seasons_vec)