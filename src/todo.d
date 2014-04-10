import std.stdio;
import std.conv;
import std.string;
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
				writeln( t.title );
				if (count == id) {
					writeln( "Deleting: ", t.title );
					t.deleted = true;
					breakout = true;
				}
				count++;
				if (breakout)
					break;
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
	scope( exit ) { writeTodos( ts ); }
	auto ts = loadTodos();

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
