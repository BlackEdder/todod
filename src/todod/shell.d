module todod.shell;

import std.stdio;
import std.array;
import std.range;
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

Todo applyTags( ref Todo td, TagDelta delta ) {
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
	td = applyTags( td, delta );
	assert( equal( td.tags, ["tag1", "tag2"] ) );
	td = applyTags( td, delta );
	assert( equal( td.tags, ["tag1", "tag2"] ) );
	delta.delete_tags = ["tag3", "tag1"];
	td = applyTags( td, delta );
	assert( equal( td.tags, ["tag2"] ) );
}

string[] parseSearchForTags( string str ) {
	string[] tags;
	auto matches = matchAll( str, r"tag:([A-z0-9]+)(?:$|\s)" );
	foreach ( hit; matches )
		tags ~= hit[1];
	return tags;
}

unittest {
	auto tags = parseSearchForTags( " bbla tag:tag1 tg tag:tag2" );
	assert( equal( tags, ["tag1","tag2"] ) );
}

/// Range that either returns elements from the array targets or returns infinitively increasing range (when all is set)
struct Targets {
	bool all = false;
	int[] targets;
	int count = 0;

	@property bool empty() const
	{
		if (all)
			return false;
		else 
			return targets.empty;
	}

	@property int front()  const
	{
		if (all)
			return count;
		else
			return targets.front();
	}
	void popFront() 
	{
		if (all)
			count++;
		else
			targets.popFront;
	}
}

/// Convert all or 1,.. into Targets
Targets parseTarget( string target ) {
	int[] targets;
	Targets ts;
	auto last_term = matchFirst( target, r"\S+$" )[0];
	if (match(last_term, r"(\d+,*){1,}$")) {
		auto map_result = (map!(a => to!int( a ))( split( last_term, regex(",")) ));
		foreach( a; map_result )
			targets ~= a;
		targets.sort;
	} else if ( last_term == "all" ) {
		ts.all = true;
		return ts;
	}
	ts.targets = targets;
	return ts;
}

unittest {
	auto targets = parseTarget( "bla 2" );
	assert( equal( targets.take(2), [2] ) );
	targets = parseTarget( "bla 2,1" );
	assert( equal( targets, [1,2] ) );

	targets = parseTarget( "bla 2,a" );
	assert( targets.walkLength == 0 );
	targets = parseTarget( "bla all" );
	assert( equal(targets.take(5), [0,1,2,3,4]) );

	targets = parseTarget( "bla" );
	assert( targets.take(5).walkLength == 0 );
}
