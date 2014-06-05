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

import todod.date;
import todod.random;
import todod.set;
import todod.shell;
import todod.storage;
import todod.tag;

/// A Todo
class Todo {
	UUID id; /// id is mainly used for syncing with habitrpg

	Date[] progress; /// Keep track of how long/often we've worked on this

	Tags tags;

	Date creation_date;
	Date due_date;

	double weight = 1; /// Weight/priority of this Todo

	private this() {}

	this( string tle ) { 
		auto tup = parseAndRemoveTags( tle );
		tags = tup[0].add_tags;

		auto date_tup = parseAndRemoveDueDate( tup[1] );
		due_date = date_tup[0];

		creation_date = Date.now;
		mytitle = date_tup[1];

		id = randomUUID;
	}

	@property string title() const {
		return mytitle;
	}

	override bool opEquals(Object t) const {
		auto td = cast(Todo)(t);
		return mytitle == td.mytitle;
	}

	override int opCmp(Object t) const { 
		auto td = cast(Todo)(t);
		if ( this == td )
			return 0;
		else if ( title < td.title )
			return -1;
		return 1;
	}

	private:
		string mytitle;
}

unittest {
	Todo t1 = new Todo( "Todo 1" );
	assert( t1.title == "Todo 1" );
	assert( !t1.id.empty );

	Todo t2 = new Todo( "Bla 1 +tag1 -tag2" );
	assert( t2.title == "Bla 1" );
	assert( t2.tags[0] == Tag("tag1") );

	Todo t3 = new Todo( "+tag1 Bla 1 -tag2" );
	assert( t3.title == "Bla 1" );
	assert( t3.tags[0] == Tag("tag1") );

	assert( t1.weight == 1 );
}

string toString( const Todo t ) {
	return t.title ~ " " ~ to!string( t.tags );
}

JSONValue toJSON( Todo t ) {
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
	jsonTODO["weight"] = t.weight;
	return JSONValue( jsonTODO );	
}

Todo toTodo( const JSONValue json ) {
	Todo t = new Todo();
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
	if ("weight" in jsonAA) {
		if (jsonAA["weight"].type == JSON_TYPE.FLOAT) 
			t.weight = jsonAA["weight"].floating;
		else
			t.weight = cast(double)(jsonAA["weight"].integer);
	}
	return t;
}

unittest {
	Todo t1 = new Todo( "Todo 1 +tag" );
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
alias Set!Todo Todos;

unittest {
	auto ts = generateSomeTodos;
	assert( ts[1].tags.length == 3 );
	ts[1].tags.add( Tag( "tag5" ) );
	assert( ts[1].tags.length == 4 );
}

/**
	Select a weighted random set of Todos
	*/
Todo[] random( Todos ts, TagDelta selected, size_t no = 5 ) {
	if (ts.length > no) {
		return randomGillespie( ts, selected, no );
	}	
	return ts.array;
}

version(unittest) {
	Todos generateSomeTodos() {
		Todo t1 = new Todo( "Todo 1 +tag1 +tag2 +tag3" );
		Todo t2 = new Todo( "Bla +tag2 +tag4" );
		Todos mytodos;
		mytodos.add( [t2,t1] );
		return mytodos;
	}
}

unittest {
	auto mytodos = generateSomeTodos().array;
	assert(	mytodos[0].title == "Bla" );
	assert(	mytodos[1].title == "Todo 1" );
}

/// Return all existing tags
Tags allTags( Todos ts ) {
	Tags tags;
	foreach( t; ts )
		tags.add( t.tags );

	return tags;
}

unittest {
	auto ts = generateSomeTodos();
	assert( equal( ts.allTags().array, [Tag("tag1"), Tag("tag2"), 
						Tag("tag3"), Tag("tag4")] ) );
}

/**
	Tags and the number of Todos with that tag
	*/
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

/**
	Turn Todos into a string
	*/
string toString( Todos ts ) {
	string str;
	foreach( t; ts ) {
		str = str ~ toString( t ) ~ "\n";
	}
	return str;
}

/**
	Turn Todos into a JSONValue
	*/
JSONValue toJSON( Todos ts ) {
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

unittest {
	auto mytodos = generateSomeTodos();
	assert(	toJSON( mytodos ).toTodos.array[0] == mytodos.array[0] );
}

Todos loadTodos( GitRepo gr ) {
	Todos ts;
	auto todosFileName = "todos.json";
	auto content = readFile( gr.workPath, todosFileName );
	if (content != "")
		ts = toTodos( parseJSON( content ) );
	return ts;
}

void writeTodos( Todos ts, GitRepo gr ) {
	auto todosFileName = "todos.json";
	writeToFile( gr.workPath, todosFileName, toJSON( ts ).toPrettyString );
	commitChanges( gr, todosFileName, "Updating todos file" );
}
