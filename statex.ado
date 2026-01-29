*! version 0.1.0 07jan2026


********************************************************************************
***************************** Access point *************************************
********************************************************************************


cap prog drop statex
prog statex
	version 16
	
	
	gettoken subcmd 0 : 0, parse(" ,")
	local subcmd = trim("`subcmd'")
	
	//di `"CALL: statex_`subcmd' `0'"'
	
	statex_`subcmd' `0'
	
	/*
	if `"`subcmd'"'=="est" {
		//
	} 
	else if `"`subcmd'"'=="sum" {
		//
	}
	else {
		di as error `"Unknown subcommand: `subcmd'"'
		di "available subcommands: sum, est"
		exit 198
	}
	*/
	
end

********************************************************************************
************************ Manage Statex Tables **********************************
********************************************************************************

prog statex_new
	syntax, ///
		[name(namelist max=1)] ///
		[coltypes(string)] ///
		[stars(numlist descending min=3 max=3) ci_level(real 95) paren(string) replace] ///
		[width(integer 20)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata
	
	* Parse
	*******
	
	cap assert !strpos("`name'", " ")
	if _rc {
		di as error "Spaces not permitted in name"
		exit 198
	}
	
	cap assert inlist("`paren'", "", "t", "se", "p", "ci", "none")
	if _rc {
		di as error `"Paren must be one of "t", "se", "p", "ci", or "none". Received `paren'."' 
		exit 198
	}
	
	cap assert inrange(`ci_level', 0, 100)
	if _rc {
		di as error `"Option ci_level must be between 0 and 100. Received `ci_level'"'
		exit 198
	}
	
	// Default options: 
	if "`stars'"=="" loc stars = ".05 .01 .001"	
	if "`paren'"=="" loc paren = "se"
	
	* Save Meta Information
	***********************
	if "`name'"=="" mata: statex.get_auto_newname() // Get auto name if name is unspecified. 
	mata: pT = statex.new_table("`name'", "`stars'", "`paren'", `width', `ci_level')
	
end

prog statex_list
	syntax, [name(string)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	mata: pT->li()
end

prog statex_dir
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata

	mata: statex.dir()
end

// FLAG: 
prog statex_change
	syntax, name(string)
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata
	
	mata: statex.set_current("`name'")
	
end

prog statex_drop
	syntax [namelist]
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata
	
	*
	************
	if "`namelist'"!="_all" {
		foreach name of local namelist {
			if "`name'"=="" mata: st_local("name", statex.get_current())
			mata: pT = statex.get_table("`name'")
			mata: statex.drop_table(pT)
		}
	}
	else {
		mata: statex.drop_all()
	}
	
end

prog statex_clear 
	statex_drop _all
end

prog statex_check_ncols
	syntax, name(namelist max=1) n_cols(integer) [coltypes(string asis) error(string)]
	// Placeholder/temp function? Checks that the number of columns is correct, and if ncols not yet set also write the boilerplate opening of the table. 
	// Consider replacing the mata version as this one writes the boilerplate if ncols is previously not set. But make sure this is done before anything is written to the table. 
	// The user can choose to provide ncols and coltypes when doing statex new. If else use default lcccc. 
	
	* Syntax
	********
	
	cap assert `n_cols'>0
	if _rc {
		di as error "Option n_cols must be > 0. Received `n_cols'"
		exit 198
	}
	
	//mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	mata: st_local("statex_ncols", strofreal(pT->ncols))
	if `statex_ncols'==-1 {
		if "`coltypes'"=="" {
			loc coltypes = "l"
			forv n = 1/`=`n_cols'-1' {
				loc coltypes = "`coltypes'c"
			}
		}
		mata: pT->add_line("\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}")
		mata: pT->add_line("\begin{tabular}{`coltypes'} \hline\midrule")
		mata: pT->ncols=`n_cols'
	}
	else {
		cap assert `statex_ncols'==`n_cols'
		if _rc {
			di as error "`error' You are trying to write `n_cols' columns, but previously wrote `statex_ncols' columns."
			exit 198
		}
	}
	
end

prog statex_list_opt
	syntax, [name(namelist max=1)]
	// For dev. purpose (I think)
	
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	foreach attr in name stars paren clustvar {
		mata: st_local("val", pT->`attr')
		di `"Attr `attr': "`val'""'
	}
	
	foreach attr in used_stars used_paren panel_counter ncols cell_width cell_overflow is_closed ci_level  ///
	used_conventional_se used_robust_se used_hac_robust_se used_clustered_se used_bootstrap_se used_jackknife_se used_unknown_se used_svy_se {
		mata: st_local("val", strofreal(pT->`attr'))
		di `"Attr `attr': `val'"'
	}

end
	
********************************************************************************
*********************************** Header / row *******************************
********************************************************************************

prog statex_row
	syntax, ///
		[name(namelist max=1)] ///
		row(string asis) [multicolumn(numlist integer min=1) blank align(string) underline(string asis) bold cmidrule(string asis)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Name
	******
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	* Parse
	*******
	loc blank = "`blank'"!=""
	loc has_multicolumn = `"`multicolumn'"'!=""
	
	
	// If not multicolumn: n in row same as columns in table
	if !`has_multicolumn' {
		loc has_multicolumn = 0
		
		// Count implied columns from syntax
		loc ncols : list sizeof row
		if `blank' loc ncols = `ncols' + 1
		
		// Check that they are the same: 
		//mata: pT->check_ncols(`ncols',  "Wrong number of columns.")
		statex_check_ncols, name("`name'") n_cols(`ncols') error("Wrong number of columns.")
		
		// Check: alignment not specified
		cap assert `"`align'"'=="" //test: statex_new, ncols(3); statex_row, row("a" "b" "c") align(c c c) 
		if _rc {
			di as error "Option 'align' requires option 'multicolumn'"
			exit 198
		}
	}
	
	* Flag: Check cmidrule spec. 
	
	// If multicolumn: n in row same as multicol, and sum(multicol)==n columns
	if `has_multicolumn' {
		// Check: same number of elements in row and multicolumn
		loc n_elems : list sizeof row
		loc n_multicol : list sizeof multicolumn
		cap assert `n_elems' == `n_multicol'
		if _rc {
			di as error "Mismatch between number of elements in row (`n_elems') and in multicolumn (`n_multicol')."
			exit 198
		}
		
		// Check: same number of impled columns as in table
		loc ncols = 0 
		foreach multicol of local multicolumn {
			loc ncols = `ncols' + `multicol'
		}
		if `blank' loc ncols = `ncols' + 1
		
			// Get number of columns of table: 
		//mata: pT->check_ncols(`ncols',  "Wrong number of elements in row.")
		statex_check_ncols, name("`name'") n_cols(`ncols') error("Wrong number of columns.")
		
		
		// Check alignment 
		loc has_align = `"`align'"'!=""
		if `has_align' {
			loc n_multicol : list sizeof multicolumn
			loc n_align    : list sizeof align
			cap assert `n_multicol' == `n_align'
			if _rc {
				di as error "Mismatch between number of multicolumns (`n_multicol') and alignments (`n_align')."
				exit 198
			}
			
			foreach a of local align {			
				cap assert inlist("`a'", "", "l", "c", "r")
				if _rc {
					di as error "Alignment must be 'l', 'c', or 'r'. Received `a'"
					exit 198
				}
			}
		}
	}
	
	if "`bold'"!="" {
		loc bold_start = `"\textbf{"'
		loc bold_end  = `"}"'
	}
	
	
	* Write row
	************
	mata: pT->add_line("")
	if !`has_multicolumn' {
		loc n = 1
		if `blank' {
			mata: pT->append_to_line("",1,"center")
			loc ++n
		}
		
		foreach elem of local row {
			if `n'>1 mata: pT->append_to_line("&", 0, "no")
			if `n'==0 	loc latexalign = "left"
			else 		loc latexalign = "center"
			mata: pT->append_to_line(`"`bold_start'`elem'`bold_end'"',1, "`latexalign'")
			loc ++n
		}
	}
	else {
		loc n = 1
		if `blank' {
			mata: pT->append_to_line("",1,"center")
			loc ++n
		}
		
		
		foreach elem of local row {
			gettoken n_cols multicolumn : multicolumn
			if `has_align' 	gettoken a align : align
			else 			loc a = "c"
			if `n'>1 mata: pT->append_to_line("&", 0, "no")
			if `n'==0 	loc latexalign = "left"
			else 		loc latexalign = "center"
			mata pT->append_to_line(`"\multicolumn{`n_cols'}{`a'}{`bold_start'`elem'`bold_end'}"',1, "`latexalign'")
			loc ++n
		}
	}
	
	mata: pT->append_to_line(`" \\"', 0, "no")
	mata: pT->cell_overflow = 0
	
	
	if `"`cmidrule'"'!="" {
		foreach lr of local cmidrule {
			gettoken l r : lr
			loc l: list clean l
			loc r: list clean r
			cap assert regexm("`l'", "^[-+]?[0-9]+$") & regexm("`r'", "^[-+]?[0-9]+$")
			if _rc {
				di as error `"midrule must consists of lists of numbers, received `l'-`r'"' // Flag: move this code up to the beguinning of the program
			}
			
			mata: pT->append_to_line(`" \cmidrule(lr){`l'-`r'} "',0, "no")
		}
	}
end

prog statex_panel
	syntax, ///
		[name(namelist max=1)] ///
		text(string) ///
		[panel_name(string) nobold]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Write Panel Header
	********************
	
	if "`nobold'"=="" {
		loc bold_start = `"\textbf{"'
		loc bold_end   = `"}"'
	}
	
	// Prepare text for LaTeX
	
	
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	mata: pT->panel()
	mata: st_local("ncols", strofreal(pT->ncols))
	
	mata: pT->add_line(`"\multicolumn{`ncols'}{l}{`bold_start'Panel `panel': `text'`bold_end'} \\"')
end

********************************************************************************
***************************** Estimates or summary stats ***********************
********************************************************************************

* Estimates
***********

prog statex_est
	syntax namelist, [name(namelist max=1)]  ///
	[b(passthru) paren(passthru) stars(passthru)] /// 
	[indicate(passthru) drop(passthru) keep(passthru) order(passthru) STATistics(passthru)] /// Which variables goes where
	[label longmidrule nogap numbers(passthru) nogroup] /// Rendition
	[noheader notable noindic nostats] // Drop specific part of table
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Syntax
	********
	// Table is open
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	if "`longmidrule'"!="" {
		cap assert "`nostats'"==""
		if _rc {
			di as error "Cannot specify both options 'longmidrule' and 'nostats'."
			exit 198
		}
	}
	
	cap assert inlist("`stars'", "", "stars(none)")
	if _rc {
		di as error `"Option "stars" only accepts "none". Received "`stars'". Set star levels when opening a new table. "'
		exit 198
	}
	
	// Default formats [FLAG: se should be multiple options? se, t or p?]
	if `"`b'"' =="" 	loc b     = "b(%19.3fc)"
	if `"`paren'"'=="" 	loc paren = "paren(%19.3fc)"
	
	if "`paren'"!="paren(none)" 	mata: pT->used_paren = 1
	if "`stars'"!="none"			mata: pT->used_stars = 1
	
	// Check that namelist contains res that exists
	foreach estname of local namelist {
		cap estimates dir `estname'
		if _rc {
			di as error `"Stored estimate `estname' not found"'
		}
	}
	
	// Check that namelist has the appropriate length. 
	loc nres : list sizeof namelist
	loc ncols = `nres' + 1
	//mata: pT->check_ncols(`ncols',  "Wrong number of estimation results.")
	statex_check_ncols, name("`name'") n_cols(`ncols') error("Wrong number of estimation results.")
	
	* Write table
	*************
	
	if "`header'"!="noheader" {
		statex_est_header `namelist', name(`name') `label' `bold' `group'
		statex_numbers, `numbers' blank
		statex_midrule, name(`name')
	}
	
	cap frame drop estframe
	loc estframe = "estframe"
	cap frame drop indframe
	loc indframe = "indframe"
	
	/*
	tempname estframe indframe
	*/
	
	frame create `estframe'
	frame `estframe': qui g strL varlist = ""
	frame `estframe': qui g strL clean_varlist = ""
	frame `estframe': qui g strL clean_label = ""
	
	frame create `indframe'
    frame `indframe': qui gen strL varlist = ""
	frame `indframe': qui gen strL label = ""
	
	
	// Move estimates to frames
	statex_est_prepare `namelist',  `label' name(`name') `drop' `keep' `order' estframe(`estframe') indframe(`indframe') `indicate'
	
	// append to latex table 
	loc n_cols : list sizeof namelist
	if "`table'"!="notable" statex_est_panel, name(`name') n_cols(`n_cols') `b' `paren' `stars' estframe(`estframe') `gap'
	if "`table'"!="notable" & "`indic'"!="noindic" & "`gap'"!="nogap" mata: pT->add_line("[1em]")
	if "`indic'"!="noindic" statex_est_indic, name(`name') n_cols(`n_cols') indframe(`indframe') `gap'
	
	
	if "`stats'"!="nostats" {
		if "`longmidrule'"!="" statex_midrule, name(`name')
		mata: st_local("ncols", strofreal(pT->ncols))
		else mata: pT->append_to_line(`" \cmidrule(lr){2-`ncols'}"', 0, "no")
		mata: pT->add_line("")
		statex_est_stats `namelist', name(`name') `statistics'
	}
end

prog statex_est_prepare 
	syntax namelist, [name(namelist max=1) label drop(string) keep(string) order(string)] estframe(namelist max=1) indframe(namelist max=1) [indicate(passthru)] // Pick out name and move to parent function
	// Take ests stored in namelist, store in (new) frame __table_res, label (if option `label'), keep, order etc.
	
	loc label = "`label'"!=""
	
	* Syntax
	********
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	mata: st_local("ncols_statex", strofreal(pT->ncols))
	
	// Check that namelist has the appropriate length. 
	loc nres : list sizeof namelist
	loc ncols = `nres' + 1
	//mata: pT->check_ncols(`ncols',  "Wrong number of estimation results.")
	statex_check_ncols, name("`name'") n_cols(`ncols') error("Wrong number of estimation results.")
	
	// Check that all provided ests exists
	qui estimates dir
	loc stored_ests = "`r(names)'"

	foreach est of local namelist {
		loc exists = 0
		foreach stored_est of local stored_ests {
			if "`est'"=="`stored_est'" loc exists = 1 // FLAG: Can plase di as error -> exit here? 
		}
		cap assert `exists'
		if _rc {
			di as error "Estimation result `est' does not exist"
			exit 198
		}
	}

	mata: st_local("ci_level", strofreal(pT->ci_level))
	statex_est_extract `namelist', name(`name') ci_level(`ci_level') estframe(`estframe') indframe(`indframe') `indicate' // Adds estimated params to frame
	
	if `"`drop'"'!="" {
		foreach token of local drop {
			frame `estframe': qui drop if strmatch(varlist, `"`token'"')
			// Flag: Check if anything is dropped by first creating a dropped variable, counting, asserting, and then continue. 
		}
	}
	if `"`keep'"'!="" {
		frame `estframe': qui g keep = 0
		loc keep = "ujive_*"
		foreach token of local keep {
			frame `: qui replace keep = 1 if strmatch(varlist, `"`token'"')
		}
		frame `estframe': qui keep if keep
		frame `estframe': drop keep
	}
	
	// Order (put _cons last unless the user specifies something else)
	
	frame `estframe' {
		qui g init_order = _n
		qui g cons_order = varlist == "_cons"
		
		if `"`order'"'!="" {
			qui g order = .
			loc n = 1
			foreach token of local order {
				qui replace order = `n' if strmatch(varlist, `"`token'"')
				loc n = `n' + 1
			}
			loc order = "order"
		}
		sort `order' cons_order init_order
		drop `order' init_order
	}
	
	
	if `label' {
		frame `estframe': qui replace clean_varlist = clean_label
	}
	
end

prog statex_est_extract // Take est and place in (i.e. add to) frame
	syntax namelist, ci_level(numlist max=1)  [name(namelist max=1) indicate(string asis)] estframe(string asis) indframe(string asis) //, est(string) suffix(string)
	
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	// Consider changing this to a mata matrix for Stata users with limited number of columns. 
	// parse indicate option
	local cpos = strpos(`"`indicate'"', ",")
	if `cpos'==0 local indicate_var_lab `"`indicate'"'
	else {
		local indicate_var_lab = strtrim(substr(`"`indicate'"', 1, `cpos' - 1))
		local indicate_options = strtrim(substr(`"`indicate'"', `cpos' + 1, .))	
	}
	loc 0 , `indicate_options'
	syntax , [label(string asis)]
	
	loc n_labels     = wordcount(`"`label'"')
	
	cap assert `n_labels'<=2 
	if _rc {
		di as error "Cannot provide more than two indicator labels (only used to display 'yes' and 'no')."
		exit 198
	}
	gettoken yes no : label
	loc no = substr(`"`no'"',2,.)
	if `n_labels'==0 loc yes = "\checkmark"
	
	
	foreach var_lab of local indicate_var_lab {
		//gettoken lab var : var_lab, parse("=")
		//loc var = substr(`"`var'"', 2, .)
		loc epos = strpos(`"`var_lab'"', "=")
		if `epos'==0 {
			loc lab	= `"`var_lab'"'
			loc var = `"`var_lab'"'
		}
		else {
			loc lab = strtrim(substr(`"`var_lab'"', 1, `epos' - 1))
			loc var = strtrim(substr(`"`var_lab'"', `epos' + 1,.))
		}
		frame `indframe' {
			qui set obs `=_N+1'
			qui replace varlist = "`var'" if _n==_N
			qui replace label = "`lab'" if _n==_N
		}
	}
	
	* Detect SE usage
	foreach est of local namelist {
		qui estimates restore `est'
		foreach loc in vce vcetype clustvar prefix {
			loc `loc' = ""
		}
		cap loc vce = lower(e(vce))
		cap loc	vcetype = lower(e(vcetype))
		cap local clustvar =  e(clustvar)
		cap local prefix = lower(e(prefix))
		
		
		if `"`prefix'"'=="svy" mata: pT->used_svy_se = 1
		else if `"`prefix'"'=="bootstrap" mata: pT->used_bootstrap_se = 1
		else if `"`prefix'"'=="jackknife" mata: pT->used_jackknife_se = 1
		else if inlist(`"`vce'"', "", "ols", "unadjusted", "oim", "conventional", "opg", "eim") 	mata: pT->used_conventional_se = 1
		else if `"`vcetype'"'=="hac" 														mata: pT->used_hac_robust_se = 1
		else if inlist(`"`vce'"', "cluster", "robust cluster", "robust two-way cluster") | (`"`clustvar'"'!="") {
			mata: pT->used_clustered_se = 1
			mata: st_local("current_clustvar", pT->clustvar)
			if `"`current_clustvar'"'!="" & `"`current_clustvar'"'!=`"`clustvar'"' mata: pT->clustvar = "_inconsistent_"
			else if `"`clustvar'"'!="" mata: pT->clustvar  = `"`clustvar'"'
		}
		else if inlist(`"`vce'"', "hc0", "hc1", "hc2", "hc3", "robust") 					mata: pT->used_robust_se = 1
		else if inlist(`"`vce'"', "bootstrap") mata: pT->used_bootstrap_se = 1
		else if inlist(`"`vce'"', "jackknife", "jackknife1") mata: pT->used_jackknife_se = 1
		else mata: pT->used_unknown_se = 1
	}
	
	
	* Extract and store parameters and indicators (absorbed or manually specified groups of variables)
	loc column = 1
	foreach est of local namelist {
		
		frame `estframe' {
			qui g in`column' = .
			qui g double b`column' = .
			qui g double se`column' = .
			qui g double t`column' = .
			qui g double p`column' = .
			qui g double ci_l`column' = .
			qui g double ci_u`column' = .
		}
		
		frame `indframe': g fe`column' = 0
		
		qui estimates restore `est'
		loc df_r = e(df_r)
		mat b = e(b)
		mat V = e(V)
		if `"`e(absvars)'"'!="_cons" loc absorbed = `"`e(absvars)'"' // reghdfe stores e(absvars)="_cons" when no "absorb()" was provided
		
		* Parameters
		************
		
		loc varnames : colnames b
		
		cap mat drop `to'
		loc n = colsof(b)
		forv i = 1/`n' { // Foreach variable
			loc varname : word `i' of `varnames'
			
			// Check if `varname' is in `indicate'
			local in_indicate = 0
			frame `indframe': qui levelsof varlist, local(indicated)
			foreach pat of local indicated {
				if strmatch("`varname'", `"`pat'"') local in_indicate = 1
			}
			
			if `in_indicate'==0 { // Include parameter
				// Make clean version of variable and label	
				loc dropped = 0				
				loc rest = "`varname'"
				loc var = ""
				loc clean_varlist = ""
				loc clean_label = ""
				while `"`rest'"'!="" {
					gettoken tok rest : rest, parse("#")
					if "`tok'"=="#" {
						loc var           = "`var'#"
						loc clean_varlist = "`clean_varlist' # "
						loc clean_label   = "`clean_label' # "
					}
					else {
						if substr("`tok'", 1, 2)=="o." | substr("`tok'", 1, 3)=="co." loc dropped = 1
						foreach pat in "c." "o." "co." {
							loc pat_n = strlen("`pat'")
							loc tok = cond(substr("`tok'",1,`pat_n')=="`pat'", substr("`tok'", `=`pat_n'+1',.), "`tok'")
							
							loc lab = ""
							cap loc lab : variable label `tok'
							if `"`tok'"'=="_cons" 	loc lab = "Constant"
							if `"`lab'"'=="" 		loc lab = "`tok'"
						}
						loc var = "`var'`tok'"
						loc clean_varlist = "`clean_varlist'`tok'"
						loc clean_label = "`clean_label'`lab'"
					}
				}
				
				
				loc b = b[1,`i']
				loc se = sqrt(V[`i', `i'])
				loc t = `b'/`se'
											
				// Use critical values from t-statistic unless there are many dfs to calculate p-values and CIs (following estout convention)
				loc df_max = 2e17
				loc level_dec = (100-`ci_level')/(2*100)
				if !mi(`df_r') & `df_r'<=`df_max' { // t
					loc p = 2 * ttail(`df_r', abs(`t'))
					loc crit = invttail(`df_r', `level_dec')
				}
				else { // norm
					loc p = 2 * normal(-abs(`t'))
					loc crit = invnormal(`level_dec')
				}
				
				loc ci_l = `b' - `crit'*`se'
				loc ci_u = `b' + `crit'*`se'
			
				frame `estframe' {
						qui count if clean_varlist == "`clean_varlist'"
						if r(N)==0 {
							qui set obs `=_N+1'
							qui replace varlist = "`var'" if _n==_N
							qui replace clean_varlist = "`clean_varlist'" if _n==_N
							qui replace clean_label = "`clean_label'" if _n==_N
						}
						if `dropped' {
							foreach param in b se t p ci_l ci_u {
								loc `param' = .
							}
						}
						qui replace in`column' = 1    if varlist=="`var'"
						qui replace b`column'  = `b'  if varlist=="`var'"
						qui replace se`column' = `se' if varlist=="`var'"
						qui replace t`column'  = `t'  if varlist=="`var'"
						qui replace p`column'  = `p'  if varlist=="`var'"
						qui replace ci_l`column' = `ci_l' if varlist=="`var'"
						qui replace ci_u`column' = `ci_u' if varlist=="`var'"
				}
			}
			else { // Include indicator
				frame `indframe': qui replace fe`column'=1 if strmatch("`varname'", varlist)
			}
		}
		
		* Absorbed FEs
		**************
		foreach abs of local absorbed {
			frame `indframe' {
				qui count if strmatch(`"`abs'"', varlist)
				if r(N)==0 {
					qui set obs `=_N+1'
					qui replace varlist = "`abs'" if _n==_N
					qui replace label = "`abs'" if _n==_N
				}
				qui replace fe`column' = 1 if strmatch(`"`abs'"', varlist)
			}
		}
		loc column = `column'+1
	}
	
	
	
	// Look for indicator variables not found in estimation results
	frame `indframe': egen rowsum = rowtotal(fe*)
	frame `indframe': qui count if rowsum==0
	if r(N)>0 {
		frame `indframe': qui levelsof varlist if rowsum==0, local(notfound)
		loc notfound : list clean notfound
		di as error `"Cannot indicate variables. Not found in estimation results: `notfound'"'
		exit 111
	}
	else { 
		frame `indframe': drop rowsum
	}
	
	// Escape characters (FLAG: not complete)
	foreach escape in "#" "_" {
	foreach v in varlist label {
		frame `estframe': qui replace clean_`v' = subinstr(clean_`v', "`escape'", "\\`escape'", .)
		frame `indframe': qui replace `v' = subinstr(`v', "`escape'", "\\`escape'", .)
	}
	}
	
	frame `indframe': qui g yes =  `"`yes'"'
	frame `indframe': qui g no =  `"`no'"'
	
end

// FLAG: add options (bold, label). Also add group to group yvars (with cmidrule)
prog statex_est_header
	syntax namelist, [name(string) bold label nogroup]
	
	* Syntax
	********
	if "`name'"=="" mata: st_local("name", statex.get_current())
	
	// Check that namelist has the appropriate length. 
	loc nres : list sizeof namelist
	loc ncols = `nres' + 1
	//mata: pT->check_ncols(`ncols',  "Wrong number of estimation results.")
	
	
	* Loop over estimates, and group identical consequtive y-vars 
	**************************************************************
	
	loc n_obj = 1
	loc first = 1
	loc start = 2
	loc i = 2
	foreach est of local namelist {
		qui estimates restore `est'
		loc y `e(depvar)'
		
		// Combine adjecent, identical yvars - infer `multicolumn', "row" etc.
		if `"`y'"'==`"`prev'"' & "`group'"!="nogroup" {
			loc ++n_obj
		}
		else {
			if (`"`prev'"'!="" | "`group'"=="nogroup") & !`first' {
				if `first' 	loc target = `"`y'"'
				else 		loc target = `"`prev'"'
				cap if "`label'"!="" 	loc ylab : variable label `target'
				if "`ylab'"==""			loc ylab = `"`target'"'
				
				loc yrow = `"`yrow' "`ylab'""'
				loc align = "`align' c"
				loc multicolumn = "`multicolumn' `n_obj'"
				loc midrule = `"`midrule' "`start' `=`i'-1'""'
				loc start = "`i'"
			}
			loc prev = `"`y'"'
			loc n_obj=1
		}
		loc first = 0
		loc ++i
	}
	
	cap if "`label'"!="" 	loc ylab : variable label `prev'
	if "`ylab'"==""			loc ylab = `"`prev'"'
	loc yrow = `"`yrow' "`ylab'""'
	loc align = "`align' c"
	loc multicolumn = "`multicolumn' `n_obj'"
	loc midrule = `"`midrule' "`start' `=`i'-1'""'
			
	foreach loc in yrow align multicolumn {
		loc `loc' = substr(`"``loc''"', 2, .)
	}
	
	* Write 
	********
	if "`group'"=="nogroup" loc midrule = ""
	statex_row, name(`name') row(`yrow') `bold' align(`align')  multicolumn(`multicolumn') cmidrule(`midrule') blank
	
end

prog statex_est_panel
	syntax, name(string) [stars(string) nogap] n_cols(integer) b(string) paren(string) estframe(string asis) //indframe(string asis)
	// Reads params from frame and writes to table. 
	
	mata: pT = statex.get_table("`name'")
	frame `estframe': loc n_vars = _N
	mata: pT->add_line(`""')
	
	// Write point estimates
	forv row_i = 1/`n_vars' {
		frame `estframe': loc var = clean_varlist[`row_i']
		mata: pT->append_to_line(`"`var'"', 1, "left")
		
		// beta/stars
		mata: st_local("starlist", pT->stars)
		gettoken 1star starlist : starlist
		gettoken 2star 3star : starlist
		
		forv col_i = 1/`n_cols' {	
			frame `estframe': loc __b = b`col_i'[`row_i']
			frame `estframe': loc __in = in`col_i'[`row_i']
			loc __b = strofreal(`__b', "`b'")
			
			if "`stars'"!="none" {
				frame `estframe': loc __p = p`col_i'[`row_i']
				if 		`__p'<`3star' loc __stars = `"\sym{***}"'
				else if `__p'<`2star' loc __stars = `"\sym{**}"'
				else if `__p'<`1star' loc __stars = `"\sym{*}"'
				else loc __stars = ""
			}
			
			mata pT->append_to_line(`"&"', 0, "no")
			/*
			if `__b'!=.		mata pT->append_to_line(`"`__b'`__stars'"', 1, "center")
			else			mata pT->append_to_line(`"."', 1, "center")
			*/
			if `__in'==1	mata pT->append_to_line(`"`__b'`__stars'"', 1, "center")
			else			mata pT->append_to_line(`" "', 1, "center")
		}
		mata: pT->append_to_line(`"\\ "', 0, "no")
		
		// parenthesis
		if "`paren'"!="none" {
			
			mata: st_local("in_paren", pT->paren)
			mata: pT->add_line(`""')
			mata pT->append_to_line("", 1, "left")
			

			forv col_i = 1/`n_cols' {	
				frame `estframe': loc __in = in`col_i'[`row_i']
				if "`in_paren'"!="ci" {
					frame `estframe': loc paren_content = `in_paren'`col_i'[`row_i']
					loc paren_content = strofreal(`paren_content', "`paren'")
					//loc has_paren_content = !mi(`paren_content')
				}
				else {
					frame `estframe': loc ci_l = ci_l`col_i'[`row_i']
					frame `estframe': loc ci_u = ci_u`col_i'[`row_i']
					loc ci_l = strofreal(`ci_l', "`paren'")
					loc ci_u = strofreal(`ci_u', "`paren'")
					loc paren_content = "`ci_l', `ci_u'"
					loc has_paren_content = !mi(`ci_l') & !mi(`ci_u')
				}
				
				mata pT->append_to_line(`"&"', 0, "no")
				if `__in'==1 	mata pT->append_to_line(`"(`paren_content')"', 1, "center")
				else 			mata pT->append_to_line(`" "', 1, "center")
			}
			
			mata: pT->append_to_line(`"\\"', 0, "no")
		}
		
		
		if `row_i'!=`n_vars' & "`gap'"!="nogap" mata: pT->add_line("[1em]")
		if `row_i'!=`n_vars' mata: pT->add_line(`""')
		//else 				 mata: pT->add_line(`""')
	}
end

prog statex_est_indic
	syntax, name(string) n_cols(integer) indframe(string asis) [nogap]
	
	// Write indicators
	frame `indframe': loc n_indics = _N
	frame `indframe': loc yes = yes[1]
	frame `indframe': loc no = no[1]
	
	forv row_i = 1/`n_indics' {
		frame `indframe': loc var = label[`row_i']
		mata: pT->add_line(`""')
		mata: pT->append_to_line(`"`var'"', 1, "left")
		
		forv col_i = 1/`n_cols' {
			frame `indframe': loc has = fe`col_i'[`row_i'] == 1
			mata pT->append_to_line(`"&"', 0, "no")
			if `has' 	mata pT->append_to_line(`"`yes'"', 1, "center")
			else 		mata pT->append_to_line(`"`no'"', 1, "center")
		}
		mata: pT->append_to_line(`"\\"', 0, "no")
		if `row_i'<`n_indics' & "`gap'"!="nogap" mata: pT->add_line(`"[1em]"')
	}
end

prog statex_est_stats
	syntax namelist, name(namelist max=1) [statistics(string asis)] //[stats(namelist) format(string) labels(string)]
	loc estnames `namelist'
	// Add regression statistics (N observations etc.)
	
	* Syntax
	********
	// Table is open
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	loc 0 `statistics'
	syntax [namelist], [format(string asis) label(string asis)]
	loc stats `namelist'
	if `"`stats'"'=="" loc stats = "N r2"
	
	// Default options if stats is unspecificed
	if "`stats'"=="" {
		loc stats = "N r2"
		loc format = `"%12.0fc %3.2fc"'
	}
	
	if "`format'"!="" 	loc format_provided = 1
	else 				loc format_provided = 0
	
	foreach fmt of local format {
		// Check format
		cap loc _ : display `fmt' 1234
		if _rc {
			di as error "Invalid format: `fmt'"
			exit 198
		}
	}
	
	
	* Write table
	*************

	loc n = 1
	foreach stat of local stats {
		if `n'>1 mata: pT->add_line("")
		loc n = `n'+1
		
		// Label - Note: Stata keeps interpreting $ when using locals, so writing directy to Mata
		loc done = 0
		gettoken lab label : label
		if "`lab'"=="" & "`stat'"=="N" 	{
			mata pT->append_to_line("Observations", 1, "left") 
			loc done = 1
		}
		if "`lab'"=="" & "`stat'"=="r2" {
			mata pT->append_to_line(`"\$R^2\$"', 1, "left") 
			loc done = 1
		}
		if !`done' {
			if `"`lab'"'!="" 	mata pT->append_to_line(`"`lab'"', 1, "left") 
			else 				mata pT->append_to_line(`"`stat'"', 1, "left") 
		}
		
		
		// Format stats
		if `format_provided' {
			loc last_format = "`fmt'"
			gettoken fmt format : format
			if `"`fmt'"'=="" loc fmt = "`last_format'" // Use last provided 	
		}
		else {
			if "`stat'"=="N"  loc fmt = "%19.0fc"
			else loc fmt = "%19.3fc"
		}
		
		foreach est of local estnames {
			qui estimates restore `est'
			loc value = e(`stat')
			if `value'==. loc value = ""
			if "`value'"!="" loc value = string(`value', "`fmt'")
			mata pT->append_to_line("&", 0, "no")
			mata pT->append_to_line("`value'", 1, "center")
		} 
		mata: pT->append_to_line(`"\\"', 0, "no")
	}
end

prog statex_mat
	syntax, b(string asis) [name(string) rowlabels(string asis) titles(string asis) se(namelist max=1) p(namelist max=1)] //Flag add 
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Syntax
	********
	// Table is open
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	// Check that namelist has the appropriate length. 
	* Flag: Need to infer cols of the table using colsof(`b') and call
	//mata: pT->check_ncols(`n_cols',  "Wrong number of columns.")
	statex_check_ncols, name("`name'") n_cols(`n_cols') error("Wrong number of columns.")
	
	mata: st_local("ncols_statex", strofreal(pT->ncols))
	
	* Parse options with suboptions into main components and suboptions
	*******************************************************************
	
	// b
	gettoken bmain bopt : b, parse(",")
	loc 0 `bmain'
	syntax [namelist(max=1)]
	loc b `namelist'
	loc 0 `bopt'
	syntax, [format(string)]
	loc bformat `format'
	
	// se
	gettoken semain seopt : se, parse(",")
	loc 0 `semain'
	syntax [namelist(max=1)]
	loc se `namelist'
	loc 0 `seopt'
	syntax, [format(string) none]
	loc seformat `format'
	if "`se'"=="" | "`none'"!="" 	loc show_se = 0
	else 							loc show_se = 1
	
	
	if `show_se' mata: pT->used_paren = 1
	// Flag: se: accept "se(semat, nose)" to be able to use se's to produce stars without showing ses. 
	
	* Check syntax
	**************
	
	// Matrices exists: 
	cap confirm matrix `b'
	if _rc {
		di as error "Matrix `b' not found"
		exit 198
	}
	
	if "`se'"!="" & "`p'"!="" {
		di as error "Cannot provide both 'se' matrix and 'p' matrix"
	} 
	
	if "`se'"!="" {
		cap confirm matrix `se'
		if _rc {
			di as error "Matrix `se' not found"
			exit 198
		}
	}
	
	if "`p'"!="" {
		cap confirm matrix `p'
		if _rc {
			di as error "Matrix `p' not found"
			exit 198
		}
	}
	
	// Flag: if se matrix provided: Create p matrix.
	
	// Expand format lists
	if `'"`bformat'"'!="" {
		loc n_formats : word count `bformat'
		loc last_format : word `n_formats' of `bformat'
		
		forv n = 1/`=`ncols_statex'-`n_formats'' {
			loc bformat = `"`bformat' `last_format'"'
		}
	}
	
	if `'"`seformat'"'!="" {
		loc n_formats : word count `seformat'
		loc last_format : word `n_formats' of `seformat'
		
		forv n = 1/`=`ncols_statex'-`n_formats'' {
			loc bformat = `"`seformat' `last_format'"'
		}
	}
	
	// Check valid formats:
	if "`bformat'"!="" {
		loc all_formats = `"`bformat'"'
		while "`all_formats'"!="" {
			gettoken current_format all_formats : all_formats
			cap confirm format `current_format'
			if _rc {
				di as error "'`current_format'' not a valid format (provided as a sub-option to the 'b' option)"
				exit 198
			}
		}
	}
	
	if "`seformat'"!="" {
		loc all_formats = `"`seformat'"'
		while "`all_formats'"!="" {
			gettoken current_format all_formats : all_formats
			cap confirm format `current_format'
			if _rc {
				di as error "'`current_format'' not a valid format (provided as a suboption to the 'se' option)"
				exit 198
			}
		}
	}
	
	// Fill `rowlabels' with matrix rownames
	if `"`rowlabels'"'=="rownames" loc rownames : rownames `b' 
	
	// Check correct number of rowlabes: 
	if !inlist("`rowlabels'", "", "rownames") {
		loc n_rowlabels : word count `rowlabels'
		cap assert `n_rowlabels'==rowsof(`b')
		if _rc {
			di as error "Number of Provided rowlabels (`n_rowlabels') is not the same as the number of rows of b (`=rowsof(`b')')."
		}
	}
	
	// Correct number of implied columns:
	/*FLAG
	loc ncols = colsof(`b')
	if `"`rowlabels'"'!="" loc ++ncols
	if `"`rowlabels'"'!="" loc ncols_p1 = ", including one for row labes"
	if `ncols'!=`ncols_statex' {
		di as error "Wrong number of implied columns. Table has `ncols_stable' columns, received `ncols'`ncols_p1'."
		exit 198
	}
	*/
	
	* Write
	*******
	
	forv row = 1/`=rowsof(`b')' {
		mata: pT->add_line("")
		// b	
		
		// flag: if rowlabels provided: ... add rowlabel "loc start_col=2 ; "
		
		forv col = 1/`=colsof(`b')' {
			if `"`bformat'"'!="" gettoken current_format bformat : bformat
			loc val = `b'[`row',`col']
			// Flag: do p stuff
			if `"`current_format'"'!="" loc val : display `current_format' `val'
			
			
			if `col'>1 mata: pT->append_to_line("&", 0, "no")
			mata: pT->append_to_line(`"`val'"',1, "center")
		}
		
		mata: pT->append_to_line(`" \\ "', 0, "no")
		
		// se 
		
		if `show_se' {
		// Flag: if has rowlabel : loc start_col=2 ; forv `start_col'/`=colsof(`b')'
		forv col = 1/`=colsof(`b')' {
			if `"`seformat'"'!="" gettoken current_format seformat : seformat
			loc val = `se'[`row',`col']
			// Flag: do p stuff
			if `"`current_format'"'!="" loc val : display `current_format' `val'
			
			
			if `col'>1 mata: pT->append_to_line("&", 0, "no")
			mata: pT->append_to_line(`"`val'"', 1, "center")
		}		
		}
	}
	
	
end

// FLAG 
prog statex_from_data
	syntax varlist, [mat(namelist max=1) name(namelist max=1)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Syntax
	********
	// Table is open
	if "`name'"=="" mata: st_local("name", statex.get_current())
end


prog statex_indicate

end

// FLAG
prog statex_diff

end

******
*
******

prog statex_footer
	/// FLAG : add option to turn subnotes off (e.g. nostars nose etc.)
	syntax, [name(namelist max=1) stars robust cluster(string asis) custom(string asis)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Syntax
	********
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	cap assert `"`robust'"'=="" | `"`cluster'"'=="" 
	if _rc {
		di as error "Cannot specify both robust and clustered SEs - since clustering implies HAC robust. "
		exit 198
	}
	
	* Add Footer
	************
	
	//statex_midrule, name("`name'")
	
	mata: st_local("n_cols_tab", strofreal(pT->ncols))
	mata: st_local("used_stars", strofreal(pT->used_stars))
		
	if `used_stars' | "`stars'"!="" {
		// Extract and format numbers
		mata: st_local("stars", pT->stars)
		gettoken 1stars stars : stars
		gettoken 2stars 3stars : stars
		forv n = 1/3 {
			loc `n'stars = string(``n'stars', "%4.3fc")
		}
		
		
		mata: pT->add_line("\multicolumn{`n_cols_tab'}{l}{\footnotesize \sym{*}\(p<`1stars'\), \sym{**} \(p<`2stars'\), \sym{***} \(p<`3stars'\)} \\")
		//mata: pT->add_line("\multicolumn{`ncols'}{l}{\footnotesize \sym" + "{" + "*" + "}" + "\(p<`1stars'\), \sym{**} \(p<`2stars'\), \sym{***} \(p<`3stars'\)} \\")
	}
	
	mata: st_local("paren", pT->paren)
	mata: st_local("used_paren", strofreal(pT->used_paren))
	mata: st_local("ci_level", strofreal(pT->ci_level))
	
	if `used_paren' | "`paren'"!="" { // FLAG Robust currently unused - and include clustering
		if "`paren'"=="se" 						 	loc in_paren = "Standard errors in parentheses"
		if "`paren'"=="t"							loc in_paren = "t statistics in parenthesis"
		if "`paren'"=="p"							loc in_paren = "p-values in parenthesis"
		if "`paren'"=="ci"							loc in_paren = "`ci_level' \% confidence intervals in parenthesis"
		mata: pT->add_line(`"\multicolumn{`n_cols_tab'}{l}{\footnotesize `in_paren'} \\"')
	}
	
	if `"`robust'"'!=""  mata: pT->add_line(`"\multicolumn{`n_cols_tab'}{l}{\footnotesize Standard errors are HAC robust} \\"')
	if `"`cluster'"'!="" mata: pT->add_line(`"\multicolumn{`n_cols_tab'}{l}{\footnotesize Standard errors are HAC robust and clustered on `cluster'} \\"')
	
	if `"`custom'"'!="" {
		if strpos(`"`custom'"', `"""')==0 loc custom = `""`custom'""'
		foreach custom_msg of local custom {
		mata: pT->add_line(`"\multicolumn{`n_cols_tab'}{l}{\footnotesize `custom_msg'} \\"')	
		}
	}
end


prog statex_close
	syntax, [name(namelist max=1) footer(string asis)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Syntax
	********
	// Table is open
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	loc 0 , `footer'
	syntax, [stars robust cluster(passthru) custom(passthru)]
	
	/*
	if "`notextprocessing'"=="" {
		loc text = subinstr(`"`text'"', `"#"', `"\#"', .)
		loc text = subinstr(`"`text'"', `"_"', `"\_"', .)
		loc text = subinstr(`"`text'"', ">", `"\textgreater"', .)
		loc text = subinstr(`"`text'"', "<", `"\textless"', .)
	}
	*/
	
	mata: pT->add_line(`"\hline\midrule"')
	statex_footer, name(`name') `stars' `robust' `cluster' `custom'
	mata: pT->add_line(`"\end{tabular}"')
	mata: pT->is_closed = 1
end


prog statex_save
	syntax, [name(namelist max=1) replace] filename(string)
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Syntax
	********
	
	// Check path exists
	mata: st_local("direxists", strofreal(direxists(pathgetparent(`"`filename'"'))))
	if !`direxists' {
		mata: st_local("not_a_dir", pathgetparent(`"`filename'"'))
		di as error "Directory not found"
		exit 601
		
	}
	
	// If replace not specified, return error if it exists
	loc filefound = fileexists(`"`filename'"')
	if "`replace'"=="" {
		if fileexists(`"`filename'"') {
			di as error "File already exists - add option 'replace' to overwrite"
			exit 602
		}
	}
	
	// If replace exists: delete file if it exists
	loc replaced = 0
	if "`replace'"!="" {
		if fileexists(`"`filename'"') {
			cap erase `"`filename'"'
            if _rc {
                di as error `"Tried to replace, but could not delete `filename'"'
                exit _rc
            }
			loc replaced = 1
		}
	}
	
	cap confirm new file `"`filename'"'
	if _rc {
		di as error `"Not a valid filename: `filename'"'
		exit 603
	}
	
	* Get Table object: 
	
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	* Write to file
	****************
	
	mata: rc = pT->write_table(`"`filename'"')
	mata: st_local("rc", strofreal(rc))
	
	if `rc'==0 {
		di as error "Stata experienced an error when trying to write the table to file"
		exit 198
	}
	
	if `replaced' loc replaced = "(replaced)"
	if !`filefound' di `"(file `filename' not found)"'
	di `"✓ LaTeX table successfully written to {it:`filename'} `replaced'"'
	
end

*********
* Other *
*********

prog statex_midrule
	syntax, [name(namelist max=1)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit

	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	mata: pT->add_line("\midrule")
	
end

prog statex_numbers 
	syntax, [name(namelist max=1) blank numbers(string asis)]
	
	// Manual parsing
	while `"`numbers'"'!="" {
		gettoken option numbers : numbers
		cap assert inlist(`"`option'"', "none", "noblank")
		if _rc {
			di as error `"Statex numbers did not recognize option `opt'"'
			exit 198
		}
		if "`option'"=="none" exit
		if "`option'"=="noblank" loc blank=0
	}
	loc blank = "`blank'"!=""
	
	
	* Syntax
	********
	
	if "`name'"=="" mata: st_local("name", statex.get_current())
	mata: pT = statex.get_table("`name'")
	
	* Prepare
	*********
	
	mata: st_local("n_cols", strofreal(pT->ncols))
	if `blank' 	loc iN = `n_cols'-1
	else		loc iN = `n_cols'
	
	* Write
	*******
	mata: pT->add_line("")
	if `blank' {
		mata: pT->append_to_line(`""', 1, "center")
		if `n_cols'>1 mata: pT->append_to_line(`"&"', 0, "no")
	}
	forv i=1/`iN' {
		mata: pT->append_to_line(`"\multicolumn{1}{c}{(`i')}"', 1, "center")
		if `i'<`iN' mata: pT->append_to_line(`"&"', 0, "no")
	}
	mata: pT->append_to_line(`"\\"', 0, "no")
	
end

*********************
* Include mata code *
*********************

include "statex.mata", adopath

prog statex_assert_mata
	syntax, [exit]
	
	cap mata: statex 
	if _rc {
		di as error `"{it:statex}: Mata object "statex" missing. Did you run "mata: mata clear"?. Reinitializing. Note that all table data is lost."'
		//mata: statex = Statex()
		//mata: statex.init()
		qui findfile statex.mata
        quietly do "`r(fn)'"
		
		if "`exit'"=="exit" exit 349
	}
	
end