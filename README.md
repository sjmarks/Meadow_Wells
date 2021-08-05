# Meadow_Wells

#### Processing functions for shallow well data collected at Rock Creek, Marian, Control, and Child's meadows near Chester, CA. Supports the research effort investigating the hydrologic response of montane meadows by conifer removal restoration. Research conducted by PI Chris Surfleet, California Polytechnic State University San Luis Obispo, NRES Dept.

The **functions** contained in this repo:

1. Read raw `.csv` files collected from Hobo Onset water depth recorders (U20/U20L).
2. Apply a barometric correction to water depth recorder data.
3. Compile well data (water depth above sensor and depth to water from ground surface) from a meadow site's respective network of wells in chronological order. Data is compiled in a "tidy" format.
4. Update a previous compilation for a given meadow site with newly collected raw data files from the field.
5. Compiles weekly averages of well data (or any time aggregation and/or several other summary statistics).

All functions are contained in the file `Well_Processing_revised.Rmd`. This document describes each function's purpose and usage in greater detail. Functions are also contained in `well_processing_funs.R` so they can be loaded into the global environment using a call to `source("well_processing_funs.R")`. The well data processing procedure is performed in the `.Rmd` files with file names indicating the month and year well data were collected in the field from research meadows. Raw data files are contained in sub-folders to this repo with nomenclature indicative of where and when files were collected in the field. Barometric correction of well data is performed in these folders, as well as weekly averaging. The functions are also able to compile files with baro correction done in HOBOware software. The weekly averaging process is only as recent as the NJuly 2021 sub-folders (CONTROL AND MARIAN ONLY).

**NOTE: Most recent compilation was done for data files collected in July 2021- `Well_Processing_July2021.Rmd` . . . Some compilations in this repo (July 2020, Aug 2020, Nov 2020) do not feature the most up to date functions in their respective `.Rmd` files due to improvements. Please reference `Well_Processing_revised.Rmd` or `Well_Processing_July2021.Rmd` for the next compilation process.**

**# TO DO (as of 8/5/2021)**

1. RCM and Childs weekly compilations. Leaving this up to Joe. Feel free to discard the weekly compilation that Simon completed for RCM back in Nov 2020 if needed (e.g choose different start date for averaging) to meet Joe's research needs and desires, Childs does not have an existing weekly compilation file FYI)


#### **Well dimensions and site IDs used in compilations:**

This info is reflected in the functions for calculating depth to groundwater, but is also included here for reference/completeness. Note site ID indicates the well name exactly how it should look on line 1 of barometric corrected files `.csv` to be compiled correctly.

| Site ID | Well Length | Riser   |
|---------|-------------|---------|
| MM2W    | 60.5 in     | 14.5 in |
| MM3W    | 10 ft       | 8 in    |
| MM4W    | 66 in       | 4 in    |
| MM5W    | 65 in       | 3 in    |
| MM6W    | 76 in       | 20 in   |
| MM7W    | 10 ft       | 6.5 in  |
| CM0W    | 10 ft       | 34 cm   |
| CM1W    | 66 in       | 8.5 in  |
| CM2W    | 75.5 in     | 23.5 in |
| CM3W    | 75.5 in     | 23 in   |
| CM4W    | 10 ft       | 9.3 cm  |
| RCW1    | 10 ft       | 15 cm   |
| RCW2    | 1.5 m       | 9 cm    |
| RCW3    | 10 ft       | 42 cm   |
| RCW6    | 10 ft       | 15 cm   |
| Childs_T2 | 3.937 ft    | 1.5 ft  |
| Childs_T3 | 3.609 ft    | 1 ft    |

#### **Barometric correction logs:**

##### **RCM**

| File           | Start           | End              | Baro file(s) used                           |
|----------------|-----------------|------------------|---------------------------------------------|
| RCW6 Sept 2019 | 5/30/2019 15:00 | 9/3/2019 17:00   | RC Sept 2020                                |
| RCW6 Apr 2020  | 9/3/2019 17:30  | 4/25/2020 12:00  | RC Apr 2020                                 |
| RCW6 July 2020 | 4/25/2020 12:30 | 7/6/2020 7:30    | RC July 2020                                |
| RCW6 Aug 2020  | 7/6/2020 8:00   | 8/17/2020 9:00   | RC Aug 2020; Control July 2020              |
| RCW6 Nov 2020  | 8/17/2020 10:00 | 11/21/2020 13:30 | RC Nov 2020                                 |
| RCW6 May 2021  | 11/21/2020 14:00| 5/01/2021 11:00  | RC May 2021                                 |
| RCW6 July 2021 | 05/01/2021 11:30| 7/06/2021 12:00  | RC July 2021                                |
| RCW1 July 2020 | 12/9/2019 12:00 | 7/6/2020 7:30    | RC July 2020                                |
| RCW1 Aug 2020  | 7/8/2020 18:00  | 8/17/2020 9:00   | RC Aug 2020; Control July 2020              |
| RCW1 Nov 2020  | 8/17/2020 10:00 | 11/21/2020 13:30 | RC Nov 2020                                 |
| RCW1 May 2021  | 11/21/2020 14:00| 5/01/2021 11:00  | RC May 2021                                 |
| RCW1 July 2021 | 05/01/2021 11:30| 7/06/2021 10:30  | RC July 2021                                |
| RCW2 Apr 2020  | 9/3/2019 11:00  | 4/25/2020 10:30  | RC Apr 2020                                 |
| RCW2 July 2020 | 4/25/2020 11:30 | 7/6/2020 7:30    | RC July 2020                                |
| RCW2 Nov 2020  | 7/6/2020 8:00   | 11/21/2020 13:30 | RC Aug 2020; Control July 2020; RC Nov 2020 |
| RCW2 May 2021  | 11/21/2020 14:00| 05/01/2021 09:30 | RC May 2021                                 |
| RCW1 July 2021 | 05/01/2021 10:00| 7/06/2021 11:00  | RC July 2021                                |
| RCW3 Aug 2020  | 7/9/2020 21:00  | 8/17/2020 9:00   | RC Aug 2020; Control July 2020              |
| RCW3 Nov 2020  | 8/17/2020 10:00 | 11/21/2020 13:30 | RC Nov 2020                                 |
| RCW3 May 2021  |11/21/2020 14:00 | 05/01/2021 08:30 | RC May 2021                                 |
| RCW3 July 2021 | 05/01/2021 9:00 | 7/06/2021 11:00  | RC July 2021                                |

##### **Marian**

| File           | Start           | End             | Baro file(s) used                               |
|----------------|-----------------|-----------------|-------------------------------------------------|
| MM2W July 2020 | 12/10/2019 9:30 | 7/7/2020 8:30   | CM July 2020                                    |
| MM2W May 2021  | 7/7/2020 9:00   | 3/5/2021 23:30  | CM Aug 2020; RC Aug 2020; CM May 2021           |
| MM2W July 2021 | 5/1/2021 17:00  | 7/5/2021 18:00  | CM July 2021                                    |
| MM3W July 2020 | 4/25/2020 16:00 | 7/7/2020 9:30   | CM July 2020                                    |
| MM3W Aug 2020  | 7/7/2020 10:30  | 8/17/2020 9:00  | RC Aug 2020; Control July 2020                  |
| MM3W Nov 2020  | 8/17/2020 9:30  | 11/23/2020 9:30 | Control Nov 2020                                |
| MM3W May 2021  | 11/23/2020 10:00| 5/1/2021 16:00  | Control May 2021                                |
| MM3W July 2021 | 5/1/2021 16:30  | 7/5/2021 18:00  | CM July 2021                                    |
| MM4W July 2020 | 4/25/2020 8:30  | 7/7/2020 10:00  | CM July 2020                                    |
| MM4W May 2021  | 7/7/2020 10:30  | 5/1/2021 16:00  | CM Aug 2020; RC Aug 2020; CM May 2021           |
| MM4W July 2021 | 5/1/2021 16:30  | 7/5/2021 18:00  | CM July 2021                                    |
| MM5W July 2020 | 4/25/2020 15:00 | 7/7/2020 11:00  | CM July 2020                                    |
| MM5W Nov 2020  | 7/7/2020 11:30  | 11/23/2020 8:30 | RC Aug 2020; Control Aug 2020; Control Nov 2020 |
| MM5W May 2021  | 11/23/2020 9:00 | 5/1/2021 16:00  | Control May 2021                                |
| MM5W July 2021 | 5/1/2021 16:30  | 7/5/2021 18:30  | CM July 2021                                    |
| MM7W July 2020 | 4/25/2019 11:00 | 7/7/2020 10:30  | CM July 2020                                    |
| MM7W Aug 2020  | 7/7/2020 11:00  | 8/17/2020 9:00  | RC Aug 2020; Control July 2020                  |
| MM7W Nov 2020  | 8/17/2020 9:30  | 11/23/2020 8:30 | Control Nov 2020                                |
| MM7W May 2021  | 11/23/2020 9:00 | 5/1/2021 16:00  | Control May 2021                                |
| MM7W July 2021 | 5/1/2021 16:30  | 7/5/2021 19:00  | CM July 2021                                    |
| MM6W Nov 2020  | 7/7/2020 10:30  | 11/23/2020 9:30 | RC Aug 2020; Control Aug 2020; Control Nov 2020 |
| MM6W May 2021  | 11/23/2020 10:00| 5/1/2021 16:00  | Control May 2021                                |
| MM6W July 2021 | 5/1/2021 16:30  | 7/5/2021 18:30  | CM July 2021                                    |

##### **Control**

| File            | Start           | End              | Baro file(s) used                               |
|-----------------|-----------------|------------------|-------------------------------------------------|
| CM0W Dec 2019   | 4/24/2019 16:30 | 12/8/2019 16:00  | CM July 2020                                    |
| CM0W April 2020 | 12/8/2019 16:30 | 4/26/2020 9:30   | CM Apr 2020                                     |
| CM0W July 2020  | 4/26/2020 10:30 | 7/7/2020 16:30   | CM July 2020                                    |
| CM0W Aug 2020   | 7/7/2020 17:00  | 8/17/2020 9:00   | RC Aug 2020; Control July 2020                  |
| CM0W Nov 2020   | 8/18/2020 9:30  | 11/23/2020 10:00 | Control Nov 2020                                |
| CM0W May 2021   | 11/23/2020 10:30| 5/01/2021 17:00  | Control May 2021                                |
| CM0W July 2021  | 5/1/2021 17:30  | 7/6/2021 7:30    | CM July 2021                                    |
| CM1W July 2020  | 12/8/2019 16:30 | 7/7/2020 15:30   | CM July 2020                                    |
| CM1W Aug 2020   | 7/7/2020 16:00  | 8/17/2020 9:00   | RC Aug 2020; Control July 2020                  |
| CM1W Nov 2020   | 8/18/2020 9:30  | 11/23/2020 9:00  | Control Nov 2020                                |
| CM1W May 2021   | 11/23/2020 09:30| 5/01/2021 16:30  | Control May 2021                                |
| CM1W July 2021  | 5/1/2021 17:00  | 7/6/2021 6:30    | CM July 2021                                    |
| CM3W July 2020  | 12/8/2019 17:00 | 7/7/2020 15:00   | CM July 2020                                    |
| CM3W Nov 2020   | 7/7/2020 16:30  | 11/23/2020 10:30 | RC Aug 2020; Control Aug 2020; Control Nov 2020 |
| CM3W May 2021   | 11/23/2020 11:00| 5/01/2021 16:30  | Control May 2021                                |
| CM3W July 2021  | 5/1/2021 17:00  | 7/6/2021 8:30    | CM July 2021                                    |
| CM4W July 2020  | 4/26/2020 11:30 | 7/7/2020 16:30   | CM July 2020                                    |
| CM4W Nov 2020   | 7/7/2020 17:00  | 11/23/2020 10:30 | RC Aug 2020; Control Aug 2020; Control Nov 2020 |
| CM4W May 2021   | 11/23/2020 11:00| 5/01/2021 16:30  | Control May 2021                                |
| CM4W July 2021  | 5/1/2021 17:00  | 7/6/2021 7:30    | CM July 2021                                    |
| CM2W Nov 2020   | 7/7/2020 17:00  | 11/23/2020 10:30 | RC Aug 2020; Control Aug 2020; Control Nov 2020 |
| CM2W May 2021   | 11/23/2020 11:00| 5/01/2021 16:30  | Control May 2021                                |
| CM2W July 2021  | 5/1/2021 17:00  | 7/6/2021 8:00    | CM July 2021                                    |

##### **Childs**

| File               | Start          | End              | Baro file(s) used                               |
|--------------------|----------------|------------------|-------------------------------------------------|
| ChildsT2 July 2020 | 9/5/2019 13:00 | 7/6/2020 10:00   | RC Aug 2020; Control Aug 2020; Control Nov 2020 |
| ChildsT2 Nov 2020  | 7/7/2020 13:30 | 11/23/2020 10:00 | RC Aug 2020; Control Aug 2020; Control Nov 2020 |
| ChildsT2 May 2021  | 11/23/2019 10:30 | 5/1/2021 16:00 | Control May 2021                                |
| ChildsT2 July 2021 | 5/1/2021 16:30 | 7/6/2021 9:00    | Control July 2021                               |
| ChildsT3 Nov 2020  | 9/5/2019 13:30 | 11/23/2020 10:00 | RC Aug 2020; Control Aug 2020; Control Nov 2020 |
| ChildsT3 May 2021  | 11/23/2019 11:00 | 5/1/2021 16:00 | Control May 2021                                | 
| ChildsT3 July 2021 | 5/1/2021 16:30 | 7/6/2021 8:00    | Control July 2021                               |

#### **Weekly compilation log:**

##### **RCM (SUBJECT TO CHANGE IF JOE WANTS TO)**

| Start Week Of | End Week Of   | Weekday start      |
|---------------|---------------|--------------------|
| 6/1/2019      | 11/14/2020    | Saturday (7)       |

##### **Marian**

| Start Week Of  | End Week Of   | Weekday start      |
|----------------|---------------|--------------------|
| 4/26/2019      | 6/25/2021    | Friday (6)          |

##### **Control**

| Start Week Of  | End Week Of   | Weekday start      |
|----------------|---------------|--------------------|
| 4/26/2019      | 6/25/2021    | Friday (6)          |
