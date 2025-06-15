
// Error codes https://www.stata.com/manuals/perror.pdf#perror
****************
* Table object *
****************

mata: mata clear
mata 
class Table {
	string vector content // Private?
	string scalar name
	string scalar stars
	string scalar paren
	real scalar panel_counter
	real scalar ncols
	real scalar cell_width
	real scalar is_closed
	void init()
	void li()
	void add_line() 
	void panel()
}

void Table::init(string scalar _name, real scalar _ncols, string scalar _stars, string scalar _paren, real scalar _cell_width) {
	content = J(0, 1, "")
	name = _name
	//filename = _filename
	ncols = _ncols
	stars= _stars
	paren = _paren
	cell_width = _cell_width
	panel_counter = 65
	is_closed = 0
}

void Table::li() {
	real scalar i
	for (i = 1; i <= rows(content); i++) {
		printf(content[i] + "\n")
	}
}

void Table::add_line(string scalar line) {
	printf(line)
	content = content \ line
}

void Table::panel() {
	real scalar current
	string scalar panel
	
	current = panel_counter
	panel = ""
	panel_counter++
	panel_counter
	
	while (current>90) {
		panel = panel + "A"
		current = current - 26
	}
	
	st_local("panel", panel + char(current))
}
end


**************************
* Global Statex Class Def*
**************************

cap mata: mata drop statex
cap mata: mata drop Statex()
mata: 
class Statex {
	// Data
	string scalar current //private
	real scalar auto_counter //private
	pointer(class Table) vector tables //private
	
	void init() //public
	
	// Add delete etc.
	pointer scalar add_table() //public
	
	// Table management
	void dir() //public
	void confirm_noexist() //private?
	void confirm_name_exists() //public
	pointer scalar get_table() //public
	
	// Current table etc. 
	string scalar get_current() //public
	void set_current() //public
	void get_auto_newname() //public -> place result in local and increment
}

void Statex::init() {
	current = ""
	auto_counter = 1
	tables = J(0,1,NULL)
}

pointer scalar Statex::add_table(string scalar name, real scalar ncols, string scalar stars, string scalar paren, cell_width) { // Add Tables
	class Table scalar T
	confirm_noexist(name)
	
	T = Table()
	T.init(name, ncols, stars, paren, cell_width)
	tables = tables \ &T
	current = name
	
	return(&T)
}

// Look for names
void Statex::confirm_noexist(string scalar _name) {
	real scalar i
	class Table scalar T
	for (i=1; i<=rows(tables); i++) {
		T = (*tables[i])
		if (_name == T.name) {
			_error(110, "table '" + _name + "' already exists") // already defined
		}
	}
}

void Statex::confirm_name_exists(string scalar _name) {
	real scalar i
	class Table scalar T
	for (i=1; i<=rows(tables); i++) {
		T = (*tables[i])
		if (_name == T.name) {
			return
		}
	}
	_error(111, "table '" + _name + "' not found") // not found
}

pointer scalar Statex::get_table(string scalar name) {
	pointer(class Table) scalar pT
	real scalar i
	for (i=1; i<=rows(tables); i++) {
		pT = tables[i]
		if (name == pT->name) {
			return(pT)
		}
	}
	_error(111, "table '" + name + "' not found") // not found
}

// Current table etc. 
string scalar Statex::get_current() {
	if (current=="") {
		_error(111, "No table set")
		return("")
	}
	st_local("name", current)
	return(current)
}

void Statex::set_current(string scalar _name) {
	confirm_name_exists(_name)
	current = _name
}


void Statex::dir() { // Dir
	real scalar i
	class Table scalar T
	for (i=1; i<=rows(tables); i++) {
		T = (*tables[i])
		if (T.name==current) 	printf("*" + T.name + " (%f columns);" + "\n", T.ncols)
		else				printf(T.name + " (%f columns);" +"\n", T.ncols)
	}
}

void Statex::get_auto_newname() {
	st_local("name", "Table" + strofreal(auto_counter))
	auto_counter++
}

end

mata: statex = Statex()
mata: statex.init()

/*
// Try
mata: statex = Statex()
mata: statex.init()
cap prog drop tmp
mata: T1 = statex.add_table("name1", "filen1", 5, ".05 .01 .001", "se", 10)
mata: T1.add_line("a line")
mata: T1.add_line("another line")
mata: T2 = statex.add_table("name2", "filen2", 3, ".05 .01 .001", "se", 10)
mata: statex.get_current()
mata: statex.set_current("name1")

mata: statex.confirm_name_exists("name1")


mata: T1.li()

mata: statex.tables
mata: statex.dir()




