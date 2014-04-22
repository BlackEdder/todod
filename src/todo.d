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
import std.stdio;

import std.path;
import std.file;

import std.string;
import std.regex;

import std.conv;
import std.algorithm;

import core.stdc.string, core.stdc.stdlib, std.stdio;
import deimos.linenoise;

import todod.todo;
import todod.date;
import todod.shell;
import todod.commandline;
import todod.habitrpg;

Todos ts; // Defined global to give C access to it in tab completion
HabitRPG hrpg;

extern(C) void completion(const char *buf, linenoiseCompletions *lc) {
	string[] command_keys = commands.commands;
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

auto commands = Commands!( Todos delegate( Todos, string) )( "Usage command [OPTIONS].
		
  This todod manager allows you to keep track of large amounts of todos. Todos can be tagged and/or given due dates. A feature specific to this todo manager is that it will show at most 5 todos at a time. Todos that are due or are old have a higher probability of being shown. Limiting the view to the more important todos allows you to focus on high priority todos first.\n");

//Todos delegate( Todos, string)[string] commands;

void init_commands() {
	commands.add(
		"add", delegate( Todos ts, string parameter ) {
			ts.addTodo( Todo( parameter ) );
			if (ts.walkLength >= 5)
				ts[0].random = false;
			ts = commands["show"]( ts, "" );
			return ts;
		}, "Add a new todo with provided title. One can respectively add tags with +tag and a due date with DYYYY-MM-DD or D+7 for a week from now." );

		commands.add( 
				"del", delegate( Todos ts, string parameter ) {
			size_t id = to!size_t(parameter);
			ts[id].deleted = true;
			ts = commands["show"]( ts, "" );
			return ts;
		}, "Usage del todo_id. Deletes Todo specified by id." );

		commands.add( 
				"done", delegate( Todos ts, string parameter ) {
			upHabit( hrpg, "productivity" );
			ts = commands["del"]( ts, parameter );
			ts = commands["show"]( ts, "" );
			return ts;
		}, "Usage done todo_id. Marks Todo specified by id as done." );

		commands.add( 
				"progress", delegate( Todos ts, string parameter ) {
			size_t id = to!size_t(parameter);
			upHabit( hrpg, "productivity" );
			ts[id].progress ~= Date.now;
			ts = commands["show"]( ts, "" );
			return ts;
		}, "Usage: progress TARGETS. Marks that you have made progress on the provided TARGETS. This will lower the weight of this todo and therefore lower the likelihood of it appearing in the randomly shown subset of todos. Targets can either be a list of numbers (2,3,4) or all for all shown Todos." );

		commands.add( 
				"search", delegate( Todos ts, string parameter ) {
			if ( parameter == "" )
				ts.filters = default_filters;
			else {
				if ( match( parameter, r" all$" ) ) // Search through all todos
					ts.filters = default_filters;
				ts.filters = ts.filters[0..$-1]; // Undo random
				ts.filters = filterOnTags( ts.filters, parseTags( parameter ) );
			}
			ts = random( ts );
			ts = commands["show"]( ts, "" );
			return ts;
		}, "Usage search +tag1 -tag2. Activates only the todos that have the specified todos. Search is incremental, i.e. search +tag1 activates all todos with tag1, then search -tag2 will deactivate the Todos with tag2 from the list of Todos with tag1. search ... all will search through all Todos instead. Similarly, search without any further parameters resets the search (activates all Todos)." );

		commands.add( 
				"reroll", delegate( Todos ts, string parameter ) {
			ts.filters = ts.filters[0..$-1]; // Undo random
			ts = random( ts );
			ts = commands["show"]( ts, "" );
			return ts;
		}, "Reroll the Todos that are active. I.e. chooses up to five Todos from all the active Todos to show" );

		commands.add(
				"tag", delegate( Todos ts, string parameter ) {
			auto targets = parseTarget( parameter );
			if (targets.empty)
				writeln( "Please provide a list of todos (1,3,..) or all" );
			else {
				auto td = parseTags( parameter );
				ts.apply( delegate( ref Todo t ) { applyTags( t, td ); }, targets );
			}
			ts = commands["show"]( ts, "" );
			return ts;
		}, "Usage: tag +tagtoadd -tagtoremove [TARGETS]. Adds or removes given tags for the provided targets. Targets can either be a list of numbers (2,3,4) or all for all shown Todos" );

		commands.add( 
				"due", delegate( Todos ts, string parameter ) {
			auto targets = parseTarget( parameter );
			if (targets.empty)
				writeln( "Please provide a list of todos (1,3,..) or all" );
			else {
				auto duedate = parseDate( parameter );
				ts.apply( delegate( ref Todo t ) { t.due_date = duedate; }, targets );
			}
			ts = commands["show"]( ts, "" );
			return ts;
		}, "Usage: due YYYY-MM-DD [TARGETS] or +days. Sets the given due date for the provided targets. Targets can either be a list of numbers (2,3,4) or all for all shown Todos" );

		commands.add( 
				"show", delegate( Todos ts, string parameter ) {
			ts = commands["clear"]( ts, "" ); 
			if (parameter == "tags")
				writeln( prettyStringTags( ts.allTags ) );
			else {
				writeln( "Tags and number of todos associated with that tag." );
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
		}, "Show a (random) subset of Todos. Subject to filters added throught the search command. Shows a list of tags present in the filtered list of Todos at the top of the output." );

		commands.add( 
				"clear", delegate( Todos ts, string parameter ) {
			linenoiseClearScreen();
			return ts;
		}, "Clear the screen." );

		commands.add( 
				"help", delegate( Todos ts, string parameter ) {
			ts = commands["clear"]( ts, "" ); 
			writeln( commands.toString );
			return ts;
		}, "Print this help message" );

		commands.add( 
				"quit", delegate( Todos ts, string parameter ) {
			return ts;
		}, "Quit todod and save the todos" );

}

Todos handle_message( string command, string parameter, Todos ts ) {
	if ( commands.exists( command ) ) {
		ts = commands[command]( ts, parameter );
	} else {
		ts = commands["help"]( ts, "" );
	}
	return ts;
}

void main( string[] args ) {
	init_commands;

	auto dirName = expandTilde( "~/.config/todod/" );
	mkdirRecurse( dirName );
	auto fileName = dirName ~ "todos.json";
	scope( exit ) { writeTodos( ts, fileName ); }

	hrpg = loadHRPG( dirName ~ "habitrpg.json" );
	
	ts = loadTodos( fileName );
	ts = random( ts );
	handle_message( "show", "", ts );

	bool quit = false;

 	// LineNoise setup
	auto historyFile = dirName ~ "history.txt";
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
		writeTodos( ts, fileName );
	}
}
