*********************************************************************
* Data assignment: Replicating Duflo Indonesia paper (2001)			*
* Date: March 21st 2024 											*	
* Submitted by: Richa Mukerjee										*
*********************************************************************

*Paper: https://www.aeaweb.org/articles?id=10.1257/aer.91.4.795

clear
capture log close
*Set up working directory and file paths

global project "C:\Users\richamuk\Downloads\Data Task_Pre Doc\Data Task"

*Open log
log using "${project}/log", text replace

				********************************************
				* 			PART I: MERGING DATASETS       *
				********************************************

*Load program dataset
use "${project}/esther_data.dta", clear

*Examine birthpl variable
codebook birthpl //290 unique values; 4-digit regency codes
tab birthpl


*Load IPUMS dataset
use "${project}/intercensus.dta", clear

*Rename birthplace variable to match the variable in the program dataset
rename id1995a_bplreg birthpl

*Examine birthpl 
codebook birthpl //there are 303 unique regency values

*Merge in program dataset
merge m:1 birthpl using "${project}/esther_data.dta", gen(_merge)

tab birthpl _merge if (_merge==1 | _merge==2), missing
//14 regencies were only in the IPUMS dataset, and 1 regency was only in the program dataset

codebook birthpl if _merge==3
//289 regencies

				********************************************
				* 			PART II: DATA CLEANING	       *
				********************************************

/*

Variables required for analysis:
1. Age at 1974 and dummy variable "post". Dataset variable: id1995a_birthyr
2. Treatment intensity. Dataset variables:
	2.1. totin - number of inpres schools constructed, bappenas
	2.2. ch73e - estimated number of children, 1973
3. Years of schooling. Dataset variable: yrschool
4. Regency. Dataset variable: birthpl
5. Person weights. Dataset variable: perwt
6. Males only. Dataset variable: id1995a_sex

*/

*Keep males only
codebook id1995a_sex
keep if id1995a_sex==1 //361,854 observations deleted
codebook birthpl //n = 356,984 observations

**************************
*  DERIVING AGE VARIABLE *
**************************
*Examine birth year variable
codebook id1995a_birthyr //coded as 53 (1953), 66 (1966) etc.

*Keep participants born between 1950 and 1972 as was followed in the study
keep if id1995a_birthyr>49 & id1995a_birthyr<73 
//237,748 observations deleted

codebook birthpl //new n = 119,236

*Generate age1974 variable to determine individuals' age in year 1974
codebook id1995a_birthyr
gen age1974 = 74 - id1995a_birthyr
tab id1995a_birthyr
tab age1974, missing

*Keep men in age groups 2-6 years and 12-17 years
keep if (age1974>1 & age1974<7) | (age1974>11 & age1974<18)
//57,976 observations deleted

codebook birthpl //new n = 61,260

*Check age variable to verify that the sample has 2-6 and 12-17 year olds
tab age1974, missing

*****************************
*  DERIVING 'POST' VARIABLE *
*****************************
*Generate a dummy variable "post" that takes the value 1 if age is 2-6 years
gen post = (age1974>1 & age1974<7) if age1974!=.
lab define post 0 "12-17 years" 1 "2-6 years"
lab values post post
tab age1974 post, missing //number of 2-6 year olds = 30,167; number of 12-17 year olds = 31,093

******************************************
*  DERIVING TREATMENT INTENSITY VARIABLE *
******************************************

*Generate a treatment intensity variable, calculated as (number of schools built/number of children)*1000

*For 1973-1978
gen intensity = (totin/ch73e)*1000
codebook intensity
sum intensity, detail //mean schools built per 1000 students = 1.875

*Check years of schooling variable
tab yrschool, missing //4 observations coded as "some secondary"

*Recode some secondary to missing (because n=4 is 0.01% ie a small proportion of the total sample size) to missing
recode yrschool (93=.) 
tab yrschool, missing
sum yrschool, detail //mean = 8.231
bysort post: sum yrschool //mean years of schooling for 2-6 year olds = 9.082; 12-17 year olds = 7.404

				*************************************
				* 		PART III: DATA ANALYSIS		*
				*************************************

*Simple regression of years of schooling on intensity of school construction
reg yrschool intensity [aweight=perwt], vce(cluster birthpl)
// we see a negative association between intensity and years of schooling. this is to be expected because more schools were being built in regions where enrolment was low.

*Adding post as a covariate 
reg yrschool intensity post [aweight=perwt], vce(cluster birthpl)
// we see that younger cohort on average has more years of schooling than the older cohort, controlling for intensity. Controlling for age, one additional school per 1000 children was associated with 14 less years of schooling, controlling for age.

*Adding interaction
reg yrschool post##c.intensity  [aweight=perwt], vce(cluster birthpl)

*Adding interaction term (with analytic weights)
reg yrschool i.birthpl i.age1974 post##c.intensity [aweight=perwt], vce(cluster birthpl)

log close
