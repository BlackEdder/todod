module todod.shell;

import std.stdio;
import std.regex;
import std.container;
import std.algorithm;
import std.conv;

import todod.todo;

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

Todo apply_tags( Todo td, TagDelta delta ) {
	td.tags ~= delta.add_tags;
	sort( td.tags );
	auto unique = uniq( sort(td.tags) );
	td.tags = [];
	foreach ( t; unique )
		td.tags ~= t;
	auto filtered = td.tags.filter!( tag => !canFind( delta.delete_tags, tag ) );
	td.tags = [];
	foreach ( t; filtered )
		td.tags ~= t;
	return td;
}

unittest {
	TagDelta delta;
	delta.add_tags = ["tag2", "tag1"];
	Todo td;
	td = apply_tags( td, delta );
	assert( equal( td.tags, ["tag1", "tag2"] ) );
	td = apply_tags( td, delta );
	assert( equal( td.tags, ["tag1", "tag2"] ) );
	delta.delete_tags = ["tag3", "tag1"];
	td = apply_tags( td, delta );
	assert( equal( td.tags, ["tag2"] ) );
}

/// Convert all or 1,.. into a list of targets
auto parseTarget( string target ) {
	// All could become infinite array?
	return [];
}
