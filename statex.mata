
// Error codes: https://www.stata.com/manuals/perror.pdf#perror
****************
* Table object *
****************

//mata: mata clear
mata 
class Table {
	string vector content // Private?
	string scalar name
	string scalar stars
	string scalar paren
	
	// Keep track of paren/SE usage
	real scalar used_stars
	real scalar used_paren
	real scalar used_conventional_se
	real scalar used_robust_se
	real scalar used_clustered_se
	string scalar cluster_var
	
	// State
	real scalar panel_counter
	real scalar ncols
	real scalar cell_width
	real scalar cell_overflow
	real scalar is_closed
	real scalar ci_level
	real scalar has_preamble
	
	void init()
	void li()
	void add_line() 
	void append_to_line()
	void panel()
	void check_ncols()
	real scalar write_table()
	string scalar pad_string()
}

void Table::init(string scalar _name, string scalar _stars, string scalar _paren, real scalar _cell_width, real scalar _ci_level) {
	content = J(0, 1, "")
	name = _name
	stars= _stars
	paren = _paren
	
	used_stars = 0
	used_paren = 0
	used_conventional_se = 0
	used_robust_se = 0
	used_clustered_se = 0
	cluster_var = ""
	
	panel_counter = 65
	ncols = -1 // -1: not set yet. Set whenever first needed
	cell_width = _cell_width
	cell_overflow = 0
	is_closed = 0
	ci_level = _ci_level
}

void Table::li() {
	real scalar i
	for (i = 1; i <= rows(content); i++) {
		sprintf("%s", content[i,1])
	}
}

void Table::add_line(string scalar line) {
	content = content \ line
	cell_overflow = 0
}

void Table::append_to_line(string scalar line, real scalar pad, string scalar lcr) { // lcr:alignment ("left", "center", or "right")
	if (pad==1) {
		line = pad_string(line, lcr)
	}
	content[rows(content),] = content[rows(content),] + line
}

// Keeps track of Panel index (A, B, ...). Sets `panel' to A, B, C etc. when called. 
void Table::panel() {
	real scalar current
	string scalar panel
	
	current = panel_counter
	panel = ""
	panel_counter++
	
	while (current>90) {
		panel = panel + "A"
		current = current - 26
	}
	
	st_local("panel", panel + char(current))
}

// Takes the cell content (string), and pads content to have length cell_width. 
// Keeps track of overflow on it's own (as long as the local `overflow' is not erased)
string scalar Table::pad_string(string scalar content, string scalar lcr) {
	real scalar overflow
	real scalar left
	real scalar right
	real scalar n
    string scalar padded
	real scalar current_width
	
	n = strlen(content) 
	current_width = cell_width - cell_overflow

    if (n >= current_width) {
		cell_overflow = n - current_width
        return(content)  // truncate if too long
    }
	cell_overflow = 0
    
    if (lcr=="left")   left = 0 // Left orient: no padding to the left
	if (lcr=="center") left = floor((current_width - n) / 2) // Center: split
    if (lcr=="right")  left = (current_width - n) // Right: All
	right = current_width - n - left
    
    padded = "" // empty string
    padded =  " "*left + content + " "*right
    
    return(padded)
}

real scalar Table::write_table(string scalar filename) {
	
	fh = _fopen(filename, "w")
	if (fh < 0) {
        return(0)
    }
	for (i = 1; i <= rows(content); i++) {
		rc = _fput(fh, content[i, 1])
		  if (rc < 0) {
            // Try to close anyway
            _fclose(fh)
            return(0)
        }
	}
	rc = _fclose(fh)
	if (rc < 0) {
        return(0)
    }
	
	return(1)
}

void Table::check_ncols(real scalar _ncols ,string scalar error_msg) {
	if (ncols==-1) ncols = _ncols
    else if (ncols != _ncols) {
		errprintf("    " + error_msg + " You are trying to write " + strofreal(_ncols) + " columns, but previously wrote " + strofreal(ncols) + " columns.\n")
		_error(3200)
	}
}
end





**************************
* Global Statex Class Def*
**************************

//cap mata: mata drop statex
cap mata: mata drop Statex()
mata: 
class Statex {
	// Data
	string scalar current
	real scalar auto_counter
	pointer(class Table) vector tables
	
	void init() //public
	
	// Add delete etc.
	pointer scalar new_table()
	void drop_table()
	void drop_all()
	
	// Table management
	void dir()
	void confirm_noexist() 
	void confirm_name_exists()
	pointer scalar get_table()
	
	// Current table etc. 
	string scalar get_current()
	void set_current()
	void get_auto_newname()
}

void Statex::init() {
	current = ""
	auto_counter = 1
	tables = J(0,1,NULL)
}

pointer scalar Statex::new_table(string scalar name, string scalar stars, string scalar paren, real scalar cell_width, real scalar ci_level) { // Add Tables
	class Table scalar T
	confirm_noexist(name)
	
	T = Table()
	T.init(name, stars, paren, cell_width, ci_level)
	tables = tables \ &T
	current = name
	
	return(&T)
}

void Statex::drop_table(pointer(real) scalar pT) {
	real colvector keep 
	real scalar i
	class Table scalar T
	
	// Remove
	keep = J(rows(tables), 1, 1)
	for (i=1; i<=rows(tables); i++) {
        if (tables[i] == pT) keep[i] = 0
    }
	
	tables = select(tables, keep)
	if (rows(tables)==0) {
		tables = J(0,1,NULL)
	}
	
	// Check if the current table was dropped (and set no current if true)
	if (current=="") {
		return
	}
	for (i=1; i<=rows(tables); i++) {
		T = (*tables[i])
		if (current == T.name) {
			return
		}
	}
	current = ""
	return
}

void Statex::drop_all() {
	real scalar i
	pointer(real) scalar pT
	
	// Replace with NULL pointers and replace pointer vector with an empty vector
	for (i=1; i<=rows(tables); i++) {
		tables[i,1] = NULL
	}
	tables = J(0,1,NULL)
	
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
		_error(111, "No current table set. Run 'help statex_manage' for more information.")
		return("")
	}
	return(current)
}

void Statex::set_current(string scalar _name) {
	confirm_name_exists(_name)
	current = _name
}


void Statex::dir() { // Dir
	real scalar i
	class Table scalar T
	if (rows(tables)>0) {
		for (i=1; i<=rows(tables); i++) {
			T = (*tables[i])
			if (T.name==current) 	printf("*" + T.name + " (%f columns);" + "\n", T.ncols)
			else				printf(T.name + " (%f columns);" +"\n", T.ncols)
		}
		printf("\nNote: The table marked with * is the currently selected table. This will be used whenever no table name is provided using the ', name()' option.\n")
	}
	else {
		printf("\Statex does not currently have tables in memory.\n")
	}
}

void Statex::get_auto_newname() {
	st_local("name", "Table" + strofreal(auto_counter))
	auto_counter++
}

end

mata: statex = Statex()
mata: statex.init()

