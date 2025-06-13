
// Error codes https://www.stata.com/manuals/perror.pdf#perror
****************
* Table object *
****************

cap mata: mata drop __TableInfo()
/*
cap mata: mata drop __TableInfo_init()

mata: 

// Object to hold information about named tables
struct __TableInfo {
	string scalar name
	string scalar filename
	real scalar ncols
}

// __TableInfo constructor
struct __TableInfo scalar __TableInfo_init(string scalar name, string scalar filename, real scalar ncols) {
	struct __TableInfo scalar tableinfo
	
	tableinfo.name = name
	tableinfo.filename = filename
	tableinfo.ncols = ncols
	
	return(tableinfo)
}
end
*/
cap mata: mata drop T
cap mata: mata drop __TableInfo()
mata 
class __TableInfo {
	string scalar name
	string scalar filename
	string scalar stars
	string scalar paren
	real scalar status
	real scalar panel
	real scalar ncols
	void init()
}

void __TableInfo::init(string scalar _name, string scalar _filename, real scalar _ncols, string scalar _stars, string scalar _paren) {
	name = _name
	filename = _filename
	ncols = _ncols
	stars= _stars
	paren = _paren
	status = 1
}

end


**************************
* Global Statex Class Def*
**************************

cap mata: mata drop __statex
cap mata: mata drop __Statex()
mata: 
class __Statex {
	string scalar current //private
	real scalar auto_counter
	//string vector names
	pointer vector tables //private
	
	void init() //public
	void add_table() //public
	void dir() //public
	void confirm_noexist() //private?
	void confirm_name_exists() //public
	string scalar get_current() //public
	void set_current() //public
}

void __Statex::init() {	 // constructor
	current = ""
	auto_counter = 0
	tables = J(0,1,NULL)
}

void __Statex::add_table(string scalar name, string scalar filename, real scalar ncols, string scalar stars, string scalar paren) { // Add Tables
	class __TableInfo scalar T
	confirm_noexist(name)
	
	T = __TableInfo()
	T.init(name, filename, ncols, stars, paren)
	tables = tables \ &T
	current = name
	
	//auto_counter = auto_counter + 1
}

// Look for names
void __Statex::confirm_noexist(string scalar _name) {
	real scalar i
	class __TableInfo scalar T
	for (i=1; i<=rows(tables); i++) {
		T = (*tables[i])
		if (_name == T.name) {
			_error(110, "table '" + _name + "' already exists") // already defined
		}
	}
}

void __Statex::confirm_name_exists(string scalar _name) {
	real scalar i
	class __TableInfo scalar T
	for (i=1; i<=rows(tables); i++) {
		T = (*tables[i])
		if (_name == T.name) {
			return
		}
	}
	_error(111, "table '" + _name + "' not found") // not found
}

string scalar __Statex::get_current() {
	if (current=="") {
		_error(111, "No table set")
		return("")
	}
	return(current)
}

void __Statex::set_current(string scalar _name) {
	confirm_name_exists(_name)
	current = _name
}


void __Statex::dir() { // Dir
	real scalar i
	class __TableInfo scalar T
	for (i=1; i<=rows(tables); i++) {
		T = (*tables[i])
		if (T.name==current) 	printf("*" + T.name + " (%f columns); @" + T.filename +"\n", T.ncols)
		else				printf(T.name + " (%f columns); @" + T.filename +"\n", T.ncols)
	}
}

end

mata: __statex = __Statex()
mata: __statex.init()
cap prog drop tmp
mata: __statex.add_table("name1", "filen1", 5, ".05 .01 .001", "se")
mata: __statex.add_table("name2", "filen2", 3, ".05 .01 .001", "se")
mata: __statex.get_current()
mata: __statex.set_current("name1")

mata: __statex.confirm_name_exists("name1")


mata: __statex.tables
mata: __statex.dir()




