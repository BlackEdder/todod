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

module todod.habitrpg;

import std.net.curl;
import std.conv;
import std.algorithm;
import std.array; 
import core.thread;
import std.encoding;

import std.stdio;
import std.file;

import std.json;

import std.uuid;
import todod.tag;
import todod.commandline;
import todod.todo;

version (unittest) {
	import std.stdio;
}

struct HabitRPG {
	string api_user = "-1";
	string api_key = "-1";

	bool opCast( T : bool )() const {
		if ( api_user == "-1" || api_key == "-1" )
			return false;
		return true;
	}
}

/// Read HabitRPG settings from config file
HabitRPG loadHRPG( string fileName ) {
	HabitRPG hrpg;
	if (exists( fileName )) {
		File file = File( fileName, "r" );
		auto content = file.readln();
		if (content != "") {
			auto json = parseJSON( content );
			hrpg.api_user = json["api_user"].str;
			hrpg.api_key = json["api_key"].str;
		}
	} else {
		// Create empty config file.
		JSONValue[string] jsonHRPG;
		jsonHRPG["api_user"] = hrpg.api_user;
		jsonHRPG["api_key"] = hrpg.api_key;
		auto json = JSONValue( jsonHRPG );
		File file = File( fileName, "w" );
		file.write( json.toString );
	}
	return hrpg;
}

HTTP connectHabitRPG( HabitRPG hrpg ) {
	assert( hrpg, "Need to provide a valid HabitRPG struct" );
	auto http = HTTP( "https://habitrpg.com/" );
	http.addRequestHeader( "x-api-user", hrpg.api_user );
	http.addRequestHeader( "x-api-key", hrpg.api_key );
	http.addRequestHeader( "Content-Type","application/json" );
	return http;
}

string upHabit( const HabitRPG hrpg, string habit ) {
	string result;

	if (hrpg) {
		auto http = connectHabitRPG( hrpg );
		auto url = "https://habitrpg.com/api/v2/user/tasks/" ~ habit ~ "/up";
		http.postData = "";
		http.method = HTTP.Method.post;
		http.url = url;
		http.onReceive = (ubyte[] data) { 
			result ~= array( map!(a => cast(char) a)( data ) );
			return data.length; 
		};

		http.perform();
	}

	return result;
}

void putMessage( HabitRPG hrpg, string url, string msg ) {
	auto http = connectHabitRPG( hrpg );
	http.method = HTTP.Method.put;
	http.url = url;
	http.contentLength = msg.length;
	http.onSend = (void[] data)
	{
		auto m = cast(void[])msg;
		size_t len = m.length > data.length ? data.length : m.length;
		if (len == 0) return len;
		data[0..len] = m[0..len];
		msg = msg[len..$];
		return len;
	};
	http.perform();
}

void postMessage( HabitRPG hrpg, string url, string msg ) {
	auto http = connectHabitRPG( hrpg );
	http.method = HTTP.Method.post;
	http.url = url;
	http.contentLength = msg.length;
	http.onSend = (void[] data)
	{
		auto m = cast(void[])msg;
		size_t len = m.length > data.length ? data.length : m.length;
		if (len == 0) return len;
		data[0..len] = m[0..len];
		msg = msg[len..$];
		return len;
	};
	http.perform();
}

void postNewTag( HabitRPG hrpg, Tag tag )
	in {
		assert( !tag.id.empty, "Tag UUID needs to be initialized" );
	}
body {
	postMessage( hrpg, "https://habitrpg.com/api/v2/user/tags",
			tag.to!JSONValue.toString);
}

/// Sync tags with habitrpg. Ensures all tag ids are set properly and returns
/// list of all tags know to habitrpg
Tags syncTags( Tags tags, HabitRPG hrpg )
in 
{
	assert( hrpg );
}
body
{
	// Get tags from habitrpg
	auto http = connectHabitRPG( hrpg );
	auto url = "https://habitrpg.com/api/v2/user/";
	http.url = url;
	string result;

	http.method = HTTP.Method.get;
	http.onReceive = (ubyte[] data) { 
		result ~= array( map!(a => cast(char) a)( data ) );
		return data.length; 
	};

	http.perform();

	Tags hrpgTags;

	auto tagsJSON = parseJSON( result )["tags"].array;
	foreach ( tag; tagsJSON ) {
		hrpgTags.add( Tag.parseJSON( tag ) );
	}

	// Remove those tags from all todo tags
	tags.remove( hrpgTags );

	// Push all tags to habitrpg (and set id)
	foreach( tag; tags ) {
		// Create new tag id
		if ( tag.id.empty )
			tag.id = randomUUID();
		postNewTag( hrpg, tag );
	}

	tags.add( hrpgTags );
	return tags;
}

/// Convert Todo toHabitRPGJSON
/// Needs a copy of all tags to check habitrpg ids etc
string toHabitRPGJSON( const Todo todo, const Tags tags ) {
	JSONValue[string] json;
	json["text"] = todo.title;
	//json["dateCreated"] = todo.creation_date.toString; // Need to convert to proper format
	json["type"] = "todo";
	return JSONValue( json ).toString;
}

Todos syncTodos( Todos ts, HabitRPG hrpg ) 
in 
{
	assert( hrpg );
}
body
{
	// Needed for tag ids for all todos 
	Tags tags = syncTags( ts.allTags, hrpg );

	auto hrpgTodos = new Todos();
	auto filters = ts.filters;
	ts.filters = default_filters;
	foreach( todo; ts )
		hrpgTodos.add( ts );
	ts.filters = filters;

	// Get all habitrpg tasks of type Todo
	auto http = connectHabitRPG( hrpg );
	auto url = "https://habitrpg.com/api/v2/user/tasks";
	http.url = url;
	string result;

	http.method = HTTP.Method.get;
	http.onReceive = (ubyte[] data) { 
		result ~= array( map!(a => cast(char) a)( data ) );
		return data.length; 
	};

	http.perform();

	foreach ( task; parseJSON( result ).array ) {
		if ( task["type"].str == "todo"
				&& task["completed"].type == JSON_TYPE.FALSE) {
			// Convert to Todo
			auto todo = Todo( task["text"].str );
			// Remove from hrpgTodos
			hrpgTodos.remove( todo );
			ts.add( todo );
		}
	}

	// Foreach hrpgTodos still in the list
	foreach ( todo; hrpgTodos ) {
		// Convert to HabitRPGTodo ( will need to pass along tags )
		auto msg = toHabitRPGJSON( todo, tags );
		// Post new Todo
		postMessage( hrpg, url, msg );
	}
	return ts;
}

Commands!( Todos delegate( Todos, string) ) addHabitRPGCommands( 
		ref Commands!( Todos delegate( Todos, string) ) main, string dirName ) {
	HabitRPG hrpg = loadHRPG( dirName ~ "habitrpg.json" );
	if (hrpg) {
		auto habitrpg_commands = Commands!( Todos delegate( Todos, string) )("Commands specifically used to interact with HabitRPG");

		habitrpg_commands.add( 
				"tags", delegate( Todos ts, string parameter ) {
			syncTags( ts.allTags, hrpg );
			return ts;
		}, "Sync tags with HabitRPG" );

		habitrpg_commands.add( 
				"todos", delegate( Todos ts, string parameter ) {
			ts = syncTodos( ts, hrpg );
			return ts;
		}, "Sync todos (and tags) with HabitRPG" );

		habitrpg_commands.add( 
				"help", delegate( Todos ts, string parameter ) {
			ts = main["clear"]( ts, "" ); 
			writeln( habitrpg_commands.toString );
			return ts;
		}, "Print this help message" );

		main.add( 
				"habitrpg", delegate( Todos ts, string parameter ) {
				auto split = parameter.findSplit( " " );
				ts = habitrpg_commands[split[0]]( ts, split[2] );
				return ts;
				}, "Syncing with HabitRPG. Use habitrpg help for more help." );

	}
	return main;
}

/*unittest {
	HabitRPG hrpg;
	hrpg.api_user = "f55f430e-36b8-4ebf-b6fa-ad4ff552fe7e";
	hrpg.api_key = "3fca0d72-2f95-4e57-99e5-43ddb85b9780";
	Tag tag;
	tag.name = "1tag";
	tag.id = randomUUID;
	postNewTag( hrpg, tag );
}*/
