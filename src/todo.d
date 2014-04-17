import std.stdio;

import std.path;

import std.string;
import std.regex;

import std.conv;
import std.algorithm;

import core.stdc.string, core.stdc.stdlib, std.stdio;
import deimos.linenoise;

import todod.todo;
import todod.date;
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
			ts[0].random = false;
			ts = commands["show"]( ts, "" );
			return ts;
		},
		"del": delegate( Todos ts, string parameter ) {
			size_t id = to!size_t(parameter);
			ts[id].deleted = true;
			ts = commands["show"]( ts, "" );
			return ts;
		},
		"done": delegate( Todos ts, string parameter ) {
			ts = commands["del"]( ts, parameter );
			ts = commands["show"]( ts, "" );
			return ts;
		},
		"progress": delegate( Todos ts, string parameter ) {
			size_t id = to!size_t(parameter);
			ts[id].progress ~= Date.now;
			ts = commands["show"]( ts, "" );
			return ts;
		},
		"search": delegate( Todos ts, string parameter ) {
			if ( parameter == "" )
				ts.filters = default_filters;
			else {
				ts.filters = ts.filters[0..$-1]; // Undo random
				ts.filters = filterOnTags( ts.filters, parseTags( parameter ) );
			}
			ts = random( ts );
			ts = commands["show"]( ts, "" );
			return ts;
		},
		"reroll": delegate( Todos ts, string parameter ) {
			ts.filters = ts.filters[0..$-1]; // Undo random
			ts = random( ts );
			ts = commands["show"]( ts, "" );
			return ts;
		},
		"tag": delegate( Todos ts, string parameter ) {
			auto targets = parseTarget( parameter );
			if (targets.empty)
				writeln( "Please provide a list of todos (1,3,..) or all" );
			else {
				auto td = parseTags( parameter );
				ts.apply( delegate( ref Todo t ) { applyTags( t, td ); }, targets );
			}
			ts = commands["show"]( ts, "" );
			return ts;
		},
		"due": delegate( Todos ts, string parameter ) {
			auto targets = parseTarget( parameter );
			if (targets.empty)
				writeln( "Please provide a list of todos (1,3,..) or all" );
			else {
				auto duedate = parseDate( parameter );
				ts.apply( delegate( ref Todo t ) { t.due_date = duedate; }, targets );
			}
			ts = commands["show"]( ts, "" );
			return ts;
		},
		"show": delegate( Todos ts, string parameter ) {
			ts = commands["clear"]( ts, "" ); 
			if (parameter == "tags")
				writeln( prettyStringTags( ts.allTags ) );
			else {
				auto filters = ts.filters;
				ts.filters = ts.filters[0..$-1];
				auto tags = ts.tagsWithCount();
				foreach( tag, count; tags ) {
					writeln( tagColor(tag).leftJustify( 20 ), "\t", count );
				}
				writeln();
				ts.filters = filters;
				write( prettyStringTodos( ts ) );
			}
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
	ts = random( ts );
	commands["show"]( ts, "" );

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
