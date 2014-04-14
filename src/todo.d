import std.stdio;

import std.path;

import std.string;
import std.regex;

import std.conv;
import std.algorithm;

import core.stdc.string, core.stdc.stdlib, std.stdio;
import deimos.linenoise;

import todod.todo;
import todod.shell;

Todos ts; // Defined global to give C access to it in tab completion

extern(C) void completion(const char *buf, linenoiseCompletions *lc) {
	string[] commands = ["add", "del", "quit", "search", "tag", "show"];
	auto regex_buf = "^" ~ to!string( buf );
	auto matching_commands = filter!( a => match( a, regex_buf ))( commands );
	foreach ( com; matching_commands ) {
		linenoiseAddCompletion(lc,std.string.toStringz(com));
	}
}

Todos handle_message( string command, string parameter, Todos ts ) {
	switch (command) {
		case "add":
			Todo t;
			t.title = parameter;
			ts.addTodo( t );
			break;
		case "del":
			size_t id = to!size_t(parameter);
			size_t count = 0;
			foreach ( ref t; ts ) {
				bool breakout = false;
				if (count == id) {
					t.deleted = true;
					breakout = true;
				}
				count++;
				if (breakout)
					break;
			}
			break;
		case "search":
			if ( parameter == "" )
				ts.filters = default_filters;
			else
				ts.filters = filter_on_title( ts.filters, parameter );
			break;
		case "tag":
			auto targets = parseTarget( parameter );
			if (targets.empty)
				writeln( "Please provide a list of todos (1,3,..) or all" );
			else {
				auto td = parseTags( parameter );
				size_t count = 0;
				auto first = targets.front;
				targets.popFront;
				foreach ( ref t; ts ) {
					bool breakout = false;
					if (count == first) {
						t = applyTags( t, td );
						if ( targets.empty )
							breakout = true;
						else {
							first = targets.front;
							targets.popFront;
						}
					}
					++count;
					if (breakout)
						break;
				}
			}
			break;
		case "show":
			write( toString( ts ) );
			break;
		default:
			writeln( "Unknown option" );
			break;
	}
	return ts;
}

void main( string[] args ) {
	auto fileName = expandTilde( "~/.config/todod/todos.yaml" );
	scope( exit ) { writeTodos( ts, fileName ); }
	
	ts = loadTodos( fileName );

	bool quit = false;

 	// LineNoise setup
	string historyFile = expandTilde( "~/.config/todod/history.txt" );
	linenoiseSetCompletionCallback( &completion );
  linenoiseHistoryLoad(std.string.toStringz(historyFile)); /* Load the history at startup */

	char *line;

	while(!quit && (line = linenoise("todod> ")) !is null) {
		/* Do something with the string. */
		if (line[0] != '\0') {
			if ( !strncmp(line,"quit",4) ) {
				quit = true;
			} else {
				auto commands = to!string( line ).chomp().findSplit( " " );
				ts = handle_message( commands[0], commands[2], ts );
			}
			linenoiseHistoryAdd(line); /* Add to the history. */
			linenoiseHistorySave(std.string.toStringz(historyFile)); /* Save the history on disk. */
		}
		free(line);
	}
}
