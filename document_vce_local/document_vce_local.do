********************************************************************************
* Data generator
********************************************************************************

cap prog drop get_data1
prog get_data1
    qui {
        frame change default
        clear
        set obs 2000

        * core regressors/instruments
        gen double x1 = rnormal()
        gen double x2 = rnormal()
        gen double z  = x1 + rnormal()

        * cluster-ish groups
        gen int g1 = floor(runiform()*10)+1
        gen int g2 = floor(runiform()*10)+1
        gen int g3 = floor(runiform()*1000)+1
        gen int g4 = floor(runiform()*10)+1

        * id nested in g1 (string concat -> numeric)
        gen long id = mod(_n, 1000)+1

        * "time" (needed for some xt commands if you want panel time dimension)
        bys id: gen int t = _n
		
		/*
		bys id: g nested_cluster = floor(runiform()*10)+1 if _n==1
		by id: replace nested_cluster = nested_cluster[_n-1] if _n>1
		*/
		
		bys id: gen cluster1 = floor(runiform()*10)+1 if _n==1
		bys id: replace cluster1 = cluster1[1]
		
		bys id: gen cluster2 = floor(runiform()*10)+1 if _n==1
		bys id: replace cluster2 = cluster2[1]
		
		bys id: gen cluster3 = floor(runiform()*10)+1 if _n==1
		bys id: replace cluster3 = cluster3[1]
		
        * latent index and outcomes
        gen double u = rnormal()
        gen double y_cont = 1 + 0.8*x1 - 0.4*x2 + 0.2*g1 + 0.1*g2 + 0.1*g3 + 0.1*g4 + u

        * binary outcome (depends on index)
        qui sum y_cont
        gen byte y_bin = (y_cont > r(mean))

        * count outcome (positive mean)
        gen double mu = exp(0.2 + 0.3*x1 - 0.2*x2 + 0.05*g1)
        gen long y_cnt = rpoisson(mu)

        * ordered outcome 1..4
        gen byte y_ord = 1 + (y_cont > 0) + (y_cont > 1) + (y_cont > 2)

        * multinomial outcome 1..3 (not "correct", just usable)
        gen double p1 = invlogit( 0.3 + 0.4*x1 - 0.2*x2)
        gen double p2 = invlogit(-0.1 - 0.1*x1 + 0.3*x2)
        gen double r  = runiform()
        gen byte y_mn = .
        replace y_mn = 1 if r < 0.33
        replace y_mn = 2 if r >= 0.33 & r < 0.66
        replace y_mn = 3 if r >= 0.66
        drop r

        * tobit-friendly: censor at 0
        gen double y_tob = y_cont
        replace y_tob = 0 if y_tob < 0

        * heckman-friendly: selection + missing when not selected
        gen byte sel = (0.2 + 0.3*x1 - 0.2*x2 + rnormal() > 0)
        gen double y_sel = y_cont
        replace y_sel = . if sel==0

        * clogit-friendly: group with within-group variation
        * (clogit needs a group identifier; g1 works; ensure some variation)
        gen byte y_cl = y_bin

        * panel settings
        xtset id t

        * survival settings (stcox needs stset)
        gen double stime = runiform()*10 + 0.01
        gen byte   fail  = y_bin
        stset stime, failure(fail)
    }
end

********************************************************************************
* Prepare frames
********************************************************************************

cap frame drop vce
frame create vce
frame vce {
    g command     = ""
    g vce_opt     = ""

	g has_eb = .
	g has_eV = .
	
    g vce     = ""
    g vcetype = ""
    g clustvar = ""
	g N_clust1 = .
	g N_clust2 = .
	g N_clust3 = .
	g N_clustervars = .
	g N_clust = .
	
    g clustvar1 = ""
    g clustvar2 = ""
	g clustvar3 = ""
}

********************************************************************************
* Store e() locals of interest
********************************************************************************


cap prog drop store_se
prog store_se
    syntax, [vce(passthru)]
	qui {
    frame vce {
        qui count if command == e(cmd) & vce == "`vce'"
        if r(N)==0 {
            qui set obs `=_N+1'
            qui replace command = e(cmd)   if _n==_N
            qui replace vce_opt     = "`vce'"  if _n==_N
        }
		
		// e(b), e(V)
		cap 
		mat list e(b)
		if !_rc replace has_eb = 1 if command == e(cmd) & vce_opt=="`vce'"
		else    replace has_eb = 0 if command == e(cmd) & vce_opt=="`vce'"
		
		cap mat list e(V)
		if !_rc replace has_eV = 1 if command == e(cmd) & vce_opt=="`vce'"
		else    replace has_eV = 0 if command == e(cmd) & vce_opt=="`vce'"
		
		// locals
        foreach loc in vce vcetype clustvar clustvar1 clustvar2 clustvar3 {
            cap local content = e(`loc')
            if _rc local content = ""
            if "`content'" == "." local content = ""
            qui replace `loc' = "`content'" if command == e(cmd) & vce_opt=="`vce'"
        }
		
		// scalars
		foreach scalar in N_clust1 N_clust2 N_clust3 N_clustervars N_clust {
			di e(`scalar')
            qui replace `scalar' = e(`scalar') if command == e(cmd) & vce_opt=="`vce'"
        }
    }
	}
end

********************************************************************************
* Runner: execute cmd; store if success 	
********************************************************************************

cap prog drop run_and_store
prog run_and_store
    syntax, CMD(string) [VCE(string)]

    * Run command (quietly but show errors if any)
	di `"`cmd'"'
    cap qui `cmd'
    if _rc==0 {
        * pass through the same vce() text to store_se
		store_se, `vce'
    }
end

********************************************************************************
* Regressions
********************************************************************************

get_data1

foreach vce in "" /// NO option
	vce(robust) vce(hc2) vce(hc3) /// HAC
	"vce(cluster cluster1)" "vce(cluster cluster1 cluster2)" "vce(cluster cluster1 cluster2 cluster3)"  /// cluster
	"vce(hac bartlett 3)" "vce(hac nwest 3)" "vce(hac gallant 3)" "vce(hac parzen 3)" "vce(hac qa 3)" "vce(hac an 3)" /// Autocorrelation
	vce(bootstrap) vce(jackknife) vce(jackknife1) ///Bootstrap
	vce(unbiased) /// ?
	vce(oim) vce(ols) vce(conventional) vce(opg) vce(eim)  /// ML based VCE
	 {
	
	// Some autocorrelation specific VCE calculations requires time series (i.e. no duplicates in t)
	if substr("`vce'", 1, 7)=="vce(hac" {
		replace t = _n
		tsset t
	}
	else xtset id t
	
    * Linear / FE / HDFE
    run_and_store, cmd(`"regress   y_cont x1 x2, `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"areg      y_cont x1 x2, absorb(g1) `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"xtreg     y_cont x1 x2, re `vce'"') vce(`"`vce'"')
	run_and_store, cmd(`"xtreg     y_cont x1 x2, fe `vce'"') vce(`"`vce'"')
	
    * Community HDFE 
	if !inlist("`vce'", "vce(bootstrap)", "vce(jacknife)") {
		run_and_store, cmd(`"reghdfe   y_cont x1 x2, absorb(g1 g2) `vce'"') vce(`"`vce'"')
	}

    * IV
    run_and_store, cmd(`"ivregress 2sls y_cont (x1 = z) x2, `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"ivregress gmm  y_cont (x1 = z) x2, `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"ivregress liml y_cont (x1 = z) x2, `vce'"') vce(`"`vce'"')
	run_and_store, cmd(`"ivreghdfe y_cont (x1 = z) x2, `vce' absorb(g1 g2)"') vce(`"`vce'"')
	
	
    * Binary response
    run_and_store, cmd(`"logit     y_bin x1 x2, `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"probit    y_bin x1 x2, `vce'"') vce(`"`vce'"')

    * Panel binary (may fail depending on separation / lack of within-id variation)
    run_and_store, cmd(`"xtlogit   y_bin x1 x2, re `vce'"') vce(`"`vce'"')
	run_and_store, cmd(`"xtlogit   y_bin x1 x2, fe `vce'"') vce(`"`vce'"')
	
    * Count models
    run_and_store, cmd(`"poisson   y_cnt x1 x2, `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"nbreg     y_cnt x1 x2, `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"glm       y_cnt x1 x2, family(poisson) link(log) `vce'"') vce(`"`vce'"')

    * Ordered / multinomial
    run_and_store, cmd(`"ologit    y_ord x1 x2, `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"oprobit   y_ord x1 x2, `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"mlogit    y_mn  x1 x2, baseoutcome(1) `vce'"') vce(`"`vce'"')
	
	/*
    * Conditional logit
    run_and_store, cmd(`"clogit    y_cl x1 x2, group(id) `vce'"') vce(`"`vce'"')
	*/
	
    * Censoring / selection
    run_and_store, cmd(`"tobit     y_tob x1 x2, ll(0) `vce'"') vce(`"`vce'"')
    run_and_store, cmd(`"heckman   y_sel x1 x2, select(sel = x1 x2) `vce'"') vce(`"`vce'"')

    * Survival
    run_and_store, cmd(`"stcox     x1 x2, `vce'"') vce(`"`vce'"')

    * If installed: ppmlhdfe (often used with clustering)
	run_and_store, cmd(`"ppmlhdfe  y_cnt x1 x2, absorb(g1 g2) `vce'"') vce(`"`vce'"') 
}

get_data1

frame vce: li, sepby(vce_opt)
frame vce: save "C:\Users\s16501\Documents\GitHub\Statex\document_vce_local\vce_local.dta", replace