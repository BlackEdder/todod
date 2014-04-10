import std.stdio;
import std.conv;

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
			case "del":
				size_t id = to!size_t(args[2]);
				if (id < ts.length)
					ts = ts[0..id] ~ ts[id+1..$];
				break;
			default:
				writeln( "Unknown option" );
				break;
		}
	} else {
		if (ts.length == 0)
			writeln( "No todos yet. Add them using todod add [TODO]" );
		else
			write( toString( ts ) );
	}
}
