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
	string[] command_keys = commands.keys;
	string mybuf = to!string( buf );
	if (match( mybuf, "^[A-z]+$" )) {
		// Main commands
		auto regex_buf = "^" ~ mybuf;
		auto matching_commands = filter!( a => match( a, regex_buf ))( command_keys );
		foreach ( com; matching_commands ) {
			linenoiseAddCompletion(lc,std.string.toStringz(com));
		}
	} else {
		auto m = match( mybuf, r"^(.* )([+-])(\w*)$" );
		if (m) {
			auto matching_commands =
				filter!( a => match( a, regex(m.captures[3]) ))( ts.allTags );
			foreach ( com; matching_commands ) {
				linenoiseAddCompletion(lc,std.string.toStringz( m.captures[1]
							~ m.captures[2] ~ com ));
			}
		}
	}
}

Todos delegate( Todos, string)[string] commands;

void init_commands() {
	commands = [
		"add": delegate( Todos ts, string parameter ) {
			ts.addTodo( Todo( parameter ) );
			return ts;
		},
		"del": delegate( Todos ts, string parameter ) {
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
			return ts;
		},
		"done": delegate( Todos ts, string parameter ) {
			ts = commands["del"]( ts, parameter );
			return ts;
		},
		"progress": delegate( Todos ts, string parameter ) {
			size_t id = to!size_t(parameter);
			size_t count = 0;
			foreach ( ref t; ts ) {
				bool breakout = false;
				if (count == id) {
					t.progress++;
					breakout = true;
				}
				count++;
				if (breakout)
					break;
			}
			return ts;
		},
		"search": delegate( Todos ts, string parameter ) {
			if ( parameter == "" )
				ts.filters = default_filters;
			//else
			//	ts.filters = filter_on_title( ts.filters, parameter );
			else
				ts.filters = filterOnTags( ts.filters, parseTags( parameter ) );
			return ts;
		}, 
		"tag": delegate( Todos ts, string parameter ) {
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
			return ts;
		},
		"show": delegate( Todos ts, string parameter ) {
			linenoiseClearScreen();
			if (parameter == "tags")
				writeln( prettyStringTags( ts.allTags ) );
			else
				write( prettyStringTodos( ts ) );
			return ts;
		},
		"clear": delegate( Todos ts, string parameter ) {
			linenoiseClearScreen();
			return ts;
		}
	];
}

Todos handle_message( string command, string parameter, Todos ts ) {
	if ( command in commands ) {
		ts = commands[command]( ts, parameter );
	} else {
		writeln( "Unknown option" );
	}
	return ts;
}

void main( string[] args ) {

	init_commands;
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
