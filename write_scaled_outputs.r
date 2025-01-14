# write_scaled_outputs.r

# Copyright (c) 2016-2019, Alan Di Vittorio and Maegen Simmonds

# This software and its associated input data are licensed under the 3-Clause BSD open source license
# Please see license.txt for details

# Converts scaled CALAND outputs to county-level (or project-level) outputs
# This is used in conjunction with write_scaled_raw_scenario.r
# All of the scenarios to be compared using plot_caland() need to be scaled simultaneously using this function
#  This is because areas managed in the alternatives may not be managed in the baseline, and these unmanaged areas need to be scaled for comparison
#  This means that the scaled scenarios for use by plot_caland() must all be present in the county raw file that gets scaled by write_scaled_raw_scenarios()

# This function uses the scalar values calculted by write_scaled_raw_scenarios.r to scale only the relevant land categories in the CALAND output files
#  Nearly all of the output variables are scaled
#  The nine per area output variables will not be scaled, as they represent the carbon densities for the county

############# Arguments to write_scaled_outputs.r ##############

# 1. scen_fnames: this is a vector of CALAND output files to be scaled to the county level

# 2. data_dir: the directory where the output files are, and where the scaled files will be written (do not include file "/"); default = "./outputs/amador"

# 3. scalar_file: the file containing the scalar values for scaling the output. Only relevant county values are included in this file
#		this must be located in ./raw_data, but the name can include as a prefix a folder within ./raw_data
#		default = "amador_example_ac_Amador_ac_scalars.xls"

############ Output ############

# New output files scaled to the county level
# the county name and "scaled" will be appended to the original output file name
# Non-county values will be zero in this file
# This assumes that only Reforestation is prescribed for forest area expansion

############ Notes ##############

# there is no way to ensure the scalars match the scenario files unless the scenario sheets include the county name

############ start script ##############

# this enables java to use up to 4GB of memory for reading and writing excel files
options(java.parameters = "-Xmx4g" )

# Load all the required packages
libs <- c( "XLConnect" )
for( i in libs ) {
    if( !require( i, character.only=T ) ) {
        cat( "Couldn't load", i, "\n" )
        stop( "Use install.packages() to download this library\nOr use the GUI Package Installer\nInclude dependencies, 
              and install it for local user if you do not have root access\n" )
    }
    library( i, character.only=T )
}

write_scaled_outputs <- function(scen_fnames, data_dir = "./outputs/amador", scalar_file = "amador_example_ac_Amador_ac_scalars.xls") {
	
	cat("Start write_scaled_outputs at", date(), "\n")

	scalar_dir = "./raw_data/"
	xltag = ".xls"
	
	exp_reg_lc_tag = "exp_reg_lc_area_"
	exp_cnty_lc_tag = "exp_cnty_lc_area_"
	exp_scalar_tag = "exp_output_scalar_"
	
	num_scen_files = length(scen_fnames)
	
	# regions
	reg_names = c("Central_Coast", "Central_Valley", "Delta", "Deserts", "Eastside", "Klamath", "North_Coast", "Sierra_Cascades", "South_Coast")
	num_reg = length(reg_names)

	# land types
	lt_names = c("Water", "Ice", "Barren", "Sparse", "Desert", "Shrubland", "Grassland", "Savanna", "Woodland", "Forest", "Meadow",
	       "Coastal_marsh", "Fresh_marsh", "Cultivated", "Developed_all", "Seagrass")
	num_lt = length(lt_names)

	# ownerships
	own_names = c("BLM", "DoD", "Easement", "Local_gov", "NPS", "Other_fed", "Private", "State_gov", "USFS_nonwild")
	num_own = length(own_names)
	
	# carbon density outputs that do not get scaled
	density_vars = c("All_orgC_den", "All_biomass_C_den", "Above_main_C_den", "Below_main_C_den", "Understory_C_den", "StandDead_C_den", "DownDead_C_den", "Litter_C_den", "Soil_orgC_den")
	
	# restoration land types
	# the first forest type is for afforestation
	# the second forest land type is for reforestation
	restoration_lt = c("Meadow", "Fresh_marsh", "Coastal_marsh", "Woodland", "Forest", "Forest")
	num_restoration_lt = length(restoration_lt)
	
	# restoration sources
	restoration_sources = array(dim=c(num_restoration_lt, num_lt))
	restoration_sources[1,] = c("Shrubland", "Grassland", "Savanna", "Woodland")
	restoration_sources[2,] = c("Cultivated")
	restoration_sources[3,] = c("Cultivated")
	restoration_sources[4,] = c("Grassland", "Cultivated")
	restoration_sources[5,] = c("Shrubland", "Grassland")
	restoration_sources[6,] = c("Shrubland")
	meadow_rest_index = 1
	afforest_rest_index = 5
	
	num_restoration_sources = c(4, 1, 1, 2, 2, 1)

	source_totals_names = c("Shrubland", "Grassland", "Savanna", "Woodland", "Cultivated")
	woodland_st_index = 4
	num_sources = length(source_totals_names)
	st_sum = array(dim=num_sources)
	st_sum_scaled = array(dim=num_sources)
	
	# output tables
	# these are necessary for recalculating the aggregated records
	out_area_sheets = c("Area", "Managed_area", "Wildfire_area")
  	num_out_area_sheets = length(out_area_sheets)
	out_density_sheets = c("All_orgC_den", "All_biomass_C_den", "Above_main_C_den", "Below_main_C_den", "Understory_C_den", "StandDead_C_den", 
                         "DownDead_C_den", "Litter_C_den", "Soil_orgC_den")
	num_out_density_sheets = length(out_density_sheets)
	
	###### probably don't need these
	out_stock_sheets = c("All_orgC_stock", "All_biomass_C_stock", "Above_main_C_stock", "Below_main_C_stock", "Understory_C_stock", 
                       "StandDead_C_stock", "DownDead_C_stock", "Litter_C_stock", "Soil_orgC_stock")
	num_out_stock_sheets = length(out_stock_sheets)
	out_atmos_sheets = c("Eco_CumGain_C_stock", "Total_Atmos_CumGain_C_stock", "Manage_Atmos_CumGain_C_stock", "Fire_Atmos_CumGain_C_stock", 
                       "LCC_Atmos_CumGain_C_stock", "Wood_Atmos_CumGain_C_stock", "Total_Energy2Atmos_C_stock", "Eco_AnnGain_C_stock", 
                       "Total_Atmos_AnnGain_C_stock", "Manage_Atmos_AnnGain_C_stock", "Fire_Atmos_AnnGain_C_stock", 
                       "LCC_Atmos_AnnGain_C_stock", "Wood_Atmos_AnnGain_C_stock", "Total_AnnEnergy2Atmos_C_stock", 
                       "Manage_Atmos_CumGain_FireC", "Manage_Atmos_CumGain_TotEnergyC", "Man_Atmos_CumGain_Harv2EnergyC",
                       "Man_Atmos_CumGain_Slash2EnergyC", "Manage_Atmos_CumGain_NonBurnedC","Fire_Atmos_CumGain_BurnedC", 
                       "Fire_Atmos_CumGain_NonBurnedC", "LCC_Atmos_CumGain_FireC", "LCC_Atmos_CumGain_TotEnergyC", 
                       "LCC_Atmos_CumGain_Harv2EnergyC", "LCC_Atmos_CumGain_Slash2EnergyC", "LCC_Atmos_CumGain_NonBurnedC", 
                       "Manage_Atmos_AnnGain_FireC", "Manage_Atmos_AnnGain_TotEnergyC", "Man_Atmos_AnnGain_Harv2EnergyC",
                       "Man_Atmos_AnnGain_Slash2EnergyC", "Manage_Atmos_AnnGain_NonBurnedC", "Fire_Atmos_AnnGain_BurnedC", 
                       "Fire_Atmos_AnnGain_NonBurnedC", "LCC_Atmos_AnnGain_FireC", "LCC_Atmos_AnnGain_TotEnergyC", 
                       "LCC_Atmos_AnnGain_Harv2EnergyC", "LCC_Atmos_AnnGain_Slash2EnergyC", "LCC_Atmos_AnnGain_NonBurnedC",
                       "Man_Atmos_AnnGain_SawmillDecayC", "Man_Atmos_AnnGain_InFrstDecayC", "Man_Atmos_CumGain_SawmillDecayC", 
                       "Man_Atmos_CumGain_InFrstDecayC",  "LCC_Atmos_AnnGain_SawmillDecayC", "LCC_Atmos_AnnGain_OnSiteDecayC", 
                       "LCC_Atmos_CumGain_SawmillDecayC", "LCC_Atmos_CumGain_OnSiteDecayC" )
  	num_out_atmos_sheets = length(out_atmos_sheets)
 	out_wood_sheets = c("Total_Wood_C_stock", "Total_Wood_CumGain_C_stock", "Total_Wood_CumLoss_C_stock", "Total_Wood_AnnGain_C_stock", 
                      "Total_Wood_AnnLoss_C_stock", "Manage_Wood_C_stock", "Manage_Wood_CumGain_C_stock", "Man_Harv2Wood_CumGain_C_stock",
                      "Man_Slash2Wood_CumGain_C_stock", "Manage_Wood_CumLoss_C_stock", "Manage_Wood_AnnGain_C_stock", 
                      "Man_Harv2Wood_AnnGain_C_stock",  "Man_Slash2Wood_AnnGain_C_stock", "Manage_Wood_AnnLoss_C_stock", 
                      "LCC_Wood_C_stock", "LCC_Wood_CumGain_C_stock", "LCC_Harv2Wood_CumGain_C_stock", "LCC_Slash2Wood_CumGain_C_stock",
                      "LCC_Wood_CumLoss_C_stock", "LCC_Wood_AnnGain_C_stock", "LCC_Harv2Wood_AnnGain_C_stock", "LCC_Slash2Wood_AnnGain_C_stock",
                      "LCC_Wood_AnnLoss_C_stock")
  	num_out_wood_sheets = length(out_wood_sheets)
	
	# Load the scalar file
    scalar_wrkbk = loadWorkbook(paste0(scalar_dir, scalar_file))
    scalar_sheets = getSheets(scalar_wrkbk)
    num_scalar_sheets = length(scalar_sheets)
    
	
	# determine whether the number of output files matches the number of scenarios
	if (num_scen_files != num_scalar_sheets) {
		cat("The number of output files does not match the number of scaled scenarios\n")
		stop("Please make sure that the output file scenarios are the same ones as are in the raw scaled input file\n")
	}

	# loop over the data files as scenarios
	for (s in 1:num_scen_files) {
		
		# determine and put the scaled scenario in an accessible table
		for (n in 1:num_scalar_sheets){
			if (regexpr(scalar_sheets[n], scen_fnames[s]) != -1) {
				scalar_df = readWorksheet(scalar_wrkbk, n, startRow = 1)
				break;
			}
		}
		
		# get the county name
		ctag = scalar_df$County[1]
		
		# Load the output file
        data_file = paste0(data_dir, "/", scen_fnames[s])
        data_wrkbk = loadWorkbook(data_file)                
        # worksheet/table names
        data_sheets = getSheets(data_wrkbk)
        num_data_sheets = length(data_sheets)
        
        # create scaled output file name
        out_file = paste0(substr(data_file, 1, regexpr(".xls", data_file)-1), "_", ctag, "_scaled", xltag)
        
        # load and convert the data one variable at a time
        data_df_list <- list()
        for (d in 1:num_data_sheets) {
        	
        	data_df_list[[d]] <- readWorksheet(data_wrkbk, d, startRow = 1)
        	
        	# remove the Xs added to the front of the year columns, and get the years as numbers only
            yinds = which(substr(names(data_df_list[[d]]),1,1) == "X")
            names(data_df_list[[d]])[yinds] = substr(names(data_df_list[[d]]),2,5)[yinds] 
            
			var_df = data_df_list[[d]]
			# get the column headers in order because the merge moves the land cat id after the three 'by' columns
			# can reorder this at the end to drop the extra columns at the same time
			col_order = colnames(var_df)
			change_col = ncol(var_df)
			var_df = merge(var_df, scalar_df, by = c("Region", "Land_Type", "Ownership"), all.x = TRUE)
			# set the non-scaled values to zero, even for density
			# this also sets the summed records to zero
			# managed and wildfire area have an extra id column
			if ( data_sheets[d] == "Managed_area" | data_sheets[d] == "Wildfire_area" ) {
				first_scalar_col = paste0(exp_scalar_tag, names(var_df)[6])
				var_df[is.na(var_df[,first_scalar_col]), c(6:change_col)] = 0
			} else {
				first_scalar_col = paste0(exp_scalar_tag, names(var_df)[5])
				var_df[is.na(var_df[,first_scalar_col]), c(5:change_col)] = 0
			}

			##### should not need this adjustment any more
			# need to calculate an additional annual scalar and apply it also
			
			#### no more?#####
			# the Area block below is used to check the scalars against the actual area, then adjust scalars if necessary before applying them
			#  it is the first sheet, so for the rest the scalars should be correct
			
			# only scale the non-density variables
			# but the aggregated density rows need to be updated!
			
			# apply the scalars by extracting matrices and multiplying
			# check that the years line up?
				
				
				# managed and wildfire area have an extra id column
				if ( data_sheets[d] == "Managed_area" | data_sheets[d] == "Wildfire_area" ) {
					first_scalar_col = paste0(exp_scalar_tag, names(var_df)[6])
					# extract just the land cat Area values - assume the years match with the scalar years
  					reg_act = var_df[!is.na(var_df[,first_scalar_col]), 6:(change_col-1)]
  					# extract just the scalars
  					scalar_matches = regexpr(exp_scalar_tag, names(var_df))
  					scalar_cols = which(scalar_matches != -1)
  					scalars = var_df[!is.na(var_df[,first_scalar_col]), scalar_cols]
  					# these are annual values so there is not the extra year at the end and the very last scalar is not used
  					scalars = scalars[,1:(ncol(scalars) - 1)]
  					
  					# check that the years match
  					if (ncol(reg_act) != ncol(scalars)) {
  						stop("Number of scalar years does not match number of output years for scenario ", scalar_sheets[n])
  					} else {
  						for (y in 1:ncol(reg_act)){
							if (regexpr(names(reg_act)[y], names(scalars)[y]) == -1) {
								stop("Output year ",  names(reg_act)[y], " does not match scalar year ", names(scalars)[y],
										" for scenario ", scalar_sheets[n])
							}
						}
					}
  					# apply the scalars
  					var_df[!is.na(var_df[,first_scalar_col]), 6:(change_col-1)] = reg_act * scalars
				} else if ( !(data_sheets[d] %in% density_vars) ) {
					first_scalar_col = paste0(exp_scalar_tag, names(var_df)[5])
					# extract just the land cat Area values - assume the years match with the scalar years
  					reg_act = var_df[!is.na(var_df[,first_scalar_col]), 5:(change_col-1)]
  					# extract just the scalars
  					scalar_matches = regexpr(exp_scalar_tag, names(var_df))
  					scalar_cols = which(scalar_matches != -1)
  					scalars = var_df[!is.na(var_df[,first_scalar_col]), scalar_cols]
  					
  					# the annual values do not have the extra year at the end and so the very last scalar is not used
  					if (regexpr("Ann", data_sheets[d]) != -1) {
  						scalars = scalars[,1:(ncol(scalars) - 1)]
  					}
  					
  					# check that the years match
  					if (ncol(reg_act) != ncol(scalars)) {
  						stop("Number of scalar years does not match number of output years for scenario ", scalar_sheets[n])
  					} else {
  						for (y in 1:ncol(reg_act)){
							if (regexpr(names(reg_act)[y], names(scalars)[y]) == -1) {
								stop("Output year ",  names(reg_act)[y], " does not match scalar year ", names(scalars)[y],
										" for scenario ", scalar_sheets[n])
							}
						}
					}
  					# apply the scalars
  					var_df[!is.na(var_df[,first_scalar_col]), 5:(change_col-1)] = reg_act * scalars					
				} # end if managed or wildfire else non-density to apply scalars
	
				
			
				####### deal with aggregated records ######
				# change column will be recalculated after variable update
				# recall that these will represent only the county area
				
				#### total area
				if (data_sheets[d] == "Area") {
  
  
  ### scratch this for now. too complicated and it could take a while to create a case to test it.
  ### and even longer to debug it so that it doesn't break the regular cases
  if(FALSE){
  					# compare Area values with expected regional area values
  					
  					# extract just the land cat Area values - assume the years match with the scalar years
  					reg_act = var_df[!(var_df$Ownership == "All_own" | var_df$Region == "Ocean"), 5:(change_col-1)]
  					# extract just the expected region areas
  					reg_exp_matches = regexpr(exp_reg_lc_tag, names(var_df))
  					reg_exp_cols = which(reg_exp_matches != -1)
  					reg_exp = var_df[!(var_df$Ownership == "All_own" | var_df$Region == "Ocean"), reg_exp_cols]
  					act_to_exp = reg_act / reg_exp
  					reg_diff_inds = which(act_to_exp != 1 & !is.na(act_to_exp) & !is.nan(act_to_exp) & act_to_exp != Inf, arr.ind=TRUE)
  					# extract the df row land cat ids that are different to determine which source land cats to alter
  					# luckily the df rows start at 1 for records
  					diff_lcs = var_df[unique(reg_diff_inds[,1]),]
  					
					# get source rows for each restoration type with diffs
					for (rt in 1:num_restoration_lt) {
						# only reforestation is allowed by the scenario scaling function
						if (rt != afforest_rest_index) {
							diff_rt = diff_lcs[diff_lcs$Land_Type == restoration_lt[rt],]
							if (nrow(diff_rt) > 0) {
								for (y in names(var_df)[5]:names(var_df)[change_col-1]) {
									# have to loop over the rows somehow
									
									# get the new county restoration areas once based on expected scalars
									# this is to maintain the correct proportions of new area to initial area for density values
									if (src == 1) {
										diff_rt[,paste0(exp_cnty_lc_tag, y)] = diff_rt[,y] * diff_rt[,paste0(exp_scalar_tag, y)]
									}
								
								# loop over the sources for this rt
								for (src in 1:num_restoration_sources[rt]) {
									# don't adjust woodland because it is also a restoration type and so it maintains its scalar
									if ( !(rt == 1 & src == woodland_st_index) ) {										
											
											
											
										
										
									} # end if not woodland
								} # end src loop over sources
								
								} # end for y loop over years for calculating new county source areas and scalars
								
							} # end if this restoration type has diffs
						} # end if not afforest restoration type	
					} # end for rt over restoration types
					
} # end FALSE to delete
  					
  
  					# (1a) Do each landtype in county
  					# get names of landtypes
  					landtype_names <- unique(var_df$Land_Type)
  					# remove "All_land" from landtype_names
  					landtype_names <- landtype_names[!landtype_names %in% c("All_land")]
  					for (l in 1:length(landtype_names)) {
    					# get current landtype name
   						landtype_name <- landtype_names[l]
   						# get the row index for this aggregation
   						reg_ind = which(var_df$Region =="All_region")
   						lt_ind = which(var_df$Land_Type == landtype_name)
   						own_ind = which(var_df$Ownership =="All_own")
   						row_ind = intersect(reg_ind, lt_ind)
   						row_ind = intersect(row_ind, own_ind)
    					# subset landtype-specific df
    					landtype_df_temp <- var_df[var_df$Land_Type == landtype_name,]
    					# delete last row to exclude the All_region row
      					landtype_df_temp <- landtype_df_temp[landtype_df_temp$Region != "All_region",]
    					# aggregate sum areas of landtype-specific areas for each column year
    					var_df[row_ind,c(5:change_col)] <- apply(landtype_df_temp[,c(5:change_col)], 2, sum)
  					}
  
  					# (1b) Do each region in county (Excludes Ocean)
  					# get names of regions
  					region_names <- unique(var_df$Region)
  					# remove "All_region" from region_names
  					region_names <- region_names[!region_names %in% c("All_region","Ocean")]
  					for (r in 1:length(region_names)) {
    					# get current region name
    					region_name <- region_names[r]
    					# get the row index for this aggregation
   						reg_ind = which(var_df$Region == region_name)
   						lt_ind = which(var_df$Land_Type == "All_land")
   						own_ind = which(var_df$Ownership =="All_own")
   						row_ind = intersect(reg_ind, lt_ind)
   						row_ind = intersect(row_ind, own_ind)
    					# subset region-specific df
    					region_df_temp <- var_df[var_df$Region == region_name,]
    					# delete last row to exclude the All_land row
      					region_df_temp <- region_df_temp[region_df_temp$Land_Type != "All_land",]
    					# aggregate sum areas of region-specific areas for each column year
    					var_df[row_ind,c(5:change_col)] <- apply(region_df_temp[,c(5:change_col)], 2, sum)
  					}
  
  					# (1c) Do all county land (Excludes Ocean)
  					reg_ind = which(var_df$Region == "All_region")
   					lt_ind = which(var_df$Land_Type == "All_land")
   					own_ind = which(var_df$Ownership =="All_own")
   					row_ind = intersect(reg_ind, lt_ind)
   					row_ind = intersect(row_ind, own_ind)
  					var_df[row_ind,c(5:change_col)] = 
    					apply(var_df[var_df$Land_Type == "All_land" & var_df$Region != "All_region", c(5:change_col)], 2 , sum)
    					
					# do a subtraction for change column for aggregated row
  					#var_df[row_ind,change_col] <- var_df[row_ind, change_col - 1] - var_df[row_ind, 5]
  					
  					# store and apply the annual scalar adjustment
  					# don't need to redo the aggregation because they are just sums, so the adjustment is sufficient for all
  					#annual_scalar = var_df[row_ind, 5] / var_df[row_ind, 5:(change_col-1)]
  					#num_area_years = length(annual_scalar)
  					#for (r in 1:nrow(var_df)) {
  					#	var_df[r, c(5:(change_col-1))] = var_df[r, c(5:(change_col-1))] * annual_scalar
  					#}
  					
					# calculate the change column
					var_df[,change_col] <- var_df[, change_col - 1] - var_df[, 5]
				} # end aggregate total area
				
				#### managed and wildfire area
				if (data_sheets[d] %in% out_area_sheets & data_sheets[d] != "Area") {
					
					# apply the annual scalar adjustment first
					# these two tables have one less year than Area
  					#for (r in 1:nrow(var_df)) {
  					#	var_df[r, c(6:(change_col-1))] = var_df[r, c(6:(change_col-1))] * annual_scalar[1:(num_area_years-1)]
  					#}
					
    				# (2a) do each landtype within county
    				landtype_names <- unique(var_df$Land_Type)
    				# remove "All_land" from landtype_names
  					landtype_names <- landtype_names[!landtype_names %in% c("All_land")]
    				for (l in 1:length(landtype_names)) {
      					# get current landtype name
      					landtype_name <- landtype_names[l]
      					# get the row index for this aggregation
   						reg_ind = which(var_df$Region =="All_region")
   						lt_ind = which(var_df$Land_Type == landtype_name)
   						own_ind = which(var_df$Ownership =="All_own")
   						extra_ind = which(var_df[,5] =="All")
   						row_ind = intersect(reg_ind, lt_ind)
   						row_ind = intersect(row_ind, own_ind)
      					row_ind = intersect(row_ind, extra_ind)
      					# subset landtype-specific df
        				# if on management areas, exclude developed_all urban forest and growth
        				#  this ensures accurate summed management areas for developed_all using only dead_removal
      					if (data_sheets[d] == "Managed_area") {
        					landtype_df_temp <- var_df[var_df$Land_Type == landtype_name & var_df$Management != "Growth" & 
                                                    var_df$Management != "Urban_forest",]
      					} else {
        					landtype_df_temp <- var_df[var_df$Land_Type == landtype_name,]
      					}
      					# delete last row to exclude the All_region row
      					landtype_df_temp <- landtype_df_temp[landtype_df_temp$Region != "All_region",]
       					# aggregate sum areas of landtype-specific areas for each column year
      					var_df[row_ind,c(6:change_col)] <- apply(landtype_df_temp[,c(6:change_col)], 2, sum)
   					}

    				# (2b) do each region within county (Excludes Ocean)
    				region_names <- unique(var_df$Region)
    				# remove "All_region" from region_names
    				region_names <- region_names[!region_names %in% c("All_region","Ocean")]
    				for (r in 1:length(region_names)) {
      					# get current region name
      					region_name <- region_names[r]
      					# get the row index for this aggregation
   						reg_ind = which(var_df$Region == region_name)
   						lt_ind = which(var_df$Land_Type == "All_land")
   						own_ind = which(var_df$Ownership =="All_own")
   						extra_ind = which(var_df[,5] =="All")
   						row_ind = intersect(reg_ind, lt_ind)
   						row_ind = intersect(row_ind, own_ind)
   						row_ind = intersect(row_ind, extra_ind)
      					# subset region-specific df
        				# if on management areas, exclude developed_all urban forest and growth
        				# this ensures accurate summed management areas for developed_all using only dead_removal
      					if (data_sheets[d] == "Managed_area") {
        					region_df_temp <- var_df[var_df $Region == region_name & var_df$Management != "Growth" & 
          										var_df$Management != "Urban_forest",]
      					} else {
        					region_df_temp <- var_df[var_df $Region == region_name,] 
      					}
      					# delete last row to exclude the All_land row
      					region_df_temp <- region_df_temp[region_df_temp$Land_Type != "All_land",]
      					# aggregate sum areas of region-specific areas for each column year
      					var_df[row_ind,c(6:change_col)] <- apply(region_df_temp[,c(6:change_col)], 2, sum)
    				}
    
    				# (2c) do all county land for the current df in out_area_df_list (Excludes Ocean)
    				reg_ind = which(var_df$Region == "All_region")
   					lt_ind = which(var_df$Land_Type == "All_land")
   					own_ind = which(var_df$Ownership =="All_own")
   					extra_ind = which(var_df[,5] =="All")
   					row_ind = intersect(reg_ind, lt_ind)
   					row_ind = intersect(row_ind, own_ind)
   					row_ind = intersect(row_ind, extra_ind)
    				var_df[row_ind,c(6:change_col)] =
    					apply(var_df[var_df$Land_Type == "All_land" & var_df$Region != "All_region", c(6:change_col)], 2 , sum)
  					
  					# calculate the change column
					var_df[,change_col] <- var_df[, change_col - 1] - var_df[, 6]
            	} # end managed and wildfire area
        	
        		#### density
        		# need to make sure the rows are ordered for the calcs
        		if (data_sheets[d] %in% out_density_sheets) {
        			
        			# apply the annual scalar adjustment first
  					#for (r in 1:nrow(var_df)) {
  					#	var_df[r, c(5:(change_col-1))] = var_df[r, c(5:(change_col-1))] * annual_scalar
  					#}
        			
        			# order var_df
        			var_df = var_df[order(var_df$Land_Cat_ID),]
        			
            		# (3a) do each landtype within county
            		landtype_names <- unique(var_df$Land_Type)
            		# remove "All_land" from landtype_names
  					landtype_names <- landtype_names[!landtype_names %in% c("All_land")]
    				for (l in 1:length(landtype_names)) {
      					# get current landtype name
      					landtype_name <- landtype_names[l]
      					# get the row index for this aggregation
   						reg_ind = which(var_df$Region =="All_region")
   						lt_ind = which(var_df$Land_Type == landtype_name)
   						own_ind = which(var_df$Ownership =="All_own")
   						row_ind = intersect(reg_ind, lt_ind)
   						row_ind = intersect(row_ind, own_ind)
      					# subset landtype-specific density df
      					landtype_df_dens_temp <- var_df[var_df$Land_Type == landtype_name,]
      					# delete last row to exclude the All_region row
      					landtype_df_dens_temp <- landtype_df_dens_temp[landtype_df_dens_temp$Region != "All_region",]
      					# order the subset df
      					landtype_df_dens_temp = landtype_df_dens_temp[order(landtype_df_dens_temp$Land_Cat_ID),]
      					# subset landtype-specific area df
      					landtype_df_area_temp <- data_df_list[[1]][data_df_list[[1]][,"Land_Type"] == landtype_name,] 
      					# delete last row to exclude the All_region row
      					landtype_df_area_temp <- landtype_df_area_temp[landtype_df_area_temp$Region != "All_region",]
      					# order the subset df
      					landtype_df_area_temp = landtype_df_area_temp[order(landtype_df_area_temp$Land_Cat_ID),]
      					# get total C for current landtype: aggregate landtype-specific densities*areas by each column year
      					var_df[row_ind,c(5:change_col)] <- 
        					apply(landtype_df_dens_temp[,c(5:change_col)] * landtype_df_area_temp[,c(5:ncol(landtype_df_area_temp))],
        						2, sum)
      					# get total area for current landtype: aggregate landtype-specific
      					landtype_tot_area <- data_df_list[[1]][(data_df_list[[1]][, "Land_Type"] == landtype_name) &
                              (data_df_list[[1]][, "Region"] == "All_region"),]
      					# get avg C density for current landtype (excluding last column for Change), divide total Mg C by total area
      					var_df[row_ind,c(5:change_col)] <- var_df[row_ind, c(5:change_col)] / landtype_tot_area[1, c(5:ncol(landtype_tot_area))]
      					# replace Inf values (where area == 0) with 0, and also NaN (where both == 0)
      					var_df[row_ind,c(5:change_col)] <- replace(var_df[row_ind,c(5:change_col)], var_df[row_ind,c(5:change_col)] == Inf, 0.0)
      					var_df[row_ind,c(5:change_col)] <- replace(var_df[row_ind,c(5:change_col)], var_df[row_ind,c(5:change_col)] == -Inf, 0.0)
      					var_df[row_ind,c(5:change_col)] <- replace(var_df[row_ind,c(5:change_col)], is.nan(unlist(var_df[row_ind,c(5:change_col)])), 0.0)
  	 	 			}

    				# (3b) do each region within county (Excluded Ocean)
    				region_names <- unique(var_df$Region)
    				# remove Ocean & All_region 
    				region_names <- region_names[!region_names %in% c("Ocean","All_region")]
    				for (r in 1:length(region_names)) { 
      					# get current region name
      					region_name <- region_names[r]
      					# get the row index for this aggregation
   						reg_ind = which(var_df$Region == region_name)
   						lt_ind = which(var_df$Land_Type == "All_land")
   						own_ind = which(var_df$Ownership =="All_own")
   						row_ind = intersect(reg_ind, lt_ind)
   						row_ind = intersect(row_ind, own_ind)
      					# subset region-specific density df
      					region_df_dens_temp <- var_df[var_df$Region == region_name,] 
      					# delete last row to exclude the All_landtype row
      					region_df_dens_temp <- region_df_dens_temp[region_df_dens_temp$Land_Type != "All_land",]
      					# order the subset df
      					region_df_dens_temp = region_df_dens_temp[order(region_df_dens_temp$Land_Cat_ID),]
      					# subset region-specific area df 
      					region_df_area_temp <- data_df_list[[1]][data_df_list[[1]][,"Region"] == region_name,] 
      					# delete last row to exclude the All_landtype row
      					region_df_area_temp <- region_df_area_temp[region_df_area_temp$Land_Type != "All_land",]
      					# order the subset df
      					region_df_area_temp = region_df_area_temp[order(region_df_area_temp$Land_Cat_ID),]
      					# get total C for current region: aggregate region-specific densities*areas by each column year (excluding Seagrass)
      					var_df[row_ind,c(5:change_col)] <- 
        					apply(region_df_dens_temp[,c(5:change_col)] * region_df_area_temp[,c(5:ncol(region_df_area_temp))],
        						2, sum)
      					# get total area for current region: aggregate region-specific
      					region_tot_area <- data_df_list[[1]][(data_df_list[[1]][, "Region"] == region_name) &
                                                   (data_df_list[[1]][, "Land_Type"] == "All_land"),]
      					# get avg C density for current region (excluding last column for Change), divide total Mg C by total area
      					var_df[row_ind,c(5:change_col)] <- var_df[row_ind, c(5:change_col)] / region_tot_area[1, c(5:ncol(region_tot_area))]
      					# replace Inf values (where area == 0) with 0
      					var_df[row_ind,c(5:change_col)] <- replace(var_df[row_ind,c(5:change_col)], var_df[row_ind,c(5:change_col)] == Inf, 0.0)
      					var_df[row_ind,c(5:change_col)] <- replace(var_df[row_ind,c(5:change_col)], var_df[row_ind,c(5:change_col)] == -Inf, 0.0)
      					var_df[row_ind,c(5:change_col)] <- replace(var_df[row_ind,c(5:change_col)], is.nan(unlist(var_df[row_ind,c(5:change_col)])), 0.0)
    				}
    
    				# (3c) Do all county land(Excludes Ocean)
    				reg_ind = which(var_df$Region == "All_region")
   					lt_ind = which(var_df$Land_Type == "All_land")
   					own_ind = which(var_df$Ownership =="All_own")
   					row_ind = intersect(reg_ind, lt_ind)
   					row_ind = intersect(row_ind, own_ind)
   		 			# calc all California land total C for each year
    				var_df[row_ind, c(5:change_col)] = 
      					apply(var_df[var_df$Land_Type == "All_land" & var_df$Region != "All_region", c(5:change_col)] *   
              				data_df_list[[1]][data_df_list[[1]][, "Land_Type"] == "All_land" & data_df_list[[1]][, "Region"] != "All_region", 
                            c(5:ncol(data_df_list[[1]]))], 2, sum)
    				# calc all California land area-weighted avg C density for each year
    				var_df[row_ind, c(5:change_col)] = var_df[row_ind, c(5:change_col)] / 
      					data_df_list[[1]][data_df_list[[1]][, "Region"] == "All_region" & data_df_list[[1]][, "Land_Type"] == "All_land", 
                         c(5:ncol(data_df_list[[1]]))]
                    # replace Inf values (where area == 0) with 0
      				var_df[row_ind,c(5:change_col)] <- replace(var_df[row_ind,c(5:change_col)], var_df[row_ind,c(5:change_col)] == Inf, 0.0)
      				var_df[row_ind,c(5:change_col)] <- replace(var_df[row_ind,c(5:change_col)], var_df[row_ind,c(5:change_col)] == -Inf, 0.0)
      				var_df[row_ind,c(5:change_col)] <- replace(var_df[row_ind,c(5:change_col)], is.nan(unlist(var_df[row_ind,c(5:change_col)])), 0.0)
  					
  					# calculate the change column
					var_df[,change_col] <- var_df[, change_col - 1] - var_df[, 5]
            	} # end if density variable
            
            	#### the rest of the tables are identical
            	if (!(data_sheets[d] %in% out_area_sheets) & !(data_sheets[d] %in% out_density_sheets)) {
            		
            		# apply the annual scalar adjustment first
  					#for (r in 1:nrow(var_df)) {
  					#	# need to check number of years in each table; some have one less year than the area (e.g. annual variables)
  					#	if (num_area_years == change_col - 5) {
  					#		var_df[r, c(5:(change_col-1))] = var_df[r, c(5:(change_col-1))] * annual_scalar
  					#	} else {
  					#		var_df[r, c(5:(change_col-1))] = var_df[r, c(5:(change_col-1))] * annual_scalar[1:(num_area_years-1)]
  					#	}
  					#}
            		
    				# (4a) do each landtype within county
    				landtype_names <- unique(var_df$Land_Type)
    				# remove "All_land" from landtype_names
  					landtype_names <- landtype_names[!landtype_names %in% c("All_land")]
    				for (l in 1:length(landtype_names)) { 
      					# get current landtype name
      					landtype_name <- landtype_names[l]
      					# get the row index for this aggregation
   						reg_ind = which(var_df$Region =="All_region")
   						lt_ind = which(var_df$Land_Type == landtype_name)
   						own_ind = which(var_df$Ownership =="All_own")
   						row_ind = intersect(reg_ind, lt_ind)
   						row_ind = intersect(row_ind, own_ind)
      					# subset landtype-specific df
      					landtype_df_temp <- var_df[var_df$Land_Type == landtype_name,]
      					# delete last row to exclude the All_region row
      					landtype_df_temp <- landtype_df_temp[landtype_df_temp$Region != "All_region",]
      					# aggregate sum of landtype-specific areas for each column year
      					var_df[row_ind,c(5:change_col)] <- apply(landtype_df_temp[,c(5:change_col)], 2, sum)
    				}
    
    				# (4b) do each region in county (Excludes Ocean)
    				region_names <- unique(var_df$Region)
    				# remove All_region and Ocean
    				region_names <- region_names[!region_names %in% c("All_region","Ocean")]
    				for (r in 1:length(region_names)) { 
      					# get current region name
      					region_name <- region_names[r]
      					# get the row index for this aggregation
   						reg_ind = which(var_df$Region == region_name)
   						lt_ind = which(var_df$Land_Type == "All_land")
   						own_ind = which(var_df$Ownership =="All_own")
   						row_ind = intersect(reg_ind, lt_ind)
   						row_ind = intersect(row_ind, own_ind)
      					# subset region-specific df
      					region_df_temp <- var_df[var_df$Region == region_name,] 
      					# delete the All_land row
      					region_df_temp <- region_df_temp[region_df_temp$Land_Type != "All_land",]
      					# aggregate sum of region-specific areas for each column year
      					var_df[row_ind,c(5:change_col)] <- apply(region_df_temp[,c(5:change_col)], 2, sum)
    				}

    				# (4c) do all county land (Excludes Ocean)
    				reg_ind = which(var_df$Region == "All_region")
   					lt_ind = which(var_df$Land_Type == "All_land")
   					own_ind = which(var_df$Ownership =="All_own")
   					row_ind = intersect(reg_ind, lt_ind)
   					row_ind = intersect(row_ind, own_ind)
   					var_df[row_ind,c(5:change_col)] =
    					apply(var_df[var_df$Land_Type == "All_land" & var_df$Region != "All_region", c(5:change_col)], 2 , sum)
  					
  					# calculate the change column
					var_df[,change_col] <- var_df[, change_col - 1] - var_df[, 5]
            	} # end if rest of variables variables
            

            
            # round
            # managed and wildfire area have an extra id column
			if ( data_sheets[d] == "Managed_area" | data_sheets[d] == "Wildfire_area" ) {
				var_df[,c(6:change_col)] = round(var_df[,c(6:change_col)], 2)
			} else {
  				var_df[,c(5:change_col)] = round(var_df[,c(5:change_col)], 2)
  			}
  			# reorder the columns and drop the extras
  			var_df = var_df[,col_order]
  			# reorder the rows
  			agg_df = var_df[var_df$Land_Cat_ID == -1,]
  			all_df = agg_df[agg_df$Region == "All_region" & agg_df$Land_Type == "All_land",]
  			agg_df = agg_df[agg_df$Region != "All_region" | agg_df$Land_Type != "All_land",]
  			agg_df = agg_df[order(agg_df$Region, agg_df$Land_Type),]
  			agg_df = rbind(agg_df, all_df)
  			lc_df = var_df[var_df$Land_Cat_ID != -1,]
  			o_df = lc_df[lc_df$Region == "Ocean",]
  			lc_df = lc_df[lc_df$Region != "Ocean",]
  			lc_df = lc_df[order(lc_df$Land_Cat_ID),]
  			lc_df = rbind(lc_df, o_df)
  			var_df = rbind(lc_df, agg_df)
  			# replace original data with scaled data
  			data_df_list[[d]] = var_df
        	
        } # end d loop over data variables
		
		# write the scaled output file
		
		cat("Starting writing output for scenario ", s, " at", date(), "\n")
    
    	# put the output tables in a workbook
    	out_wrkbk =  loadWorkbook(out_file, create = TRUE)
    
    	createSheet(out_wrkbk, name = data_sheets)
    	clearSheet(out_wrkbk, sheet = data_sheets)
    	writeWorksheet(out_wrkbk, data = data_df_list, sheet = data_sheets, header = TRUE)
    
    	# write the workbook
    	saveWorkbook(out_wrkbk)
    
    	cat("Finished writing output for scenario ", s, " at", date(), "\n")
		
	} # end s loop over data files as scenarios
	
	cat("Finished write_scaled_outputs at", date(), "\n")
}