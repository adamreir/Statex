
********************************************************************************
*********************************** New Table **********************************
********************************************************************************


cap prog drop statex_new
prog statex_new
	syntax, ///
		[name(namelist max=1)] ///
		[coltypes(string)] n_cols(integer) ///
		[stars(numlist descending min=3 max=3) t se p ci none replace]
	
	* Parse
	*******
	
	cap assert !strpos("`name'", " ")
	if _rc {
		di as error "Spaces not permitted in name"
		exit 198
	}
	
	cap assert inlist("`t'`se'`p'`ci'`none'", "", "t", "se", "p", "ci", "none")
	if _rc {
		di as error "Can at most one of the following: 't', 'se', 'p', 'ci', 'none'. Received multiple." 
		exit 198
	}
	
	// Default options: 
	if "`stars'"=="" loc stars = ".05 .01 .001"	
	if "`t'`se'`p'"=="" 	loc se = "se"
	if "`coltypes'"=="" {
		loc coltypes = "l"
		forv n = 1/`=`n_cols'-1' {
			loc coltypes = "`coltypes'c"
		}
	}
	
	* Save Meta Information
	***********************
	if "`name'"=="" mata: statex.get_auto_newname() // Get auto name if name is unspecified. 
	mata: pT = statex.add_table("`name'", `n_cols', "`stars'", "`t'`se'`p'", 10)
	mata: pT->add_line("\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}")
	mata: pT->add_line("\begin{tabular}{`coltypes'} \hline\midrule")
end

cap prog drop statex_list
prog statex_list
	syntax, [name(string)]
	
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	mata: pT->li()
end

cap prog drop statex_dir
prog statex_dir
	mata: statex.dir()
end

cap prog drop statex_row
prog statex_row
	syntax, ///
		[name(namelist max=1)] ///
		row(string asis) [multicolumn(numlist integer min=1) blank align(string) underline(string asis) bold]
	
	di `"`row'"'
	//loc row `""a" "b" "c""'
	//di `"`row'"'
	* Name
	******
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	mata: pT->add_line("")
	
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
		if `blank' mata: pT->append_to_line(" & ")
		
		loc n = 0
		foreach elem of local row {
			if `n'>0 mata: pT->append_to_line(`" & `bold_start'`elem'`bold_end'"')
			else 	 mata: pT->append_to_line(`"`bold_start'`elem'`bold_end'"')
			
			loc n = `n'+1
		}
	}
	else {
		if `blank' mata: pT->append_to_line(" & ")
		
		loc n = 0
		foreach elem of local row {
			gettoken n_cols multicolumn : multicolumn
			if `has_align' 	gettoken a align : align
			else 			loc a = "c"
			if `n'>0 mata: pT->append_to_line(`" & \multicolumn{`n_cols'}{`a'}{`bold_start'`elem'`bold_end'}"')
			else 	 mata: pT->append_to_line(`"\multicolumn{`n_cols'}{`a'}{`bold_start'`elem'`bold_end'}"')
			loc n = `n'+1
		}
	}
	mata: pT->append_to_line(`" \\ "')
	
	loc has_midrule = `"`midrule'"'!=""
	if `has_midrule' {
		foreach lr of local midrule {
			gettoken l r : lr
			loc l: list clean l
			loc r: list clean r
			cap assert regexm("`l'", "^[-+]?[0-9]+$") & regexm("`r'", "^[-+]?[0-9]+$")
			if _rc {
				di as error `"midrule must consists of lists of numbers, received `l'-`r'"'
			}
			
			pT->append_to_line(`"\cmidrule(lr){`l'-`r'} "')
		}
	}
	
	//file write `name'__tab `""' _n
end


cap prog drop statex_panel
prog statex_panel
	syntax, ///
		[name(namelist max=1)] ///
		text(string) ///
		[panel_name(string) nobold]
	
	* Write Panel Header
	********************
	
	if "`nobold'"=="" {
		loc bold_start = `"\\textbf{"'
		loc bold_end   = `"}"'
	}
	
	// Prepare text for LaTeX
	
	
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	mata: pT->panel()
	mata: st_local("ncols", strofreal(pT->ncols))
	
	mata: pT->add_line(`"\multicolumn{`ncols'}{l}{`bold_start'Panel `panel': `text'`bold_end'} \\"')
end


cap prog drop table_add_midrule
prog table_add_midrule
	syntax, name(namelist max=1)

	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	mata: pT->add_line("\midrule")
	
end

cap prog drop table_from_data
prog table_from_data
	syntax varlist, [mat(namelist max=1)] name(namelist max=1)
	
	* Syntax
	********
	// Table is open
	cap assert ${`name'__tab_open}==1
	if _rc {
		di as error `"Table `name' not open"'
		exit 198
	}
	
	// Specify either varlist or mat (currently disabled)
	cap assert ("`varlist'"!="" | "`mat'"!="")
	if _rc {
		di as error "Must specify either varlist or mat"
	}
	cap assert !("`varlist'"=="" & "`mat'"=="")
	if _rc {
		di as error "Cannot specify both varlist and mat"
	}
	
	// Check varlist 
	if "`varlist'"!="" {
		loc n_vars : list sizeof varlist
		cap assert `n_vars' == ${`name'__tab_n_cols} 
		if _rc {
			di as error "Wrong number of variables. Received `n_vars' variables and the table has ${`name'__tab_n_cols} columns."
			exit 198
		}
		cap assert _N<100
		if _rc {
			di as error "Cannot create table with more than 100 rows"
			exit 198
		}
	}
	
	* Write panel
	*************
	forv n=1/`=_N' {
		loc n_var = 1
		foreach v of varlist `varlist' {
			loc val = `v'[`n']
			if `n_var'==1 	file write `name'__tab `"`val'"'
			else 			file write `name'__tab `" & `val'"'
			loc n_var = `n_var' + 1
		}
		file write `name'__tab " \\" _n
	}
end

cap prog drop __table_est_extract
prog __table_est_extract // Take ests stored in namelist, store in (new) frame __table_res, and label (if option `label')
	syntax namelist, name(namelist max=1) [label drop(string) keep(string) order(string)] // Pick out name and move to parent function
	
	//loc namelist = "reg1 reg2 reg4"
	//loc name = "test" 
	
	loc label = "`label'"!=""
	
	* Syntax
	********
	// Table is open
	cap assert ${`name'__tab_open}==1
	if _rc {
		di as error `"Table `name' not open"'
		exit 198
	}
	
	// Correct number of results/columns
	loc n_res : list sizeof namelist
	cap assert `n_res' + 1 == ${`name'__tab_n_cols} // column for varnames
	if _rc {
		di as error "Wrong number of estimation results. Received `n_res', expected `=${`name'__tab_n_cols}-1' (${`name'__tab_n_cols} minus one column for the varlist)"
		exit 198
	}
	
	// Check that all ests exists
	qui estimates dir
	loc stored_ests = "`r(names)'"

	foreach est of local namelist {
		loc exists = 0
		foreach stored_est of local stored_ests {
			if "`est'"=="`stored_est'" loc exists = 1
		}
		cap assert `exists'
		if _rc {
			di as error "Estimation result `est' does not exist"
			exit 198
		}
	}
	
	cap frame drop __table_res
	frame create __table_res
	frame __table_res: qui g varlist = ""
	global table_current = 1
	global table_varlist_all = ""
	
	//loc namelist = "reg1 reg2"
	foreach est of local namelist {
		__table_est_frame, est(`est')
	}
	frame __table_res: qui replace varlist = subinstr(varlist, "c.", " ", .)
	
	if `"`drop'"'!="" {
		foreach token of local drop {
			frame __table_res: qui drop if strmatch(varlist, `"`token'"')
			// Flag: Check if anything is dropped by first creating a dropped variable, counting, asserting, and then continue. 
		}
	}
	if `"`keep'"'!="" {
		frame __table_res: qui g keep = 0
		loc keep = "ujive_*"
		foreach token of local keep {
			frame __table_res: qui replace keep = 1 if strmatch(varlist, `"`token'"')
		}
		frame __table_res: qui keep if keep
		frame __table_res: drop keep
	}
	
	if `"`order'"'!="" {
		frame __table_res: qui g order = .
		frame __table_res: qui g init_order = _n
		loc current_order = 1
		foreach token of local order {
			frame __table_res: qui replace order = `current_order' if strmatch(varlist, `"`token'"')
			loc current_order = `current_order' + 1
		}
		frame __table_res: sort order init_order
	}
	
	
	if `label' {	
		foreach v of global table_varlist_all {
			cap loc lab : variable label `v'
			if _rc 	  loc lab = ""
			if "`lab'"!="" frame __table_res: qui replace varlist = subinstr(varlist, "`v'", "`lab'", .)
		}
		frame __table_res: qui replace varlist = subinstr(varlist, "_cons", "Constant", .)
	}
	frame __table_res: qui replace varlist = subinstr(varlist, "#", " \#", .) // I imagine this should be outside of the if `label' branch?
	frame __table_res: qui replace varlist = subinstr(varlist, "_", "\_", .) // I imagine this should be outside of the if `label' branch?
end

cap prog drop __table_est_table
prog __table_est_table
	syntax, name(string) n_cols(integer) b(string) se(string)
	// Reads params from frame and writes to table. 
	
	mata: pT = statex.get_table("`name'")
	
	frame __table_res: loc n_vars = _N
	
	forv row_i = 1/`n_vars' {
		frame __table_res: loc var = varlist[`row_i']
		mata: pT->add_line(`"`var'"')
		
		// beta/stars
		forv col_i = 1/`n_cols' {			
			frame __table_res: loc __b = b`col_i'[`row_i']
			loc __b = strofreal(`__b', "`b'")
			frame __table_res: loc __p = p`col_i'[`row_i']
			if 		`__p'<${`name'__3stars} loc __stars = `"\sym{***}"'
			else if `__p'<${`name'__2stars} loc __stars = `"\sym{**}"'
			else if `__p'<${`name'__1stars} loc __stars = `"\sym{*}"'
			else loc __stars = ""
			
			if `__b'!=.		mata pT->append_to_line(`" & `__b'`__stars'"')
			else			mata pT->append_to_line(`" & "'
		}
		file write `name'__tab " \\" _n
		
		// se
		forv col_i = 1/`n_cols' {			
			frame __table_res: loc __se = se`col_i'[`row_i']
			loc __se = strofreal(`__se', "`se'")
			frame __table_res: loc __p = p`col_i'[`row_i']
			
			if `__se'!=. 	file write `name'__tab `" & (`__se')"'
			else 			file write `name'__tab `" & "'
		}
		file write `name'__tab " \\" _n
		if `row_i'!=`n_vars' file write `name'__tab " [1em]" _n
	}
	
end

cap prog drop tmp 
prog tmp 
	syntax namelist

	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	
	loc n_res : list sizeof namelist
	
	
	di "`n_cols'"
end

tmp reg1


cap prog drop table_add_est
prog table_add_est
	syntax namelist, name(namelist max=1) label b(passthru) se(passthru) [stat(string) nostats absorbed(string asis) drop(passthru) keep(passthru) order(passthru) shortmidrule]	
	* Syntax
	********
	// Table is open
	if "`name'"=="" mata: _ = statex.get_current()
	mata: pT = statex.get_table("`name'")
	
	if "`shortmidrule'"!="" {
		cap assert "`nostats'"==""
		if _rc {
			di as error "Cannot specify both options 'shortmidrule' and 'nostats'."
			exit 198
		}
	}
	
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
		di as error "Number of estimation results provided (`nres') not the same as the number expected (`=`ncols'-1)"
		di as error "Expects one less estimation result than the number of columns in table (the first is reserve variable names)."
		exit 198
	}
	
	// FLAG: Check that user did not provide both keep and order?
	
	* Write table
	*************
	
	// Move est. to frame
	
	__table_est_extract `namelist',  `label' name(`name') `drop' `keep' `order'
	
	// export to latex file. 
	loc n_cols : list sizeof namelist
	__table_est_table, n_cols(`n_cols') name(`name') `b' `se'
	
	// Flag: Should look for these variables in `absorb' (or wherever they are stored), as well as the usual varlists. 
	if `"`absorbed'"'!="" {
		foreach abs of local absorbed {
			loc abs = subinstr(`"`abs'"', "#", `"\#"', .)
			file write `name'__tab "`abs'" // Write FE text
			
			// Write checkmarks
			loc param_cols = ${`name'__tab_n_cols} - 1 
			forv n = 1/`param_cols' {
				file write `name'__tab `" & \checkmark"' 
			}
			file write `name'__tab " \\" _n
		}
	}
	
	if "`nostats'"=="" {
		if "`shortmidrule'"=="" table_add_midrule, name(`name')
		else	file write `name'__tab `"\cmidrule(lr){2-${`name'__tab_n_cols}} "'
		// Pars stats options by splitting at first comma (if it exists)
		// i.e. stats(a b c, fmt(%9.0fc)) -> stats_main_opt = "a b c" & stats_other_opt = "fmt(%9.0fc)"
		//if `"`stat'"'=="" loc stat = ""
		loc comma_pos = strpos(`"`stat'"', ",")
		if `comma_pos' {
			loc stat_main_opt = substr(`"`stat'"', 1, `comma_pos'-1)
			loc stat_other_opt = substr(`"`stat'"', `comma_pos'+1, .)
		}
		else loc stat_main_opt = `"`stat'"'
		table_add_est_stats `namelist', name(`name') stats(`stat_main_opt') `stat_other_opt'
	}
end

cap prog drop table_add_est_stats
program table_add_est_stats
	syntax namelist, name(namelist max=1) [stats(namelist) format(string) labels(string)]
	// Add regression statistics (N observations etc.)
	
	* Syntax
	********
	// Table is open
	cap assert ${`name'__tab_open}==1
	if _rc {
		di as error `"Table `name' not open"'
		exit 198
	}
	
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
	
	foreach stat_name of local stats {
		// Label stats
		loc stat_label = ""
		loc stat_label_written = 0
		gettoken stat_label labels : labels  // Use user provided label if provided
		if "`stat_label'"!="" {
			file write `name'__tab "`stat_label'"
			loc stat_label_written = 1
		}
		if !`stat_label_written' & `"`stat_name'"'=="N" {
			file write `name'__tab "Observations"
			loc stat_label_written = 1
		}
		if !`stat_label_written' & `"`stat_name'"'=="r2"	{
			file write `name'__tab "\$R^2\$"
			loc stat_label_written = 1
		}
		if !`stat_label_written' file write `name'__tab `"`stat_name'"'
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
			file write `name'__tab " & `stat'"
		} 
		
		file write `name'__tab " \\" _n
	}
end

//table_add_est_stats reg1 reg2 reg3, name(regtable) //format("%12.0fc" "%4.3fc") //stats(N r2 Q) 

cap prog drop __table_est_frame
prog __table_est_frame // Take est and place in (i.e. add to) frame
	syntax, /*to(string)*/ est(string) 
	
	//loc est = "reg1"
	
	frame __table_res {
		qui g double b${table_current} = .
		qui g double se${table_current} = .
		qui g double t${table_current} = .
		qui g double p${table_current} = .
	}
	
	qui estimates restore `est'
	mat b = e(b)
	mat V = e(V)
	
	loc varnames : colnames b
	
	cap mat drop `to'
	loc n = colsof(b)
	forv i = 1/`n' {
	//loc i = 1
		loc varname : word `i' of `varnames'
		loc clean_varname = subinstr("`varname'", "c.", " ", .)
		loc clean_varname = subinstr("`clean_varname'", "#", " ",.)
		global table_varlist_all = `"${table_varlist_all} `clean_varname'"'
		loc b = b[1,`i']
		loc se = sqrt(V[`i', `i'])
		loc t = `b'/`se'
		loc p = 2 * ttail(e(df_r), abs(`t'))
		
		frame __table_res {
			if substr("`varname'",1,2)!="o."{ //loc varname = substr("`varname'",3,.)
				qui count if varlist == "`varname'"
				if r(N)==0 {
					qui set obs `=_N+1'
					qui replace varlist = "`varname'" if _n==_N
				}
				qui replace b${table_current}  = `b'  if varlist=="`varname'"
				qui replace se${table_current} = `se' if varlist=="`varname'"
				qui replace t${table_current}  = `t'  if varlist=="`varname'"
				qui replace p${table_current}  = `p'  if varlist=="`varname'"
			}
		}
	}
	
	global table_current = ${table_current} + 1
	global table_varlist_all : list clean global(table_varlist_all)
	global table_varlist_all : list uniq global(table_varlist_all)	
end

cap prog drop table_indicate 
prog table_indicate
end

cap prog drop __table_add_footer
prog __table_add_footer
	syntax, name(namelist max=1) [paren stars robust]
	
	* Syntax
	********
	// Table is open
	cap assert ${`name'__tab_open}==1
	if _rc {
		di as error `"Table `name' not open"'
		exit 198
	}
	
	cap assert `"`paren'`stars'"'!="" 
	if _rc {
		di as error "Specify either option 'paren' or option 'stars'"
		exit 198
	}
	if "`robust'"!="" {
		assert "`paren'"!=""
		if _rc {
			di as error "Cannot specify option 'robust' without specifying option 'paren'"
			exit 198
		}
	}
	
	* Add Footer
	************
	
	if "`paren'"!="" { // Robust currently unused
		if "${`name'__paren}"=="se"		loc in_paren = "Standard errors"
		if "${`name'__paren}"=="t"		loc in_paren = "t statistics"
		if "${`name'__paren}"=="p"		loc in_paren = "p-values"
		
		file write `name'__tab `"\multicolumn{${`name'__tab_n_cols}}{l}{\footnotesize `in_paren' in parentheses} \\"' _n
	}
	if "`stars'"!="" {
		// Format numbers
		forv n = 1/3 {
			loc `n'stars = string(${`name'__`n'stars}, "%9.0g")
			if substr("``n'stars'", 1, 1) == "." loc `n'stars = "0``n'stars'"
		}
		
		file write `name'__tab `"\multicolumn{${`name'__tab_n_cols}}{l}{\footnotesize \sym{*} \(p<`1stars'\), \sym{**} \(p<`2stars'\), \sym{***} \(p<`3stars'\)} \\"' _n
	}
	if `"`custom'"'!="" {
		file write `name'__tab `"\multicolumn{${`name'__tab_n_cols}}{l}{`custom'} \\"' _n
	}
end

cap prog drop table_close
prog table_close
	syntax, name(namelist max=1) [paren stars robust]
	
	* Syntax
	********
	// Table is open
	cap assert ${`name'__tab_open}==1
	if _rc {
		di as error `"Table `name' not open"'
		exit 198
	}
	
	/*
	if "`notextprocessing'"=="" {
		loc text = subinstr(`"`text'"', `"#"', `"\#"', .)
		loc text = subinstr(`"`text'"', `"_"', `"\_"', .)
		loc text = subinstr(`"`text'"', ">", `"\textgreater"', .)
		loc text = subinstr(`"`text'"', "<", `"\textless"', .)
	}
	*/
	
	file write `name'__tab `"\hline\midrule"' _n
	if "`paren'`stars'"!="" __table_add_footer, name(`name') `paren' `stars' `robust'
	file write `name'__tab `"\end{tabular}"' _n
	file write `name'__tab `"}"' _n
	cap file close `name'__tab
	global `name'__tab_open = 0
end


