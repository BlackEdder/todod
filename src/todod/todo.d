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
	this() {
		resetFilter();
	};
	this( Todo[] ts ) {
		myTodos = ts;
		resetFilter();
	}

	void add( Todo todo ) {
		myTodos ~= todo;
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

	void resetFilter() {
		filters = [];
		applyFilter( t => !t.deleted );
	}

	size_t walkLength() {
		size_t l = 0;
		foreach( t; this )
			l++;
		return l;
	}

	private:
		Todo[] myTodos;
		bool delegate( const Todo )[] filters;
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
	todos.applyFilter( t => !matchFirst( t.title.toLower, "Bla".toLower ).empty );
	assert( todos.array.length == 1 );

	// Test for deleted
	Todo deleted_t;
	deleted_t.deleted = true;
	mytodos = new Todos([deleted_t]).array;
	assert( mytodos.length == 0 );
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
	Todos ts;
	foreach ( js; json["todos"].array )
		ts.add( toTodo( js ) );
	return ts;
}

/*unittest {
	auto mytodos = generate_some_todos();
	assert(	toJSON(mytodos).toTodos.array[0] == mytodos.array[0] );
}*/

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
