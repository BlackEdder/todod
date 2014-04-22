module todod.habitrpg;

import std.net.curl;
import std.conv;
import std.algorithm;
import std.array; 
import core.thread;
import std.encoding;

version (unittest) {
	import std.stdio;
}

string user_id = "f55f430e-36b8-4ebf-b6fa-ad4ff552fe7e";
string api_token = "3fca0d72-2f95-4e57-99e5-43ddb85b9780";

unittest {
	auto http = HTTP( "https://habitrpg.com/api/v2/user/tasks/productivity/up" );
	http.addRequestHeader( "x-api-user", user_id );
	http.addRequestHeader( "x-api-key", api_token );
	http.addRequestHeader( "Content-Type","application/json" );
	http.postData = "";
	http.method = HTTP.Method.post;
	http.verbose( true );

	string result;
	http.onReceive = (ubyte[] data) { 
		auto result = array( map!(a => cast(char) a)( data ) );
		writeln( result );

		return data.length; };

	http.perform();

	writeln( result );

	assert( true );
}


