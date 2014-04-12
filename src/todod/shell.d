module todod.shell;

import std.stdio;
import std.regex;
import std.container;
import std.algorithm;

struct TagDelta {
	string[] add_tags;
	string[] delete_tags;
}

TagDelta parseTags( string str ) {
	TagDelta td;
	auto m = matchAll( str, r"(?:^|\s)\+(\w+)" );
	foreach ( hits ; m ) {
		td.add_tags ~=  hits[1];
	}
	m = matchAll( str, r"(?:^|\s)\-(\w+)" );
	foreach ( hits ; m ) {
		td.delete_tags ~=  hits[1];
	}
	return td;
}

unittest {
	auto td = parseTags( "+tag1" );
	assert( std.algorithm.equal(td.add_tags, ["tag1"]) );
	td = parseTags( "+tag1 +tag2" );
	assert( std.algorithm.equal(td.add_tags, ["tag1", "tag2"]) );
	td = parseTags( "+tag1+tag2" );
	assert( std.algorithm.equal(td.add_tags, ["tag1"]) ); 

	// Same for negative tags
	td = parseTags( "-tag1" );
	assert( std.algorithm.equal(td.delete_tags, ["tag1"]) );
	td = parseTags( "-tag1 -tag2" );
	assert( std.algorithm.equal(td.delete_tags, ["tag1", "tag2"]) );
	td = parseTags( "-tag1-tag2" );
	assert( std.algorithm.equal(td.delete_tags, ["tag1"]) );

	td = parseTags( "-tag1+tag2" );
	assert( std.algorithm.equal(td.delete_tags, ["tag1"]) );
	assert( td.add_tags.length == 0 );
	td = parseTags( "+tag1-tag2" );
	assert( std.algorithm.equal(td.add_tags, ["tag1"]) );
	assert( td.delete_tags.length == 0 );

	td = parseTags( "-tag1 +tag2" );
	assert( std.algorithm.equal(td.delete_tags, ["tag1"]) );
	assert( std.algorithm.equal(td.add_tags, ["tag2"]) ); 
	td = parseTags( "+tag1 -tag2" );
	assert( std.algorithm.equal(td.delete_tags, ["tag2"]) );
	assert( std.algorithm.equal(td.add_tags, ["tag1"]) ); 
}
