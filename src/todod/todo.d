module todod.todo;

import std.string;
import std.regex;

import std.json;

import std.stdio;
import std.file;
import std.conv;

struct Todo {
	string title;

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
	return t.title;
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

Filters filter_on_title( Filters fltrs, string title ) {
	fltrs ~= t => !matchFirst( t.title.toLower, title.toLower ).empty;
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
	todos.applyFilters( filter_on_title( default_filters, "Bla" ) );
	assert( todos.array.length == 1 );
	todos.addTodo( Todo( "Blaat" ) );
	assert( todos.array.length == 2 );
	todos.filters = filter_on_title( todos.filters, "Blaat" );
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

Todos loadTodos() {
	Todos ts = new Todos;
	if (exists(".todod.yaml" )) {
		File file = File( ".todod.yaml", "r" );
		ts = toTodos( parseJSON( file.readln() ) );
	}
	return ts;
}

void writeTodos( Todos ts ) {
	File file = File( ".todod.yaml", "w" );
	auto applied_filters = ts.filters;
	ts.resetFilter;
	file.write( toJSON( ts ).toString );
	ts.applyFilters( applied_filters );
}
