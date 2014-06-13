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

import todod.commandline;
import todod.date;
import todod.dependency;
import todod.habitrpg;
import todod.random;
import todod.shell;
import todod.storage;
import todod.tag;
import todod.todo;

/// Struct holding the program state
class State {
	Todos todos;
}

TagDelta selected;

Todo[] selectedTodos;

extern(C) void completion(const char *buf, linenoiseCompletions *lc) {
	string mybuf = to!string( buf );
	if (match( mybuf, "^[A-z]+$" )) {
		// Main commands
		string[] commandKeys = commands.commands;
		auto regex_buf = "^" ~ mybuf;
		auto matching_commands = filter!( a => match( a, regex_buf ))( commandKeys );
		foreach ( com; matching_commands ) {
			linenoiseAddCompletion(lc,std.string.toStringz(com));
		}
	} else {
		auto m = match( mybuf, r"^([A-z]+) (.*)$" );
		if (m) {
			auto matching_commands =
				commands.completionOptions( m.captures[1], m.captures[2] );
			foreach ( com; matching_commands ) {
				linenoiseAddCompletion(lc,std.string.toStringz( com ));
			}
		}
	}
}

auto commands = Commands!( State delegate( State, string) )( "Usage command [OPTIONS].
		
  This todod manager allows you to keep track of large amounts of todos. Todos can be tagged and/or given due dates. A feature specific to this todo manager is that it will show at most 5 todos at a time. Todos that are due or are old have a higher probability of being shown. Limiting the view to the more important todos allows you to focus on high priority todos first.\n");

//Todos delegate( Todos, string)[string] commands;

void initCommands( State state, ref Dependencies dependencies, 
		in ref double[string] defaultWeights, ref HabitRPG hrpg ) {
	commands.add(
		"add", delegate( State state, string parameter ) {
			state.todos.add( new Todo( parameter ) );
			state = commands["show"]( state, "" );
			return state;
		}, "Add a new todo with provided title. One can respectively add tags with +tag and a due date with DYYYY-MM-DD or D+7 for a week from now." );

		commands.add( 
				"del", delegate( State state, string parameter ) {
			size_t id = to!size_t(parameter);
			state.todos.remove( selectedTodos[id] );
			dependencies = dependencies.removeUUID( selectedTodos[id].id );
			state = commands["reroll"]( state, "" );
			return state;
		}, "Usage del todo_id. Deletes Todo specified by id." );

		commands.add( 
				"done", delegate( State state, string parameter ) {
			auto todo = selectedTodos[to!size_t(parameter)];
			if (hrpg)
				doneTodo( todo, hrpg );
				
			state.todos.remove( todo );
			dependencies = dependencies.removeUUID( todo.id );
			state = commands["reroll"]( state, "" );
			return state;
		}, "Usage done todo_id. Marks Todo specified by id as done." );

		commands.add( 
				"progress", delegate( State state, string parameter ) {
			auto targets = parseTarget( parameter );
			if (targets.empty)
				writeln( "Please provide a list of todos (1,3,..) or all" );
			else {
				targets.apply( delegate( ref Todo t ) { 
					upHabit( hrpg, "productivity" );
					t.progress ~= Date.now; }, selectedTodos );
				state = commands["show"]( state, "" );
			}
			return state;
		}, "Usage: progress TARGETS. Marks that you have made progress on the provided TARGETS. This will lower the weight of this todo and therefore lower the likelihood of it appearing in the randomly shown subset of todos. Targets can either be a list of numbers (2,3,4) or all for all shown Todos." );

		commands.add( 
				"search", delegate( State state, string parameter ) {
			if ( parameter == "" )
				selected = TagDelta();
			else {
				if ( match( parameter, r" all$" ) ) // Search through all todos
					selected = TagDelta();
				TagDelta newTags = parseTags( parameter );
				selected.add_tags.add( newTags.add_tags );
				selected.delete_tags.add( newTags.delete_tags );
			}
			selectedTodos = random( state.todos, selected, dependencies, defaultWeights );
			state = commands["show"]( state, "" );
			return state;
		}, "Usage search +tag1 -tag2. Activates only the todos that have the specified todos. Search is incremental, i.e. search +tag1 activates all todos with tag1, then search -tag2 will deactivate the Todos with tag2 from the list of Todos with tag1. search ... all will search through all Todos instead. Similarly, search without any further parameters resets the search (activates all Todos)." );

		commands.add( 
				"reroll", delegate( State state, string parameter ) {
			selectedTodos = random( state.todos, selected, dependencies, defaultWeights );
			state = commands["show"]( state, "" );
			return state;
		}, "Reroll the Todos that are active. I.e. chooses up to five Todos from all the active Todos to show" );

		commands.add(
				"tag", delegate( State state, string parameter ) {
			auto targets = parseTarget( parameter );
			if (targets.empty)
				writeln( "Please provide a list of todos (1,3,..) or all" );
			else {
				auto td = parseTags( parameter );
				targets.apply( delegate( ref Todo t ) { applyTags( t, td ); },
					selectedTodos );
				state = commands["show"]( state, "" );
			}
			return state;
		}, "Usage: tag +tagtoadd -tagtoremove [TARGETS]. Adds or removes given tags for the provided targets. Targets can either be a list of numbe constrs (2,3,4) or all for all shown Todos" );

		commands.add( 
				"due", delegate( State state, string parameter ) {
			auto targets = parseTarget( parameter );
			if (targets.empty)
				writeln( "Please provide a list of todos (1,3,..) or all" );
			else {
				auto duedate = parseDate( parameter );
				targets.apply( delegate( ref Todo t ) { t.due_date = duedate; },
					selectedTodos );
				state = commands["show"]( state, "" );
			}
			return state;
		}, "Usage: due YYYY-MM-DD [TARGETS] or +days. Sets the given due date for the provided targets. Targets can either be a list of numbers (2,3,4) or all for all shown Todos" );

		commands.add( 
				"clear", delegate( State state, string parameter ) {
			linenoiseClearScreen();
			return state;
		}, "Clear the screen." );

		commands.add( 
				"weight", delegate( State state, string parameter ) {
			if (parameter == "")
				state = commands["show"]( state, "weight" );
			else {
				auto vs = parameter.split(" ");
				if (vs.length != 2) {
					writeln( "Expecting parameters: [WEIGHT] [TARGET]" );
				} else {
					auto targets = parseTarget( vs[1] );
					if (targets.empty)
						writeln( "Please provide a list of todos (1,3,..) or all" );
					else {
						double weight = vs[0].to!double;
						targets.apply( delegate( ref Todo t ) { 
							t.weight = weight; }, selectedTodos );
						state = commands["show"]( state, "" );
					}
				}
			}
			return state;
		}, "Usage: weight WEIGHT TARGETS. Set the weight/priority of the one of the Todos. The higher the weight the more likely the Todo will be shown/picked. Default weight value is 1." );

		commands.add(
				"depend", delegate( State state, string parameter ) {
			auto targets = parameter.split.map!(to!int);
			if ( targets.length != 2 ) {
				writeln( "Expecting two parameters" );
			} else {
				dependencies ~= Link( selectedTodos[targets[1]].id,
					selectedTodos[targets[0]].id );
				state = commands["reroll"]( state, "" );
			}
			return state;
		}, "Usage: depend TODOID1 TODOID2. The first Todo depends on the second. Causing the first Todo to be hidden untill the second Todo is done." );

		commands.add( 
				"help", delegate( State state, string parameter ) {
			state = commands["clear"]( state, "" ); 
			writeln( commands.toString );
			return state;
		}, "Print this help message" );

		commands.add( 
				"quit", delegate( State state, string parameter ) {
			return state;
		}, "Quit todod and save the todos" );

		auto tagCompletion = delegate( string cmd, string parameter ) {
			string[] result;
			auto m = match( parameter, r"^(.*\s*)([+-])(\w*)$" );
			if (m) {
				auto matching_commands =
					filter!( a => match( a.name, regex("^"~m.captures[3]) ))( 
							state.todos.allTags.array );
				foreach ( com; matching_commands ) {
					result ~= [cmd ~ " " ~ m.captures[1] ~ m.captures[2] ~ com.name];
				}
			}
			return result;
		};
		// For now set tag completion as general completion
		commands.defaultCompletion( tagCompletion );
}

State handleMessage( string command, string parameter, State state ) {
	if ( commands.exists( command ) ) {
		state = commands[command]( state, parameter );
	} else {
		state = commands["help"]( state, "" );
	}
	return state;
}

void main( string[] args ) {
	auto state = new State;

	auto dirName = expandTilde( "~/.config/todod/" );
	mkdirRecurse( dirName );
	auto gitRepo = openRepo( dirName );

	scope( exit ) { writeTodos( state.todos, gitRepo ); }

	auto hrpg = loadHRPG( dirName ~ "habitrpg.json" );
	commands = addHabitRPGCommands( commands, dirName );
	
	version( assert ) {
		commands = addStorageCommands( commands, gitRepo );
	}

	auto dependencies = loadDependencies( gitRepo );
	auto defaultWeights = loadDefaultWeights( dirName ~ "weights.json" );
	
	state.todos = loadTodos( gitRepo );
	selectedTodos = random( state.todos, selected, dependencies, defaultWeights );

	initCommands( state, dependencies, defaultWeights, hrpg );

	commands = addShowCommands( commands, selectedTodos, selected, dependencies,
			defaultWeights );

	handleMessage( "show", "", state );

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
				state = handleMessage( commands[0], commands[2], state );
			}
			linenoiseHistoryAdd(line); /* Add to the history. */
			linenoiseHistorySave(std.string.toStringz(historyFile)); /* Save the history on disk. */
		}
		free(line);
		writeTodos( state.todos, gitRepo );
		writeDependencies( dependencies, gitRepo );
	}
}
