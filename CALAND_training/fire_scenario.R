# CALAND training fire scenario
#   October, 31, 2019
#   Sacramento, California

# Fire management statewide, by 2100
# BASELINE: CALAND given - but only harvest practices 
# ALTERNATIVE A: CA forest is treated 1% per year, repeat every 20 yrs, thinning + burn
# ALTERNATIVE B: CA forest is treated 1% per year, repeat every 20 yrs, understory + burn

library('XLConnect') 

setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory

source('write_caland_inputs.r') # call function to use soon
write_caland_inputs(scenarios_file = 'fire_management2100_ac_11_05_19.xls', 
                    units_scenario = "ac", # acres
                    climate_c_file = "climate_c_scalars_iesm_rcp45.csv", # scalars from CESM to adapt for future RCP4.5 climate 
                    fire_area_file = "fire_area_canESM2_45_bau_2001_2100.csv",
                    land_change_method = "Landuse_Avg_Annual",
                    scen_tag = "11_05_19_fire_mgmt_2100", # this is the filename appended to the run
                    end_year = 2101, # run to year after final management year
                    CLIMATE = "PROJ") # PROJ indicates projected climate 


# SET THIS UP FOR TERMINAL
# mean baseline
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Baseline_11_05_19_fire_mgmt_2100_RCP45.xls",
       end_year = 2101, 
       blackC = FALSE,
       value_col_dens = 7, # mean
       value_col_accum = 7, # mean
       ADD_dens = TRUE,
       ADD_accum = TRUE,
       NR_Dist = 120)

# alt a baseline
#R # open R if not already in terminal window
#setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
#source('CALAND.r')
CALAND(scen_file_arg = "Alternative_A_11_05_19_fire_mgmt_2100_RCP45.xls",
       end_year = 2101, 
       blackC = FALSE,
       value_col_dens = 7, # mean
       value_col_accum = 7, # mean
       ADD_dens = TRUE,
       ADD_accum = TRUE,
       NR_Dist = 120)


# alt b baseline
#R # open R if not already in terminal window
#setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
#source('CALAND.r')
CALAND(scen_file_arg = "Alternative_B_11_05_19_fire_mgmt_2100_RCP45.xls",
       end_year = 2101, 
       blackC = FALSE,
       value_col_dens = 7, # mean
       value_col_accum = 7, # mean
       ADD_dens = TRUE,
       ADD_accum = TRUE,
       NR_Dist = 120)


# RUN IN TERMINAL
# set up plot caland
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_11_05_19_fire_mgmt_2100_RCP45_output_mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_A_11_05_19_fire_mgmt_2100_RCP45_output_mean_BC1_NR120.xls',
                            'Alternative_B_11_05_19_fire_mgmt_2100_RCP45_output_mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_A_firemgmt','Alt_B_firemgmt'), # label 
            data_dir = "./outputs/fire_mgmt_2100",
            lt = 'Forest',
            reg = c('All_region'), 
            own = c('All_own'), 
            figdir = 'mean',
            last_year = 2101)

# Plot scen types
# can run in R Studo
source('plot_scen_types.r')
plot_scen_types(varname = 'Total_CumCO2eq_all_diff',
                data_dir = "./outputs/fire_mgmt_2100",
                ylabel = 'Change from baseline (MMT CO2eq)',
                lt = 'Forest',
                reg = 'All_region',
                figdir = 'mean',
                file_tag = 'forest')


