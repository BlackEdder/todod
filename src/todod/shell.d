module todod.shell;

import std.stdio;
import std.regex;

struct TagDelta {
	string[] delete_tags;
	string[] add_tags;
}

TagDelta parseTags( string str ) {
	TagDelta td;
	auto m = matchAll( str, r"(?:^|\s)\+(\w+)" );
	foreach ( hits ; m ) {
		td.add_tags ~= hits[1];
	}
	return td;
}

unittest {
	auto td = parseTags( "+tag1" );
	assert( td.add_tags == ["tag1"] );
	td = parseTags( "+tag1 +tag2" );
	assert( td.add_tags == ["tag1", "tag2"] );
	td = parseTags( "+tag1+tag2" );
	assert( td.add_tags == ["tag1"] );

	// Same for negative tags

	// If same tag is possitive and negative then ignore them
}
