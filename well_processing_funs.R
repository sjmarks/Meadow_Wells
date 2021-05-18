#### Packages

library(plyr)
library(tidyverse)
library(lubridate)
library(data.table)


#### Barometric Correction Function

# **Description**
#   
# Written based off this resource from Onset: link[https://www.onsetcomp.com/support/tech-note/barometric-compensation-method/] `barometric_datafile_correction` corrects HOBO U20 logger data for barometric. 
# 
# **Arguments**
#   
# * `logger.data` data to correct, as a data.frame. First three variables (columns) of data.frame should reflect **in order**; Date/timestamp, measured pressure in PSI, measured temperature in deg. F
# * `baro.data` barometric data used to correct, as a data.frame. First three variables (columns) of data.frame should reflect **in order**; Date/timestamp, measured barometric pressure in PSI, measured temperature in deg. F
# 
# **Value**
#   
# A data.frame

barometric_datafile_correction <- function(logger.data, baro.data) {
  
  colnames(logger.data) <- c("Date", "total.pressure_psi", "temp.ref_F")
  colnames(baro.data) <- c("Date", "baro.pressure_psi", "baro.temp_F")
  
  logger.dt <- logger.data %>%
    filter(!is.na(Date),
           !is.na(total.pressure_psi), !is.na(temp.ref_F)) %>%
    data.table(key = 'Date')
  
  baro.dt <- data.table(filter(baro.data, !is.na(Date), 
                               !is.na(baro.pressure_psi), !is.na(baro.temp_F)),
                        key = 'Date')
  
  logger.baro.dt <- baro.dt[logger.dt, roll = 'nearest']
  
  logger.baro.dt <- logger.baro.dt %>%
    dplyr::mutate(water.pressure_psi = total.pressure_psi - baro.pressure_psi) %>%
    dplyr::select(-baro.temp_F)
  
  level.conversion <- logger.baro.dt %>% 
    # convert temperature of water logger at reference time to deg c for density computation
    dplyr::mutate(temp.ref_C = (temp.ref_F - 32) * (5/9)) %>% 
    # Compute density of water at reference time (lb/ft^3)
    dplyr::mutate(h2o.density = ((999.83952 + (16.945176 * temp.ref_C) - (7.9870401 * 10^-3 * temp.ref_C^2) - (46.170461 * 10^-6 * temp.ref_C^3) + (105.56302 * 10^-9 * temp.ref_C^4) - (280.54253 * 10^-12 * temp.ref_C^5))/(1 + (16.879850 * 10^-3 * temp.ref_C))) * 0.0624279606) %>%
    # compute water level above sensor in ft.
    dplyr::mutate(water.level.above.sensor = round(((water.pressure_psi * 144) / h2o.density), digits = 3)) %>% 
    dplyr::select(-h2o.density, -water.pressure_psi, -temp.ref_C)
  
  if(min(logger.dt$Date) < min(baro.dt$Date) || max(logger.dt$Date) > max(baro.dt$Date))
    warning(sprintf('URGENT: Time range for logger data (%s - %s) is not contained within time range for baro data (%s - %s). Data will be incorrectly compensated.', format(min(logger.dt$Date), '%Y-%m-%d %H:%M'), format(max(logger.dt$Date), '%Y-%m-%d %H:%M'), format(min(baro.dt$Date), '%Y-%m-%d %H:%M'), format(max(baro.dt$Date), '%Y-%m-%d %H:%M')))
  
  return(level.conversion)
  
}

#### Read HOBO U20 atmospheric datafile

# **Description**
#   
# `read_atm_hobo_u20` reads Hobo u20 produced atmospheric pressure `.csv` files into R. 
# Returns a data.frame usable in `barometric_datafile_correction`'s `baro.data` argument. 
# 
# **Arguments**
# 
# * `path` path to raw `.csv` atmospheric datafile produced by HOBO U20
# 
# **Value**
# 
# A data.frame

read_atm_hobo_u20 <- function(path){
  
  # Avoid problem of not knowing the number of cols coming from Hobo file (i.e. avoid warning)
  no_of_cols <- readr::read_csv(path, skip = 1, n_max = 1, col_types = cols(.default = col_guess())) %>% 
    ncol()
  
  no_of_cols_drop_at_end <- no_of_cols - 4
  
  data <- readr::read_csv(path, skip = 2, 
                          col_types = paste0("_cdd", stringi::stri_dup("_", no_of_cols_drop_at_end)), 
                          col_names = c("Date", "baro.pressure_psi", "baro.temp_F")) %>% 
    dplyr::mutate(Date = lubridate::mdy_hms(Date)) %>% 
    dplyr::filter(!is.na(baro.pressure_psi))
  
  return(data)
  
}

#### Helper function `coalesce_join`

# **Description**
#   
# `coalesce_join` performs a majority of the data aggregation work within the `process_well_data`. The function combines two datasets containing identical non-key variables in varying states of completeness. This allows for the well data compilation to be updated/appended to without worry of overlap with the existing time series in the existing compilation.
# 
# **Arguments:**
#   
# * `x`, `y` tbls to join
# * `by` a character vector of variables to join by. If NULL, the default, *_join() defined by the `join` argument will do a natural join, using all variables with common names across the two tables. A message lists the variables so that you can check they're right (to suppress the message, simply explicitly list the variables that you want to join).
# * `suffix` If there are non-joined duplicate variables in x and y, these suffixes will be added to the output to disambiguate them. Should be a character vector of length 2
# * `join` type of mutating join supported by `dplyr`
# * ... other parameters passed onto methods, for instance, `na_matches` to control how NA values are matched. This is mostly included for robustness.
# 
# **Value**
# 
# A data frame `tbl_df`

coalesce_join <- function(x, y, 
                          by = NULL, suffix = c(".x", ".y"), 
                          join = dplyr::full_join, ...) {
  
  joined <- join(x, y, by = by, suffix = suffix, ...)
  
  # names of desired output
  cols <- dplyr::union(names(x), names(y))
  
  to_coalesce <- names(joined)[!names(joined) %in% cols]
  
  suffix_used <- suffix[ifelse(endsWith(to_coalesce, suffix[1]), 1, 2)]
  
  # remove suffixes and deduplicate
  to_coalesce <- unique(substr(
    to_coalesce, 
    1, 
    nchar(to_coalesce) - nchar(suffix_used)
  ))
  
  coalesced <- purrr::map_dfc(to_coalesce, ~dplyr::coalesce(
    joined[[paste0(.x, suffix[1])]], 
    joined[[paste0(.x, suffix[2])]]
  ))
  
  names(coalesced) <- to_coalesce
  
  dplyr::bind_cols(joined, coalesced)[cols]
}

#### Helper Function `clean_dwyer`

# **Description**
#   
# `clean_dwyer` reads in Dwyer pressure transducer setup `.txt` files, calculates and Q/C `water.level.above.sensor` values, and calculates depth to groundwater. 
# 
# **Arguments**
#   
# * `path` path to raw `.txt` well data file
# 
# **Value**
#   
# A data.frame

clean_dwyer <- function(path){
  
  column_names <- readr::read_lines(path, n_max = 1) %>% 
    stringr::str_split(pattern = ",") %>% 
    purrr::pluck(1) %>% 
    stringr::str_trim()
  
  ID <- column_names[1]
  
  weird_first_line <- readr::read_csv(path, n_max = 1, skip = 1, col_names = column_names,
                                      col_types = cols(.default = col_double(), 
                                                       `Serial Number` = col_character(), Time = col_datetime(format = ""))) %>% 
    dplyr::select(-`Serial Number`)
  
  # read in fun. parses date to POSIXct 
  data <- readr::read_csv(path, skip = 2, col_names = column_names[1:3], 
                          col_types = cols(.default = col_double(), Time = col_datetime(format = ""))) 
  
  data <- dplyr::bind_rows(weird_first_line, data) %>% 
    dplyr::rename(Date = Time, total.pressure_psi = `Current(PSI)`) %>% 
    dplyr::select(Date, total.pressure_psi) %>% 
    dplyr::mutate(ID = ID) %>% 
    # replace erronous measurments with NA (i.e. when battery system failed)
    ##### UNSURE IF I SHOULD MANAGE THIS DIFFERENTLY
    dplyr::mutate(total.pressure_psi = dplyr::case_when(
      total.pressure_psi < 0 ~ NA_real_,
      TRUE ~ total.pressure_psi
    )) %>% 
    # compute depth above the sensor from psi measurement (assumes density of freshwater = 997.0474 kg/m^3)
    #### UNSURE HOW THIS CONVERSION HAS BEEN DONE IN THE PAST
    dplyr::mutate(water.level.above.sensor = round((total.pressure_psi/0.432), digits =3)) %>%
    # Add well length and well riser info based on condition of ID- riser and lengths from Well dimensions .docx
    dplyr::mutate(well_length_ft = dplyr::case_when(
      ID == "RCW1" ~ 10,
      ID == "RCW2" ~ 1.5/0.3048,
      ID == "RCW3" ~ 10,
      ID == "RCW6" ~ 10,
      ID == "MM3W" ~ 10,
      ID == "CM0W" ~ 10,
      ID == "CM1W" ~ 66/12,
      ID == "CM2W" ~ 75.5/12,
      ID == "CM3W" ~ 75.5/12,
      ID == "CM4W" ~ 10
    )) %>%
    # riser lengths were converted from cm to ft
    dplyr::mutate(well_riser_ft = dplyr::case_when(
      ID == "RCW1" ~ (15/2.54)/12,
      ID == "RCW2" ~ (9/2.54)/12,
      ID == "RCW3" ~ (42/2.54)/12,
      ID == "RCW6" ~ (15/2.54)/12,
      ID == "MM3W" ~ 8/12,
      ID == "CM0W" ~ (34/2.54)/12,
      ID == "CM1W" ~ 8.5/12,
      ID == "CM2W" ~ 23.5/12,
      ID == "CM3W" ~ 23/12,
      ID == "CM4W" ~ (9.3/2.54)/12
    )) %>% 
    # check to make sure that negative depths are resolved to depth of 0
    dplyr::mutate(water.level.above.sensor = dplyr::case_when(
      water.level.above.sensor < 0 ~ 0,
      TRUE ~ water.level.above.sensor
    )) %>%
    # compute depth to gw
    dplyr::mutate(depth.gw_ft = round(((well_length_ft - well_riser_ft) - water.level.above.sensor), digits = 3)) %>% 
    # drop unnecessary vars
    dplyr::select(-well_length_ft, -well_riser_ft, -total.pressure_psi)
  
  return(data)
}

#### Helper Function `clean_hobo_u20`

# **Description**
#   
#   `clean_hobo_u20` reads in barometric corrected Hobo u20 produced `.csv` files, performs Q/C for erroneous `water.level.above.sensor` values, and calculates depth to groundwater. 
# 
# **Arguments**
#   
#   * `path` path to raw `.csv` barometric corrected well data file
# 
# **Value**
#   
#   A data.frame

clean_hobo_u20 <- function(path){
  
  ## files with barometric correction performed in HoboWare
  if(stringr::str_detect(path, "_hobocorrected")){
    
    # Deduce site ID from first line of file
    ID <- readr::read_csv(path, n_max = 1, col_names = FALSE, col_types = cols(.default = col_character())) %>% 
      dplyr::pull(var = X1) %>%
      as.character() %>%
      # extracts everything after a colon
      stringr::str_extract(pattern = "[^:]*$") %>%
      stringr::str_trim()
    
    # Avoid problem of not knowing the number of cols coming from Hobo Corrected file 
    no_of_cols <- readr::read_csv(path, skip = 1, n_max = 1, col_types = cols(.default = col_guess())) %>% 
      ncol()
    
    no_of_cols_drop_at_end <- no_of_cols - 6
    
    data <- readr::read_csv(path, skip = 2, col_types = paste0("_cdddd", stringi::stri_dup("_", no_of_cols_drop_at_end)), 
                            col_names = c("Date", "total.pressure_psi", "temp.ref_F", "baro.pressure_psi", "water.level.above.sensor"))
    
    # parse date time
    # Add well length and well riser info based on condition of ID- riser and lengths from README
    data <- data %>%
      dplyr::filter(!is.na(Date), !is.na(total.pressure_psi)) %>%
      dplyr::mutate(Date = lubridate::mdy_hms(Date)) %>%
      dplyr::mutate(ID = ID) %>%
      dplyr::mutate(well_length_ft = dplyr::case_when(
        ID == "RCW1" ~ 10,
        ID == "RCW2" ~ 1.5/0.3048,
        ID == "RCW3" ~ 10,
        ID == "RCW6" ~ 10,
        ID == "MM2W" ~ 60.5/12,
        ID == "MM3W" ~ 10,
        ID == "MM4W" ~ 66/12,
        ID == "MM5W" ~ 65/12,
        ID == "MM6W" ~ 76/12,
        ID == "MM7W" ~ 10,
        ID == "CM0W" ~ 10,
        ID == "CM1W" ~ 66/12,
        ID == "CM2W" ~ 75.5/12,
        ID == "CM3W" ~ 75.5/12,
        ID == "CM4W" ~ 10,
        ID == "Childs_T2" ~ 3.937,
        ID == "Childs_T3" ~ 3.609
      )) %>% 
      # riser lengths were converted from cm to ft where necessary
      dplyr::mutate(well_riser_ft = dplyr::case_when(
        ID == "RCW1" ~ (15/2.54)/12,
        ID == "RCW2" ~ (9/2.54)/12,
        ID == "RCW3" ~ (42/2.54)/12,
        ID == "RCW6" ~ (15/2.54)/12,
        ID == "MM2W" ~ 14.5/12,
        ID == "MM3W" ~ 8/12,
        ID == "MM4W" ~ 4/12,
        ID == "MM5W" ~ 3/12,
        ID == "MM6W" ~ 20/12,
        ID == "MM7W" ~ 6.5/12,
        ID == "CM0W" ~ (34/2.54)/12,
        ID == "CM1W" ~ 8.5/12,
        ID == "CM2W" ~ 23.5/12,
        ID == "CM3W" ~ 23/12,
        ID == "CM4W" ~ (9.3/2.54)/12,
        ID == "Childs_T2" ~ 1.5,
        ID == "Childs_T3" ~ 1
      )) %>%
      # check to make sure that negative depths are resolved to depth of 0
      dplyr::mutate(water.level.above.sensor = dplyr::case_when(
        water.level.above.sensor < 0 ~ 0,
        TRUE ~ water.level.above.sensor
      )) %>%
      # compute depth to gw
      dplyr::mutate(depth.gw_ft = round(((well_length_ft - well_riser_ft) - water.level.above.sensor), digits = 3)) %>% 
      dplyr::select(-temp.ref_F, -baro.pressure_psi, -well_length_ft, -well_riser_ft, -total.pressure_psi)
    
    return(data)
    
  }
  
  ## files corrected using R script
  if(stringr::str_detect(path, "_corrected")){
    
    # parse date time
    # add well length and well riser info based on condition of ID- riser and lengths from README
    data <- readr::read_csv(path, col_types = "cddddc") %>% 
      dplyr::mutate(Date = lubridate::ymd_hms(Date)) %>% 
      dplyr::mutate(well_length_ft = dplyr::case_when(
        ID == "RCW1" ~ 10,
        ID == "RCW2" ~ 1.5/0.3048,
        ID == "RCW3" ~ 10,
        ID == "RCW6" ~ 10,
        ID == "MM2W" ~ 60.5/12,
        ID == "MM3W" ~ 10,
        ID == "MM4W" ~ 66/12,
        ID == "MM5W" ~ 65/12,
        ID == "MM6W" ~ 76/12,
        ID == "MM7W" ~ 10,
        ID == "CM0W" ~ 10,
        ID == "CM1W" ~ 66/12,
        ID == "CM2W" ~ 75.5/12,
        ID == "CM3W" ~ 75.5/12,
        ID == "CM4W" ~ 10,
        ID == "Childs_T2" ~ 3.937,
        ID == "Childs_T3" ~ 3.609
      )) %>% 
      # riser lengths were converted from cm to ft where necessary
      dplyr::mutate(well_riser_ft = dplyr::case_when(
        ID == "RCW1" ~ (15/2.54)/12,
        ID == "RCW2" ~ (9/2.54)/12,
        ID == "RCW3" ~ (42/2.54)/12,
        ID == "RCW6" ~ (15/2.54)/12,
        ID == "MM2W" ~ 14.5/12,
        ID == "MM3W" ~ 8/12,
        ID == "MM4W" ~ 4/12,
        ID == "MM5W" ~ 3/12,
        ID == "MM6W" ~ 20/12,
        ID == "MM7W" ~ 6.5/12,
        ID == "CM0W" ~ (34/2.54)/12,
        ID == "CM1W" ~ 8.5/12,
        ID == "CM2W" ~ 23.5/12,
        ID == "CM3W" ~ 23/12,
        ID == "CM4W" ~ (9.3/2.54)/12,
        ID == "Childs_T2" ~ 1.5,
        ID == "Childs_T3" ~ 1
      )) %>% 
      # check to make sure that negative depths are resolved to depth of 0
      dplyr::mutate(water.level.above.sensor = dplyr::case_when(
        water.level.above.sensor < 0 ~ 0,
        TRUE ~ water.level.above.sensor
      )) %>% 
      # compute depth to gw
      dplyr::mutate(depth.gw_ft = round(((well_length_ft - well_riser_ft) - water.level.above.sensor), digits = 3)) %>% 
      # drop unnecessary vars
      dplyr::select(-temp.ref_F, -baro.pressure_psi, -well_length_ft, -well_riser_ft, -total.pressure_psi)
    
    return(data)
    
  }
  
}

#### Helper

clean_well_data <- function(path){
  
  path <- stringr::str_to_lower(path)
  
  if(stringr::str_detect(path, pattern = ".txt")){
    
    data <- clean_dwyer(path = path)
    
    return(data)
    
  }
  
  if(stringr::str_detect(path, ".csv")){
    
    data <- clean_hobo_u20(path = path)
    
    return(data)
    
  }
  
}

#### Main Function `process_well_data`

# **Description**
#   
#   `process_well_data` takes a folder containing raw .csv files from one meadow site and performs well data compilation, appending to an existing compilation for that meadow site if prompted. Outputs a written .csv file.
# 
# **Arguments**
#   
# * `path` path to folder containing raw .csv well data files. This provided path is where the compilation .csv will be written to.
# * `site` meadow site where the raw files were collected- one of "Marian", "RC", "Control", or "Childs" in quotes
# * `prev_compile` previous data compilation. By default this is set to `NULL` 
# * `written_file` name of produced compilation file, must be quoted and end with .csv
# 
# **Value**
#   
#   A .csv file written to `path`
# 
# **Other notes**
#   
# Make sure that the first line of the HOBO U20 `.csv` file contains a **site ID** that is consistent with the column naming convention 
# in the file that is being appended to. If the file is `.txt` from a Dwyer setup make sure site ID is the first item in the header (first) 
# row of the file. See site naming convention in the table in the `README`. Suggestion is to edit the `.csv` or `.txt` file in NotePad. HOBO U 20 
# raw files need to have been corrected previously for barometric using `HOBOware Pro` software or the `barometric_datafile_correction` function 
# found in this repo. **ENSURE that files follow the proper naming convention that allows the functions to discern between the two data correction
# methods when compiling. `HOBOware Pro` corrected files should have "_hobocorrected" in their file name, while files corrected with the function 
# should have "_corrected in their name.**
  
process_well_data <- function(path, site, prev_compile = NULL, written_file_name = NULL){
  
  ## Control sequence checks before proceeding with function eval
  
  site <- stringr::str_to_lower(site)
  
  # Generic name for the outputted file based on site if a file name is not provided
  if(is.null(written_file_name)){
    written_file_name <- paste0("WellCompilation_", site, ".csv")
  }
  
  if(!stringr::str_detect(written_file_name, pattern = ".csv")){
    stop("provided written file name must end with .csv")
  }
  
  if(!site %in% c("marian", "rc", "control", "childs")){
    stop("site must be inputted as one of Marian, RC, Control, or Childs in quotes (not case sensitive).")
  }
  
  ## Create char. vector of file names w/ directory path prepended contained in provided path
  
  files <- list.files(path, full.names = TRUE)
  
  # make sure that function doesn't proceed with improper file naming convention
  if(!all(stringr::str_detect(files, "(?<![:alpha:])corrected|_hobo(?=corrected)"))){
    stop("ensure raw files have '_corrected' or '_hobocorrected` in all file names as appropriate")
  }
  
  ## Creates list of clean/standardized data (data frames) for all those provided in the path using `clean_SM_data` function
  
  listed_wells <- purrr::map(files, clean_well_data)
  
  ## Compiles well data using only those files provided in the path
  
  # Keeps files grouped by instrument and orders data chronologically. Duplicate observations are removed.
  compiled <- dplyr::bind_rows(listed_wells) %>% 
    dplyr::distinct() %>%
    dplyr::group_by(ID) %>% 
    # `dplyr::arrange` would not function properly here
    do(data.frame(with(data = .,.[order(Date),]))) %>% 
    ungroup()
  
  # Extract colnames for the compiled data
  compiled_colnames <- colnames(compiled) %>% 
    stringr::str_remove(pattern = "Date|ID")
  
  compiled_colnames <- compiled_colnames[compiled_colnames != ""]
  
  # Wide pivot the data with `names_from` ID, `values_from` compiled_colnames (excluding date and ID)
  compiled_pivoted <- compiled %>% 
    tidyr::pivot_wider(names_from = ID, values_from = all_of(compiled_colnames), values_fn = list) %>%
    tidyr::unnest(-Date, keep_empty = FALSE)
  
  if(is.null(prev_compile)){
    
    compiled_pivoted <- compiled_pivoted %>% 
      do(data.frame(with(data = .,.[order(Date),]))) %>%
      dplyr::distinct() %>%
      purrr::discard(~all(is.na(.))) %>% 
      dplyr::mutate(Date = as.character(Date))
    
    # Write out compiled file from provided files only 
    readr::write_csv(compiled_pivoted, path = paste0(path, "/", written_file_name))
    
    ## When prev_compile file is provided, the files provided in the path are appended to the previously compiled file
    # Performs coalescing join- user does not have to worry about feeding in data that has been previously compiled
  } else {
    
    appended_compile <- prev_compile %>%
      coalesce_join(compiled_pivoted, by = "Date") %>% 
      do(data.frame(with(data = .,.[order(Date),]))) %>%
      dplyr::distinct() %>% 
      purrr::discard(~all(is.na(.))) %>% 
      dplyr::mutate(Date = as.character(Date))
    
    # Write out appended compile file
    readr::write_csv(appended_compile, path = paste0(path, "/", written_file_name))
  }
  
}

## Temporal Aggregation Function

# **Description**
#   
# `temp_agg_meadow_dat` takes a data.frame of a meadow data compilation (e.g. soil moisture, well, climate, sap flow data) and 
# performs a temporal aggregation. 
# 
# **Arguments**
#   
# * `data` dataframe with data to aggregate, **must** contain a variable called "Date" of class `POSIXct` 
# * `start_day_of_week` an integer specifying the start day of the week for the temporal aggregation. 1 corresponds to Sunday and so on.
# * `interval` the function tries to determine the interval of the original time series (e.g. hourly) by calculating the most common interval between time steps. The interval is needed for calculations where the `data.thresh > 0` as is defaulted. For example, a time step of 30 minutes would be specified as `interval = "30 min"`
# * `avg.time` This defines the time period to average to. Can be “sec”, “min”, “hour”, “day”, “DSTday”, “week”, “month”, “quarter” or “year”. For much increased flexibility a number can precede these options followed by a space. For example, a 7 day aggregation would be `avg.time = "7 day"`. In addition, avg.time can equal “season”, in which case 3-month seasonal values are calculated with spring defined as March, April, May and so on.
# * `data.thresh` The data capture threshold to use (%). A value of zero means that all available data will be used in a particular period regardless if of the number of values available. Conversely, a value of 100 will mean that all data will need to be present for the average to be calculated, else it is recorded as NA. 
# * `statistic` The statistic to apply when aggregating the data; default is the mean. Can be one of “mean”, “max”, “min”, “median”, “sd”. "sd" is standard deviation.
# 
# **Value**
#   
# A data.frame with Date in class `POSIXct` and WY in class `numeric`. WY indicates the water year that the aggregation belongs to.
# 
# **Other notes**
#   
# Make sure there is a variable in the supplied data.frame called "Date"

temp_agg_meadow_dat <- function(data, start_day_of_week, interval = "30 min", avg.time = "7 day", data.thresh = 50, statistic = "mean"){
  
  # data <- readr::read_csv(path, col_types = cols(Date = col_character(), .default = col_double())) %>% 
  #   dplyr::mutate(Date = as.POSIXct(Date, tz = "UTC"))
  
  # path_write_out <- paste0(stringr::str_replace(path, "[^/]+$", replacement = ""), file_name_write)
  
  # Determine the dates corresponding to the first and last of chosen weekday (start date for averaging) present in data
  start_date <- data %>% 
    dplyr::mutate(is.chosen_wday = ifelse(lubridate::wday(Date) == start_day_of_week, T, F)) %>%
    dplyr::filter(is.chosen_wday == TRUE) %>% 
    dplyr::summarise(min(Date)) %>% 
    dplyr::pull()
  
  end_date <- data %>% 
    dplyr::mutate(is.chosen_wday = ifelse(lubridate::wday(Date) == start_day_of_week - 1, T, F)) %>%
    dplyr::filter(is.chosen_wday == TRUE) %>% 
    dplyr::summarise(max(Date)) %>% 
    dplyr::pull()
  
  data <- data %>% 
    # rename Date variable to "date" to play nicely w/ openair::timeAverage
    dplyr::rename(date = Date) %>% 
    dplyr::filter(date >= start_date & date <= end_date)
  
  aggregation <- openair::timeAverage(data, avg.time = avg.time, 
                                      data.thresh = data.thresh, statistic = statistic,
                                      start.date = start_date, end.date = end_date, interval = interval) %>% 
    # determine water year membership of the time avg- this might need to be tweaked
    dplyr::mutate(WY = dplyr::case_when(
      date %within% lubridate::interval(ymd("2017-10-01", tz = "UTC"), 
                                        ymd("2018-09-30", tz = "UTC")) ~ 2018,
      date %within% lubridate::interval(ymd("2018-10-01", tz = "UTC"), 
                                        ymd("2019-09-30", tz = "UTC")) ~ 2019,
      date %within% lubridate::interval(ymd("2019-10-01", tz = "UTC"), 
                                        ymd("2020-09-30", tz = "UTC")) ~ 2020,
      date %within% lubridate::interval(ymd("2020-10-01", tz = "UTC"), 
                                        ymd("2021-09-30", tz = "UTC")) ~ 2021,
      date %within% lubridate::interval(ymd("2021-10-01", tz = "UTC"), 
                                        ymd("2022-09-30", tz = "UTC")) ~ 2022
    )) 
  # %>% 
  #   mutate(date = as.character(date)) %>% 
  #   rename(Date = date) %>%  
  #   # Write to .csv
  #   readr::write_csv(path = path_write_out)
  
}
  