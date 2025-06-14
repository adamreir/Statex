mata: mata clear
do "C:/Users/`=c(username)'/Documents/GitHub/statex/statex.mata"
do "C:/Users/`=c(username)'/Documents/GitHub/statex/make_latex_table.do"

statex_new, n_cols(7) file("a file")
statex_list


mata: Tptr = statex.get_table("Table1")
mata: Tptr->li()
mata: class Table scalar T
mata: T = (*Tptr)

statex_list