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

unittest {
	HabitRPG hrpg;
	hrpg.api_user = "f55f430e-36b8-4ebf-b6fa-ad4ff552fe7e";
	hrpg.api_key = "3fca0d72-2f95-4e57-99e5-43ddb85b9780";
	string result;
	if (hrpg) {
		auto http = connectHabitRPG( hrpg );
		http.method = HTTP.Method.get;
		auto url = "https://habitrpg.com/api/v2/user/tasks/";
		http.url = url;
		//http.verbose( true );
		http.onReceive = (ubyte[] data) { 
			result ~= array( map!(a => cast(char) a)( data ) );
			return data.length; 
		};

		http.perform();
	}

	//writeln( result );

	auto tasks = parseJSON( result ).array;

	foreach ( task; tasks ) {
		if ( task["type"].str == "todo" && task["completed"].type == JSON_TYPE.FALSE ) {
			writeln( task );
		}
	}
}
