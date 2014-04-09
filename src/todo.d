import std.stdio;

import todod.todo;

void main( string[] args ) {
	scope( exit ) { writeTodos( ts ); }
	auto ts = loadTodos();

	if ( args.length >= 2 ) {
		switch (args[1]) {
			case "add":
				Todo t;
				t.title = args[2];
				ts ~= t;
				break;
			default:
				writeln( "Unknown option" );
				break;
		}
	}
}
