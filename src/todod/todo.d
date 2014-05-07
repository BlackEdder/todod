/*
	 -------------------------------------------------------------------

	 Copyright (C) 2014, Edwin van Leeuwen

	 This file is part of todod todo list manager.

	 Todod is free software; you can redistribute it and/or modify
	 it under the terms of the GNU General Public License as published by
	 the Free Software Foundation; either version 3 of the License, or
	 (at your option) any later version.

	 Todod is distributed in the hope that it will be useful,
	 but WITHOUT ANY WARRANTY; without even the implied warranty of
	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	 GNU General Public License for more details.

	 You should have received a copy of the GNU General Public License
	 along with Todod. If not, see <http://www.gnu.org/licenses/>.

	 -------------------------------------------------------------------
	 */

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

import std.random;

import std.uuid;

import todod.shell;
import todod.date;
import todod.random;
import todod.tag;

struct Todo {
	UUID id; /// id is mainly used for syncing with habitrpg

	Date[] progress; /// Keep track of how long/often we've worked on this
	bool random = true;

	Tags tags;

	Date creation_date;
	Date due_date;

	this( string tle ) { 
		auto tup = parseAndRemoveTags( tle );
		tags = tup[0].add_tags;

		auto date_tup = parseAndRemoveDueDate( tup[1] );
		due_date = date_tup[0];

		creation_date = Date.now;
		mytitle = date_tup[1];
	}

	@property string title() const {
		return mytitle;
	}

	bool opEquals(const Todo t) const {
		return mytitle == t.mytitle;
	}

	int opCmp(ref const Todo otherTodo ) const { 
		if ( this == otherTodo )
			return 0;
		else if ( title < otherTodo.title )
			return -1;
		return 1;
	}

	private:
		string mytitle;
}

unittest {
	Todo t1 = Todo( "Todo 1" );
	assert( t1.title == "Todo 1" );

	Todo t2 = Todo( "Bla 1 +tag1 -tag2" );
	assert( t2.title == "Bla 1" );
	assert( t2.tags[0] == Tag("tag1") );

	Todo t3 = Todo( "+tag1 Bla 1 -tag2" );
	assert( t3.title == "Bla 1" );
	assert( t3.tags[0] == Tag("tag1") );
}

string toString( const Todo t ) {
	return t.title ~ " " ~ to!string( t.tags );
}

JSONValue toJSON( const Todo t ) {
	JSONValue[string] jsonTODO;
	jsonTODO["title"] = t.title;
	JSONValue[] tags;
	foreach( tag; t.tags )
		tags ~= tag.to!JSONValue();
	jsonTODO["tags"] = JSONValue(tags);

	string[] progress_array;
	foreach( d; t.progress )
		progress_array ~= d.toStringDate;
	jsonTODO["progress"] = progress_array;
	jsonTODO["creation_date"] = t.creation_date.toStringDate;
	jsonTODO["due_date"] = t.due_date.toStringDate;
	jsonTODO["id"] = t.id.toString;
	return JSONValue( jsonTODO );	
}

Todo toTodo( const JSONValue json ) {
	Todo t;
	const JSONValue[string] jsonAA = json.object;
	t.mytitle = jsonAA["title"].str;
	foreach ( tag; jsonAA["tags"].array )
		t.tags.add( Tag.parseJSON( tag ) );
	foreach ( js; jsonAA["progress"].array )
		t.progress ~= Date( js.str );
	t.creation_date = Date( jsonAA["creation_date"].str );
	if ("due_date" in jsonAA)
		t.due_date = Date( jsonAA["due_date"].str );
	if ("id" in jsonAA)
		t.id = UUID( jsonAA["id"].str );
	return t;
}

unittest {
	Todo t1 = Todo( "Todo 1 +tag" );
	assert( toJSON( t1 ).toTodo == t1 );

	string missingDate = "{\"title\":\"Todo 1\",\"tags\":[{\"name\":\"tag\",\"id\":\"00000000-0000-0000-0000-000000000000\"}],\"progress\":[],\"creation_date\":\"2014-05-06\"}";

	assert( toTodo( parseJSON(missingDate) ).title == "Todo 1" );
}

/// Days since last progress. If no progress has been made then days since creation
auto lastProgress( const Todo t ) {
	Date currentDate = Date.now;
	if ( t.progress.length > 0 )
		return currentDate.substract( t.progress[$-1] );
	else
		return currentDate.substract( t.creation_date );
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
		myTodos = [];
		foreach ( todo ; ts )
			add( ts );
		resetFilter();
	}

	void add( Todo todo ) {
		auto todos = myTodos.find( todo  );
		if ( todos.empty ) {
			myTodos ~= todo;
			sort( myTodos );
		} else {
			if (!todo.id.empty) // Will automatically cause sync to HabitRPG id
				todos[0].id = todo.id;
		}
	}

	void add(RANGE)(RANGE todos ) {
		// TODO optimize this since both ranges are sorted
		foreach (todo; todos)
			add( todo );
	}

	void remove( Todo todo ) {
		auto i = countUntil( myTodos, todo );
		if (i != -1)
			myTodos = myTodos[0..i] ~ myTodos[i+1..$];
	}

	void remove(RANGE)( RANGE todos ) {
		// TODO optimize this since both ranges are sorted
		foreach (todo; todos)
			remove( todo );
	}

	/*
		Will need to take into account filters
		Todo[] array() {
		return myTodos;
	}*/

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
		assert( ts[1].tags.length == 3 );
		ts.apply( delegate( ref Todo t ) { t.tags.add( Tag( "tag5" ) ); }, targets );
		assert( ts[1].tags.length == 4 );
		ts = generateSomeTodos;
		targets = parseTarget( "all" );
		ts.apply( delegate( ref Todo t ) { t.tags.add( Tag( "tag5" ) ); }, targets );
		assert( ts[0].tags.length == 3 );
		assert( ts[1].tags.length == 4 );
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
		assert( ts[1].tags.length == 3 );
		ts[1].tags.add( Tag( "tag5" ) );
		assert( ts[1].tags.length == 4 );
	}

	private:
		Todo[] myTodos;
}

alias bool delegate( const Todo )[] Filters;

Filters default_filters() {
	Filters fltrs;
	return fltrs;
}

Filters filterOnTitle( Filters fltrs, string title ) {
	fltrs ~= t => !matchFirst( t.title.toLower, title.toLower ).empty;
	return fltrs;
}

Filters filterOnTags( Filters fltrs, TagDelta tagDelta ) {
	foreach ( tag; tagDelta.add_tags )
		fltrs ~= t => t.tags.canFind( tag );
	foreach ( tag; tagDelta.delete_tags )
		fltrs ~= t => !t.tags.canFind( tag );
	return fltrs;
}

Filters filterOnRandom( Filters fltrs ) {
	fltrs ~= t => t.random;
	return fltrs;
}

Todos random( Todos ts, size_t no = 5 ) {
	if (ts.walkLength > no) {
		// Clear all old randoms
		foreach ( ref t; ts )
			t.random = false;

		ts = randomGillespie( ts, no );

	} else {
		foreach ( ref t; ts )
			t.random = true;
	}
	ts.filters = filterOnRandom( ts.filters );
	return ts;
}

version(unittest) {
	Todos generateSomeTodos() {
		Todo t1 = Todo( "Todo 1 +tag1 +tag2 +tag3" );
		Todo t2 = Todo( "Bla +tag2 +tag4" );
		Todos mytodos = new Todos( [t2, t1] );
		return mytodos;
	}
}

unittest {
	auto mytodos = generateSomeTodos().array;
	assert(	mytodos[1].title == "Todo 1" );
	assert(	mytodos[0].title == "Bla" );

	// Filter on title
	auto todos = generateSomeTodos();
	todos.applyFilters( filterOnTitle( default_filters, "Bla" ) );
	assert( todos.array.length == 1 );
	todos.add( Todo( "Blaat" ) );
	assert( todos.array.length == 2 );
	todos.filters = filterOnTitle( todos.filters, "Blaat" );
	assert( todos.array.length == 1 );
}

/// Return all existing tags
Tags allTags( Todos ts ) {
	Tags tags;
	auto filters = ts.filters;
	scope(exit) { ts.filters = filters; }
	ts.filters = default_filters;
	foreach( t; ts )
		tags.add( t.tags );

	return tags;
}

unittest {
	auto ts = generateSomeTodos();
	assert( equal( ts.allTags().array, [Tag("tag1"), Tag("tag2"), 
						Tag("tag3"), Tag("tag4")] ) );
}

size_t[Tag] tagsWithCount( Todos ts ) {
	size_t[Tag] tags;
	foreach( t; ts ) {
		foreach( tag; t.tags ) {
			tags[tag]++;
		}
		if (t.tags.length == 0)
			tags[Tag("untagged")]++;
	}
	return tags;
}

unittest {
	auto ts = generateSomeTodos();
	auto expected = ["tag2":2, "tag3":1, "tag4":1, "tag1":1];
	foreach( k, v; ts.tagsWithCount() ) {
		assert( v == expected[k.name] );
	}
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
		ts.add( toTodo( js ) );
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
