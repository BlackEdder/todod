module todod.todo;

import std.string;
import std.regex;

import std.json;

import std.stdio;
import std.file;
import std.conv;

import std.algorithm;

struct Todo {
	string title;
	string[] tags;

	bool deleted = false;

	this( string tle ) { title = tle; }

	bool opEquals(const Todo t) const {
		return title == t.title;
	}
}

unittest {
	Todo t1;
	t1.title = "Todo 1";
	assert( t1.title == "Todo 1" );
}

string toString( const Todo t ) {
	return t.title ~ " " ~ to!string( t.tags );
}

JSONValue toJSON( const Todo t ) {
	JSONValue[string] jsonTODO;
	jsonTODO["title"] = t.title;
	jsonTODO["tags"] = t.tags;
	return JSONValue( jsonTODO );	
}

Todo toTodo( const JSONValue json ) {
	Todo t;
	t.title = json["title"].str;
	foreach ( tag; json["tags"].array )
		t.tags ~= tag.str;
	return t;
}

unittest {
	Todo t1;
	t1.title = "Todo 1";
	t1.tags = ["tag"];
	assert( toJSON( t1 ).toTodo == t1 );
}

/**
	Working on list of todos
	*/
class Todos {

	Filters filters;

	this() {
		resetFilter();
	};

	this( Todo[] ts ) {
		myTodos = ts;
		resetFilter();
	}

	void addTodo( Todo t ) {
		myTodos ~= t;
	}

	public int opApply(int delegate(ref Todo) dg) {
		foreach( ref t; myTodos ) {
			bool keep = true;
			foreach ( f ; filters ) {
				if ( !f( t ) ) {
					keep = false;
					break;
				}
			}
			if (keep) {
				dg(t);
			}
		}
		return 1;
	}

	public int opApply(int delegate(const Todo) dg) const {
		foreach( t; myTodos ) {
			bool keep = true;
			foreach ( f ; filters ) {
				if ( !f( t ) ) {
					keep = false;
					break;
				}
			}
			if (keep) {
				dg(t);
			}
		}
		return 1;
	}

	Todo[] array() {
		Todo[] result;
		foreach( t; this )
			result ~= t;
		return result;
	}

	void applyFilter( bool delegate(const Todo) dg ) {
		filters ~= dg;
	}

	Todos applyFilters( Filters fltrs ) {
		filters ~= fltrs;
		return this;
	}


	void resetFilter() {
		filters = default_filters;
	}

	size_t walkLength() {
		size_t l = 0;
		foreach( t; this )
			l++;
		return l;
	}

	private:
		Todo[] myTodos;
}

alias bool delegate( const Todo )[] Filters;

Filters default_filters() {
	Filters fltrs;
	fltrs ~= t => !t.deleted;
	return fltrs;
}

Filters filterOnTitle( Filters fltrs, string title ) {
	fltrs ~= t => !matchFirst( t.title.toLower, title.toLower ).empty;
	return fltrs;
}

Filters filterOnTags( Filters fltrs, string[] tags ) {
	foreach ( tag; tags )
		fltrs ~= t => canFind( t.tags, tag );
	return fltrs;
}

version(unittest) {
	Todos generate_some_todos() {
		Todo t1;
		t1.title = "Todo 1";
		Todo t2;
		t2.title = "Bla";
		Todos mytodos = new Todos( [t1, t2] );
		return mytodos;
	}
}

unittest {
	auto mytodos = generate_some_todos().array;
	assert(	mytodos[0].title == "Todo 1" );
	assert(	mytodos[1].title == "Bla" );

	// Filter on title
	auto todos = generate_some_todos();
	todos.applyFilters( filterOnTitle( default_filters, "Bla" ) );
	assert( todos.array.length == 1 );
	todos.addTodo( Todo( "Blaat" ) );
	assert( todos.array.length == 2 );
	todos.filters = filterOnTitle( todos.filters, "Blaat" );
	assert( todos.array.length == 1 );


	// Test for deleted
	Todo deleted_t;
	deleted_t.deleted = true;
	mytodos = new Todos([deleted_t]).array;
	assert( mytodos.length == 0 );
	Todo t;
	mytodos = new Todos([t, deleted_t]).array;
	assert( mytodos.length == 1 );
	mytodos = new Todos([deleted_t, t]).array;
	assert( mytodos.length == 1 );
}

string toString( const Todos ts ) {
	string str;
	size_t id = 0;
	foreach( t; ts ) {
		str = str ~ to!string( id ) ~ " " ~ toString( t ) ~ "\n";
		id++;
	}
	return str;
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
	Todos ts = new Todos;
	foreach ( js; json["todos"].array )
		ts.addTodo( toTodo( js ) );
	return ts;
}

unittest {
	auto mytodos = generate_some_todos();
	assert(	toJSON( mytodos ).toTodos.array[0] == mytodos.array[0] );
}

Todos loadTodos( string fileName ) {
	Todos ts = new Todos;
	if (exists( fileName )) {
		File file = File( fileName, "r" );
		ts = toTodos( parseJSON( file.readln() ) );
	}
	return ts;
}

void writeTodos( Todos ts, string fileName ) {
	File file = File( fileName, "w" );
	auto applied_filters = ts.filters;
	ts.resetFilter;
	file.write( toJSON( ts ).toString );
	ts.applyFilters( applied_filters );
}
