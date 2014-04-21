module todod.habitrpg;

import std.net.curl;

version (unittest) {
	import std.stdio;
}

string user_id = "f55f430e-36b8-4ebf-b6fa-ad4ff552fe7e";
string api_token = "3fca0d72-2f95-4e57-99e5-43ddb85b9780";

unittest {
  auto content = post("https://beta.habitrpg.com/api/v2/user/tasks/productivity/up", "" ); //x-api-key: 3fca0d72-2f95-4e57-99e5-43ddb85b9780;x-api-user: f55f430e-36b8-4ebf-b6fa-ad4ff552fe7e");
	writeln( content );
	assert( true );
}


