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

string upHabit( const HabitRPG hrpg, string habit ) {
	string result;

	if (hrpg) {
		auto url = "https://habitrpg.com/api/v2/user/tasks/" ~ habit ~ "/up";
		auto http = HTTP( url );
		http.addRequestHeader( "x-api-user", hrpg.api_user );
		http.addRequestHeader( "x-api-key", hrpg.api_key );
		http.addRequestHeader( "Content-Type","application/json" );
		http.postData = "";
		http.method = HTTP.Method.post;
		//http.verbose( true );
		http.onReceive = (ubyte[] data) { 
			result ~= array( map!(a => cast(char) a)( data ) );
			return data.length; 
		};

		http.perform();
	}

	return result;
}

