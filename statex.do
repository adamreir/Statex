cap prog drop statex
prog statex
	version 16
	
	gettoken subcmd 0 : 0, parse(" ,")
	local subcmd = trim("`subcmd'")
	
	di "subcmd: |`subcmd'|"
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
end