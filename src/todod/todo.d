module todod.todo;

import std.string;
import std.regex;

import std.json;

import std.stdio;
import std.file;

struct Todo {
	string title;

	bool opEquals(const Todo t) const { 
		return title == t.title;
	}
}

unittest {
	Todo t1;
	t1.title = "Todo 1";
	assert( t1.title == "Todo 1" );
}

JSONValue toJSON( const Todo t ) {
	JSONValue[string] jsonTODO;
	jsonTODO["title"] = t.title;
	return JSONValue( jsonTODO );	
}

Todo toTodo( const JSONValue json ) {
	Todo t;
	t.title = json["title"].str;
	return t;
}

unittest {
	Todo t1;
	t1.title = "Todo 1";
	assert( toJSON( t1 ).toTodo == t1 );
}

/**
	Working on list of todos
	*/

alias Todo[] Todos;

version(unittest) {
	Todos generate_some_todos() {
		Todo t1;
		t1.title = "Todo 1";
		Todo t2;
		t2.title = "Bla";
		Todos mytodos = [t1, t2];
		return mytodos;
	}
}

unittest {
	auto mytodos = generate_some_todos();
	assert(	mytodos[0].title == "Todo 1" );
}

Todos search_title( const Todos ts, string search ) {
	Todos answer;
	foreach ( t; ts ) {
		if (matchFirst( t.title.toLower, search.toLower ))
		answer ~= t;
	}
	return answer;
}

unittest {
	auto mytodos = generate_some_todos();
	auto s = search_title( mytodos, "Bla" );

	assert(	s.length == 1 );
	assert(	s[0] == mytodos[1] );

	s = search_title( mytodos, "bla" );

	assert(	s.length == 1 );
	assert(	s[0] == mytodos[1] );
}


JSONValue toJSON( const Todos ts ) {
	JSONValue[] jsonTODOS;
	foreach (t; ts) 
		jsonTODOS ~= toJSON( t );
	JSONValue[string] json;
	json["todos"] = jsonTODOS;
	return JSONValue( json );	
}

Todos toTodos( const JSONValue json ) {
	Todos ts;
	foreach ( js; json["todos"].array )
		ts ~= toTodo( js );
	return ts;
}

unittest {
	auto mytodos = generate_some_todos();
	assert(	toJSON(mytodos).toTodos[0] == mytodos[0] );
}

Todos loadTodos() {
	Todos ts;
	if (exists(".todod.yaml" )) {
		File file = File( ".todod.yaml", "r" );
		ts = toTodos( parseJSON( file.readln() ) );
	}
	return ts;
}

void writeTodos( const Todos ts ) {
	File file = File( ".todod.yaml", "w" );
	file.write( toJSON(ts).toString );
}
