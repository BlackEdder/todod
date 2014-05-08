/*
	 -------------------------------------------------------------------

	 Copyright (C) 2014, Edwin van Leeuwen

	 This file is part of todod todo list manager.

	 Todod is free software; you can redistribute it and/or modify
	 it under the terms of the GNU General Public License as published by
	 the Free Software Foundation; either version 3 of the License, or
	 (at your option) any later version.

	 Todod is distributed in the hope that it will be useful,
	 but WITHOUT ANY WARRANTY; without even the implied warranty of
	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	 GNU General Public License for more details.

	 You should have received a copy of the GNU General Public License
	 along with Todod. If not, see <http://www.gnu.org/licenses/>.

	 -------------------------------------------------------------------
	 */

module todod.commandline;

import std.algorithm;
import std.string;

/// Manage command line arguments
struct Commands(COMMAND) {
	alias string[] delegate( string ) Completion;

	@disable this();

	/// Create commands using the introduction when printing help
	this( string introduction ) {
		myintroduction = introduction;
		myDefaultCompletion = delegate ( string parameter ) { 
			string[] emptyResult = [];
			return emptyResult; };
	}

	///
	unittest {
		auto cmds = Commands!( string delegate( string ) )( "Usage: myprogram [OPTION]" );

		cmds.add( "world", delegate( string parameter ) { return parameter ~ " world"; }, 
				"Append world to the given parameter" );
		cmds.add( "help", delegate( string parameter ) { cmds.toString; return parameter; }, 
				"Print this help message." );
		assert( cmds["world"]( "Hello" ) == "Hello world" );
		assert( equal( ["world", "help"], cmds.commands() ) );
	}

	/// Add a new command given de name, the action to perform and a description
	void add( string command, COMMAND action, string description ) {
		addition_order ~= command;
		mycommands[command] = action;
		myhelp[command] = description;
	}

	/// Create help message
	string toString() {
		string description = myintroduction ~ "\n";
		foreach( comm; addition_order ) {
			description ~= "    \033[1;31m" ~ comm.leftJustify( 15 ) ~ "\033[0m " 
				~ myhelp[comm] ~ "\n\n";
		}
		return description;
	}

	COMMAND opIndex(string command) {
		return mycommands[command];
	}

	/// Return an array with all possible commands
	string[] commands() {
		return mycommands.keys;
	}

	/// Is this command provided?
	bool exists( const string cmd ) {
		if (cmd in mycommands)
			return true;
		else
			return false;
	}

	/// Add completion option for this specific command
	void addCompletion( const string cmd, Completion completion ) {
		completions[cmd] = completion;
	}

	/// Set default completion function
	void defaultCompletion( Completion completion ) {
		myDefaultCompletion = completion;
	}

	/// Return completion options
	string[] completionOptions( const string cmd, const string parameter ) {
		if ( cmd in completions )
			return completions[cmd]( parameter );
		return myDefaultCompletion( parameter );
	}
	
	private:
		string[] addition_order;

		string myintroduction;
		COMMAND[string] mycommands;
		string[string] myhelp;
		Completion[string] completions;
		Completion myDefaultCompletion;
}

unittest {
	auto cmd = Commands!int( "Intro" );
	cmd.add( "cmd1", 1, "help1" );
	cmd.add( "cmd2", 2, "help2" );
	assert( cmd["cmd1"] == 1 );
	assert( cmd["cmd2"] == 2 );
}

unittest {
	import std.stdio;
	auto cmd = Commands!int( "" );
	assert( cmd.myDefaultCompletion( "" ).length == 0 );
}
