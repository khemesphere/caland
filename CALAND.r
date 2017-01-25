# CALAND.r

# This is the carbon accounting model for CA

# CAlifornia natural and working LANDs carbon and greenhouse gas model

# Inputs
# ca_carbon_input.xlsx
#	The initial carbon density, carbon fluxes, and management/fire/conversion carbon adjustments
# <scenario_name>.xlsx
#	The initial land area, managed area, fire area, and annual changes to these areas; also the annual mortality rates
#	Name the file something appropriate
# These files have matching formats, including the number of preceding rows, the land types, the ownership, the management, the fire

# Outputs
# <scenario_name>_output_###.xlsx
# "_output_" is appended to the input scenario name, then a tag to denote which input values were used (e.g., the default ### = "mean")
# output precision is to the integer (for ha and Mg C and their ratios)

# This model follows basic density (stock) and flow guidelines similar to IPCC protocols
# The initial year area data are used for the first year for carbon operations
# The area data for each year are operated on by the carbon adjustments for management, flux, and fire within that year
#	first eco fluxes are applied, then management, then fire
# Land conversion area changes are applied after the carbon operations, and conversion carbon fluxes assigned to that same year
# Each subsequent step uses the updated carbon values from the previous step
# The new carbon density and area are assigned to the beginning of next year

# Output positive flux values are land uptake; negative values are losses to the atmosphere

# all wood products are lumped together and labeled as "wood"

# This R script is in the caland directory, which should be the working directory
#	Open R by opening this R script, or set the working the directory to caland/
# setwd("<your_path>/caland/")

# The input excel files are in caland/inputs/
# Output excel file is written to caland/outputs/

# CALAND is now a function!
# 7 arguments:
#	scen_file		name of the scenario file; assumed to be in caland/inptus/
#	c_file			name of the carbon parameter input file; assumed to be in caland/inputs/
#	start_year		simulation begins at the beginning of this year
#	end_year		simulation ends at the beginning of this year (so the simulation goes through the end of end_year - 1)
#	value_col		select which carbon density and accumulation values to use; 4 = min, 5 = max, 6 = mean, 7 = std dev
#	ADD				for use with value_col==7: TRUE= add the std dev to the mean; FALSE= subtract the std dev from the mean
#	WRITE_OUT_FILE	TRUE= write the output file; FALSE= do not write the output file

# notes:
# carbon calcs occur in start_year up to end_year-1
# end_year denotes the final area after the changes in end_year-1
# density values are the stats of the total pixel population within each land type id
# accumulation values are stats of literature values

CALAND <- function(scen_file, c_file = "ca_carbon_input.xlsx", start_year = 2010, end_year = 2051, value_col = 6, ADD = TRUE, WRITE_OUT_FILE = TRUE) {

cat("Start CALAND at", date(), "\n")
# this enables java to use up to 4GB of memory for reading and writing excel files
options(java.parameters = "-Xmx4g" )

# to do: separate the selection of c density and accumulation non-mean values values

# output label for: value_col and ADD select which carbon density and accumulation values to use; see notes above
ftag = c("", "", "", "min", "max", "mean", "sd")

inputdir = "inputs/"
outputdir = "outputs/"
dir.create(outputdir, recursive=TRUE)

# get scenario name as file name without extension
scen_name = substr(scen_file, 1, nchar(scen_file) - 5)
# add the directory to the scen_file name and c_file name
scen_file = paste0(inputdir, scen_file)
c_file = paste0(inputdir, c_file)

# the start row of the tables is the same for all sheets
start_row = 12

# Several assumptions are contained between this line down to the output table lines
# They shouldn't need to be changed for differenct scenarios, but they would be useful for testing sensitivity of the model
# below the output tables and before the library load lines are names specific to columns in the input xlsx file

# this is used only for forest understory mortality
# default mortality is 1%
default_mort_frac = 0.01

# this is the default fration of root carbon to above ground veg carbon
default_below2above_frac = 0.20

# default fraction of understory to above main c
# this is for types not listed here: forest, savanna, woodland
default_under_frac = 0.10

# default fractions of dead material to assign to dead pools
# this is for types not listed here: forest, savanna, woodland
default_standdead_frac = 0.11
default_downdead_frac = 0.23
default_litter_frac = 0.66

# forest component biomass fractions from jenkins et al. 2003
leaffrac = 0.05
barkfrac = 0.12
branchfrac = 0.17
stemfrac = 0.66

# average half-life for all CA wood products (years) (stewart and nakamura 2012)
wp_half_life = 52

if (value_col != 7) {
	out_file = paste0(outputdir, scen_name, "_output_", ftag[value_col], ".xlsx")
}else {
	if(ADD) {
		out_file = paste0(outputdir, scen_name, "_output_" , ftag[value_col], "_add", ".xlsx")
	}else {
		out_file = paste0(outputdir, scen_name, "_output_" , ftag[value_col], "_sub", ".xlsx")
	}
}

# output tables
out_area_sheets = c("Area", "Managed_area", "Wildfire_area")
num_out_area_sheets = length(out_area_sheets)
out_density_sheets = c("All_orgC_den", "All_biomass_C_den", "Above_main_C_den", "Below_main_C_den", "Understory_C_den", "StandDead_C_den", "DownDead_C_den", "Litter_C_den", "Soil_orgC_den")
num_out_density_sheets = length(out_density_sheets)
out_stock_sheets = c("All_orgC_stock", "All_biomass_C_stock", "Above_main_C_stock", "Below_main_C_stock", "Understory_C_stock", "StandDead_C_stock", "DownDead_C_stock", "Litter_C_stock", "Soil_orgC_stock")
num_out_stock_sheets = length(out_stock_sheets)
out_atmos_sheets = c("Eco_CumGain_C_stock", "Total_Atmos_CumGain_C_stock", "Manage_Atmos_CumGain_C_stock", "Fire_Atmos_CumGain_C_stock", "LCC_Atmos_CumGain_C_stock", "Wood_Atmos_CumGain_C_stock", "Total_Energy2Atmos_C_stock", "Eco_AnnGain_C_stock", "Total_Atmos_AnnGain_C_stock", "Manage_Atmos_AnnGain_C_stock", "Fire_Atmos_AnnGain_C_stock", "LCC_Atmos_AnnGain_C_stock", "Wood_Atmos_AnnGain_C_stock", "Total_AnnEnergy2Atmos_C_stock")
num_out_atmos_sheets = length(out_atmos_sheets)
out_wood_sheets = c("Total_Wood_C_stock", "Total_Wood_CumGain_C_stock", "Total_Wood_CumLoss_C_stock", "Total_Wood_AnnGain_C_stock", "Total_Wood_AnnLoss_C_stock", "Manage_Wood_C_stock", "Manage_Wood_CumGain_C_stock", "Manage_Wood_CumLoss_C_stock", "Manage_Wood_AnnGain_C_stock", "Manage_Wood_AnnLoss_C_stock", "LCC_Wood_C_stock", "LCC_Wood_CumGain_C_stock", "LCC_Wood_CumLoss_C_stock", "LCC_Wood_AnnGain_C_stock", "LCC_Wood_AnnLoss_C_stock")
num_out_wood_sheets = length(out_wood_sheets)

# column names from the management table to calculate non-accum manage carbon adjustments
man_frac_names = c("Above_removed_frac", "StandDead_removed_frac", "Removed2Wood_frac", "Removed2Energy_frac", "Removed2Atmos_frac", "Understory2Atmos_frac", "DownDead2Atmos_frac", "Litter2Atmos_frac", "Soil2Atmos_frac", "Understory2DownDead_frac", "Above2StandDead_frac", "Below2Atmos_frac", "Below2Soil_frac")
num_manfrac_cols = length(man_frac_names)
# new c trans column names matching the non-accum manage frac names
c_trans_names = c("Above_removed_c", "StandDead_removed_c", "Removed2Wood_c", "Removed2Energy_c", "Removed2Atmos_c", "Understory2Atmos_c", "DownDead2Atmos_c", "Litter2Atmos_c", "Soil2Atmos_c", "Understory2DownDead_c", "Above2StandDead_c", "Below2Atmos_c", "Below2Soil_c")
# indices of the appropriate density source df for the non-accum manage frac to c calcs; corresponds with out_density_sheets above
# value == -1 indicates that the source is the removed c; take the sum of the first two c trans columns
manage_density_inds = c(3, 6, -1, -1, -1, 5, 7, 8, 9, 5, 3, 4, 4)

# column names from the fire table to calculate fire carbon adjustments
fire_frac_names = c("Above2Atmos_frac", "StandDead2Atmos_frac", "Understory2Atmos_frac", "DownDead2Atmos_frac", "Litter2Atmos_frac", "Above2StandDead_frac", "Understory2DownDead_frac", "Below2Atmos_frac", "Soil2Atmos_frac")
num_firefrac_cols = length(fire_frac_names)
# new c trans column names matching the fire frac names
firec_trans_names = c("Above2Atmos_c", "StandDead2Atmos_c", "Understory2Atmos_c", "DownDead2Atmos_c", "Litter2Atmos_c", "Above2StandDead_c", "Understory2DownDead_c", "Below2Atmos_c", "Soil2Atmos_c")
# indices of the appropriate density source df for the fire frac to c calcs; corresponds with out_density_sheets above
fire_density_inds = c(3, 6, 5, 7, 8, 3, 5, 4, 9)

# column names from the conversion to ag/urban table to calculate conversion to ag/urban carbon adjustments
conv_frac_names = c("Above_removed_conv_frac", "StandDead_removed_conv_frac", "Removed2Wood_conv_frac", "Removed2Energy_conv_frac", "Removed2Atmos_conv_frac", "Understory2Atmos_conv_frac", "DownDead2Atmos_conv_frac", "Litter2Atmos_conv_frac", "Soil2Atmos_conv_frac", "Understory2DownDead_conv_frac", "Below2Atmos_conv_frac", "Below2Soil_conv_frac")
num_convfrac_cols = length(conv_frac_names)
# new c trans column names matching the conversion frac names
convc_trans_names = c("Above_removed_conv_c", "StandDead_removed_conv_c", "Removed2Wood_conv_c", "Removed2Energy_conv_c", "Removed2Atmos_conv_c", "Understory2Atmos_conv_c", "DownDead2Atmos_conv_c", "Litter2Atmos_conv_c", "Soil2Atmos_conv_c", "Understory2DownDead_conv_c", "Below2Atmos_conv_c", "Below2Soil_conv_c")
# indices of the appropriate density source df for the conversion frac to c calcs; corresponds with out_density_sheets above
# value == -1 indicates that the source is the removed c; take the sum of the first two c trans columns
conv_density_inds = c(3, 6, -1, -1, -1, 5, 7, 8, 9, 5, 4, 4)

# Load all the required packages
libs <- c( "XLConnect" )
for( i in libs ) {
    if( !require( i, character.only=T ) ) {
        cat( "Couldn't load", i, "\n" )
        stop( "Use install.packages() to download this library\nOr use the GUI Package Installer\nInclude dependencies, and install it for local user if you do not have root access\n" )
    }
    library( i, character.only=T )
}

# Load the input files
c_wrkbk = loadWorkbook(c_file)
scen_wrkbk = loadWorkbook(scen_file)

# worksheet/table names
c_sheets = getSheets(c_wrkbk)
num_c_sheets = length(c_sheets)
scen_sheets = getSheets(scen_wrkbk)
num_scen_sheets = length(scen_sheets)

# NA values need to be converted to numeric
# the warnings thrown by readWorksheet below are ok because they just state that the NA string can't be converted a number so it is converted to NA value
c_col_types1 = c("numeric", "character", "character", rep("numeric",50))
c_col_types2 = c("numeric", "numeric", "character", "character", "character", rep("numeric",50))
c_col_types3 = c("numeric", "character", rep("numeric",50))

# Load the worksheets into a list of data frames
c_df_list <- list()
scen_df_list <- list()
for (i in 1:12) { # through conversion2ag_urban
	c_df_list[[i]] <- readWorksheet(c_wrkbk, i, startRow = start_row, colTypes = c_col_types1, forceConversion = TRUE)
}
for (i in 13:16) { # forest_manage to ag_manage
	c_df_list[[i]] <- readWorksheet(c_wrkbk, i, startRow = start_row, colTypes = c_col_types2, forceConversion = TRUE)
}
for (i in 17:17) { # wildfire
	c_df_list[[i]] <- readWorksheet(c_wrkbk, i, startRow = start_row, colTypes = c_col_types3, forceConversion = TRUE)
}
for (i in 1:2) { # annual change and initial area
	scen_df_list[[i]] <- readWorksheet(scen_wrkbk, i, startRow = start_row, colTypes = c_col_types1, forceConversion = TRUE)
}
for (i in 3:4) { # annual managed area and annual wildfire area
	scen_df_list[[i]] <- readWorksheet(scen_wrkbk, i, startRow = start_row, colTypes = c_col_types2, forceConversion = TRUE)
}
for (i in 5:5) { # annual mortality fraction
	scen_df_list[[i]] <- readWorksheet(scen_wrkbk, i, startRow = start_row, colTypes = c_col_types1, forceConversion = TRUE)
}
names(c_df_list) <- c_sheets
names(scen_df_list) <- scen_sheets

# remove the Xs added to the front of the year columns, and get the years as numbers
man_targetyear_labels = names(scen_df_list[[3]])[c(6:ncol(scen_df_list[[3]]))]
man_targetyear_labels = substr(man_targetyear_labels,2,nchar(man_targetyear_labels[1]))
names(scen_df_list[[3]])[c(6:ncol(scen_df_list[[3]]))] = man_targetyear_labels
man_targetyears = as.integer(substr(man_targetyear_labels,1,4))

fire_targetyear_labels = names(scen_df_list[[4]])[c(6:ncol(scen_df_list[[4]]))]
fire_targetyear_labels = substr(fire_targetyear_labels,2,nchar(fire_targetyear_labels[1]))
names(scen_df_list[[4]])[c(6:ncol(scen_df_list[[4]]))] = fire_targetyear_labels
fire_targetyears = as.integer(substr(fire_targetyear_labels,1,4))

mortality_targetyear_labels = names(scen_df_list[[5]])[c(4:ncol(scen_df_list[[5]]))]
mortality_targetyear_labels = substr(mortality_targetyear_labels,2,nchar(mortality_targetyear_labels[1]))
names(scen_df_list[[5]])[c(4:ncol(scen_df_list[[5]]))] = mortality_targetyear_labels
mortality_targetyears = as.integer(substr(mortality_targetyear_labels,1,4))

# get some tables

# these include all target years
man_target_df <- scen_df_list[[3]]
fire_target_df <- scen_df_list[[4]]
mortality_target_df <- scen_df_list[[5]]
# these are useful
conv_area_df = scen_df_list[[1]]
names(conv_area_df)[ncol(conv_area_df)] = "base_area_change"
vegc_uptake_df = c_df_list[[10]]
vegc_uptake_df$vegc_uptake_val = vegc_uptake_df[,value_col]
deadc_frac_df = c_df_list[[3]][,c("Land_Type_ID", "Land_Type", "Ownership")]
soilc_accum_df = c_df_list[[11]]
soilc_accum_df$soilc_accum_val = soilc_accum_df[,value_col]
conv_df = c_df_list[[12]]
man_forest_df = c_df_list[[13]]
forest_soilcaccumfrac_colind = which(names(man_forest_df) == "SoilCaccum_frac")
man_dev_df = c_df_list[[14]]
dev_soilcaccumfrac_colind = which(names(man_dev_df) == "SoilCaccum_frac")
man_grass_df = c_df_list[[15]]
man_ag_df = c_df_list[[16]]
fire_df = c_df_list[[17]]

# get the correct values for the accum tables if value is std dev
if(value_col == 7) { # std dev as value
	if(ADD) {
		vegc_uptake_df$vegc_uptake_val = vegc_uptake_df$vegc_uptake_val + vegc_uptake_df$Mean_Mg_ha_yr
		soilc_accum_df$soilc_accum_val = soilc_accum_df$soilc_accum_val + soilc_accum_df$Mean_Mg_ha_yr
	} else {
		vegc_uptake_df$vegc_uptake_val = vegc_uptake_df$Mean_Mg_ha_yr - vegc_uptake_df$vegc_uptake_val
		soilc_accum_df$soilc_accum_val = soilc_accum_df$Mean_Mg_ha_yr - soilc_accum_df$soilc_accum_val
	}
}

# create lists of the output tables
# change the NA value to zero for calculations
out_area_df_list <- list()
out_density_df_list <- list()
out_atmos_df_list <- list()
out_stock_df_list <- list()
out_wood_df_list <- list()
start_area_label = paste0(start_year, "_ha")
end_area_label = paste0(end_year, "_ha")
start_density_label = paste0(start_year, "_Mg_ha")
end_density_label = paste0(end_year, "_Mg_ha")
start_atmos_label = paste0(start_year, "_Mg")
end_atmos_label = paste0(end_year, "_Mg")
start_stock_label = paste0(start_year, "_Mg")
end_stock_label = paste0(end_year, "_Mg")
start_wood_label = paste0(start_year, "_Mg")
end_wood_label = paste0(end_year, "_Mg")

# area
out_area_df_list[[1]] <- scen_df_list[[2]]
names(out_area_df_list[[1]])[ncol(out_area_df_list[[1]])] <- as.character(start_area_label)
out_area_df_list[[2]] <- scen_df_list[[3]][,c(1:6)]
names(out_area_df_list[[2]])[ncol(out_area_df_list[[2]])] <- as.character(start_area_label)
#the wildfire out area df is added at the end because it has the breakdown across land type ids
for ( i in 1:(num_out_area_sheets-1)) {
	out_area_df_list[[i]][is.na(out_area_df_list[[i]])] <- 0.0
}

# c density
# update the all c and bio c sums using the components, mainly because the std dev input values will not be consistent
for ( i in 1:num_out_density_sheets) {
	out_density_df_list[[i]] <- c_df_list[[i]][,c(1,2,3,value_col)]
	names(out_density_df_list[[i]])[ncol(out_density_df_list[[i]])] <- as.character(start_density_label)
	if(value_col == 7) { # std dev as value
		# this will not be the same as the sum of the components, so update it later
		if(ADD) {
			out_density_df_list[[i]][,4] = out_density_df_list[[i]][,4] + c_df_list[[i]][,"Mean_Mg_ha"]
		} else {
			out_density_df_list[[i]][,4] = c_df_list[[i]][,"Mean_Mg_ha"] - out_density_df_list[[i]][,4]
		}
	}
	out_density_df_list[[i]][is.na(out_density_df_list[[i]])] <- 0.0
	out_density_df_list[[i]][,4] <- replace(out_density_df_list[[i]][,4], out_density_df_list[[i]][,4] < 0, 0.00)
}
names(out_density_df_list) <- out_density_sheets
# add up the total org c pool density
out_density_df_list[[1]][, start_density_label] = 0
for (i in 3:num_out_density_sheets) {
	out_density_df_list[[1]][, start_density_label] = out_density_df_list[[1]][, start_density_label] + out_density_df_list[[i]][, start_density_label]
}
	
# add up the biomass c pool density (all non-decomposed veg material; i.e. all non-soil c)
out_density_df_list[[2]][, start_density_label] = 0
for (i in 3:(num_out_density_sheets-1)) {
	out_density_df_list[[2]][, start_density_label] = out_density_df_list[[2]][, start_density_label] + out_density_df_list[[i]][, start_density_label]
}

# c stock
for (i in 1:num_out_stock_sheets) {
	out_stock_df_list[[i]] <- out_density_df_list[[1]]
	names(out_stock_df_list[[i]])[ncol(out_stock_df_list[[i]])] <- as.character(start_stock_label)
	out_stock_df_list[[i]][, start_stock_label] = out_density_df_list[[i]][, start_density_label] * out_area_df_list[[1]][,start_area_label]
}
names(out_stock_df_list) <- out_stock_sheets
for ( i in 1:num_out_stock_sheets) {
	out_stock_df_list[[i]][is.na(out_stock_df_list[[i]])] <- 0.0
}

# c to atmosphere (and c from atmosphere to ecosystems)
for (i in 1:num_out_atmos_sheets) {
	out_atmos_df_list[[i]] <- out_density_df_list[[1]]
	names(out_atmos_df_list[[i]])[ncol(out_atmos_df_list[[i]])] <- as.character(start_atmos_label)
	out_atmos_df_list[[i]][,ncol(out_atmos_df_list[[i]])] = 0.0
}
names(out_atmos_df_list) <- out_atmos_sheets
for ( i in 1:num_out_atmos_sheets) {
	out_atmos_df_list[[i]][is.na(out_atmos_df_list[[i]])] <- 0.0
}

# wood c stock
for (i in 1:num_out_wood_sheets) {
	out_wood_df_list[[i]] <- c_df_list[[1]][,c("Land_Type_ID", "Land_Type", "Ownership")]
	out_wood_df_list[[i]][,start_wood_label] = 0.0
}
names(out_wood_df_list) <- out_wood_sheets

# useful variables

man_area_sum = out_area_df_list[[2]]
names(man_area_sum)[ncol(man_area_sum)] <- "man_area"
man_area_sum$man_area_sum = 0.0

# loop over the years
for (year in start_year:(end_year-1)) {
#for (year in start_year:2017) {

	cat("\nStarting year ", year, "...\n")

	cur_density_label = paste0(year, "_Mg_ha")
	next_density_label = paste0(year+1, "_Mg_ha")
	cur_wood_label = paste0(year, "_Mg")
	next_wood_label = paste0(year+1, "_Mg")
	cur_area_label = paste0(year, "_ha")
	next_area_label = paste0(year+1, "_ha")
	cur_stock_label = paste0(year, "_Mg")
	next_stock_label = paste0(year+1, "_Mg")
	cur_atmos_label = paste0(year, "_Mg")
	next_atmos_label = paste0(year+1, "_Mg")

	# Determine the area weighted average eco fluxes based on the amount of managed land
	# use the running sum of the managed area for forest and range amendment, up to the total available area
	#  this is because the management changes the flux for an extended period of time, especially if the management is repeated later
	#  rangeland amendment is repeated on 10, 30, or 100 year periods
	# but ag is annual, and developed has its own system of independent areas
	# restoration and afforestation practices are not dependent on existing area, and are applied in land conversion
	#  afforestation area should not be included in forest aggregate managed area and aggregate managed area sum
	# store the difference between the unmanaged and averaged with management eco fluxes, per ag, soil, and forest
	
	# this is the current year total area by land type id
	tot_area_df = out_area_df_list[[1]][,c(1:3,ncol(out_area_df_list[[1]]))]
	names(tot_area_df)[names(tot_area_df) == cur_area_label] <- "tot_area"
	
	# reset the man_area_sum df
	man_area_sum = man_area_sum[,1:7]
	
	# determine the managed areas for this year from target years
	# linear interpolation between target years
	# if the year is past the final target year than use the final target year
	linds = which(man_targetyears <= year)
	hinds = which(man_targetyears >= year)
	prev_targetyear = max(man_targetyears[linds])
	next_targetyear = min(man_targetyears[hinds])
	pind = which(man_targetyears == prev_targetyear)
	nind = which(man_targetyears == next_targetyear)
	pcol = man_targetyear_labels[pind]
	ncol = man_targetyear_labels[nind]
	
	if (prev_targetyear == next_targetyear | length(hinds) == 0) {
		man_area_sum$man_area = man_target_df[,pcol]
	} else {
		man_area_sum$man_area = man_target_df[,pcol] + (year - prev_targetyear) * (man_target_df[,ncol] - man_target_df[,pcol]) / (next_targetyear - prev_targetyear)
	}

	# the developed practices are independent of each other and so they don't use the aggregate sums
	#  they use their individual practice sums
	# ag management does not use sum area because they are annual practices to maintain the benefits
	# afforestation and restoration are not dependent on existing area and are not included in aggregate managed area
	man_area_sum$man_area_sum = man_area_sum$man_area_sum + man_area_sum$man_area
	man_area_sum = merge(man_area_sum, tot_area_df, by = c("Land_Type_ID", "Land_Type","Ownership"), all.x = TRUE)
	man_area_sum = man_area_sum[order(man_area_sum$Land_Type_ID, man_area_sum$Manage_ID),]
	man_area_sum_agg = aggregate(man_area_sum ~ Land_Type_ID, man_area_sum[man_area_sum$Management != "Afforestation" & man_area_sum$Management != "Restoration",], FUN=sum)
	names(man_area_sum_agg)[ncol(man_area_sum_agg)] <- "man_area_sum_agg_extra"
	man_area_sum = merge(man_area_sum, man_area_sum_agg, by = "Land_Type_ID", all.x = TRUE)
	man_area_sum$man_area_sum_agg_extra = replace(man_area_sum$man_area_sum_agg_extra, is.na(man_area_sum$man_area_sum_agg_extra), 0)
	man_area_sum = man_area_sum[order(man_area_sum$Land_Type_ID, man_area_sum$Manage_ID),]
	man_area_sum$man_area_sum_agg_extra[man_area_sum$Land_Type == "Developed_all"] = man_area_sum$man_area_sum[man_area_sum$Land_Type == "Developed_all"]
	man_area_sum$man_area_sum_agg_extra[man_area_sum$Management == "Afforestation" | man_area_sum$Management == "Restoration"] = 0
	man_area_sum$excess_sum_area = man_area_sum$man_area_sum_agg_extra - man_area_sum$tot_area
	excess_sum_area_inds = which(man_area_sum$excess_sum_area > 0)
	man_area_sum$man_area_sum[excess_sum_area_inds] = man_area_sum$man_area_sum[excess_sum_area_inds] - man_area_sum$excess_sum_area[excess_sum_area_inds] * man_area_sum$man_area_sum[excess_sum_area_inds] / man_area_sum$man_area_sum_agg_extra[excess_sum_area_inds]
	man_area_sum$man_area_sum = replace(man_area_sum$man_area_sum, is.nan(man_area_sum$man_area_sum), 0)
	man_area_sum$man_area_sum = replace(man_area_sum$man_area_sum, man_area_sum$man_area_sum == Inf, 0)
	man_area_sum_agg2 = aggregate(man_area_sum ~ Land_Type_ID, man_area_sum[man_area_sum$Management != "Afforestation" & man_area_sum$Management != "Restoration",], FUN=sum)
	names(man_area_sum_agg2)[ncol(man_area_sum_agg2)] <- "man_area_sum_agg"
	man_area_sum = merge(man_area_sum, man_area_sum_agg2, by = "Land_Type_ID", all.x =TRUE)
	man_area_sum$man_area_sum_agg = replace(man_area_sum$man_area_sum_agg, is.na(man_area_sum$man_area_sum_agg), 0)
	man_area_sum = man_area_sum[order(man_area_sum$Land_Type_ID, man_area_sum$Manage_ID),]
	man_area_sum$man_area_sum_agg[man_area_sum$Land_Type == "Developed_all"] = man_area_sum$man_area_sum[man_area_sum$Land_Type == "Developed_all"]
	man_area_agg = aggregate(man_area ~ Land_Type_ID, man_area_sum[man_area_sum$Management != "Afforestation" & man_area_sum$Management != "Restoration",], FUN=sum)
	names(man_area_agg)[ncol(man_area_agg)] <- "man_area_agg_extra"
	man_area_sum = merge(man_area_sum, man_area_agg, by = "Land_Type_ID", all.x = TRUE)
	man_area_sum$man_area_agg_extra = replace(man_area_sum$man_area_agg_extra, is.na(man_area_sum$man_area_agg_extra), 0)
	man_area_sum = man_area_sum[order(man_area_sum$Land_Type_ID, man_area_sum$Manage_ID),]
	man_area_sum$man_area_agg_extra[man_area_sum$Land_Type == "Developed_all"] = man_area_sum$man_area[man_area_sum$Land_Type == "Developed_all"]
	man_area_sum$man_area_agg_extra[man_area_sum$Management == "Afforestation" | man_area_sum$Management == "Restoration"] = 0
	man_area_sum$excess_area = man_area_sum$man_area_agg_extra - man_area_sum$tot_area
	excess_area_inds = which(man_area_sum$excess_area > 0)
	man_area_sum$man_area[excess_area_inds] = man_area_sum$man_area[excess_area_inds] - man_area_sum$excess_area[excess_area_inds] * man_area_sum$man_area[excess_area_inds] / man_area_sum$man_area_agg_extra[excess_area_inds]
	man_area_sum$man_area_sum = replace(man_area_sum$man_area_sum, is.nan(man_area_sum$man_area_sum), 0)
	man_area_sum$man_area_sum = replace(man_area_sum$man_area_sum, man_area_sum$man_area_sum == Inf, 0)
	man_area_agg2 = aggregate(man_area ~ Land_Type_ID, man_area_sum[man_area_sum$Management != "Afforestation" & man_area_sum$Management != "Restoration",], FUN=sum)
	names(man_area_agg2)[ncol(man_area_agg2)] <- "man_area_agg"
	man_area_sum = merge(man_area_sum, man_area_agg2, by = "Land_Type_ID", all.x =TRUE)
	man_area_sum$man_area_agg = replace(man_area_sum$man_area_agg, is.na(man_area_sum$man_area_agg), 0)
	man_area_sum = man_area_sum[order(man_area_sum$Land_Type_ID, man_area_sum$Manage_ID),]
	man_area_sum$man_area_agg[man_area_sum$Land_Type == "Developed_all"] = man_area_sum$man_area[man_area_sum$Land_Type == "Developed_all"]
	# build some useful data frames
	all_c_flux = tot_area_df
	all_c_flux = merge(all_c_flux, man_area_agg2, by = "Land_Type_ID", all.x = TRUE)
	all_c_flux = all_c_flux[order(all_c_flux$Land_Type_ID),]
	all_c_flux$man_area_agg[all_c_flux$Land_Type == "Developed_all"] = man_area_sum$man_area[man_area_sum$Management == "Dead_removal"]
	na_inds = which(is.na(all_c_flux[,"man_area_agg"]))
	all_c_flux[na_inds,"man_area_agg"] = 0
	all_c_flux$unman_area = all_c_flux[,"tot_area"] - all_c_flux[,"man_area_agg"]
	all_c_flux = merge(all_c_flux, man_area_sum_agg2, by = "Land_Type_ID", all.x = TRUE)
	all_c_flux = all_c_flux[order(all_c_flux$Land_Type_ID),]
	all_c_flux$man_area_sum_agg[all_c_flux$Land_Type == "Developed_all"] = man_area_sum$man_area_sum[man_area_sum$Management == "Dead_removal"]
	na_inds = which(is.na(all_c_flux[,"man_area_sum_agg"]))
	all_c_flux[na_inds,"man_area_sum_agg"] = 0
	all_c_flux$unman_area_sum = all_c_flux[,"tot_area"] - all_c_flux[,"man_area_sum_agg"]
	
	man_adjust_df = rbind(man_grass_df, man_ag_df)
	man_adjust_df = rbind(man_adjust_df, man_forest_df[,c(1:5,forest_soilcaccumfrac_colind)])
	man_adjust_df = rbind(man_adjust_df, man_dev_df[,c(1:5,dev_soilcaccumfrac_colind)])
	man_adjust_df = merge(man_adjust_df, rbind(man_forest_df, man_dev_df), by = c("Land_Type_ID","Manage_ID", "Land_Type", "Ownership", "Management", "SoilCaccum_frac"), all.x = TRUE)
	man_adjust_df = merge(man_area_sum, man_adjust_df, by = c("Land_Type_ID","Manage_ID", "Land_Type", "Ownership", "Management"), all.x = TRUE)
	man_adjust_df = man_adjust_df[order(man_adjust_df$Land_Type_ID, man_adjust_df$Manage_ID),]
	# replace the NA values with more appropriate ones
	man_adjust_df[,c("SoilCaccum_frac","VegCuptake_frac","DeadCaccum_frac")] <- apply(man_adjust_df[,c("SoilCaccum_frac","VegCuptake_frac","DeadCaccum_frac")], 2, function (x) {replace(x, is.na(x), 1.00)})
	man_adjust_df[,c(6:ncol(man_adjust_df))] <- apply(man_adjust_df[,c(6:ncol(man_adjust_df))], 2, function (x) {replace(x, is.na(x), 0.00)})
	# the proportional increase in urban forest area is represented as a proportional increase in veg c uptake
	if (year == start_year) {
		start_urban_forest_fraction = man_adjust_df[man_adjust_df$Management == "Urban_forest","man_area"] / man_adjust_df[man_adjust_df$Management == "Urban_forest","tot_area"]
	}
	man_adjust_df[man_adjust_df$Management == "Urban_forest","VegCuptake_frac"] = man_adjust_df[man_adjust_df$Management == "Urban_forest","man_area"] / man_adjust_df[man_adjust_df$Management == "Urban_forest","tot_area"] / start_urban_forest_fraction
	
	# soil
	# agriculture uses the current year managed area
	man_soil_df = merge(man_adjust_df, soilc_accum_df, by = c("Land_Type_ID", "Land_Type","Ownership"), all = TRUE)
	man_soil_df = man_soil_df[order(man_soil_df$Land_Type_ID, man_soil_df$Manage_ID),]
	man_soil_df$soilcfluxXarea[man_soil_df$Land_Type != "Agriculture"] = man_soil_df$man_area_sum[man_soil_df$Land_Type != "Agriculture"] * man_soil_df$SoilCaccum_frac[man_soil_df$Land_Type != "Agriculture"] * man_soil_df$soilc_accum_val[man_soil_df$Land_Type != "Agriculture"]
	man_soil_df$soilcfluxXarea[man_soil_df$Land_Type == "Agriculture"] = man_soil_df$man_area[man_soil_df$Land_Type == "Agriculture"] * man_soil_df$SoilCaccum_frac[man_soil_df$Land_Type == "Agriculture"] * man_soil_df$soilc_accum_val[man_soil_df$Land_Type == "Agriculture"]
	man_soilflux_agg = aggregate(soilcfluxXarea ~ Land_Type_ID + Land_Type + Ownership, man_soil_df, FUN=sum)
	man_soilflux_agg = merge(all_c_flux, man_soilflux_agg, by = c("Land_Type_ID", "Land_Type","Ownership"), all = TRUE)
	na_inds = which(is.na(man_soilflux_agg$soilcfluxXarea))
	man_soilflux_agg$soilcfluxXarea[na_inds] = 0
	man_soilflux_agg = merge(man_soilflux_agg, man_soil_df[,c("Land_Type_ID", "Land_Type","Ownership", "soilc_accum_val")], by = c("Land_Type_ID", "Land_Type","Ownership"))
	man_soilflux_agg = man_soilflux_agg[order(man_soilflux_agg$Land_Type_ID),]
	man_soilflux_agg = unique(man_soilflux_agg)
	na_inds = which(is.na(man_soilflux_agg$soilc_accum_val))
	man_soilflux_agg[na_inds,"soilc_accum_val"] = 0
	man_soilflux_agg$fin_soilc_accum[man_soilflux_agg$Land_Type != "Agriculture"] = (man_soilflux_agg$soilcfluxXarea[man_soilflux_agg$Land_Type != "Agriculture"] + man_soilflux_agg$unman_area_sum[man_soilflux_agg$Land_Type != "Agriculture"] * man_soilflux_agg$soilc_accum_val[man_soilflux_agg$Land_Type != "Agriculture"]) / tot_area_df$tot_area[tot_area_df$Land_Type != "Agriculture"]
	man_soilflux_agg$fin_soilc_accum[man_soilflux_agg$Land_Type == "Agriculture"] = (man_soilflux_agg$soilcfluxXarea[man_soilflux_agg$Land_Type == "Agriculture"] + man_soilflux_agg$unman_area[man_soilflux_agg$Land_Type == "Agriculture"] * man_soilflux_agg$soilc_accum_val[man_soilflux_agg$Land_Type == "Agriculture"]) / tot_area_df$tot_area[tot_area_df$Land_Type == "Agriculture"]
	nan_inds = which(is.nan(man_soilflux_agg$fin_soilc_accum) | man_soilflux_agg$fin_soilc_accum == Inf)
	man_soilflux_agg$fin_soilc_accum[nan_inds] = man_soilflux_agg[nan_inds,"soilc_accum_val"]
	man_soilflux_agg$man_change_soilc_accum = man_soilflux_agg$fin_soilc_accum - man_soilflux_agg$soilc_accum_val
	
	# veg
	# all developed area veg c uptake is adjusted because urban forest increased
	#  so remove the other developed managements from this table and multiply by total area and use unman area = 0
	man_veg_df = merge(man_adjust_df, vegc_uptake_df, by = c("Land_Type_ID", "Land_Type","Ownership"), all = TRUE)
	man_veg_df = man_veg_df[order(man_veg_df$Land_Type_ID, man_veg_df$Manage_ID),]
	man_veg_df = man_veg_df[(man_veg_df$Management != "Dead_removal" & man_veg_df$Management != "Growth") | is.na(man_veg_df$Management),]
	man_veg_df$vegcfluxXarea = man_veg_df$man_area_sum * man_veg_df$VegCuptake_frac * man_veg_df$vegc_uptake_val
	man_veg_df$vegcfluxXarea[man_veg_df$Land_Type == "Developed_all"] = man_veg_df$tot_area[man_veg_df$Land_Type == "Developed_all"] * man_veg_df$VegCuptake_frac[man_veg_df$Land_Type == "Developed_all"] * man_veg_df$vegc_uptake_val[man_veg_df$Land_Type == "Developed_all"]
	man_vegflux_agg = aggregate(vegcfluxXarea ~ Land_Type_ID + Land_Type + Ownership, man_veg_df, FUN=sum)
	man_vegflux_agg = merge(all_c_flux, man_vegflux_agg, by = c("Land_Type_ID", "Land_Type","Ownership"), all = TRUE)
	na_inds = which(is.na(man_vegflux_agg$vegcfluxXarea))
	man_vegflux_agg$vegcfluxXarea[na_inds] = 0
	man_vegflux_agg = merge(man_vegflux_agg, man_veg_df[,c("Land_Type_ID", "Land_Type","Ownership", "vegc_uptake_val")], by = c("Land_Type_ID", "Land_Type","Ownership"))
	man_vegflux_agg = man_vegflux_agg[order(man_vegflux_agg$Land_Type_ID),]
	man_vegflux_agg = unique(man_vegflux_agg)
	na_inds = which(is.na(man_vegflux_agg$vegc_uptake_val))
	man_vegflux_agg[na_inds,"vegc_uptake_val"] = 0
	man_vegflux_agg$fin_vegc_uptake = (man_vegflux_agg$vegcfluxXarea + man_vegflux_agg$unman_area_sum * man_vegflux_agg$vegc_uptake_val) / tot_area_df$tot_area
	man_vegflux_agg$fin_vegc_uptake[man_vegflux_agg$Land_Type == "Developed_all"] = man_vegflux_agg$vegcfluxXarea[man_vegflux_agg$Land_Type == "Developed_all"] / tot_area_df$tot_area[man_vegflux_agg$Land_Type == "Developed_all"]
	nan_inds = which(is.nan(man_vegflux_agg$fin_vegc_uptake) | man_vegflux_agg$fin_vegc_uptake == Inf)
	man_vegflux_agg$fin_vegc_uptake[nan_inds] = man_vegflux_agg[nan_inds,"vegc_uptake_val"]
	man_vegflux_agg$man_change_vegc_uptake = man_vegflux_agg$fin_vegc_uptake - man_vegflux_agg$vegc_uptake_val
	
	# dead
	
	# determine the fractional mortality c rate of above ground main for this year from target years (from the current year mortality fraction)
	# this is then applied to the above ground main c pools and the below ground main c pools
	# the understory mortality is set to a default value at the beginning of this script
	# linear interpolation between target years
	# if the year is past the final target year than use the final target year
	linds = which(mortality_targetyears <= year)
	hinds = which(mortality_targetyears >= year)
	prev_targetyear = max(mortality_targetyears[linds])
	next_targetyear = min(mortality_targetyears[hinds])
	pind = which(mortality_targetyears == prev_targetyear)
	nind = which(mortality_targetyears == next_targetyear)
	pcol = mortality_targetyear_labels[pind]
	ncol = mortality_targetyear_labels[nind]
	
	if (prev_targetyear == next_targetyear | length(hinds) == 0) {
		deadc_frac_df$deadc_frac_in = mortality_target_df[,pcol]
	} else {
		deadc_frac_df$deadc_frac_in = mortality_target_df[,pcol] + (year - prev_targetyear) * (mortality_target_df[,ncol] - mortality_target_df[,pcol]) / (next_targetyear - prev_targetyear)
	}
	
	man_dead_df = merge(man_adjust_df, deadc_frac_df, by = c("Land_Type_ID", "Land_Type","Ownership"), all = TRUE)
	man_dead_df = man_dead_df[order(man_dead_df$Land_Type_ID, man_dead_df$Manage_ID),]
	man_dead_df$deadcfracXarea = man_dead_df$man_area_sum * man_dead_df$DeadCaccum_frac * man_dead_df$deadc_frac_in
	man_deadfrac_agg = aggregate(deadcfracXarea ~ Land_Type_ID + Land_Type + Ownership, man_dead_df, FUN=sum)
	man_deadfrac_agg = merge(all_c_flux, man_deadfrac_agg, by = c("Land_Type_ID", "Land_Type","Ownership"), all = TRUE)
	na_inds = which(is.na(man_deadfrac_agg$deadcfracXarea))
	man_deadfrac_agg$deadcfracXarea[na_inds] = 0
	man_deadfrac_agg = merge(man_deadfrac_agg, man_dead_df[,c("Land_Type_ID", "Land_Type","Ownership", "deadc_frac_in")], by = c("Land_Type_ID", "Land_Type","Ownership"))
	man_deadfrac_agg = man_deadfrac_agg[order(man_deadfrac_agg$Land_Type_ID),]
	man_deadfrac_agg = unique(man_deadfrac_agg)
	na_inds = which(is.na(man_deadfrac_agg$deadc_frac_in))
	man_deadfrac_agg[na_inds,"deadc_frac_in"] = 0
	man_deadfrac_agg$fin_deadc_frac = (man_deadfrac_agg$deadcfracXarea + man_deadfrac_agg$unman_area_sum * man_deadfrac_agg$deadc_frac_in) / tot_area_df$tot_area
	nan_inds = which(is.nan(man_deadfrac_agg$fin_deadc_frac) | man_deadfrac_agg$fin_deadc_frac == Inf)
	man_deadfrac_agg$fin_deadc_frac[nan_inds] = man_deadfrac_agg[nan_inds,"deadc_frac_in"]
	man_deadfrac_agg$man_change_deadc_accum = man_deadfrac_agg$fin_deadc_frac - man_deadfrac_agg$deadc_frac_in

	cat("Starting eco c transfers\n")

	# apply the eco fluxes to the carbon pools (current year area and carbon)
	# (final flux * tot area + density * tot area) / tot area
	# above main, below main, understory, stand dead, down dead, litter, soil
	
	# general procedure
	# assume veg uptake is net live standing biomass accum (sans mortality)
	# calculate net below ground accum based on above to below ratio
	# assume dead accum is net mortality, subtract from above veg uptake - this goes to standing dead, downed dead, litter
	# calculate net below ground mortality from dead accum to above accum ratio - this is only subtracted from below pool because soil c values are assumed to be net density changes
	# calculate net understory uptake and mortality from above values - this goes to downed dead and litter pools
	# estimate litter accum values from mortality and litter fraction of dead pools

	# notes
	# developed and ag have only above ground and soil c pools
	#  estimate above ground mortality like the rest, based on above ground flux, but send it to atmosphere
	# treat na values as zeros
	# mortality fractions are zero in the input table if no veg c accum is listed in the carbon inputs
	# these flux transfers are normalized to current tot_area, and gains are positive
	
	# forest above main accum needs net foliage and branches/bark accums added to it based on estimated component fractions
	# forest downed dead and litter accum are estimated from the added above c based on mort:vegc flux ratio - this goes from above to downed dead and litter - and this value is also a net value
	# forest dead standing is subtracted from above main
	# forest below main accum and understory accum need to calculated based on ratio of these existing densities to the above densities
	# forest understory mortality uses a 1% default value (so it is not directly affected by prescribed tree mortality) - this is added to downed dead and litter - as the additional veg c uptake is a net values, this accumulation is also a net value
	# forest below mortality is estimated based upon standing dead accum to vegc uptake ratio - this is only subtracted from below as soil c is a net value

	# savanna/woodland veg uptake is net above and below (sans mortality) - so split it based on existing ratios
	# savanna/woodland has net eco exchange flux based on the tree uptake and the soil accum so don't add any other flux unless it cancels out
	# savanna/woodland to include mortality: transfer mortality to standing and downed dead and litter proportionally
	# savanna/woodland to include mortality: transfer mortality of below density to soil c
	# savanna/woodland understory will stay the same over time

	# out density sheet names: c("All_orgC_den", "All_biomass_C_den", "Above_main_C_den", "Below_main_C_den", "Understory_C_den", "StandDead_C_den", "DownDead_C_den", "Litter_C_den", "Soil_orgC_den")
	# put the current year density values into the next year column to start with
	# then add the carbon transfers to the next year column
	# eco accum names
	egnames = NULL
	for (i in 1:num_out_density_sheets) {
		out_density_df_list[[i]][, next_density_label] = out_density_df_list[[i]][, cur_density_label]
		if(i >= 3) {
			egnames = c(egnames, paste0(out_density_sheets[i],"_gain_eco"))
			all_c_flux[,egnames[i-2]] = 0
		}
	}
	
	# forest
	
	# above main
	above_vals = out_density_df_list[[3]][out_density_df_list[[3]]$Land_Type == "Forest", cur_density_label]
	vegc_flux_vals = man_vegflux_agg$fin_vegc_uptake[man_vegflux_agg$Land_Type == "Forest"]
	added_vegc_flux_vals = vegc_flux_vals * (leaffrac + barkfrac + branchfrac) / stemfrac 
	deadc_flux_vals = man_deadfrac_agg$fin_deadc_frac[man_deadfrac_agg$Land_Type == "Forest"] * out_density_df_list[[3]][out_density_df_list[[3]]$Land_Type == "Forest", cur_density_label] * stemfrac
	above2dldead_flux_vals = man_deadfrac_agg$fin_deadc_frac[man_deadfrac_agg$Land_Type == "Forest"] * out_density_df_list[[3]][out_density_df_list[[3]]$Land_Type == "Forest", cur_density_label] * (1.0 - stemfrac)
	#deadc2vegc_ratios = deadc_flux_vals / vegc_flux_vals
	#above2dldead_flux_vals = deadc2vegc_ratios * added_vegc_flux_vals
	all_c_flux[all_c_flux$Land_Type == "Forest",egnames[1]] = vegc_flux_vals + added_vegc_flux_vals - deadc_flux_vals - above2dldead_flux_vals
		
	# standing dead
	all_c_flux[all_c_flux$Land_Type == "Forest",egnames[4]] = deadc_flux_vals
		
	# understory
	under_vals = out_density_df_list[[5]][out_density_df_list[[5]]$Land_Type == "Forest", cur_density_label]
	underfrac = under_vals / above_vals
	underc_flux_vals = underfrac * vegc_flux_vals / stemfrac
	under2dldead_flux_vals = default_mort_frac * out_density_df_list[[5]][out_density_df_list[[5]]$Land_Type == "Forest", cur_density_label]
	#under2dldead_flux_vals = deadc2vegc_ratios * underc_flux_vals
	all_c_flux[all_c_flux$Land_Type == "Forest",egnames[3]] = underc_flux_vals - under2dldead_flux_vals
	
	# downed dead and litter
	downfrac = out_density_df_list[[7]][out_density_df_list[[7]]$Land_Type == "Forest", cur_density_label] / (out_density_df_list[[7]][out_density_df_list[[7]]$Land_Type == "Forest", cur_density_label] + out_density_df_list[[8]][out_density_df_list[[8]]$Land_Type == "Forest", cur_density_label])
	# downded dead
	all_c_flux[all_c_flux$Land_Type == "Forest",egnames[5]] = downfrac * (above2dldead_flux_vals + under2dldead_flux_vals)
	# litter
	all_c_flux[all_c_flux$Land_Type == "Forest",egnames[6]] = (1.0 - downfrac) * (above2dldead_flux_vals + under2dldead_flux_vals)
		
	# below ground
	# recall that the input historical soil c fluxes are net, so the default historical mortality here implicitly goes to the soil
	#  but any change from the default mortality needs to be added to the soil
	#  so store the initial below ground mortality flux
	# assume that the other soil fluxes do not change (litter input rates and emissions) because I don't have enough info to change these
	#  basically, the litter input would change based on its density, and the emissions may increase with additional soil c
	below2dead_flux_vals = man_deadfrac_agg$fin_deadc_frac[man_deadfrac_agg$Land_Type == "Forest"] * out_density_df_list[[4]][out_density_df_list[[4]]$Land_Type == "Forest", cur_density_label]
	if (year == start_year) { below2dead_flux_initial_forest = below2dead_flux_vals }
	# first calculate the net root biomass increase
	below_vals = out_density_df_list[[4]][out_density_df_list[[4]]$Land_Type == "Forest", cur_density_label]
	rootfrac = below_vals / above_vals
	all_c_flux[all_c_flux$Land_Type == "Forest",egnames[2]] = rootfrac * vegc_flux_vals / stemfrac - below2dead_flux_vals
	
	# soil
	# need to add the difference due to chnages from default/initial mortality
	all_c_flux[all_c_flux$Land_Type == "Forest",egnames[7]] = man_soilflux_agg$fin_soilc_accum[man_soilflux_agg$Land_Type == "Forest"] + (below2dead_flux_vals - below2dead_flux_initial_forest)

	# savanna/woodland

	# above and below main
	# root loss has to go to soil c because the veg gain is tree nee, and the soil flux is ground nee, together they are the net flux
	#  so here changing mortality is already accounted for with respect to additions to soil carbon
	# transfer above loss proportionally to standing, down, and litter pools
	# leave understory c static because the available data are for a grass understory, which has no long-term veg accumulation
	above_vals = out_density_df_list[[3]][out_density_df_list[[3]]$Land_Type == "Savanna" | out_density_df_list[[3]]$Land_Type == "Woodland", cur_density_label]
	vegc_flux_vals = man_vegflux_agg$fin_vegc_uptake[man_vegflux_agg$Land_Type == "Savanna" | man_vegflux_agg$Land_Type == "Woodland"]
	below_vals = out_density_df_list[[4]][out_density_df_list[[4]]$Land_Type == "Savanna" | out_density_df_list[[4]]$Land_Type == "Woodland", cur_density_label]
	above_flux_vals = vegc_flux_vals * above_vals / (above_vals + below_vals)
	below_flux_vals = vegc_flux_vals * below_vals / (above_vals + below_vals)
	above2dead_flux_vals = man_deadfrac_agg$fin_deadc_frac[man_deadfrac_agg$Land_Type == "Savanna" | man_deadfrac_agg$Land_Type == "Woodland"] * above_vals
	#zinds = which(above2dead_flux_vals == 0 & above_flux_vals > 0)
	#above2dead_flux_vals[zinds] = default_mort_frac * above_vals[zinds]
	#deadc2vegc_ratios = above2dead_flux_vals / above_flux_vals
	below2dead_flux_vals = man_deadfrac_agg$fin_deadc_frac[man_deadfrac_agg$Land_Type == "Savanna" | man_deadfrac_agg$Land_Type == "Woodland"] * below_vals
	#naninds = which(is.nan(below2dead_flux_vals) & below_flux_vals > 0)
	#below2dead_flux_vals[naninds] = default_mort_frac * below_vals[naninds]
	#naninds = which(is.nan(below2dead_flux_vals))
	#below2dead_flux_vals[naninds] = 0
	all_c_flux[all_c_flux$Land_Type == "Savanna" | all_c_flux $Land_Type == "Woodland",egnames[1]] = above_flux_vals - above2dead_flux_vals
	all_c_flux[all_c_flux$Land_Type == "Savanna" | all_c_flux $Land_Type == "Woodland",egnames[2]] = below_flux_vals - below2dead_flux_vals

	# standing, down, and litter
	standdead_vals = out_density_df_list[[6]][out_density_df_list[[6]]$Land_Type == "Savanna" | out_density_df_list[[6]]$Land_Type == "Woodland", cur_density_label]
	downdead_vals = out_density_df_list[[7]][out_density_df_list[[7]]$Land_Type == "Savanna" | out_density_df_list[[7]]$Land_Type == "Woodland", cur_density_label]
	litter_vals = out_density_df_list[[8]][out_density_df_list[[8]]$Land_Type == "Savanna" | out_density_df_list[[8]]$Land_Type == "Woodland", cur_density_label]
	standdead_frac_vals = standdead_vals / (standdead_vals + downdead_vals + litter_vals)
	downdead_frac_vals = downdead_vals / (standdead_vals + downdead_vals + litter_vals)
	litter_frac_vals = litter_vals / (standdead_vals + downdead_vals + litter_vals)
	all_c_flux[all_c_flux$Land_Type == "Savanna" | all_c_flux $Land_Type == "Woodland",egnames[4]] = standdead_frac_vals * above2dead_flux_vals
	all_c_flux[all_c_flux$Land_Type == "Savanna" | all_c_flux $Land_Type == "Woodland",egnames[5]] = downdead_frac_vals * above2dead_flux_vals
	all_c_flux[all_c_flux$Land_Type == "Savanna" | all_c_flux $Land_Type == "Woodland",egnames[6]] = litter_frac_vals * above2dead_flux_vals

	# soil - recall that this is nee flux measurement, not density change, so the root mortality has to go to soil c
	soilc_flux_vals = man_soilflux_agg$fin_soilc_accum[man_soilflux_agg$Land_Type == "Savanna" | man_soilflux_agg$Land_Type == "Woodland"]
	all_c_flux[all_c_flux$Land_Type == "Savanna" | all_c_flux $Land_Type == "Woodland",egnames[7]] = soilc_flux_vals + below2dead_flux_vals

	# the rest
	# assume vegc flux is all standing net density change, sans mortality
	# assume above an understory deadc flux is all mort density change - take from above and distribute among stand, down, and litter
	# use mortality only if there is veg c accum due to growth
	# assume soilc flux is net density change - so the below is simply a net root density change, and the calculated mortality implicitly goes to soil
	above_vals = out_density_df_list[[3]][out_density_df_list[[3]]$Land_Type != "Savanna" & out_density_df_list[[3]]$Land_Type != "Woodland" & out_density_df_list[[3]]$Land_Type != "Forest", cur_density_label]
	below_vals = out_density_df_list[[4]][out_density_df_list[[4]]$Land_Type != "Savanna" & out_density_df_list[[4]]$Land_Type != "Woodland" & out_density_df_list[[4]]$Land_Type != "Forest", cur_density_label]
	under_vals = out_density_df_list[[5]][out_density_df_list[[5]]$Land_Type != "Savanna" & out_density_df_list[[5]]$Land_Type != "Woodland" & out_density_df_list[[5]]$Land_Type != "Forest", cur_density_label]
	standdead_vals = out_density_df_list[[6]][out_density_df_list[[6]]$Land_Type != "Savanna" & out_density_df_list[[6]]$Land_Type != "Woodland" & out_density_df_list[[6]]$Land_Type != "Forest", cur_density_label]
	downdead_vals = out_density_df_list[[7]][out_density_df_list[[7]]$Land_Type != "Savanna" & out_density_df_list[[7]]$Land_Type != "Woodland" & out_density_df_list[[7]]$Land_Type != "Forest", cur_density_label]
	litter_vals = out_density_df_list[[8]][out_density_df_list[[8]]$Land_Type != "Savanna" & out_density_df_list[[8]]$Land_Type != "Woodland" & out_density_df_list[[8]]$Land_Type != "Forest", cur_density_label]
	soil_vals = out_density_df_list[[9]][out_density_df_list[[9]]$Land_Type != "Savanna" & out_density_df_list[[9]]$Land_Type != "Woodland" & out_density_df_list[[9]]$Land_Type != "Forest", cur_density_label]
	# above and below
	above_flux_vals = man_vegflux_agg$fin_vegc_uptake[man_vegflux_agg$Land_Type != "Savanna" & man_vegflux_agg$Land_Type != "Woodland" & man_vegflux_agg$Land_Type != "Forest"]
	below_flux_vals = above_flux_vals * below_vals / above_vals
	naninds = which(is.nan(below_flux_vals))
	below_flux_vals[naninds] = above_flux_vals[naninds] * default_below2above_frac
	#deadc_flux_vals = man_deadfrac_agg$fin_deadc_frac[man_deadfrac_agg$Land_Type != "Savanna" & man_deadfrac_agg$Land_Type != "Woodland" & man_deadfrac_agg$Land_Type != "Forest"]
	soilc_flux_vals = man_soilflux_agg$fin_soilc_accum[man_soilflux_agg$Land_Type != "Savanna" & man_soilflux_agg$Land_Type != "Woodland" & man_soilflux_agg$Land_Type != "Forest"]
	above2dead_flux_vals = man_deadfrac_agg$fin_deadc_frac[man_deadfrac_agg$Land_Type != "Savanna" & man_deadfrac_agg$Land_Type != "Woodland" & man_deadfrac_agg$Land_Type != "Forest"] * above_vals
	#zinds = which(above2dead_flux_vals == 0 & above_flux_vals > 0)
	#above2dead_flux_vals[zinds] = default_mort_frac * above_vals[zinds]
	#deadc2vegc_ratios = above2dead_flux_vals / above_flux_vals
	# recall that the input historical soil c fluxes are net, so the default historical mortality here implicitly goes to the soil
	#  but any change from the default mortality needs to be added to the soil
	#  so store the initial below ground mortality flux
	# assume that the other soil fluxes do not change (litter input rates and emissions) because I don't have enough info to change these
	#  basically, the litter input would change based on its density, and the emissions may increase with additional soil c
	below2dead_flux_vals = man_deadfrac_agg$fin_deadc_frac[man_deadfrac_agg$Land_Type != "Savanna" & man_deadfrac_agg$Land_Type != "Woodland" & man_deadfrac_agg$Land_Type != "Forest"] * below_vals
	if (year == start_year) { below2dead_flux_initial_rest = below2dead_flux_vals }
	#naninds = which(is.nan(below2dead_flux_vals) & below_flux_vals > 0)
	#below2dead_flux_vals[naninds] = default_mort_frac * below_vals[naninds]
	#naninds = which(is.nan(below2dead_flux_vals))
	#below2dead_flux_vals[naninds] = 0
	
	# above
	all_c_flux[all_c_flux$Land_Type != "Savanna" & all_c_flux$Land_Type != "Woodland" & all_c_flux$Land_Type != "Forest",egnames[1]] = above_flux_vals - above2dead_flux_vals

	# below
	all_c_flux[all_c_flux$Land_Type != "Savanna" & all_c_flux$Land_Type != "Woodland" & all_c_flux$Land_Type != "Forest",egnames[2]] = below_flux_vals - below2dead_flux_vals

	# understory
	underfrac = under_vals / above_vals
	underc_flux_vals = underfrac * above_flux_vals
	naninds = which(is.nan(underc_flux_vals))
	underc_flux_vals[naninds] = default_under_frac * above_flux_vals[naninds]
	under2dead_flux_vals = default_mort_frac * out_density_df_list[[5]][out_density_df_list[[5]]$Land_Type != "Savanna" & out_density_df_list[[5]]$Land_Type != "Woodland" & out_density_df_list[[5]]$Land_Type != "Forest", cur_density_label]
	#under2dead_flux_vals = deadc2vegc_ratios * underc_flux_vals
	#naninds = which(is.nan(under2dead_flux_vals) & underc_flux_vals > 0)
	#under2dead_flux_vals[naninds] = default_mort_frac * under_vals[naninds]
	#naninds = which(is.nan(under2dead_flux_vals))
	#under2dead_flux_vals[naninds] = 0
	all_c_flux[all_c_flux$Land_Type != "Savanna" & all_c_flux$Land_Type != "Woodland" & all_c_flux$Land_Type != "Forest",egnames[3]] = underc_flux_vals - under2dead_flux_vals

	# stand, down, litter
	standdead_frac_vals = standdead_vals / (standdead_vals + downdead_vals + litter_vals)
	naninds = which(is.nan(standdead_frac_vals))
	standdead_frac_vals[naninds] = default_standdead_frac
	downdead_frac_vals = downdead_vals / (standdead_vals + downdead_vals + litter_vals)
	naninds = which(is.nan(downdead_frac_vals))
	downdead_frac_vals[naninds] = default_downdead_frac
	litter_frac_vals = litter_vals / (standdead_vals + downdead_vals + litter_vals)
	naninds = which(is.nan(litter_frac_vals))
	litter_frac_vals[naninds] = default_litter_frac
	all_c_flux[all_c_flux$Land_Type != "Savanna" & all_c_flux$Land_Type != "Woodland" & all_c_flux$Land_Type != "Forest",egnames[4]] = standdead_frac_vals * (above2dead_flux_vals + under2dead_flux_vals)
	all_c_flux[all_c_flux$Land_Type != "Savanna" & all_c_flux$Land_Type != "Woodland" & all_c_flux$Land_Type != "Forest",egnames[5]] = downdead_frac_vals * (above2dead_flux_vals + under2dead_flux_vals)
	all_c_flux[all_c_flux$Land_Type != "Savanna" & all_c_flux$Land_Type != "Woodland" & all_c_flux$Land_Type != "Forest",egnames[6]] = litter_frac_vals * (above2dead_flux_vals + under2dead_flux_vals)

	# soil
	# add any c due to changes from default/initial mortality
	all_c_flux[all_c_flux$Land_Type != "Savanna" & all_c_flux$Land_Type != "Woodland" & all_c_flux$Land_Type != "Forest",egnames[7]] = soilc_flux_vals + (below2dead_flux_vals - below2dead_flux_initial_rest)

	# clean up numerical errors
	all_c_flux[,c(7:ncol(all_c_flux))] <- apply(all_c_flux[,c(7:ncol(all_c_flux))], 2, function (x) {replace(x, is.na(x), 0.00)})
	all_c_flux[,c(7:ncol(all_c_flux))] <- apply(all_c_flux[,c(7:ncol(all_c_flux))], 2, function (x) {replace(x, is.nan(x), 0.00)})
	all_c_flux[,c(7:ncol(all_c_flux))] <- apply(all_c_flux[,c(7:ncol(all_c_flux))], 2, function (x) {replace(x, x == Inf, 0.00)})

	# loop over the out density tables to update the carbon pools based on the eco fluxes
	# carbon cannot go below zero
	sum_change = 0
	sum_neg_eco = 0
	for (i in 3:num_out_density_sheets) {
		sum_change = sum_change + sum(all_c_flux[, egnames[i-2]] * all_c_flux$tot_area)
		out_density_df_list[[i]][, next_density_label] = out_density_df_list[[i]][, next_density_label] + all_c_flux[, egnames[i-2]]
		# first calc the carbon not subtracted because it sends density negative
		neginds = which(out_density_df_list[[i]][, next_density_label] < 0)
		cat("neginds for out_density_df_list eco" , i, "are", neginds, "\n")
		sum_neg_eco = sum_neg_eco + sum(all_c_flux$tot_area[out_density_df_list[[i]][,next_density_label] < 0] * out_density_df_list[[i]][out_density_df_list[[i]][,next_density_label] < 0, next_density_label])
		out_density_df_list[[i]][, next_density_label] <- replace(out_density_df_list[[i]][, next_density_label], out_density_df_list[[i]][, next_density_label] <= 0, 0.00)
	} # end loop over out densities for updating due to eco fluxes
	cat("eco carbon change is", sum_change, "\n")
	cat("eco negative carbon cleared is", sum_neg_eco, "\n")

	######
	######
	# apply the transfer (non-eco, non-accum) flux management to the carbon pools (current year area and updated carbon)
	cat("Starting manage c transfers\n")
	
	# loop over the non-accum manage frac columns to calculate the transfer carbon density for each frac column
	# the transfer carbon density is based on tot_area so that it can be aggregated and subtracted directly from the current density
	for (i in 1:num_manfrac_cols){
		# the removed values are calculated first, so this will work
		# if manage_density_inds[i] == -1, then the source is the removed pool; use the sum of the first two c trans columns
		if (manage_density_inds[i] == -1) {
			man_adjust_df[,c_trans_names[i]] = (man_adjust_df[,c_trans_names[1]] + man_adjust_df[,c_trans_names[2]]) * man_adjust_df[,man_frac_names[i]]
		} else {
			if (!out_density_sheets[manage_density_inds[i]] %in% colnames(man_adjust_df)) {
				man_adjust_df = merge(man_adjust_df, out_density_df_list[[manage_density_inds[i]]][,c("Land_Type_ID", "Land_Type", "Ownership", next_density_label)], by = c("Land_Type_ID", "Land_Type", "Ownership"), all.x = TRUE)
				names(man_adjust_df)[names(man_adjust_df) == next_density_label] = out_density_sheets[manage_density_inds[i]]
			}
			man_adjust_df[,c_trans_names[i]] = man_adjust_df[,out_density_sheets[manage_density_inds[i]]] * man_adjust_df[,man_frac_names[i]] * man_adjust_df$man_area / man_adjust_df$tot_area
		}
	} # end for i loop over the managed transfer fractions for calcuting the transfer carbon
	man_adjust_df = man_adjust_df[order(man_adjust_df$Land_Type_ID),]
	man_adjust_df[,c(6:ncol(man_adjust_df))] <- apply(man_adjust_df[,c(6:ncol(man_adjust_df))], 2, function (x) {replace(x, is.na(x), 0.00)})
	man_adjust_df[,c(6:ncol(man_adjust_df))] <- apply(man_adjust_df[,c(6:ncol(man_adjust_df))], 2, function (x) {replace(x, is.nan(x), 0.00)})
	man_adjust_df[,c(6:ncol(man_adjust_df))] <- apply(man_adjust_df[,c(6:ncol(man_adjust_df))], 2, function (x) {replace(x, x == Inf, 0.00)})
	
	# now consolidate the c density transfers to the pools
	# convert these to gains for consistency: all terrestrial gains are positive, losses are negative
	# store the names for aggregation below
	agg_names = NULL
	# above
	agg_names = c(agg_names, paste0(out_density_sheets[3], "_gain_man"))
	man_adjust_df[,agg_names[1]] = -man_adjust_df$Above_removed_c - man_adjust_df$Above2StandDead_c
	# below
	agg_names = c(agg_names, paste0(out_density_sheets[4], "_gain_man"))
	man_adjust_df[,agg_names[2]] = -man_adjust_df$Below2Soil_c - man_adjust_df$Below2Atmos_c
	# understory
	agg_names = c(agg_names, paste0(out_density_sheets[5], "_gain_man"))
	man_adjust_df[,agg_names[3]] = -man_adjust_df$Understory2Atmos_c - man_adjust_df$Understory2DownDead_c
	# standing dead
	agg_names = c(agg_names, paste0(out_density_sheets[6], "_gain_man"))
	man_adjust_df[,agg_names[4]] = -man_adjust_df$StandDead_removed_c + man_adjust_df$Above2StandDead_c
	# down dead
	agg_names = c(agg_names, paste0(out_density_sheets[7], "_gain_man"))
	man_adjust_df[,agg_names[5]] = -man_adjust_df$DownDead2Atmos_c + man_adjust_df$Understory2DownDead_c
	# litter
	agg_names = c(agg_names, paste0(out_density_sheets[8], "_gain_man"))
	man_adjust_df[,agg_names[6]] = -man_adjust_df$Litter2Atmos_c
	# soil
	agg_names = c(agg_names, paste0(out_density_sheets[9], "_gain_man"))
	man_adjust_df[,agg_names[7]] = -man_adjust_df$Soil2Atmos_c + man_adjust_df$Below2Soil_c
	# to get the carbon must multiply these by the tot_area
	# atmos
	agg_names = c(agg_names, paste0("Land2Atmos_c_stock_man"))
	man_adjust_df[,agg_names[8]] = -man_adjust_df$tot_area * (man_adjust_df$Soil2Atmos_c + man_adjust_df$Litter2Atmos_c + man_adjust_df$DownDead2Atmos_c + man_adjust_df$Understory2Atmos_c + man_adjust_df$Removed2Atmos_c + man_adjust_df$Below2Atmos_c)
	# energy - this is assume to go to the atmosphere immediately
	agg_names = c(agg_names, paste0("Land2Energy_c_stock_man"))
	man_adjust_df[,agg_names[9]] = -man_adjust_df$tot_area * man_adjust_df$Removed2Energy_c
	# wood - this decays with a half-life
	agg_names = c(agg_names, paste0("Land2Wood_c_stock_man"))
	man_adjust_df[,agg_names[10]] = -man_adjust_df$tot_area * man_adjust_df$Removed2Wood_c
	
	# now aggregate to land type by summing the management options
	# these c density values are the direct changes to the overall c density
	# the c stock values are the total carbon form each land type going to atmos, energy (atmos), and wood
	agg_cols = array(dim=c(length(man_adjust_df$Land_Type_ID),length(agg_names)))
	for (i in 1:length(agg_names)) {
		agg_cols[,i] = man_adjust_df[,agg_names[i]]
	}
	man_adjust_agg = aggregate(agg_cols ~ Land_Type_ID + Land_Type + Ownership, data=man_adjust_df, FUN=sum)
	agg_names2 = paste0(agg_names,"_agg")
	names(man_adjust_agg)[c(4:ncol(man_adjust_agg))] = agg_names2
	# merge these values to the unman area table to apply the adjustments to each land type
	all_c_flux = merge(all_c_flux, man_adjust_agg, by = c("Land_Type_ID", "Land_Type", "Ownership"), all.x = TRUE)
	all_c_flux = all_c_flux[order(all_c_flux$Land_Type_ID),]
	all_c_flux[,c(7:ncol(all_c_flux))] <- apply(all_c_flux[,c(7:ncol(all_c_flux))], 2, function (x) {replace(x, is.na(x), 0.00)})
	all_c_flux[,c(7:ncol(all_c_flux))] <- apply(all_c_flux[,c(7:ncol(all_c_flux))], 2, function (x) {replace(x, is.nan(x), 0.00)})
	all_c_flux[,c(7:ncol(all_c_flux))] <- apply(all_c_flux[,c(7:ncol(all_c_flux))], 2, function (x) {replace(x, x == Inf, 0.00)})

	# loop over the out density tables to update the carbon pools based on the management fluxes
	# carbon cannot go below zero
	sum_change = 0
	sum_neg_man = 0
	for (i in 3:num_out_density_sheets) {
		sum_change = sum_change + sum(all_c_flux[, agg_names2[i-2]] * all_c_flux$tot_area)
		out_density_df_list[[i]][, next_density_label] = out_density_df_list[[i]][, next_density_label] + all_c_flux[, agg_names2[i-2]]
		# first calc the carbon not subtracted because it sends density negative
		neginds = which(out_density_df_list[[i]][, next_density_label] < 0)
		cat("neginds for out_density_df_list manage" , i, "are", neginds, "\n")
		sum_neg_man = sum_neg_man + sum(all_c_flux$tot_area[out_density_df_list[[i]][,next_density_label] < 0] * out_density_df_list[[i]][out_density_df_list[[i]][,next_density_label] < 0, next_density_label])
		out_density_df_list[[i]][, next_density_label] <- replace(out_density_df_list[[i]][, next_density_label], out_density_df_list[[i]][, next_density_label] <= 0, 0.00)
	} # end loop over out densities for updating due to veg management
	cat("manage carbon change is ", sum_change, "\n")
	cat("manage carbon to wood is ", sum(man_adjust_agg$Land2Wood_c_stock_man), "\n")
	cat("manage carbon to atmos is ", sum(man_adjust_agg$Land2Atmos_c_stock_man), "\n")
	cat("manage carbon to energy is ", sum(man_adjust_agg$Land2Energy_c_stock_man), "\n")
	cat("manage negative carbon cleared is ", sum_neg_man, "\n")

	# update the managed wood tables
	# recall that the transfers from land are negative values
	# use the IPCC half life equation for first order decay of wood products, and the CA average half life for all products
	#  this includes the current year loss on the current year production
	# running stock and cumulative change values are at the beginning of the labeled year - so the next year value is the stock or sum after current year production and loss
	# annual change values are in the year they occurred
	
	k = log(2) / wp_half_life
	out_wood_df_list[[6]][,next_wood_label] = out_wood_df_list[[6]][,cur_wood_label] * exp(-k) + ((1 - exp(-k)) / k) * -all_c_flux$Land2Wood_c_stock_man_agg
	out_wood_df_list[[7]][,next_wood_label] = out_wood_df_list[[7]][,cur_wood_label] - all_c_flux$Land2Wood_c_stock_man_agg
	out_wood_df_list[[9]][,cur_wood_label] = -all_c_flux$Land2Wood_c_stock_man_agg
	out_wood_df_list[[10]][,cur_wood_label] = out_wood_df_list[[6]][,cur_wood_label] - all_c_flux$Land2Wood_c_stock_man_agg - out_wood_df_list[[6]][,next_wood_label]
	out_wood_df_list[[8]][,next_wood_label] = out_wood_df_list[[8]][,cur_wood_label] + out_wood_df_list[[10]][,cur_wood_label]
	
	####
	####
	# apply fire to the carbon pools (current year area and updated carbon)
	# distribute fire to forest, woodland, savanna, shrubland, and grassland, proportionally within the ownerships
	# assume that burn area is not reflected in the baseline land type change numbers
	#  (which isn't necessarily the case)
	cat("Starting fire c transfers\n")
	
	# calculate this years fire area based on the targets
	# if the year is past the final target year than use the final target year
	linds = which(fire_targetyears <= year)
	hinds = which(fire_targetyears >= year)
	prev_targetyear = max(fire_targetyears[linds])
	next_targetyear = min(fire_targetyears[hinds])
	pind = which(fire_targetyears == prev_targetyear)
	nind = which(fire_targetyears == next_targetyear)
	pcol = fire_targetyear_labels[pind]
	ncol = fire_targetyear_labels[nind]
	
	fire_area_df = fire_target_df[,c(1:5)]
	if (prev_targetyear == next_targetyear | length(hinds) == 0) {
		fire_area_df[,pcol] = fire_target_df[,pcol]
	} else {
		fire_area_df = fire_target_df[,c(1:5,pcol)]
		fire_area_df[,pcol] = fire_target_df[,pcol] + (year - prev_targetyear) * (fire_target_df[,ncol] - fire_target_df[,pcol]) / (next_targetyear - prev_targetyear)
	}

	names(fire_area_df)[names(fire_area_df) == pcol] = "fire_own_area"
	fire_adjust_df = merge(fire_area_df, fire_df, by = c("Fire_ID", "Intensity"), all.x = TRUE)
	fire_adjust_df$Land_Type_ID = NULL
	fire_adjust_df$Land_Type = NULL
	fire_adjust_df = merge(tot_area_df, fire_adjust_df, by = c("Ownership"), all.x = TRUE)
	fire_adjust_df = fire_adjust_df[fire_adjust_df$Land_Type == "Forest" | fire_adjust_df$Land_Type == "Woodland" | fire_adjust_df$Land_Type == "Savanna" | fire_adjust_df$Land_Type == "Grassland" | fire_adjust_df$Land_Type == "Shrubland",]
	avail_own_area = aggregate(tot_area ~ Ownership, data = unique(fire_adjust_df[,c(1:4)]), sum)
	names(avail_own_area)[2] = "avail_own_area"
	fire_adjust_df = merge(avail_own_area, fire_adjust_df, by = c("Ownership"), all.y = TRUE)
	fire_adjust_df$fire_own_area <- replace(fire_adjust_df$fire_own_area, fire_adjust_df$fire_own_area > fire_adjust_df$avail_own_area, fire_adjust_df$avail_own_area)
	fire_adjust_df$fire_burn_area = fire_adjust_df$fire_own_area * fire_adjust_df$tot_area / fire_adjust_df$avail_own_area
	
	# loop over the fire frac columns to calculate the transfer carbon density for each frac column
	# the transfer carbon density is based on tot_area so that it can be aggregated and subtracted directly from the current density
	for (i in 1:num_firefrac_cols){
		if (!out_density_sheets[fire_density_inds[i]] %in% colnames(fire_adjust_df)) {
			fire_adjust_df = merge(fire_adjust_df, out_density_df_list[[fire_density_inds[i]]][,c("Land_Type_ID", "Land_Type", "Ownership", next_density_label)], by = c("Land_Type_ID", "Land_Type", "Ownership"), all.x = TRUE)
			names(fire_adjust_df)[names(fire_adjust_df) == next_density_label] = out_density_sheets[fire_density_inds[i]]
		}
		fire_adjust_df[,firec_trans_names[i]] = fire_adjust_df[,out_density_sheets[fire_density_inds[i]]] * fire_adjust_df[,fire_frac_names[i]] * fire_adjust_df$fire_burn_area / fire_adjust_df$tot_area
	} # end for loop over the fire transfer fractions for calcuting the transfer carbon
	fire_adjust_df = fire_adjust_df[order(fire_adjust_df$Land_Type_ID),]
	fire_adjust_df[,c(8:ncol(fire_adjust_df))] <- apply(fire_adjust_df[,c(8:ncol(fire_adjust_df))], 2, function (x) {replace(x, is.na(x), 0.00)})
	fire_adjust_df[,c(8:ncol(fire_adjust_df))] <- apply(fire_adjust_df[,c(8:ncol(fire_adjust_df))], 2, function (x) {replace(x, is.nan(x), 0.00)})
	fire_adjust_df[,c(8:ncol(fire_adjust_df))] <- apply(fire_adjust_df[,c(8:ncol(fire_adjust_df))], 2, function (x) {replace(x, x == Inf, 0.00)})

	# now consolidate the c density transfers to the pools
	# convert these to gains for consistency: all terrestrial gains are positive, losses are negative
	# store the names for aggregation below
	fire_agg_names = NULL
	# above
	fire_agg_names = c(fire_agg_names, paste0(out_density_sheets[3], "_gain"))
	fire_adjust_df[,fire_agg_names[1]] = -fire_adjust_df$Above2Atmos_c - fire_adjust_df$Above2StandDead_c
	# below
	fire_agg_names = c(fire_agg_names, paste0(out_density_sheets[4], "_gain"))
	fire_adjust_df[,fire_agg_names[2]] = -fire_adjust_df$Below2Atmos_c
	# understory
	fire_agg_names = c(fire_agg_names, paste0(out_density_sheets[5], "_gain"))
	fire_adjust_df[,fire_agg_names[3]] = -fire_adjust_df$Understory2Atmos_c - fire_adjust_df$Understory2DownDead_c
	# standing dead
	fire_agg_names = c(fire_agg_names, paste0(out_density_sheets[6], "_gain"))
	fire_adjust_df[,fire_agg_names[4]] = -fire_adjust_df$StandDead2Atmos_c + fire_adjust_df$Above2StandDead_c
	# down dead
	fire_agg_names = c(fire_agg_names, paste0(out_density_sheets[7], "_gain"))
	fire_adjust_df[,fire_agg_names[5]] = -fire_adjust_df$DownDead2Atmos_c + fire_adjust_df$Understory2DownDead_c
	# litter
	fire_agg_names = c(fire_agg_names, paste0(out_density_sheets[8], "_gain"))
	fire_adjust_df[,fire_agg_names[6]] = -fire_adjust_df$Litter2Atmos_c
	# soil
	fire_agg_names = c(fire_agg_names, paste0(out_density_sheets[9], "_gain"))
	fire_adjust_df[,fire_agg_names[7]] = -fire_adjust_df$Soil2Atmos_c
	# to get the carbon must multiply these by the tot_area
	# atmos
	fire_agg_names = c(fire_agg_names, paste0("Land2Atmos_c_stock"))
	fire_adjust_df[,fire_agg_names[8]] = -fire_adjust_df$tot_area * (fire_adjust_df$Soil2Atmos_c + fire_adjust_df$Litter2Atmos_c + fire_adjust_df$DownDead2Atmos_c + fire_adjust_df$StandDead2Atmos_c + fire_adjust_df$Understory2Atmos_c + fire_adjust_df$Below2Atmos_c + fire_adjust_df$Above2Atmos_c)

	# now aggregate to land type by summing the fire intensities
	# these c density values are the direct changes to the overall c density
	# the c stock values are the total carbon form each land type going to atmos
	fire_agg_cols = array(dim=c(length(fire_adjust_df$Land_Type_ID),length(fire_agg_names)))
	for (i in 1:length(fire_agg_names)) {
		fire_agg_cols[,i] = fire_adjust_df[,fire_agg_names[i]]
	}
	fire_adjust_agg = aggregate(fire_agg_cols ~ Land_Type_ID + Land_Type + Ownership, data=fire_adjust_df, FUN=sum)
	fire_agg_names2 = paste0(fire_agg_names,"_fire_agg")
	names(fire_adjust_agg)[c(4:ncol(fire_adjust_agg))] = fire_agg_names2
	# merge these values to the unman area table to apply the adjustments to each land type
	all_c_flux = merge(all_c_flux, fire_adjust_agg, by = c("Land_Type_ID", "Land_Type", "Ownership"), all.x = TRUE)
	all_c_flux = all_c_flux[order(all_c_flux$Land_Type_ID),]
	all_c_flux[,c(7:ncol(all_c_flux))] <- apply(all_c_flux[,c(7:ncol(all_c_flux))], 2, function (x) {replace(x, is.na(x), 0.00)})
	all_c_flux[,c(7:ncol(all_c_flux))] <- apply(all_c_flux[,c(7:ncol(all_c_flux))], 2, function (x) {replace(x, is.nan(x), 0.00)})
	all_c_flux[,c(7:ncol(all_c_flux))] <- apply(all_c_flux[,c(7:ncol(all_c_flux))], 2, function (x) {replace(x, x == Inf, 0.00)})

	# loop over the relevant out density tables to update the carbon pools based on the fire fluxes
	# carbon cannot go below zero
	sum_change = 0
	sum_neg_fire = 0
	for (i in 3:num_out_density_sheets) {
		sum_change = sum_change + sum(all_c_flux[, fire_agg_names2[i-2]] * all_c_flux$tot_area)
		out_density_df_list[[i]][, next_density_label] = out_density_df_list[[i]][, next_density_label] + all_c_flux[, fire_agg_names2[i-2]]
		# first calc the carbon not subtracted because it sends density negative
		neginds = which(out_density_df_list[[i]][, next_density_label] < 0)
		cat("neginds for out_density_df_list fire" , i, "are", neginds, "\n")
		sum_neg_fire = sum_neg_fire + sum(all_c_flux$tot_area[out_density_df_list[[i]][,next_density_label] < 0] * out_density_df_list[[i]][out_density_df_list[[i]][,next_density_label] < 0, next_density_label])
		out_density_df_list[[i]][, next_density_label] <- replace(out_density_df_list[[i]][, next_density_label], out_density_df_list[[i]][, next_density_label] <= 0, 0.00)
	} # end loop over out densities for updating due to fire
	cat("fire carbon to atmosphere is ", sum_change, "\n")
	cat("fire negative carbon cleared is ", sum_neg_fire, "\n")

	####
	####
	# apply land conversion to the carbon pools (current year area and updated carbon)
	# as the changes are net, the land type area gains will be distributed proportionally among the land type area losses
	# the "to" land type columns are in land type id order and do not include seagrass because it is just an expansion
	#  do ocean/seagrass separately
	# operate within ownership categories and merge them back together at the end
	cat("Starting conversion c transfers\n")

	# need to adjust historical baseline by the management targets
	# managed adjustments are assumed to be independent of each other so the net adjustments are calculated
	# these initial annual rates are assumed to be included in the baseline annual change numbers:
	#  Afforestation, Growth
	#  so the adjustment is based on a difference between the target annual change and the baseline annual change
	#  the baseline annual change is the year 2010 for these management types
	# urban forest is only tracked internally to determine the carbon accumulation rate,
	#  it is not used here in the context of land type converison
	# Restoration is an annual addition of a land type
	# assume that these entries do not need aggregation with other similar management activities within land type id
	#  in other words, there is only one area-changing management per land type id and each is dealt with uniquely
	
	conv_adjust_df = merge(tot_area_df, conv_area_df, by = c("Land_Type_ID", "Land_Type", "Ownership"))
	conv_adjust_df = conv_adjust_df[order(conv_adjust_df$Land_Type_ID),]
	conv_adjust_df$area_change = conv_adjust_df$base_area_change
	# put the total area in the new area column for now
	# so that it can be adjusted as necessary by ownership below
	conv_adjust_df$new_area = conv_adjust_df$tot_area
	
	man_conv_df = man_adjust_df[man_adjust_df$Management == "Restoration" | man_adjust_df$Management == "Afforestation" | man_adjust_df$Management == "Growth",1:7]
	man_conv_df = merge(man_conv_df, man_target_df[,1:6], by = c("Land_Type_ID", "Land_Type", "Ownership", "Manage_ID", "Management"))
	names(man_conv_df)[names(man_conv_df) == start_area_label] = "initial_man_area"
	
	conv_adjust_df = merge(conv_adjust_df, man_conv_df, by = c("Land_Type_ID", "Land_Type", "Ownership"), all.x=TRUE)
	conv_adjust_df = conv_adjust_df[order(conv_adjust_df$Land_Type_ID),]
	conv_adjust_df[,c(10:ncol(conv_adjust_df))] <- apply(conv_adjust_df[,c(10:ncol(conv_adjust_df))], 2, function (x) {replace(x, is.na(x), 0.00)})
	
	# initialize the managed adjustments to base area change to zero
	conv_adjust_df$base_change_adjust = 0

	# merge the conversion fractions before splitting upon ownership
	conv_adjust_df = merge(conv_adjust_df, conv_df, by = c("Land_Type_ID", "Land_Type", "Ownership"))
	conv_adjust_df = conv_adjust_df[order(conv_adjust_df$Land_Type_ID),]
	conv_col_names = unique(conv_adjust_df$Land_Type[conv_adjust_df$Land_Type != "Seagrass"])
	num_conv_col_names = length(conv_col_names)
	own_names = unique(conv_adjust_df$Ownership)
	
	own_conv_df_list <- list()
	for (i in 1:length(own_names)) {
		conv_own = conv_adjust_df[conv_adjust_df$Ownership == own_names[i],]
		
		# first need to adjust the baseline change rates and calculate the new area
		
		# the seagrass adjustment is separate
		if (own_names[i] == "Ocean") {
			conv_own$base_change_adjust[conv_own$Land_Type == "Seagrass" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)] = conv_own$man_area[conv_own$Land_Type == "Seagrass" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)]
		} else {
			
		# calc growth adjustment before specific activities
		# change will be distributed to other land types proportionally within land type id, except for fresh marsh
		# note that developed land doesn't quite play out as prescribed, does this have to do with fresh marsh?
		temp_adjust = conv_own$man_area[conv_own$Management == "Growth" & !is.na(conv_own$Management)] - conv_own$initial_man_area[conv_own$Management == "Growth" & !is.na(conv_own$Management)]
		conv_own$base_change_adjust[conv_own$Management == "Growth" & !is.na(conv_own$Management)] = temp_adjust
		conv_own$base_change_adjust[conv_own$Land_Type != "Developed_all" & conv_own$Land_Type != "Fresh_marsh"] = conv_own$base_change_adjust[conv_own$Land_Type != "Developed_all" & conv_own$Land_Type != "Fresh_marsh"] - sum(temp_adjust) * conv_own$tot_area[conv_own$Land_Type != "Developed_all" & conv_own$Land_Type != "Fresh_marsh"] / sum(conv_own$tot_area[conv_own$Land_Type != "Developed_all" & conv_own$Land_Type != "Fresh_marsh"])
	
		# Afforestation activities will come proportionally out of shrub and grass only
		temp_adjust = conv_own$man_area[conv_own$Management == "Afforestation" & !is.na(conv_own$Management)] - conv_own$initial_man_area[conv_own$Management == "Afforestation" & !is.na(conv_own$Management)]
		conv_own$base_change_adjust[conv_own$Management == "Afforestation" & !is.na(conv_own$Management)] = conv_own$base_change_adjust[conv_own$Management == "Afforestation" & !is.na(conv_own$Management)] + temp_adjust
		conv_own$base_change_adjust[conv_own$Land_Type == "Shrubland" | conv_own$Land_Type == "Grassland"] = conv_own$base_change_adjust[conv_own$Land_Type == "Shrubland" | conv_own$Land_Type == "Grassland"] - sum(temp_adjust) * conv_own$tot_area[conv_own$Land_Type == "Shrubland" | conv_own$Land_Type == "Grassland"] / sum(conv_own$tot_area[conv_own$Land_Type == "Shrubland" | conv_own$Land_Type == "Grassland"])
	
		# coastal marsh restoration will come out of ag land only
		temp_adjust = conv_own$man_area[conv_own$Land_Type == "Coastal_marsh" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)]
		conv_own$base_change_adjust[conv_own$Land_Type == "Coastal_marsh" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)] = conv_own$base_change_adjust[conv_own$Land_Type == "Coastal_marsh" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)] + temp_adjust
		conv_own$base_change_adjust[conv_own$Land_Type == "Agriculture"] = conv_own$base_change_adjust[conv_own$Land_Type == "Agriculture"] - sum(temp_adjust) * conv_own$tot_area[conv_own$Land_Type == "Agriculture"] / sum(conv_own$tot_area[conv_own$Land_Type == "Agriculture"])
		
		# fresh marsh restoration will come out of ag land only
		temp_adjust = conv_own$man_area[conv_own$Land_Type == "Fresh_marsh" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)]
		conv_own$base_change_adjust[conv_own$Land_Type == "Fresh_marsh" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)] = conv_own$base_change_adjust[conv_own$Land_Type == "Fresh_marsh" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)] + temp_adjust
		conv_own$base_change_adjust[conv_own$Land_Type == "Agriculture"] = conv_own$base_change_adjust[conv_own$Land_Type == "Agriculture"] - sum(temp_adjust) * conv_own$tot_area[conv_own$Land_Type == "Agriculture"] / sum(conv_own$tot_area[conv_own$Land_Type == "Agriculture"])
	
		# meadow restoration will come proportionally out of shrub, grass, savanna, woodland only
		temp_adjust = conv_own$man_area[conv_own$Land_Type == "Meadow" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)]
		conv_own$base_change_adjust[conv_own$Land_Type == "Meadow" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)] = conv_own$base_change_adjust[conv_own$Land_Type == "Meadow" & conv_own$Management == "Restoration" & !is.na(conv_own$Management)] + temp_adjust
		conv_own$base_change_adjust[conv_own$Land_Type == "Shrubland" | conv_own$Land_Type == "Grassland" | conv_own$Land_Type == "Savanna" | conv_own$Land_Type == "Woodland"] = conv_own$base_change_adjust[conv_own$Land_Type == "Shrubland" | conv_own$Land_Type == "Grassland" | conv_own$Land_Type == "Savanna" | conv_own$Land_Type == "Woodland"] - sum(temp_adjust) * conv_own$tot_area[conv_own$Land_Type == "Shrubland" | conv_own$Land_Type == "Grassland" | conv_own$Land_Type == "Savanna" | conv_own$Land_Type == "Woodland"] / sum(conv_own$tot_area[conv_own$Land_Type == "Shrubland" | conv_own$Land_Type == "Grassland" | conv_own$Land_Type == "Savanna" | conv_own$Land_Type == "Woodland"])
		} # end else calc land adjusments to baseline area change
		
		# clean up division numerical errors
		conv_own$base_change_adjust[is.nan(conv_own$base_change_adjust)] = 0
		conv_own$base_change_adjust[conv_own$base_change_adjust == Inf] = 0
		
		# calc the area change and the new area
		conv_own$area_change = conv_own$base_area_change + conv_own$base_change_adjust
		conv_own$new_area = conv_own$tot_area + conv_own$area_change
		
		# first adjust the new area and area change to account for the protection of restored fresh marsh and restored meadow and restored coastal marsh
		# this alos accounts for new area going negative
		conv_own$area_change[conv_own$new_area < conv_own$man_area_sum & (conv_own$Land_Type == "Fresh_marsh" | conv_own$Land_Type == "Meadow" | conv_own$Land_Type == "Coastal_marsh")] = conv_own$area_change[conv_own$new_area < conv_own$man_area_sum & (conv_own$Land_Type == "Fresh_marsh" | conv_own$Land_Type == "Meadow" | conv_own$Land_Type == "Coastal_marsh")] + (conv_own$man_area_sum[conv_own$new_area < conv_own$man_area_sum & (conv_own$Land_Type == "Fresh_marsh" | conv_own$Land_Type == "Meadow" | conv_own$Land_Type == "Coastal_marsh")] - conv_own$new_area[conv_own$new_area < conv_own$man_area_sum & (conv_own$Land_Type == "Fresh_marsh" | conv_own$Land_Type == "Meadow" | conv_own$Land_Type == "Coastal_marsh")])
		sum_restored_neg = -sum(conv_own$man_area_sum[conv_own$new_area < conv_own$man_area_sum & (conv_own$Land_Type == "Fresh_marsh" | conv_own$Land_Type == "Meadow" | conv_own$Land_Type == "Coastal_marsh")] - conv_own$new_area[conv_own$new_area < conv_own$man_area_sum & (conv_own$Land_Type == "Fresh_marsh" | conv_own$Land_Type == "Meadow" | conv_own$Land_Type == "Coastal_marsh")])
		conv_own$new_area[conv_own$new_area < conv_own$man_area_sum & (conv_own$Land_Type == "Fresh_marsh" | conv_own$Land_Type == "Meadow" | conv_own$Land_Type == "Coastal_marsh")] = conv_own$man_area_sum[conv_own$new_area < conv_own$man_area_sum & (conv_own$Land_Type == "Fresh_marsh" | conv_own$Land_Type == "Meadow" | conv_own$Land_Type == "Coastal_marsh")]
	
		# if new area is negative, add the magnitude of the negative area to the area_change and subtract the difference proportionally from the positive area changes (except for fresh marsh and meadow and coastal marsh), then calc new area again
		# restored fresh marsh and meadow and coastal marsh are protected, so make sure that these restored areas are not negated by this adjustment
		conv_own$area_change[conv_own$new_area < 0] = conv_own$area_change[conv_own$new_area < 0] - conv_own$new_area[conv_own$new_area < 0]
		sum_neg_new = sum(conv_own$new_area[conv_own$new_area < 0]) + sum_restored_neg
		sum_pos_change = sum(conv_own$area_change[conv_own$area_change > 0 & conv_own$Land_Type != "Fresh_marsh" & conv_own$Land_Type != "Meadow" & conv_own$Land_Type != "Coastal_marsh"])
		conv_own$area_change[conv_own$area_change > 0 & conv_own$Land_Type != "Fresh_marsh" & conv_own$Land_Type != "Meadow" & conv_own$Land_Type != "Coastal_marsh"] = conv_own$area_change[conv_own$area_change > 0 & conv_own$Land_Type != "Fresh_marsh" & conv_own$Land_Type != "Meadow" & conv_own$Land_Type != "Coastal_marsh"] + sum_neg_new * conv_own$area_change[conv_own$area_change > 0 & conv_own$Land_Type != "Fresh_marsh" & conv_own$Land_Type != "Meadow" & conv_own$Land_Type != "Coastal_marsh"] / sum_pos_change
		conv_own$new_area = conv_own$tot_area + conv_own$area_change
		
		# calculate the conversion area matrices by ownership
		# these store the area change from the Land_Type column to the individual land type columns, by ownership
		# a from-to value is positive, a to-from value is negative
		# carbon needs to be subracted for the area losses because the density change values are tracked as normalized carbon
		
		# do only land here because ocean/seagrass is different
		if(own_names[i] != "Ocean") {
			conv_own$own_gain_sum = sum(conv_own$area_change[conv_own$area_change > 0])
			conv_own2 = conv_own
			# loop over the land types to get the positive from-to area values
			for (l in 1:length(conv_own$Land_Type)) {
				conv_own[,conv_own$Land_Type[l]] = 0.0
				conv_own[,conv_own$Land_Type[l]][conv_own$area_change < 0] = - conv_own$area_change[conv_own$area_change < 0] * conv_own$area_change[l] / conv_own$own_gain_sum[l]
			} # end for l loop over land type
			conv_own[,conv_own$Land_Type] <- apply(conv_own[,conv_own$Land_Type], 2, function (x) {replace(x, x < 0, 0.00)})
			conv_own[,conv_own$Land_Type] <- apply(conv_own[,conv_own$Land_Type], 2, function (x) {replace(x, is.nan(x), 0.00)})
			conv_own[,conv_own$Land_Type] <- apply(conv_own[,conv_own$Land_Type], 2, function (x) {replace(x, x == Inf, 0.00)})

			# do it again to get the negative to-from values
			for (l in 1:length(conv_own$Land_Type)) {
				conv_own2[,conv_own2$Land_Type[l]] = 0.0
				conv_own2[,conv_own2$Land_Type[l]][conv_own2$area_change > 0] = - conv_own2$area_change[conv_own2$area_change > 0] * conv_own2$area_change[l] / conv_own2$own_gain_sum[l]
			} # end for l loop over land type
			conv_own2[,conv_own2$Land_Type] <- apply(conv_own2[,conv_own2$Land_Type], 2, function (x) {replace(x, x < 0, 0.00)})
			conv_own2[,conv_own2$Land_Type] <- apply(conv_own2[,conv_own2$Land_Type], 2, function (x) {replace(x, is.nan(x), 0.00)})
			conv_own2[,conv_own2$Land_Type] <- apply(conv_own2[,conv_own2$Land_Type], 2, function (x) {replace(x, x == Inf, 0.00)})

			# put the negative to-from values into conv_own
			# first find which columns are empty
			zinds = which(apply(conv_own[,conv_col_names],2,sum) == 0)
			conv_own[,conv_col_names][,zinds] = -conv_own2[,conv_col_names][,zinds]

			# calc from land type losses due to conversion to ag and developed
			# if there is an ag or urban loss, then there is no conversion flux
			# assume that these losses are immediate
			# a comprehensive study shows that most soil c loss in conversion to ag happens within the first 3-5 years
			# ag and developed only have above main c, so only need to adjust this as new area with zero carbon
			# loop over the ag/dev conversion frac columns to calculate the transfer carbon density for each frac column
			# this applies to the ag and developed columns only, and add these two areas to get one adjustment
			# the carbon density change is based on land type id tot_area so that it can be aggregated and subtracted directly from the current density values
			# probably should deal with the remaining c transfer here, rather than below, so that all transfers are included
			for (f in 1:num_convfrac_cols){
				# the removed values are calculated first, so this will work
				# if conv_density_inds[f] == -1, then the source is the removed pool; use the sum of the first two c trans columns
				if (conv_density_inds[f] == -1) {
					conv_own[,convc_trans_names[f]] = (conv_own[,convc_trans_names[1]] + conv_own[,convc_trans_names[2]]) * conv_own[,conv_frac_names[f]]
				} else {
					if (!out_density_sheets[conv_density_inds[f]] %in% names(conv_own)) {
						conv_own = merge(conv_own, out_density_df_list[[conv_density_inds[f]]][,c("Land_Type_ID", "Land_Type", "Ownership", next_density_label)], by = c("Land_Type_ID", "Land_Type", "Ownership"), all.x = TRUE)
						names(conv_own)[names(conv_own) == next_density_label] = out_density_sheets[conv_density_inds[f]]
					}
					conv_own[conv_own$Agriculture > 0,convc_trans_names[f]] = conv_own[conv_own$Agriculture > 0,out_density_sheets[conv_density_inds[f]]] * conv_own[conv_own$Agriculture > 0,conv_frac_names[f]] * conv_own$Agriculture[conv_own$Agriculture > 0] / conv_own$tot_area[conv_own$Agriculture > 0]
					
					conv_own[conv_own$Developed_all > 0,convc_trans_names[f]] = conv_own[conv_own$Developed_all > 0,convc_trans_names[f]] + conv_own[conv_own$Developed_all > 0,out_density_sheets[conv_density_inds[f]]] * conv_own[conv_own$Developed_all > 0,conv_frac_names[f]] * conv_own$Developed_all[conv_own$Developed_all > 0] / conv_own$tot_area[conv_own$Developed_all > 0]
				} # end if removed source else density source
			} # end for f loop over the managed transfer fractions for calcuting the transfer carbon
			conv_own[,10:ncol(conv_own)] <- apply(conv_own[,10:ncol(conv_own)], 2, function (x) {replace(x, is.nan(x), 0.00)})
			conv_own[,10:ncol(conv_own)] <- apply(conv_own[,10:ncol(conv_own)], 2, function (x) {replace(x, is.na(x), 0.00)})
			conv_own[,10:ncol(conv_own)] <- apply(conv_own[,10:ncol(conv_own)], 2, function (x) {replace(x, x == Inf, 0.00)})
			conv_own = conv_own[order(conv_own$Land_Type_ID),]
			# need a copy for below
			conv_own_static = conv_own

			# calculate the density changes due to contraction and expansion of land types
			# these are actually normlized carbon values, so the change in density values need to be calculated for area gains and losses
			#  the density changes are based on change area, from carbon, and the land type id total area
			# the from-to areas are positive, the to-from areas are negative
			#
			# from-to (positive columns)
			# ag and developed only have above main c (zero new carbon added) and soil c (frac of from carbon added) densities
			#  the others are zero, so they are taken care of automatically for contraction
			#  they need a special case for above and below addition
			#   and the from conversion loss from total clearing has been calculated above
			# assume that loss happens faster than gain
			# above ground carbon expansion:
			#  if new land type has less carbon, send the difference to the atmosphere, and calc the to carbon change based on area change and to land type carbon
			#  if new land type has more carbon, just calc the to carbon change, based on area change and from land type carbon
			# below ground and soil carbon expansion:
			#  regardless of difference, calc the to density change based on area change and from land type carbon
			#  assume that these transitions do not alter underground c immediately, and that the new c dynamics will eventually dominate
			#
			# to-from (negative columns)
			# this is the carbon transferred from one land type to another
			# for to ag and urban some of the carbon has been removed already
			#  in fact, all above ground pools and a fraction of the underground pools as well
			# just need to remove some carbon from the remaining from land type area
			# from ag and developed only have above main c and soil c densities for now
			#   the others are zero, so they are taken care of automatically
			# assume that loss happens faster than gain
			# for all cases:
			#  calc density change based on change area and from land type carbon, normalized to from total area
			#  but make sure not to remove carbon already removed when the from-to c den diff is positive!
			#
			# loop over the specific land type columns to generate land type specific conversion effect dfs
			# the final change values in these dfs will be aggregated put in columns in conv_own
			# these density changes are with respect to the current land type id total area for consistency with the other changes
			# at the end of the current year multiply the final densities by tot_area/new_area
			conv_df_list <- list()
			for (l in 1:num_conv_col_names) {
				lt_conv = conv_own_static
				# loop over the c pools
				for (c in 3:num_out_density_sheets) {
					cind = which(names(lt_conv) == out_density_sheets[c])
					chname = paste0(out_density_sheets[c],"_change")
					lt_conv[, chname] = 0
					diffname = paste0(out_density_sheets[c],"_diff")
					# this is the land type column minus the l column difference
					lt_conv[,diffname] = lt_conv[,cind] - lt_conv[l,cind]
					# do from-to first; don't need to do anything for a zero column
					if(sum(lt_conv[,conv_col_names[l]]) > 0) {
						# only operate where the "to" area is > 0
						if (c != 4 & c != 9) { # above
							if(conv_col_names[l] == "Agriculture" | conv_col_names[l] == "Developed_all") {
								# density change = change in "from-to" area * zero carbon / "to" total area
								lt_conv[lt_conv[,conv_col_names[l]] > 0, chname] = 0
							} else {
								# the diff matters, but the c to atmos is tallied below in the to-from section
								# positive diff here means that some c is lost to atmosphere
								# calc density for diff positive
								# density change = change in "from-to" area * "to" carbon / "to" total area
								lt_conv[(lt_conv[,diffname] > 0 & lt_conv[,conv_col_names[l]] > 0), chname] = lt_conv[(lt_conv[,diffname] > 0 & lt_conv[,conv_col_names[l]] > 0), conv_col_names[l]] * lt_conv[l, cind] / lt_conv$tot_area[l]
								# calc density for diff negative
								# density change = change in "from-to" area * "from" carbon / "to" total area
								lt_conv[(lt_conv[,diffname] < 0 & lt_conv[,conv_col_names[l]] > 0), chname] = lt_conv[(lt_conv[,diffname] < 0 & lt_conv[,conv_col_names[l]] > 0), conv_col_names[l]] * lt_conv[(lt_conv[,diffname] < 0 & lt_conv[,conv_col_names[l]] > 0), cind] / lt_conv$tot_area[l]
							} # end not to ag or developed
						} else {		# underground
							if(conv_col_names[l] == "Agriculture" | conv_col_names[l] == "Developed_all") {
								if (c==4) {
									# this should be zero, and the frac should send it all to the atmos above
									# but add it just in case the frac is changed
									# density change = change in "from-to" area * "from" carbon * rembelowcfrac / "to" total area
									lt_conv[lt_conv[,conv_col_names[l]] > 0, chname] = lt_conv[lt_conv[,conv_col_names[l]] > 0, conv_col_names[l]] * lt_conv[lt_conv[,conv_col_names[l]] > 0, cind] * (1-lt_conv[lt_conv[,conv_col_names[l]] > 0, "Below2Atmos_conv_frac"]) / lt_conv$tot_area[l]
								} else {
									# a fraction of the from soil c has been removed to atmosphere
									# density change = change in "from-to" area * "from" carbon * remsoilcfrac / "to" total area
									lt_conv[lt_conv[,conv_col_names[l]] > 0, chname] = lt_conv[lt_conv[,conv_col_names[l]] > 0, conv_col_names[l]] * lt_conv[lt_conv[,conv_col_names[l]] > 0, cind] * (1-lt_conv[lt_conv[,conv_col_names[l]] > 0, "Soil2Atmos_conv_frac"]) / lt_conv$tot_area[l]
								} # end else soil c for to ag and dev
							} else {	# end else underground ag and dev
								# density change = change in "from-to" area * "from" carbon / "to" total area
								lt_conv[lt_conv[,conv_col_names[l]] > 0, chname] = lt_conv[lt_conv[,conv_col_names[l]] > 0, conv_col_names[l]] * lt_conv[lt_conv[,conv_col_names[l]] > 0, cind] / lt_conv$tot_area[l]
							}
						} # end else underground
					} else if(sum(lt_conv[,conv_col_names[l]]) < 0) {
						# to-from
						# only operate where the "from" area is < 0
						# to ag and dev already have removed carbon based on clearing above
						#  all above ground has been removed
						#  but some soil carbon still needs to be tallied as transferred
						#  and some below ground is the frac is changed
						#  so only operate on the non-ag, non-dev rows for all except underground
						# carbon has been sent to atmos when the to-from difference is negative
						if (c==4 | c==9) {
							# include ag and dev for the underground
							# it doesn't matter what the c den diff is
							# density change = change in "to-from" area * "from" carbon / "from" total area
							# do the "to" non-ag non-dev
							# this value should be negative
							lt_conv[lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all", chname] = lt_conv[lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all", conv_col_names[l]] * lt_conv[l, cind] / lt_conv$tot_area[l]
							# "to" ag and dev needs the remaining fraction of c for each c pool
							# this value should be negative
							if(c==4) {remfrac = (1-lt_conv[l,"Below2Atmos_conv_frac"])} else
							{remfrac = (1-lt_conv[l,"Soil2Atmos_conv_frac"])}
							lt_conv[lt_conv[,conv_col_names[l]] < 0 & (lt_conv$Land_Type == "Agriculture" | lt_conv$Land_Type == "Developed_all"), chname] = lt_conv[lt_conv[,conv_col_names[l]] < 0 & (lt_conv$Land_Type == "Agriculture" | lt_conv$Land_Type == "Developed_all"), conv_col_names[l]] * remfrac * lt_conv[l, cind] / lt_conv$tot_area[l]	
						} else {	# end if underground for to-from
							# above ground
							# the diff matters here - positive diff values mean all from carbon is transferred
							# density change = change in "to-from" area * "from" carbon / "from" total area
							# this value should be negative
							lt_conv[lt_conv[,diffname] > 0 & lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all", chname] = lt_conv[lt_conv[,diffname] > 0 & lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all", conv_col_names[l]] * lt_conv[l, cind] / lt_conv$tot_area[l]
							# the diff matters here - negative diff values mean some carbon is sent to atmosphere
							# density change = change in "to-from" area * "to" carbon / "from" total area
							# this value should be negative
							lt_conv[lt_conv[,diffname] < 0 & lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all", chname] = lt_conv[lt_conv[,diffname] < 0 & lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all", conv_col_names[l]] * lt_conv[lt_conv[,diffname] < 0 & lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all", cind] / lt_conv$tot_area[l]
							# send above ground lost carbon to the atmosphere if necessary
							# operate only where to-from diff is negative
							# 2atmos = "to" minus "from" diff * "from-to" area / "from" total area
							# this value ends up positive, consistent with the removed transfers above
							atmosname = paste0(out_density_sheets[c],"2Atmos")
							lt_conv[,atmosname] = 0
							lt_conv[(lt_conv[,diffname] < 0 & lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all"), atmosname] = lt_conv[(lt_conv[,diffname] < 0 & lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all"),diffname] * lt_conv[(lt_conv[,diffname] < 0 & lt_conv[,conv_col_names[l]] < 0 & lt_conv$Land_Type != "Agriculture" & lt_conv$Land_Type != "Developed_all"), conv_col_names[l]] / lt_conv$tot_area[l]
							conv_own[conv_own$Land_Type_ID == lt_conv$Land_Type_ID[l],atmosname] = sum(lt_conv[,atmosname])
							# these deal with numerical errors due to roundoff, divide by zero, and any added NA values
							conv_own[,atmosname] = replace(conv_own[,atmosname], is.na(conv_own[,atmosname]), 0.0)
							conv_own[,atmosname] = replace(conv_own[,atmosname], is.nan(conv_own[,atmosname]), 0.0)
							conv_own[,atmosname] = replace(conv_own[,atmosname], conv_own[,atmosname] == Inf, 0.0)
						} # end else above ground for to-from
					} # end else to-from
					conv_own[conv_own$Land_Type_ID == lt_conv$Land_Type_ID[l],chname] = sum(lt_conv[,chname])
					# these deal with numerical errors due to roundoff, divide by zero, and any added NA values
					conv_own[,chname] = replace(conv_own[,chname], is.na(conv_own[,chname]), 0.0)
					conv_own[,chname] = replace(conv_own[,chname], is.nan(conv_own[,chname]), 0.0)
					conv_own[,chname] = replace(conv_own[,chname], conv_own[,chname] == Inf, 0.0)
				} # end for c loop over the c pools
				conv_df_list[[l]] = lt_conv
			} # end for l loop over the "to" conversion column names
			
		} else {
			# ocean/seagrass
			# add the columns and update them accordingly
			# there is only expansion and contraction
			#  on expansion, do not add carbon because the initial state is unknown
			#  so calc carbon density transfers to maintain correct average c density
			#  these are also normalized to current tot_area
			# no losses to atmosphere - it is assumed that it stays in the ocean
			conv_own$own_gain_sum = sum(conv_own$area_change[conv_own$area_change > 0])
			skip = length(names(conv_own))
			add = names(own_conv_df_list[[1]])[(skip+1):ncol(own_conv_df_list[[1]])]
			conv_own[,add] = 0
			conv_own[conv_own$Land_Type == "Seagrass", "Above_main_C_den"] = out_density_df_list[[3]][out_density_df_list[[3]]$Land_Type == "Seagrass",next_density_label]
			conv_own[conv_own$Land_Type == "Seagrass", "Soil_orgC_den"] = out_density_df_list[[9]][out_density_df_list[[9]]$Land_Type == "Seagrass",next_density_label]
			# contraction
			conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change < 0), "Above_main_C_den_change"] = conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change < 0), "area_change"] * conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change < 0), "Above_main_C"] / conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change < 0), "tot_area"]
			conv_own[,"Above_main_C_den_change"] = replace(conv_own[,"Above_main_C_den_change"], is.nan(conv_own[,"Above_main_C_den_change"]), 0.0)
			conv_own[,"Above_main_C_den_change"] = replace(conv_own[,"Above_main_C_den_change"], conv_own[,"Above_main_C_den_change"] == Inf, 0.0)
			conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change < 0), "Soil_orgC_den_change"] = conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change < 0), "area_change"] * conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change < 0), "Soil_orgC_den"] / conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change < 0), "tot_area"]
			conv_own[,"Soil_orgC_den_change"] = replace(conv_own[,"Soil_orgC_den_change"], is.nan(conv_own[,"Soil_orgC_den_change"]), 0.0)
			conv_own[,"Soil_orgC_den_change"] = replace(conv_own[,"Soil_orgC_den_change"], conv_own[,"Soil_orgC_den_change"] == Inf, 0.0)
			# expansion
			conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change > 0), "Above_main_C_den_change"] = 0
			conv_own[(conv_own$Land_Type == "Seagrass" & conv_own$area_change > 0), "Soil_orgC_den_change"] = 0
		} # end if land own else ocean/seagrass
		own_conv_df_list[[i]] = conv_own
	} # end i loop over ownership for calculating land conversion c adjustments
		
	# now rebuild the conv_adjust_df
	conv_adjust_df = rbind(own_conv_df_list[[1]], own_conv_df_list[[2]])
	for (i in 3:length(own_names)) {
		conv_adjust_df = rbind(conv_adjust_df, own_conv_df_list[[i]])
	}
	conv_adjust_df = conv_adjust_df[order(conv_adjust_df$Land_Type_ID),]
	
	# aggregate the transfer densities to the density pools
	# recall that the transfer densities are normalized to tot_area
	#  so after the sums, multiply by tot_area/new_area, because these are the final adjustments
	# convert these to gains where necessary for consistency: all terrestrial gains are positive, losses are negative
	# store the transfers in all_c_flux
	all_c_flux = merge(conv_adjust_df[,c(1:3,7)], all_c_flux, by = c("Land_Type_ID", "Land_Type", "Ownership"))
	all_c_flux = all_c_flux[order(all_c_flux$Land_Type_ID),]

	cgnames = NULL
	# above
	cgnames = c(cgnames, paste0(out_density_sheets[3],"_gain_conv"))
	all_c_flux[,cgnames[1]] = - conv_adjust_df$Above_removed_conv_c - conv_adjust_df$Above_main_C_den2Atmos + conv_adjust_df$Above_main_C_den_change
	# below
	cgnames = c(cgnames, paste0(out_density_sheets[4],"_gain_conv"))
	all_c_flux[,cgnames[2]] = - conv_adjust_df$Below2Atmos_conv_c + conv_adjust_df$Below_main_C_den_change
	# understory
	cgnames = c(cgnames, paste0(out_density_sheets[5],"_gain_conv"))
	all_c_flux[,cgnames[3]] = - conv_adjust_df$Understory2Atmos_conv_c - conv_adjust_df$Understory2DownDead_conv_c - conv_adjust_df$Understory_C_den2Atmos + conv_adjust_df$Understory_C_den_change
	# standing dead
	cgnames = c(cgnames, paste0(out_density_sheets[6],"_gain_conv"))
	all_c_flux[,cgnames[4]] = - conv_adjust_df$StandDead_removed_conv_c - conv_adjust_df$StandDead_C_den2Atmos + conv_adjust_df$StandDead_C_den_change
	# down dead
	cgnames = c(cgnames, paste0(out_density_sheets[7],"_gain_conv"))
	all_c_flux[,cgnames[5]] = - conv_adjust_df$DownDead2Atmos_conv_c + conv_adjust_df$Understory2DownDead_conv_c - conv_adjust_df$DownDead_C_den2Atmos + conv_adjust_df$DownDead_C_den_change
	# litter
	cgnames = c(cgnames, paste0(out_density_sheets[8],"_gain_conv"))
	all_c_flux[,cgnames[6]] = - conv_adjust_df$Litter2Atmos_conv_c - conv_adjust_df$Litter_C_den2Atmos + conv_adjust_df$Litter_C_den_change
	# soil
	cgnames = c(cgnames, paste0(out_density_sheets[9],"_gain_conv"))
	all_c_flux[,cgnames[7]] = - conv_adjust_df$Soil2Atmos_conv_c + conv_adjust_df$Soil_orgC_den_change
	
	
	# loop over the relevant out density tables to update the carbon pools based on the conversion fluxes
	# carbon cannot go below zero
	sum_change = 0
	sum_change2 = 0
	sum_neg_conv = 0
	for (i in 3:num_out_density_sheets) {
		sum_change = sum_change + sum(all_c_flux[,cgnames[i-2]] * all_c_flux$tot_area)
		sum_change2 = sum_change2 + sum(conv_adjust_df[,paste0(out_density_sheets[i],"_change")] * all_c_flux$tot_area)
		out_density_df_list[[i]][, next_density_label] = out_density_df_list[[i]][, next_density_label] + all_c_flux[,cgnames[i-2]]
		# first calc the carbon not subtracted because it sends density negative
		neginds = which(out_density_df_list[[i]][, next_density_label] < 0)
		cat("neginds for out_density_df_list lcc" , i, "are", neginds, "\n")
		sum_neg_conv = sum_neg_conv + sum(all_c_flux$tot_area[out_density_df_list[[i]][,next_density_label] < 0] * out_density_df_list[[i]][out_density_df_list[[i]][,next_density_label] < 0, next_density_label])
		out_density_df_list[[i]][, next_density_label] <- replace(out_density_df_list[[i]][, next_density_label], out_density_df_list[[i]][, next_density_label] <= 0, 0.00)
		# normalize it to the new area and check for zero new area
		out_density_df_list[[i]][, next_density_label] = out_density_df_list[[i]][, next_density_label] * all_c_flux$tot_area / all_c_flux$new_area
		out_density_df_list[[i]][, next_density_label] <- replace(out_density_df_list[[i]][, next_density_label], is.nan(out_density_df_list[[i]][, next_density_label]), 0.00)
		out_density_df_list[[i]][, next_density_label] <- replace(out_density_df_list[[i]][, next_density_label], out_density_df_list[[i]][, next_density_label] == Inf, 0.00)
	} # end loop over out densities for updating due to conversion
	
	# to get the carbon must multiply these by the tot_area
	# atmos
	all_c_flux[,"Land2Atmos_c_stock_conv"] = -conv_adjust_df$tot_area * (conv_adjust_df$Soil2Atmos_conv_c + conv_adjust_df$Litter2Atmos_conv_c + conv_adjust_df$DownDead2Atmos_conv_c + conv_adjust_df$Understory2Atmos_conv_c + conv_adjust_df$Removed2Atmos_conv_c + conv_adjust_df$Below2Atmos_conv_c + conv_adjust_df$Above_main_C_den2Atmos + conv_adjust_df$Understory_C_den2Atmos + conv_adjust_df$StandDead_C_den2Atmos + conv_adjust_df$DownDead_C_den2Atmos + conv_adjust_df$Litter_C_den2Atmos)
	# energy - this is assumed to go to the atmosphere immediately
	all_c_flux[,"Land2Energy_c_stock_conv"] = -conv_adjust_df$tot_area * (conv_adjust_df$Removed2Energy_conv_c)
	# wood - this decays with a half-life
	all_c_flux[,"Land2Wood_c_stock_conv"] = -conv_adjust_df$tot_area * (conv_adjust_df$Removed2Wood_conv_c)

	cat("lcc carbon change is ", sum_change, "\n")
	cat("lcc net carbon transfer to other land types is ", sum_change2, "\n")
	cat("lcc carbon to wood is ", sum(all_c_flux$Land2Wood_c_stock_conv), "\n")
	cat("lcc carbon to atmos is ", sum(all_c_flux$Land2Atmos_c_stock_conv), "\n")
	cat("lcc carbon to energy is ", sum(all_c_flux$Land2Energy_c_stock_conv), "\n")
	cat("lcc negative carbon cleared is ", sum_neg_conv, "\n")

	# update the conversion wood tables
	# recall that the transfers from land are negative values
	# use the IPCC half life equation for first order decay of wood products, and the CA average half life for all products
	#  this includes the current year loss on the current year production
	# running stock and cumulative change values are at the beginning of the labeled year - so the next year value is the stock or sum after current year production and loss
	# annual change values are in the year they occurred
	
	k = log(2) / wp_half_life
	out_wood_df_list[[11]][,next_wood_label] = out_wood_df_list[[11]][,cur_wood_label] * exp(-k) + ((1 - exp(-k)) / k) * (-all_c_flux$Land2Wood_c_stock_conv)
	out_wood_df_list[[12]][,next_wood_label] = out_wood_df_list[[12]][,cur_wood_label] - all_c_flux$Land2Wood_c_stock_conv
	out_wood_df_list[[14]][,cur_wood_label] = -all_c_flux$Land2Wood_c_stock_conv
	out_wood_df_list[[15]][,cur_wood_label] = out_wood_df_list[[11]][,cur_wood_label] - all_c_flux$Land2Wood_c_stock_conv - out_wood_df_list[[11]][,next_wood_label]
	out_wood_df_list[[13]][,next_wood_label] = out_wood_df_list[[13]][,cur_wood_label] + out_wood_df_list[[15]][,cur_wood_label]
	
	# update the total wood tables
	out_wood_df_list[[1]][,next_wood_label] = out_wood_df_list[[6]][,next_wood_label] + out_wood_df_list[[11]][,next_wood_label]
	out_wood_df_list[[2]][,next_wood_label] = out_wood_df_list[[7]][,next_wood_label] + out_wood_df_list[[12]][,next_wood_label]
	out_wood_df_list[[3]][,next_wood_label] = out_wood_df_list[[8]][,next_wood_label] + out_wood_df_list[[13]][,next_wood_label]
	out_wood_df_list[[4]][,cur_wood_label] = out_wood_df_list[[9]][,cur_wood_label] + out_wood_df_list[[14]][,cur_wood_label]
	out_wood_df_list[[5]][,cur_wood_label] = out_wood_df_list[[10]][,cur_wood_label] + out_wood_df_list[[15]][,cur_wood_label]
	
	# set the new tot area
	out_area_df_list[[1]][,next_area_label] = all_c_flux$new_area

	# set this years actual managed area (the area change activities are still just targets)
	out_area_df_list[[2]][,cur_area_label] = man_adjust_df$man_area
	
	# set this years actual fire area - output by the lt breakdown
	if(year == start_year){
		out_area_df_list[[3]] = fire_adjust_df[,c("Land_Type_ID", "Fire_ID", "Land_Type", "Ownership", "Intensity")]
	}
	out_area_df_list[[3]][,cur_area_label] = fire_adjust_df$fire_burn_area
	
	# add up the total org c pool density
	out_density_df_list[[1]][, next_density_label] = 0
	for (i in 3:num_out_density_sheets) {
		out_density_df_list[[1]][, next_density_label] = out_density_df_list[[1]][, next_density_label] + out_density_df_list[[i]][, next_density_label]
	}
	
	# add up the biomass c pool density (all non-decomposed veg material)
	out_density_df_list[[2]][, next_density_label] = 0
	for (i in 3:(num_out_density_sheets-1)) {
		out_density_df_list[[2]][, next_density_label] = out_density_df_list[[2]][, next_density_label] + out_density_df_list[[i]][, next_density_label]
	}

	# fill the carbon stock out tables and the atmos tables
	#out_stock_sheets = c("All_orgC_stock", "All_biomass_C_stock", "Above_main_C_stock", "Below_main_C_stock", "Understory_C_stock", "StandDead_C_stock", "DownDead_C_stock", "Litter_C_stock", "Soil_orgC_stock")
	#out_atmos_sheets = c("Eco_CumGain_C_stock", "Total_Atmos_CumGain_C_stock", "Manage_Atmos_CumGain_C_stock", "Fire_Atmos_CumGain_C_stock", "LCC_Atmos_CumGain_C_stock", "Wood_Atmos_CumGain_C_stock", "Total_Energy2Atmos_C_stock", "Eco_AnnGain_C_stock", "Total_Atmos_AnnGain_C_stock", "Manage_Atmos_AnnGain_C_stock", "Fire_Atmos_AnnGain_C_stock", "LCC_Atmos_AnnGain_C_stock", "Wood_Atmos_AnnGain_C_stock", "Total_AnnEnergy2Atmos_C_stock")
	#out_wood_sheets = c("Total_Wood_C_stock", "Total_Wood_CumGain_C_stock", "Total_Wood_CumLoss_C_stock", "Total_Wood_AnnGain_C_stock", "Total_Wood_AnnLoss_C_stock", "Manage_Wood_C_stock", "Manage_Wood_CumGain_C_stock", "Manage_Wood_CumLoss_C_stock", "Manage_Wood_AnnGain_C_stock", "Manage_Wood_AnnLoss_C_stock", "LCC_Wood_C_stock", "LCC_Wood_CumGain_C_stock", "LCC_Wood_CumLoss_C_stock", "LCC_Wood_AnnGain_C_stock", "LCC_Wood_AnnLoss_C_stock")

	# carbon stock
	for (i in 1:num_out_stock_sheets) {
		out_stock_df_list[[i]][, next_stock_label] = out_density_df_list[[i]][, next_density_label] * out_area_df_list[[1]][,next_area_label]
	}
	
	# cumulative c to atmosphere (and net cumulative c from atmos to ecosystems)
	# also store the annual values
	# gains are positive (both land and atmosphere)
	# so need to subtract the releases to atmosphere becuase they are negative in all_c_flux
	# as these are cumulative, they represent the values at the beginning of the labelled year

	# net atmos to ecosystems; this includes c accumulation adjustments based on management
	# "Above_main_C_den_gain_eco" to "Soil_orgC_den_gain_eco"
	sum_change = 0
	for(i in 1:7){
		sum_change = sum_change + sum(all_c_flux[, egnames[i]] * all_c_flux$tot_area)
	}

	# cumulative values
	out_atmos_df_list[[1]][, next_atmos_label] = out_atmos_df_list[[1]][, cur_atmos_label] + all_c_flux[,"tot_area"] * (all_c_flux[,10] + all_c_flux[,11] + all_c_flux[,12] + all_c_flux[,13] + all_c_flux[,14] + all_c_flux[,15] + all_c_flux[,16])
	# manage to atmos; based on biomass removal, includes energy from biomass
	out_atmos_df_list[[3]][, next_atmos_label] = out_atmos_df_list[[3]][, cur_atmos_label] - all_c_flux[,"Land2Atmos_c_stock_man_agg"] - all_c_flux[,"Land2Energy_c_stock_man_agg"]
	# fire to atmos; based on fire
	out_atmos_df_list[[4]][, next_atmos_label] = out_atmos_df_list[[4]][, cur_atmos_label] - all_c_flux[,"Land2Atmos_c_stock_fire_agg"]
	# lcc to atmos; based on land cover change with associated biomass removal, includes energy from biomass
	out_atmos_df_list[[5]][, next_atmos_label] = out_atmos_df_list[[5]][, cur_atmos_label] - all_c_flux[,"Land2Atmos_c_stock_conv"] - all_c_flux[,"Land2Energy_c_stock_conv"]
	# wood products to atmos; from the wood tables: "Total_Wood_CumLoss_C_stock"
	out_atmos_df_list[[6]][, next_atmos_label] = out_wood_df_list[[3]][,next_wood_label]
	# total energy to atmos; just to compare it with the total cum atmos c
	out_atmos_df_list[[7]][, next_atmos_label] = out_atmos_df_list[[7]][, cur_atmos_label] - all_c_flux[,"Land2Energy_c_stock_man_agg"] - all_c_flux[,"Land2Energy_c_stock_conv"]
	# total to atmos; the total release of land and wood product and energy c to the atmosphere
	# the energy release is inluded in the manage and lcc releases
	out_atmos_df_list[[2]][, next_atmos_label] = out_atmos_df_list[[3]][,next_atmos_label] + out_atmos_df_list[[4]][,next_atmos_label] + out_atmos_df_list[[5]][,next_atmos_label] + out_atmos_df_list[[6]][,next_atmos_label]
	# annual values
	out_atmos_df_list[[8]][, cur_atmos_label] = all_c_flux[,"tot_area"] * (all_c_flux[,10] + all_c_flux[,11] + all_c_flux[,12] + all_c_flux[,13] + all_c_flux[,14] + all_c_flux[,15] + all_c_flux[,16])
	# manage to atmos; based on biomass removal, includes energy from biomass
	out_atmos_df_list[[10]][, cur_atmos_label] = - all_c_flux[,"Land2Atmos_c_stock_man_agg"] - all_c_flux[,"Land2Energy_c_stock_man_agg"]
	# fire to atmos; based on fire
	out_atmos_df_list[[11]][, cur_atmos_label] = - all_c_flux[,"Land2Atmos_c_stock_fire_agg"]
	# lcc to atmos; based on land cover change with associated biomass removal, includes energy from biomass
	out_atmos_df_list[[12]][, cur_atmos_label] = - all_c_flux[,"Land2Atmos_c_stock_conv"] - all_c_flux[,"Land2Energy_c_stock_conv"]
	# wood products to atmos; from the wood tables: "Total_Wood_CumLoss_C_stock"
	out_atmos_df_list[[13]][, cur_atmos_label] = out_wood_df_list[[5]][,cur_wood_label]
	# total energy to atmos; just to compare it with the total cum atmos c
	out_atmos_df_list[[14]][, cur_atmos_label] = - all_c_flux[,"Land2Energy_c_stock_man_agg"] - all_c_flux[,"Land2Energy_c_stock_conv"]
	# total to atmos; the total release of land and wood product and energy c to the atmosphere
	# the energy release is inluded in the manage and lcc releases
	out_atmos_df_list[[9]][, cur_atmos_label] = out_atmos_df_list[[10]][,cur_atmos_label] + out_atmos_df_list[[11]][,cur_atmos_label] + out_atmos_df_list[[12]][,cur_atmos_label] + out_atmos_df_list[[13]][,cur_atmos_label]


} # end loop over calculation years

# Calculate some changes and totals
# also round everything to integer ha, MgC and MgC/ha places for realistic precision
cat("Starting change/total calcs...\n")

# area
out_area_df_list[[1]][, "Change_ha"] = out_area_df_list[[1]][,end_area_label] - out_area_df_list[[1]][,start_area_label]
sum_row = out_area_df_list[[1]][1,]
sum_row[,c(1:3)] = c(-1, "All_land", "All_own")
sum_row[,c(4:ncol(sum_row))] = apply(out_area_df_list[[1]][out_area_df_list[[1]][, "Ownership"] != "Ocean", c(4:ncol(out_area_df_list[[1]]))], 2 , sum)
out_area_df_list[[1]] = rbind(out_area_df_list[[1]], sum_row)
out_area_df_list[[1]][,c(4:ncol(out_area_df_list[[1]]))] = round(out_area_df_list[[1]][,c(4:ncol(out_area_df_list[[1]]))], 0)
for (i in 2:num_out_area_sheets) {
	end_label = ncol(out_area_df_list[[i]])
	out_area_df_list[[i]][, "Change_ha"] = out_area_df_list[[i]][,end_label] - out_area_df_list[[i]][,start_area_label]
	sum_row = out_area_df_list[[i]][1,]
	sum_row[,c(1:5)] = c(-1, -1, "All_land", "All_own", "All")
	sum_row[,c(6:ncol(sum_row))] = apply(out_area_df_list[[i]][out_area_df_list[[i]][, "Ownership"] != "Ocean", c(6:ncol(out_area_df_list[[i]]))], 2 , sum)
	out_area_df_list[[i]] = rbind(out_area_df_list[[i]], sum_row)
	out_area_df_list[[i]][,c(6:ncol(out_area_df_list[[i]]))] = round(out_area_df_list[[i]][,c(6:ncol(out_area_df_list[[i]]))], 0)
}

# density
for (i in 1:num_out_density_sheets) {
	out_density_df_list[[i]][, "Change_Mg_ha"] = out_density_df_list[[i]][,end_density_label] - out_density_df_list[[i]][,start_density_label]
	avg_row = out_density_df_list[[i]][1,]
	avg_row[,c(1:3)] = c(-1, "All_land", "All_own")
	avg_row[,c(4:ncol(avg_row))] = apply(out_density_df_list[[i]][1:45, c(4:ncol(out_density_df_list[[i]]))] * out_area_df_list[[1]][1:45, c(4:ncol(out_area_df_list[[1]]))], 2, sum)
	avg_row[1,c(4:(ncol(avg_row)-1))] = avg_row[1,c(4:(ncol(avg_row)-1))] / out_area_df_list[[1]][out_area_df_list[[1]][, "Land_Type_ID"] == -1, c(4:(ncol(out_area_df_list[[1]])-1))]
	avg_row[1,ncol(avg_row)] = avg_row[1,ncol(avg_row)] / out_area_df_list[[1]][out_area_df_list[[1]][, "Land_Type_ID"] == -1, ncol(out_area_df_list[[1]])-1]
	out_density_df_list[[i]] = rbind(out_density_df_list[[i]], avg_row)
	out_density_df_list[[i]][,c(4:ncol(out_density_df_list[[i]]))] = round(out_density_df_list[[i]][,c(4:ncol(out_density_df_list[[i]]))], 0)
}

# stock
for (i in 1:num_out_stock_sheets) {
	out_stock_df_list[[i]][, "Change_Mg"] = out_stock_df_list[[i]][,end_stock_label] - out_stock_df_list[[i]][,start_stock_label]
	sum_row = out_stock_df_list[[i]][1,]
	sum_row[,c(1:3)] = c(-1, "All_land", "All_own")
	sum_row[,c(4:ncol(sum_row))] = apply(out_stock_df_list[[i]][1:45, c(4:ncol(out_stock_df_list[[i]]))], 2, sum)
	out_stock_df_list[[i]] = rbind(out_stock_df_list[[i]], sum_row)
	out_stock_df_list[[i]][,c(4:ncol(out_stock_df_list[[i]]))] = round(out_stock_df_list[[i]][,c(4:ncol(out_stock_df_list[[i]]))], 0)
}

# wood
for (i in 1:num_out_wood_sheets) {
	end_label = ncol(out_wood_df_list[[i]])
	out_wood_df_list[[i]][, "Change_Mg"] = out_wood_df_list[[i]][,end_label] - out_wood_df_list[[i]][,start_wood_label]
	sum_row = out_wood_df_list[[i]][1,]
	sum_row[,c(1:3)] = c(-1, "All_land", "All_own")
	sum_row[,c(4:ncol(sum_row))] = apply(out_wood_df_list[[i]][out_wood_df_list[[i]][, "Ownership"] != "Ocean", c(4:ncol(out_wood_df_list[[i]]))], 2 , sum)
	out_wood_df_list[[i]] = rbind(out_wood_df_list[[i]], sum_row)
	out_wood_df_list[[i]][,c(4:ncol(out_wood_df_list[[i]]))] = round(out_wood_df_list[[i]][,c(4:ncol(out_wood_df_list[[i]]))], 0)
}

# atmosphere
for (i in 1:num_out_atmos_sheets) {
	end_label = ncol(out_atmos_df_list[[i]])
	out_atmos_df_list[[i]][, "Change_Mg"] = out_atmos_df_list[[i]][,end_label] - out_atmos_df_list[[i]][,start_atmos_label]
	sum_row = out_atmos_df_list[[i]][1,]
	sum_row[,c(1:3)] = c(-1, "All_land", "All_own")
	sum_row[,c(4:ncol(sum_row))] = apply(out_atmos_df_list[[i]][1:45, c(4:ncol(out_atmos_df_list[[i]]))], 2, sum)
	out_atmos_df_list[[i]] = rbind(out_atmos_df_list[[i]], sum_row)
	out_atmos_df_list[[i]][,c(4:ncol(out_atmos_df_list[[i]]))] = round(out_atmos_df_list[[i]][,c(4:ncol(out_atmos_df_list[[i]]))], 0)
}


# write to excel file
if(WRITE_OUT_FILE) {

	cat("Starting writing output at", date(), "\n")

	# put the output tables in a workbook
	out_wrkbk =  loadWorkbook(out_file, create = TRUE)

	# area
	createSheet(out_wrkbk, name = out_area_sheets)
	clearSheet(out_wrkbk, sheet = out_area_sheets)
	writeWorksheet(out_wrkbk, data = out_area_df_list, sheet = out_area_sheets, header = TRUE)

	# c density
	createSheet(out_wrkbk, name = out_density_sheets)
	clearSheet(out_wrkbk, sheet = out_density_sheets)
	writeWorksheet(out_wrkbk, data = out_density_df_list, sheet = out_density_sheets, header = TRUE)

	# c stock
	createSheet(out_wrkbk, name = out_stock_sheets)
	clearSheet(out_wrkbk, sheet = out_stock_sheets)
	writeWorksheet(out_wrkbk, data = out_stock_df_list, sheet = out_stock_sheets, header = TRUE)

	# wood
	createSheet(out_wrkbk, name = out_wood_sheets)
	clearSheet(out_wrkbk, sheet = out_wood_sheets)
	writeWorksheet(out_wrkbk, data = out_wood_df_list, sheet = out_wood_sheets, header = TRUE)

	# atmosphere
	createSheet(out_wrkbk, name = out_atmos_sheets)
	clearSheet(out_wrkbk, sheet = out_atmos_sheets)
	writeWorksheet(out_wrkbk, data = out_atmos_df_list, sheet = out_atmos_sheets, header = TRUE)

	# write the workbook
	saveWorkbook(out_wrkbk)

	cat("Finished writing output at", date(), "\n")
}

cat("Finished CALAND at", date(), "\n")

} # end function CALAND()