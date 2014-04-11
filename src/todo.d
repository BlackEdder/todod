import std.stdio;

import std.path;

import std.string;

import std.conv;
import std.algorithm;

import todod.todo;

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
	auto ts = loadTodos( fileName );

	bool quit = false;
	while (!quit) {
		write( "> " );
		auto commands = readln().chomp().findSplit( " " );
		if (commands[0] == "quit")
			quit = true;
		else 
			ts = handle_message( commands[0], commands[2], ts );
	}
}
