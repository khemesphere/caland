# CALAND training workshop practice
#   October, 28-29, 2019
#   Sacramento, California

library('XLConnect')

## MODULE 3
# First prepare the input files 

setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('write_caland_inputs.r') # call function to use soon

write_caland_inputs(scenarios_file = 'my_first_scenarios_ac_10_29_19.xls', 
                    units_scenario = "ac", # acres
                    climate_c_file = "climate_c_scalars_iesm_rcp85.csv", # scalars from CESM to adapt for future RCP8.5 climate 
                    fire_area_file = "fire_area_canESM2_85_bau_2001_2100.csv",
                    land_change_method = "Landuse_Avg_Annual",
                    scen_tag = "10_29_19", # this is the filename appended to the run
                    end_year = 2022, # run to year after final management year
                    CLIMATE = "PROJ") # PROJ indicates projected climate 

# three input files, with scen_tag, placed in inputs subfolder

## MODULE 4
#   these are ready to go into CALAND model
#   set up here, but actually copy and paste into 6 terminal windows to make it much faster. 
#   For baseline and alternative, need mean runs, and + and - standard deviation

# 1: Baseline Average
#   mean outputs, baseline scenario, cblack is CO2 (FALSE), recommended fire regen, end year through year 2022
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Baseline_10_29_19_RCP85.xls",
      end_year = 2022, 
      blackC = FALSE,
      value_col_dens = 7, # mean
      value_col_accum = 7, # mean
      ADD_dens = TRUE,
      ADD_accum = TRUE,
      NR_Dist = 120)

# 2: Baseline Upper Uncertainty Bounds
#   upper uncertainty bound, baseline scenario, cblack is CO2 (FALSE), recommended fire regen, end year through year 2022
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Baseline_10_29_19_RCP85.xls",
       end_year = 2022, 
       blackC = FALSE,
       value_col_dens = 8, # std 
       value_col_accum = 8, # std
       ADD_dens = TRUE,
       ADD_accum = FALSE,
       NR_Dist = 120)

# 3: Baseline Lower Uncertainty Bounds
#   lower uncertainty bound, baseline scenario, cblack is CO2 (FALSE), recommended fire regen, end year through year 2022
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Baseline_10_29_19_RCP85.xls",
       end_year = 2022, 
       blackC = FALSE,
       value_col_dens = 8, # std 
       value_col_accum = 8, # std
       ADD_dens = FALSE,
       ADD_accum = TRUE,
       NR_Dist = 120)


# 4: Alternative Average
#   mean outputs, alternative B scenario, cblack is CO2 (FALSE), recommended fire regen, end year through year 2022
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Alternative_B_10_29_19_RCP85.xls",
       end_year = 2022, 
       blackC = FALSE,
       value_col_dens = 7,
       value_col_accum = 7,
       ADD_dens = TRUE,
       ADD_accum = TRUE,
       NR_Dist = 120)

# 5: Alternative Upper Uncertainty Bounds
#   mean outputs, alternative B scenario, cblack is CO2 (FALSE), recommended fire regen, end year through year 2022
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Alternative_B_10_29_19_RCP85.xls",
       end_year = 2022, 
       blackC = FALSE,
       value_col_dens = 8,
       value_col_accum = 8,
       ADD_dens = TRUE,
       ADD_accum = FALSE,
       NR_Dist = 120)

# 6: Alternative Lower Uncertainty Bounds
#   mean outputs, alternative B scenario, cblack is CO2 (FALSE), recommended fire regen, end year through year 2022
R # open R if not already in terminal window
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('CALAND.r')
CALAND(scen_file_arg = "Alternative_B_10_29_19_RCP85.xls",
       end_year = 2022, 
       blackC = FALSE,
       value_col_dens = 8,
       value_col_accum = 8,
       ADD_dens = FALSE,
       ADD_accum = TRUE,
       NR_Dist = 120)


## MODULE 5
#   Compare alternative and baseline
#   set up here, but actually copy and paste into terminal windows to make it much faster. 


# 1: Mean difference, All Region aggregate and Central Coast
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('All_region','Central_Coast'), # aggregate all regions, break out central coast
            own = c('All_own'), 
            figdir = 'mean',
            last_year = 2022)

# 2: Mean difference, Central Valley, Delta, Deserts
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('Central_Valley','Delta','Deserts'), # regions
            own = c('All_own'), 
            figdir = 'mean',
            last_year = 2022)

# 3: Mean difference, Eastside, Klamath, North_Coast
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('Eastside', 'Klamath', 'North_Coast'), # regions
            own = c('All_own'), 
            figdir = 'mean',
            last_year = 2022)

# 4: Mean difference, "Sierra_Cascades", "South_Coast", "Ocean"
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('Sierra_Cascades', 'South_Coast', 'Ocean'), # regions
            own = c('All_own'), 
            figdir = 'mean',
            last_year = 2022)

# 5: High Emission, All Region aggregate and Central Coast
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_D+sd_A-sd_S=mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_D+sd_A-sd_S=mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('All_region','Central_Coast'), # aggregate all regions, break out central coast
            own = c('All_own'), 
            figdir = 'high',
            last_year = 2022)

# 6: High Emission, Central Valley, Delta, Deserts
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_D+sd_A-sd_S=mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_D+sd_A-sd_S=mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('Central_Valley','Delta','Deserts'), # regions
            own = c('All_own'), 
            figdir = 'high',
            last_year = 2022)

# 7: High Emission, Eastside, Klamath, North_Coast
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_D+sd_A-sd_S=mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_D+sd_A-sd_S=mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('Eastside', 'Klamath', 'North_Coast'), # regions
            own = c('All_own'), 
            figdir = 'high',
            last_year = 2022)

# 8: High Emission, "Sierra_Cascades", "South_Coast", "Ocean"
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_D+sd_A-sd_S=mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_D+sd_A-sd_S=mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('Sierra_Cascades', 'South_Coast', 'Ocean'), # regions
            own = c('All_own'), 
            figdir = 'high',
            last_year = 2022)

# 9: Low Emission, All Region aggregate and Central Coast
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_D-sd_A+sd_S=mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_D-sd_A+sd_S=mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('All_region','Central_Coast'), # aggregate all regions, break out central coast
            own = c('All_own'), 
            figdir = 'low',
            last_year = 2022)

# 10: Low Emission, Central Valley, Delta, Deserts
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_D-sd_A+sd_S=mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_D-sd_A+sd_S=mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('Central_Valley','Delta','Deserts'), # regions
            own = c('All_own'), 
            figdir = 'low',
            last_year = 2022)

# 11: Low Emission, Eastside, Klamath, North_Coast
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_D-sd_A+sd_S=mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_D-sd_A+sd_S=mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('Eastside', 'Klamath', 'North_Coast'), # regions
            own = c('All_own'), 
            figdir = 'low',
            last_year = 2022)

# 12: Low Emission, "Sierra_Cascades", "South_Coast", "Ocean"
R
setwd('/Users/khemes/Repos/midden/Models/CALAND') # set working directory
source('plot_caland.r')
plot_caland(scen_fnames = c('Baseline_10_29_19_RCP85_output_D-sd_A+sd_S=mean_BC1_NR120.xls', # what files to pull in
                            'Alternative_B_10_29_19_RCP85_output_D-sd_A+sd_S=mean_BC1_NR120.xls'),
            scen_snames = c('Baseline','Alt_B'), # label 
            data_dir = "./outputs/",
            reg = c('Sierra_Cascades', 'South_Coast', 'Ocean'), # regions
            own = c('All_own'), 
            figdir = 'low',
            last_year = 2022)


# Module 6.1
#   Impacts of a scenario on different land types
#   Can run plot_scen_types in RStudio

source('plot_scen_types.r')

# Average statewide landtype comparison total CO2eq
# Will be put in ./outputs/mean/All_region
plot_scen_types(varname = 'Total_CumCO2eq_all_diff',
                ylabel = 'Change from baseline (MMT CO2eq)',
                reg = 'All_region',
                figdir = 'mean')


# Module 6.2
#   Shaded uncertainty bounds around scenario trendline
#   Can run plot_scen_types in RStudio

# Uncertainty bounds around statewide Alternative B impacts (change from baseline in MMT CO2eq)
source('plot_uncertainty.r')
plot_uncertainty(varname = 'Total_CumCO2eq_all_diff',
                 end_year = 2022,
                 ylabel = 'Change from baseline (MMT CO2eq)',
                 scenarios_a = 'Alternative_B_10_29_19_RCP85_output_mean_BC1_NR120',
                 scen_labs_a = 'Alternative_B')
                 
source('plot_uncertainty.r')
plot_uncertainty(varname = 'Total_CumCH4eq_diff',
                 end_year = 2022,
                 ylabel = 'Change from baseline (MMT CH4eq)',
                 scenarios_a = 'Alternative_B_10_29_19_RCP85_output_mean_BC1_NR120',
                 scen_labs_a = 'Alternative_B')


source('plot_uncertainty.r')
plot_uncertainty(varname = 'TotalFire_AnnCO2eq_all_diff',
                 end_year = 2022,
                 ylabel = 'Change from baseline (MMT CO2eq)',
                 scenarios_a = 'Alternative_B_10_29_19_RCP85_output_mean_BC1_NR120',
                 scen_labs_a = 'Alternative_B')

source('plot_uncertainty.r')
plot_uncertainty(varname = 'Soil_orgC_den_diff',
                 end_year = 2022,
                 ylabel = '(MgC/ac)',
                 scenarios_a = 'Alternative_B_10_29_19_RCP85_output_mean_BC1_NR120',
                 scen_labs_a = 'Alternative_B')


  # Module 7
#   County level scaling - Amador county

source('write_scaled_raw_scenarios.r') # creates amador_example_ac_Amador_ac in RawData
write_scaled_raw_scenarios(scen_file = 'amador_example_ac.xls',
                           county = 'Amador',
                           units = 'ac')

source('write_scaled_outputs.r')
write_scaled_outputs(scen_fnames = c('Amador_Base_default_RCP85_output_mean_BC1.xls', # uses pre-made outputs and scales them to county
                                     'Amador_Alt_A_default_RCP85_output_mean_BC1.xls',
                                     'Amador_Alt_B_default_RCP85_output_mean_BC1.xls'),
                     data_dir = './outputs/amador',
                     scalar_file = 'amador_example_ac_Amador_ac_scalars.xls')







