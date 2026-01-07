*! version 0.1.0 07jan2026


********************************************************************************
***************************** Access point *************************************
********************************************************************************


cap prog drop statex
prog statex
	version 16
	
	
	gettoken subcmd 0 : 0, parse(" ,")
	local subcmd = trim("`subcmd'")
	
	di `"CALL: statex_`subcmd' `0'"'
	
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
		[coltypes(string)] n_cols(integer) ///
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
	//if "`ci_level'"=="" loc ci_level = "95"
	if "`coltypes'"=="" {
		loc coltypes = "l"
		forv n = 1/`=`n_cols'-1' {
			loc coltypes = "`coltypes'c"
		}
	}
	
	* Save Meta Information
	***********************
	if "`name'"=="" mata: statex.get_auto_newname() // Get auto name if name is unspecified. 
	mata: pT = statex.add_table("`name'", `n_cols', "`stars'", "`paren'", `width', `ci_level')
	mata: pT->add_line("\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}")
	mata: pT->add_line("\begin{tabular}{`coltypes'} \hline\midrule")
end

prog statex_list
	syntax, [name(string)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	if "`name'"=="" mata: _ = statex.get_current()
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
	syntax, [name(string)]
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata
	
	*
	************
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	mata: statex.drop_table(pT)
	
end

********************************************************************************
*********************************** Header / row *******************************
********************************************************************************

prog statex_row
	syntax, ///
		[name(namelist max=1)] ///
		row(string asis) [multicolumn(numlist integer min=1) noblank align(string) underline(string asis) bold]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Name
	******
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	mata: pT->add_line("")
	
	* Parse
	*******
	loc blank = "`noblank'"==""
	loc has_multicolumn = `"`multicolumn'"'!=""
	
	// If not multicolumn: n in row same as columns in table
	if !`has_multicolumn' {
		loc has_multicolumn = 0
		
		// Count implied columns from syntax
		loc ncols : list sizeof row
		if `blank' loc ncols = `ncols' + 1
		
		// Get number of columns of table: 
		mata: st_local("ncols_table", strofreal(pT->ncols))
		
		// Check that they are the same: 
		cap assert `ncols' == `ncols_table' //test: statex_new, ncols(3); statex_row, row("a" "b" "c" "d")
		if _rc {
			if `blank' loc blank_message = " including one blank column"
			di as error "Wrong number of elements in row. Received `ncols' columns`blank_message', expected `ncols_table'"
			exit 198
		}
		
		// Check: alignment not specified
		cap assert `"`align'"'=="" //test: statex_new, ncols(3); statex_row, row("a" "b" "c") align(c c c) 
		if _rc {
			di as error "Cannot specify 'align' without multicolumn"
			exit 198
		}
	}
	
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
		if `blank' loc p1 = "+1" // Move below the loop and change to if `blank' loc n_cols = `n_cols'+1
		loc n_cols = 0 
		foreach multicol of local multicolumn {
			loc n_cols = `n_cols' + `multicol'
		}
			// Get number of columns of table: 
		mata: st_local("n_cols_tab", strofreal(pT->ncols))
		
		cap assert `n_cols' `p1' == `n_cols_tab'
		if _rc {
			if `blank' loc blank_message = " including one blank column"
			di as error `"Total Number of columns, i.e. sum of multicolumns (`n_cols'`blank_message'), is not the same as the number of columns in Table `name' (`n_cols_tab')"'
			exit 198
		}
		
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
	if !`has_multicolumn' {
		loc n = 0
		if `blank' {
			mata: pT->append_to_line("",1,"left")
			loc ++n
		}
		
		foreach elem of local row {
			if `n'>0 mata: pT->append_to_line("&", 0, "no")
			mata: pT->append_to_line(`"`bold_start'`elem'`bold_end'"',1, "left")
			loc ++n
		}
	}
	else {
		loc n = 0
		if `blank' {
			mata: pT->append_to_line("&", 0, "no")
		}
		
		
		foreach elem of local row {
			gettoken n_cols multicolumn : multicolumn
			if `has_align' 	gettoken a align : align
			else 			loc a = "c"
			if `n'>0 mata: pT->append_to_line("&", 0, "no")
			mata pT->append_to_line(`"\multicolumn{`n_cols'}{`a'}{`bold_start'`elem'`bold_end'}"',1, "left")
			loc n = `n'+1
		}
	}
	mata: pT->append_to_line(`"\\ "', 0, "no")
	mata: pT->cell_overflow = 0
	
	loc has_midrule = `"`midrule'"'!=""
	if `has_midrule' {
		foreach lr of local midrule {
			gettoken l r : lr
			loc l: list clean l
			loc r: list clean r
			cap assert regexm("`l'", "^[-+]?[0-9]+$") & regexm("`r'", "^[-+]?[0-9]+$")
			if _rc {
				di as error `"midrule must consists of lists of numbers, received `l'-`r'"' // Flag: move this code up to the beguinning of the program
			}
			
			pT->append_to_line(`" \cmidrule(lr){`l'-`r'} "',0, "no")
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
	
	
	if "`name'"=="" mata: _ = statex.get_current()
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
	syntax namelist, [name(namelist max=1)]  [label] [b(passthru) paren(passthru)] [stat(string) nostats absorbed(string asis) drop(passthru) keep(passthru) order(passthru) longmidrule stars(passthru)] ///
	[indicate(passthru)] [noheader]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Syntax
	********
	// Table is open
	if "`name'"=="" mata: _ = statex.get_current()
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
	if `"`b'"' =="" 	loc b  =  "b(%4.3fc)"
	if `"`paren'"'=="" 	loc paren = "paren(%4.3fc)"
	
	if "`paren'"!="paren(none)" 	mata: pT->used_paren = 1
	if "`stars'"!="none"	mata: pT->used_stars = 1
	
	// Check that namelist contains res that exists
	foreach estname of local namelist {
		cap estimates dir `estname'
		if _rc {
			di as error `"Stored estimate `estname' not found"'
		}
	}
	
	// Check that namelist has the appropriate length. 
	loc nres : list sizeof namelist
	mata: st_local("ncols", strofreal(pT->ncols))
	
	cap assert `nres'==`ncols'-1
	if _rc {
		di as error "Number of estimation results provided (`nres') not the same as the number expected (`=`ncols'-1')"
		di as error "	Expects one less estimation result than the number of columns in table (the first is reserved for variable names)."
		exit 198
	}
	
	* Write table
	*************
	
	if "`header'"=="" {
		statex_est_header `namelist', name(`name') `label' `bold'
		statex_midrule, name("`name'")
	}
	
	cap frame drop __table_res
	frame create __table_res
	frame __table_res: qui g strL varlist = ""
	
	cap frame drop __table_indicate
    frame create __table_indicate
    frame __table_indicate: qui gen strL varlist = ""
	frame __table_indicate: qui gen strL label = ""
	
	/*
	tempname estframe indframe
	*/
	
	// Move est. to frame
	
	statex_est_prepare `namelist',  `label' name(`name') `drop' `keep' `order' estframe(__table_res) indframe(__table_indicate) `indicate'
	
	// export to latex file. 
	loc n_cols : list sizeof namelist
	statex_est_write, n_cols(`n_cols') name(`name') `b' `paren' `stars' estframe(__table_res) indframe(__table_indicate)
	
	// Flag: Should look for these variables in `absorb' (or wherever they are stored), as well as the usual varlists. 
	if `"`absorbed'"'!="" {
		foreach abs of local absorbed {
			loc abs = subinstr(`"`abs'"', "#", `"\#"', .)
			mata: pT->add_line("`abs'", 1) // Write FE text
			
			// Write checkmarks
			loc param_cols = `ncols' - 1 
			forv n = 1/`param_cols' {
				mata: pT->append_to_line(`" & \checkmark"', 0, "center")
			}
			//mata: pT->append_to_line(" \\", 0)
		}
	}
	
	if "`nostats'"=="" {
		if "`longmidrule'"!="" statex_midrule, name(`name')
		else mata: pT->append_to_line(`" \cmidrule(lr){2-`ncols'}"', 0, "no")
		mata: pT->add_line("")
		// Pars stats options by splitting at first comma (if it exists)
		// i.e. stats(a b c, fmt(%9.0fc)) -> stats_main_opt = "a b c" & stats_other_opt = "fmt(%9.0fc)"
		//if `"`stat'"'=="" loc stat = ""
		loc comma_pos = strpos(`"`stat'"', ",")
		if `comma_pos' {
			loc stat_main_opt = substr(`"`stat'"', 1, `comma_pos'-1)
			loc stat_other_opt = substr(`"`stat'"', `comma_pos'+1, .)
		}
		else loc stat_main_opt = `"`stat'"'
		statex_est_stats `namelist', name(`name') stats(`stat_main_opt') `stat_other_opt'
	}
end

prog statex_est_prepare 
	syntax namelist, [name(namelist max=1) label drop(string) keep(string) order(string)] estframe(namelist max=1) indframe(namelist max=1) [indicate(passthru)] // Pick out name and move to parent function
	// Take ests stored in namelist, store in (new) frame __table_res, label (if option `label'), keep, order etc.
	
	loc label = "`label'"!=""
	
	* Syntax
	********
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	mata: st_local("ncols_statex", strofreal(pT->ncols))
	
	// Check that the user provided the correct number of results/columns
	loc n_res : list sizeof namelist
	cap assert `n_res' + 1 == `ncols_statex' // column for varnames
	if _rc {
		di as error "Wrong number of estimation results. Received `n_res', expected `=`ncols_statex'-1'" 
		di "(The table has `ncols_statex' columns, of which one is used for the varlist)"
		exit 198
	}
	
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
	statex_est_extract `namelist', ci_level(`ci_level') estframe(`estframe') indframe(`indframe') `indicate' // Adds estimated params to frame

	frame __table_res: qui replace varlist = subinstr(varlist, "c.", " ", .)
	
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
	
	if `"`order'"'!="" {
		frame `estframe': qui g order = .
		frame `estframe': qui g init_order = _n
		loc current_order = 1
		foreach token of local order {
			frame `estframe': qui replace order = `current_order' if strmatch(varlist, `"`token'"')
			loc current_order = `current_order' + 1
		}
		frame `estframe': sort order init_order
		frame `estframe': drop order init_order
	}
	
	
	if `label' {
		frame `estframe': qui levelsof varlist, local(varlist)
		loc varlist : list clean varlist
		foreach v of local varlist {
			cap loc lab : variable label `v'
			if _rc 	  			loc lab = ""
			if "`lab'"!="" frame `estframe': qui replace varlist = subinstr(varlist, "`v'", "`lab'", .)
		}
		frame `estframe': qui replace varlist = subinstr(varlist, "_cons", "Constant", .)
	}
	
	// Escape characters (FLAG: not complete)
	frame `estframe': qui replace varlist = subinstr(varlist, "#", " \#", .)
	frame `estframe': qui replace varlist = subinstr(varlist, "_", "\_", .)
end

prog statex_est_extract // Take est and place in (i.e. add to) frame
	syntax namelist, ci_level(numlist max=1) [indicate(string asis)] estframe(string asis) indframe(string asis) //, est(string) suffix(string)
	
	// Consider changing this to a mata matrix for Stata users with limited number of columns. 
	// parse indicate option
	local cpos = strpos(`"`indicate'"', ",")
	if `cpos'==0 local indicate_var_lab `"`indicate'"'
	else {
		local indicate_var_lab = strtrim(substr(`"`indicate'"', 1, `cpos' - 1))
		local indicate_options = strtrim(substr(`"`indicate'"', `cpos' + 1, .))	
	}
	loc 0 , `indicate_options'
	syntax , [indicators(string asis)]
	
	loc n_indicators     = wordcount(`"`indicators'"')
	
	cap assert `n_indicators'<=2 
	if _rc {
		di as error "Cannot provide more than two indicators (only used to display 'yes' and 'no')."
		exit 198
	}
	
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
		di `"`var_lab': `var' - `lab'"'
		di "`indframe'"
		frame `indframe' {
			set obs `=_N+1'
			replace varlist = "`var'" if _n==_N
			replace label = "`lab'" if _n==_N
		}
	}
	
	loc column = 1
	foreach est of local namelist {
		
		frame `estframe' {
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
		loc absorbed = "`e(absvars)'"
		
		* Parameters
		************
		
		loc varnames : colnames b
		
		cap mat drop `to'
		loc n = colsof(b)
		forv i = 1/`n' {
			loc varname : word `i' of `varnames'
			if substr("`varname'",1,2)!="o." {
				
				// Check if `varname' is in `indicate'?
                local in_indicate = 0
				frame `indframe': qui levelsof varlist, local(indicated)
				//loc indicated : list clean indicated
				foreach pat of local indicated {
					if strmatch("`varname'", `"`pat'"') local in_indicate = 1
					//di `"			compare |`pat'| with |`varname'"'
					//di strmatch("`varname'", `"`pat'"')
				}
				
				if `in_indicate'==0 { // Include parameter
					loc clean_varname = subinstr("`varname'", "c.", " ", .)
					loc clean_varname = subinstr("`clean_varname'", "#", " ",.)
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
							qui count if varlist == "`varname'"
							if r(N)==0 {
								qui set obs `=_N+1'
								qui replace varlist = "`varname'" if _n==_N
							}
							qui replace b`column'  = `b'  if varlist=="`varname'"
							qui replace se`column' = `se' if varlist=="`varname'"
							qui replace t`column'  = `t'  if varlist=="`varname'"
							qui replace p`column'  = `p'  if varlist=="`varname'"
							qui replace ci_l`column' = `ci_l' if varlist=="`varname'"
							qui replace ci_u`column' = `ci_u' if varlist=="`varname'"
					}
				}
				else { // Include indicator
					frame `indframe': replace fe`column'=1 if strmatch("`varname'", varlist)
				}
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
		//frame drop __table_res
		//frame drop __table_indicate
		di as error `"Cannot indicate variables. Not found in estimation results: `notfound'"'
		exit 111
	}
	else { 
		frame `indframe': drop rowsum
	}
end

// FLAG: add options (bold, label). Also add group to group yvars (with cmidrule)
prog statex_est_header
	syntax namelist, [name(string) bold label]
	
	* Syntax
	********
	if "`name'"=="" mata: _ = statex.get_current()
	//mata: pT = statex.get_table("`name'")
	//mata: st_local("ncols_statex", strofreal(pT->ncols))
	
	* Write 
	********
		
	foreach est of local namelist {
		qui estimates restore `est'
		loc y `e(depvar)'
		cap if "`label'"!="" 	loc ylab : variable label `y' // cap in case the variable is not defined
		if "`ylab'"==""		loc ylab = "`y'"
		loc yrow = `"`yrow' "`ylab'""'
		loc align = "`align' c"
		loc multicolumn = "`multicolumn' 1"
	}

	statex row, row(`yrow') `bold' align(`align') name(`name') multicolumn(`multicolumn')
	
end



prog statex_est_write
	syntax, name(string) [stars(string)] n_cols(integer) b(string) paren(string) estframe(string asis) indframe(string asis) //se(string)
	// Reads params from frame and writes to table. 
	
	mata: pT = statex.get_table("`name'")
	frame `estframe': loc n_vars = _N
	mata: pT->add_line(`""')
	
	// Write point estimates
	forv row_i = 1/`n_vars' {
		frame `estframe': loc var = varlist[`row_i']
		mata: pT->append_to_line(`"`var'"', 1, "left")
		
		// beta/stars
		mata: st_local("starlist", pT->stars)
		gettoken 1star starlist : starlist
		gettoken 2star 3star : starlist
		
		forv col_i = 1/`n_cols' {	
			frame `estframe': loc __b = b`col_i'[`row_i']
			loc __b = strofreal(`__b', "`b'")
			
			if "`stars'"!="none" {
				frame `estframe': loc __p = p`col_i'[`row_i']
				if 		`__p'<`3star' loc __stars = `"\sym{***}"'
				else if `__p'<`2star' loc __stars = `"\sym{**}"'
				else if `__p'<`1star' loc __stars = `"\sym{*}"'
				else loc __stars = ""
			}
			
			mata pT->append_to_line(`"&"', 0, "no")
			if `__b'!=.		mata pT->append_to_line(`"`__b'`__stars'"', 1, "center")
			else			mata pT->append_to_line(`""', 1, "center")
		}
		mata: pT->append_to_line(`"\\ "', 0, "no")
		
		// parenthesis
		if "`paren'"!="none" {
			
			mata: st_local("in_paren", pT->paren)
			mata: pT->add_line(`""')
			mata pT->append_to_line("", 1, "left")
			
			forv col_i = 1/`n_cols' {			
				if "`in_paren'"!="ci" {
					frame `estframe': loc paren_content = `in_paren'`col_i'[`row_i']
					loc paren_content = strofreal(`paren_content', "`paren'")
					loc has_paren_content = !mi(`paren_content')
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
				if `has_paren_content' 	mata pT->append_to_line(`"(`paren_content')"', 1, "center")
				else 					mata pT->append_to_line(`""', 1, "center")
			}
			
			mata: pT->append_to_line(`"\\"', 0, "no")
		}
		
		
		if `row_i'!=`n_vars' mata: pT->add_line("[1em]")
		if `row_i'!=`n_vars' mata: pT->add_line(`""')
		//else 				 mata: pT->add_line(`""')
	}
	
	// Write indicators
	frame `indframe': loc n_indics = _N
	
	forv row_i = 1/`n_indics' {
		frame `indframe': loc var = label[`row_i']
		mata: pT->add_line(`""')
		mata: pT->append_to_line(`"`var'"', 1, "left")
		
		forv col_i = 1/`n_cols' {
			frame `indframe': loc has = fe`col_i' == 1
			mata pT->append_to_line(`"&"', 0, "no")
			if `has' 	mata pT->append_to_line(`"\checkbox"', 1, "center")
			else 		mata pT->append_to_line(`""', 1, "center")
		}
		mata: pT->append_to_line(`"\\"', 0, "no")
	}
end

program statex_est_stats
	syntax namelist, name(namelist max=1) [stats(namelist) format(string) labels(string)]
	// Add regression statistics (N observations etc.)
	
	* Syntax
	********
	// Table is open
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	
	if "`label'"!=""  	loc option_label  = 1
	else				loc option_label  = 0
	if "`format'"!=""	loc option_format = 1
	else 				loc option_format = 0
	
	// Default options if stats is unspecificed
	if "`stats'"=="" {
		loc stats = "N r2"
		loc format = `"%12.0fc %3.2fc"'
		loc option_format = 1
	}
	* Write table
	*************
	
	loc n = 1
	foreach stat_name of local stats {
		if `n'>1 mata: pT->add_line("")
		loc n = `n'+1
		
		// Label stats
		loc stat_label = ""
		loc stat_label_written = 0 // FLAG: Can just do if, else if etc?
		gettoken stat_label labels : labels  // Use user provided label if provided
		if "`stat_label'"!="" {
			mata pT->append_to_line("`stat_label'", 1, "left")
			loc stat_label_written = 1
		}
		if !`stat_label_written' & `"`stat_name'"'=="N" {
			mata pT->append_to_line("Observations", 1, "left")
			loc stat_label_written = 1
		}
		if !`stat_label_written' & `"`stat_name'"'=="r2"	{
			mata pT->append_to_line("\$R^2\$", 1, "left")
			loc stat_label_written = 1
		}
		if !`stat_label_written' mata pT->append_to_line(`"`stat_name'"', 1, "left")
		// Format stats
		if `option_format' gettoken stat_format format : format
		if `"`stat_format'"'=="" loc stat_format = "`last_stat_format'" // Use last provided 
		if `"`stat_format'"'=="" loc stat_format = "%12.2fc" // Use default if still empty
		loc last_stat_format = `"`stat_format'"'
		
		foreach est of local namelist {
			qui estimates restore `est'
			loc stat = e(`stat_name')
			if `stat'==. loc stat = ""
			if "`stat'"!="" loc stat = string(`stat', "`stat_format'")
			mata pT->append_to_line("&", 0, "no")
			mata pT->append_to_line("`stat'", 1, "center")
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
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
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
	di "All formats OK"
	
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
	loc ncols = colsof(`b')
	if `"`rowlabels'"'!="" loc ++ncols
	if `"`rowlabels'"'!="" loc ncols_p1 = ", including one for row labes"
	if `ncols'!=`ncols_statex' {
		di as error "Wrong number of implied columns. Table has `ncols_stable' columns, received `ncols'`ncols_p1'."
		exit 198
	}
	
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
	if "`name'"=="" mata: _ = statex.get_current()
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
	if "`name'"=="" mata: _ = statex.get_current()
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
			di "`n'stars: ``n'stars'"
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
		if strpos(`"`custom'"', `"""')==0 loc opt = `""`custom'""'
		foreach custom_msg of local custom {
		mata: pT->add_line(`"\multicolumn{`n_cols_tab'}{l}{`custom_msg'}"')	
		}
	}
end


prog statex_close
	syntax, [name(namelist max=1) /stars robust cluster(passthru) custom(passthru)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Syntax
	********
	// Table is open
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	
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
	syntax, [name(namelist max=1) replace] filename(string asis)
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit
	
	* Syntax
	********
	
	// If replace not specified, return error if it exists
	if "`replace'"=="" {
		if fileexists(`filename') {
			di as error "File already exists"
			exit 602
		}
	}
	
	// If replace exists: delete file if it exists
	if "`replace'"!="" {
		if fileexists(`filename') {
			cap erase `filename'
            if _rc {
                di as error `"Tried to replace, but could not delete `filename'"'
                exit _rc
            }
		}
	}
	
	cap confirm new file `filename'
	if _rc {
		di as error `"Not a valid filename: `filename'"'
		exit 603
	}
	
	* Get Table object: 
	
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	
	* Write to file
	****************
	
	mata: rc = pT->write_table(`filename')
	mata: st_local("rc", strofreal(rc))
	
	di "Return code: `rc'"
	if `rc'==0 {
		di as error "Stata (Mata) experienced an error when trying to write the table to file"
		exit 198
	}
end

*********
* Other *
*********

prog statex_midrule
	syntax, [name(namelist max=1)]
	
	* Check that mata object statex exists: 
	***************************************
	statex_assert_mata, exit

	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	mata: pT->add_line("\midrule")
	
end

*********************
* Include mata code *
*********************

include "statex.mata", adopath

prog statex_assert_mata
	syntax, [exit]
	/*
	cap mata: statex 
	if _rc {
		di as error `"{it:statex}: Mata object "statex" missing. Did you run "mata: mata clear"?. Reinitializing. Note that all data is lost."'
		//mata: statex = Statex()
		//mata: statex.init()
		qui findfile statex.mata
        quietly do "`r(fn)'"
		
		if "`exit'"=="exit" exit 349
	}
	*/
	
end