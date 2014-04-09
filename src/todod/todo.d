module todod.todo;

import std.string;
import std.regex;

struct todo {
	string title;
}

unittest {
	todo t1;
	t1.title = "Todo 1";
	assert( t1.title == "Todo 1" );
}

alias todo[] todos;

unittest {
	todo t1;
	t1.title = "Todo 1";
	todo t2;
	t2.title = "Bla";
	todos mytodos = [t1, t2];

	assert(	mytodos[0].title == "Todo 1" );
}

todos search_title( const todos ts, string search ) {
	todos answer;
	foreach ( t; ts ) {
		if (matchFirst( t.title.toLower, search.toLower ))
		answer ~= t;
	}
	return answer;
}

unittest {
	todo t1;
	t1.title = "Todo 1";
	todo t2;
	t2.title = "Bla";
	todos mytodos = [t1, t2];

	auto s = search_title( mytodos, "Bla" );

	assert(	s.length == 1 );
	assert(	s[0].title == "Bla" );

	s = search_title( mytodos, "bla" );

	assert(	s.length == 1 );
	assert(	s[0].title == "Bla" );

}
