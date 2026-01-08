
global statex   = "C:/Users/`=c(username)'/Documents/GitHub/Statex"
global overleaf = "C:/Users/s16501/Dropbox/Apps/Overleaf/statex"

mata: mata clear
discard
adopath + "${statex}"

//findfile statex.mata
//qui do "`r(fn)'"

do "C:/Users/`=c(username)'/Documents/GitHub/statex/statex.mata"
//do "C:/Users/`=c(username)'/Documents/GitHub/statex/statex.ado"



statex new, n_cols(3) paren("se")

clear
set obs 20000
g x1 = rnormal()
g x2 = rnormal()
g y = x1 + x2 + rnormal()
lab var y "Y"
g year = floor(runiform()*5+2000)
g id = floor(runiform()*5+1)

lab var x1 "X1"

//set trace on
set tracedepth 2

eststo est1: qui reghdfe y x1 x2 i.year i.id
estadd scalar M = 123
eststo est2: qui reghdfe y x1			, absorb(i.year i.id) 

//statex est_extract est1 est2, indicate("Xs=x?", indicators("yes" "no"))
//frame __table_res: li
//frame __table_indicate: li

//statex row, row("abc" "def") //blank //align(c c) multicolumn(1 1)



//set trace on 
set tracedepth 4

statex midrule
statex panel, text("A panel")
statex est est1 est2, label b(%3.2fc) indicate("Year FE=*year" "indiv FE=*.id") nogap
/*
statex midrule
statex panel, text("Another panel")
statex est est1 est2, label b(%3.2fc) indicate("Year FE=*year") //noindic //se(%3.2fc)
statex panel, text("Just Fixed Effects")
statex est est1 est2, indicate("Year FE=*year") noheader notable nostats
*/

statex close, robust


statex list

//mata: pT->write_table("C:\Users\s16501\Dropbox\Apps\Overleaf\statex\tables\test1.tex")


esttab est1 est2 using "${overleaf}/tables/esttab1.tex", replace indicate("Year FE=*.year" "Indiv FE=*.id", label("\checkbox" "")) stats(N M)
esttab est1 est2 using "${overleaf}/tables/esttab_nogap.tex", replace nogap  indicate("Year FE=*.year" "Indiv FE=*.id", label("\checkbox" "")) stats(N M)
statex_write, filename("${overleaf}/tables/test1.tex") replace

exit198
//mata: pT->write_table("C:\Users\s16501\Documents\GitHub\Statex\text_table3.tex")

mata
tables = statex.tables

keep = J(rows(tables), 1, 1)
for (i=1; i<=rows(tables); i++) {
	if (tables[i] == p) keep[i] = 0
}
keep

end

/*

mata 

	
	fh = _fopen("C:\Users\s16501\Documents\GitHub\Statex\test_file.txt", "w")

	_fput(fh, "abc")
	_fput(fh, "123")
	_fclose(fh)

end






statex_list




mata: st_local("used_stars", strofreal(pT->used_stars))
di "`used_stars'"
mata: st_local("stars", pT->stars)
di "`stars'"


mata: pT->used_stars

foreach loc in 1star 2star 3star {
	di "`loc':``loc''"
}


__table_est_extract est1 est2, label order(x2 x1) drop(_cons)  //[label drop(string) keep(string) order(string)]
frame __table_res: li






statex_new, n_cols(2)
mata: pT = statex.get_table("Table1")

statex_list
statex_row, row("aaaaaaaaaaaaaaaaaaaaaaaa" "c") //align(c c) multicolumn(1 1)
statex_row, row("c") blank //align(c c) multicolumn(1 1)
statex_list

statex_row, row("*DDDD" "b") align(c c) multicolumn(1 1)
statex_panel, text("some text")
statex_panel, text("some text")

mata: pT = statex.get_table("Table1")
mata: pT->content

statex_list
statex_dir

//set tracedepth 2
//set trace on

mata: pT = statex.get_table("Table1")
mata: pT->ncols = 2
mata: st_local("ncols", strofreal(pT->ncols))
di "`ncols'"
mata: st_local("cell_width", strofreal(pT->cell_width))
di "`cell_width'"
mata: statex.tables[1]
mata: pT->panel()
mata: pT->panel_counter
mata: pT->panel_counter = pT->panel_counter + 1
mata: pT->panel_counter


mata: statex.dir()

mata: Tptr = statex.get_table("Table1")
mata: Tptr->li()
mata: class Table scalar T
mata: T = (*Tptr)

statex_list