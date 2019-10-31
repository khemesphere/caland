# CALAND training fire scenario
#   October, 29, 2019
#   Sacramento, California

# Fire management statewide

setwd('/Users/khemes/Repos/midden/Models/caland-v3.0.0') # set working directory


source('write_caland_inputs.r') # call function to use soon
write_caland_inputs(scenarios_file = 'fire_management_ac_10_29_19.xls', 
                    units_scenario = "ac", # acres
                    climate_c_file = "climate_c_scalars_iesm_rcp85.csv", # scalars from CESM to adapt for future RCP8.5 climate 
                    fire_area_file = "fire_area_canESM2_85_bau_2001_2100.csv",
                    land_change_method = "Landuse_Avg_Annual",
                    scen_tag = "10_29_19_firesce", # this is the filename appended to the run
                    end_year = 2016, # run to year after final management year
                    CLIMATE = "PROJ") # PROJ indicates projected climate 


# SET THIS UP FOR TERMINAL
# mean baseline
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/caland-v3.0.0') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Baseline_10_29_19_firesce_RCP85.xls",
       end_year = 2016, 
       blackC = FALSE,
       value_col_dens = 7, # mean
       value_col_accum = 7, # mean
       ADD_dens = TRUE,
       ADD_accum = TRUE,
       NR_Dist = 120)

# alt a baseline
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/caland-v3.0.0') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Alternative_A_10_29_19_firesce_RCP85.xls",
       end_year = 2016, 
       blackC = FALSE,
       value_col_dens = 7, # mean
       value_col_accum = 7, # mean
       ADD_dens = TRUE,
       ADD_accum = TRUE,
       NR_Dist = 120)


# alt b baseline
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/caland-v3.0.0') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Alternative_B_10_29_19_firesce_RCP85.xls",
       end_year = 2016, 
       blackC = FALSE,
       value_col_dens = 7, # mean
       value_col_accum = 7, # mean
       ADD_dens = TRUE,
       ADD_accum = TRUE,
       NR_Dist = 120)


# set up plot caland
R
setwd('/Users/khemes/Repos/midden/Models/caland-v3.0.0') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_firesce_RCP85_output_mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_A_10_29_19_firesce_RCP85_output_mean_BC1_NR120.xls',
                            'Alternative_B_10_29_19_firesce_RCP85_output_mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_A','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('All_region'), 
            own = c('All_own'), 
            figdir = 'mean',
            last_year = 2016)


