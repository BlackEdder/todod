module todod.todo;

import std.string;
import std.regex;

import std.json;

import std.stdio;
import std.file;
import std.conv;

import std.algorithm;
import std.range;
import std.array;

import todod.shell;

struct Todo {
	string title;
	string[] tags;
	long progress = 0; /// Keep track of how long/often we've worked on this

	bool deleted = false;

	this( string tle ) { 
		auto tup = parseAndRemoveTags( tle );
		tags = tup[0].add_tags;
		title = tup[1]; 
	}

	bool opEquals(const Todo t) const {
		return title == t.title;
	}
}

unittest {
	Todo t1;
	t1.title = "Todo 1";
	assert( t1.title == "Todo 1" );

	Todo t2 = Todo( "Bla +tag1 -tag2" );
	assert( t2.title == "Bla" );
	assert( t2.tags[0] == "tag1" );
}

string toString( const Todo t ) {
	return t.title ~ " " ~ to!string( t.tags );
}

JSONValue toJSON( const Todo t ) {
	JSONValue[string] jsonTODO;
	jsonTODO["title"] = t.title;
	jsonTODO["tags"] = t.tags;
	jsonTODO["progress"] = t.progress;
	return JSONValue( jsonTODO );	
}

Todo toTodo( const JSONValue json ) {
	Todo t;
	t.title = json["title"].str;
	foreach ( tag; json["tags"].array )
		t.tags ~= tag.str;
	t.progress = json["progress"].integer;
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
		int res = 0;
		foreach( ref t; myTodos ) {
			bool keep = true;
			foreach ( f ; filters ) {
				if ( !f( t ) ) {
					keep = false;
					break;
				}
			}
			if (keep) {
				res = dg(t);
				if (res) return res;
			}
		}
		return res;
	}

	public int opApply(int delegate(ref int, ref const Todo) dg) const {
		int res = 0;
		int index = 0;
		foreach( t; this ) {
			res = dg(index, t);
			if (res) return res;
			++index;
		}
		return res;
	}

	public int opApply(int delegate(ref int, ref Todo) dg) {
		int res = 0;
		int index = 0;
		foreach( ref t; this ) {
			res = dg(index, t);
			if (res) return res;
			++index;
		}
		return res;
	}

	public int opApply(int delegate(ref const Todo) dg) const {
		int res = 0;
		foreach( t; myTodos ) {
			bool keep = true;
			foreach ( f ; filters ) {
				if ( !f( t ) ) {
					keep = false;
					break;
				}
			}
			if (keep) {
				res = dg(t);
				if (res) return res;
			}
		}
		return res;
	}

	Todo[] array() {
		Todo[] result;
		foreach( ref t; this )
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

	/// Apply a delegate to all todos specified by targets
	void apply( void delegate( ref Todo ) dg, Targets targets ) {
		auto first = targets.front;
		targets.popFront;
		foreach ( count, ref t; this ) {
			if (count == first) {
				dg( t );
				if ( targets.empty )
					break;
				else {
					first = targets.front;
					targets.popFront;
				}
			}
		}
	}

	unittest {
		auto targets = parseTarget( "1" );
		auto ts = generateSomeTodos;
		ts.apply( delegate( ref Todo t ) { t.deleted = true; }, targets );
		assert( ts.walkLength == 1 );
		ts = generateSomeTodos;
		assert( ts.walkLength == 2 );
		targets = parseTarget( "all" );
		ts.apply( delegate( ref Todo t ) { t.deleted = true; }, targets );
		assert( ts.walkLength == 0 );
	}

	/// Access by id. 
	/// Performance: starts at the beginning every time, so if you need to access multiple then
	/// using apply might be more performant 
	ref Todo opIndex(size_t id) {
		foreach ( count, ref t; this ) {
			if (count == id) {
				return t;
			}
		}
		assert( false );
	}

	unittest {
		auto ts = generateSomeTodos;
		assert( ts.walkLength == 2 );
		ts[1].deleted = true;
		assert( ts.walkLength == 1 );
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

struct TagDelta {
	string[] add_tags;
	string[] delete_tags;
}

Filters filterOnTags( Filters fltrs, TagDelta tagDelta ) {
	foreach ( tag; tagDelta.add_tags )
		fltrs ~= t => canFind( t.tags, tag );
	foreach ( tag; tagDelta.delete_tags )
		fltrs ~= t => !canFind( t.tags, tag );
	return fltrs;
}

version(unittest) {
	Todos generateSomeTodos() {
		Todo t1;
		t1.title = "Todo 1";
		t1.tags = ["tag1", "tag2", "tag3"];
		Todo t2;
		t2.title = "Bla";
		t2.tags = ["tag2", "tag4"];
		Todos mytodos = new Todos( [t1, t2] );
		return mytodos;
	}
}

unittest {
	auto mytodos = generateSomeTodos().array;
	assert(	mytodos[0].title == "Todo 1" );
	assert(	mytodos[1].title == "Bla" );

	// Filter on title
	auto todos = generateSomeTodos();
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

/// Return all existing tags
string[] allTags( Todos ts ) {
	string[] tags;
	auto filters = ts.filters;
	scope(exit) { ts.filters = filters; }
	ts.filters = default_filters;
	foreach( t; ts )
		tags ~= t.tags;

	sort( tags );
	tags = array( uniq( tags ) );

	return tags;
}

unittest {
	auto ts = generateSomeTodos();
	assert( equal( ts.allTags(), ["tag1", "tag2", "tag3", "tag4"] ) );
}


string toString( const Todos ts ) {
	string str;
	foreach( id, t; ts ) {
		str = str ~ to!string( id ) ~ " " ~ toString( t ) ~ "\n";
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
	auto mytodos = generateSomeTodos();
	assert(	toJSON( mytodos ).toTodos.array[0] == mytodos.array[0] );
}

Todos loadTodos( string fileName ) {
	Todos ts = new Todos;
	if (exists( fileName )) {
		File file = File( fileName, "r" );
		auto content = file.readln();
		if (content != "")
			ts = toTodos( parseJSON( content ) );
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
