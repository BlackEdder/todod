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
			ts ~= t;
			break;
		case "del":
			size_t id = to!size_t(parameter);
			if (id < ts.length - 1 )
				ts = ts[0..id] ~ ts[id+1..$];
			else if (id == ts.length - 1)
				ts = ts[0..id];
			break;
		case "show":
			if (ts.length == 0)
				writeln( "No todos yet. Add them using todod add [TODO]" );
			else
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
		ts = handle_message( commands[0], commands[2], ts );
	}
}
