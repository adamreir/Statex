mata: mata clear
do "C:/Users/`=c(username)'/Documents/GitHub/statex/statex.mata"
do "C:/Users/`=c(username)'/Documents/GitHub/statex/make_latex_table.do"


statex_new, n_cols(7)
statex_panel, text("some text")
statex_panel, text("some text")

statex_list
statex_dir

mata: pT = statex.get_table("Table1")
mata: st_local("ncols", strofreal(pT->ncols))
di "`ncols'"
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