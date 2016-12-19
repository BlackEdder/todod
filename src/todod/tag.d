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

module todod.tag;

import std.json;
import std.conv;
import std.uuid;

import std.range;
import std.array;
import std.algorithm;

import todod.set;
import todod.storage;

version (unittest) {
	import std.stdio;
}

class Tag {
	string name;
	UUID id;

	this( string tag_name ) {
		name = tag_name;
	}

	unittest {
		Tag tag = new Tag("tag1");
		tag.id = randomUUID;
		assert( tag.name == "tag1" );
		assert( !tag.id.empty );
	}

	void opAssign( string tag_name ) {
		name = tag_name;
		id = UUID();
	}

	/// If either id is uninitialized (empty) compare on name, otherwise on id
	override bool opEquals(Object t) const {
		auto otherTag = cast(Tag)(t);
		if (id.empty || otherTag.id.empty)
			return name == otherTag.name;
		else
			return id == otherTag.id;
	}

	unittest {
		Tag tag1 = new Tag( "tag1" ); 
		Tag tag2 = new Tag( "tag2" );

		assert( tag1 != tag2 );
		tag1.id = randomUUID;
		assert( tag1 != tag2 );
		tag2.id = tag1.id;
		assert( tag1 == tag2 );

		tag1 = new Tag( "tag1" );
		tag2 = new Tag( "tag1" );

		assert( tag1 == tag2 );
		tag1.id = randomUUID;
		assert( tag1 == tag2 );
		tag2.id = randomUUID;
		assert( tag1 != tag2 );
	}

	override int opCmp(Object t) const { 
		auto otherTag = cast(Tag)(t);
		if ( this == otherTag )
			return 0;
		else if ( name < otherTag.name )
			return -1;
		return 1;
	}

	unittest {
		Tag tag1 = new Tag( "tag1" ); 
		Tag tag2 = new Tag( "tag2" );

		assert( tag1 < tag2 );

		tag1 = "tag1";
		tag2 = "tag1";

		assert( !(tag1 < tag2) );
		assert( !(tag1 > tag2) );
		assert( (tag1 <= tag2) );
		assert( (tag1 >= tag2) );
	}


	/// Turn into hash used by associative arrays.
	/// Note that in rare cases (i.e. where one tag is id is initialized 
	/// and the other isn't this can lead to different hashes even though
	/// opEquals returns equal.
	override const nothrow size_t toHash()
	{ 
		if ( id.empty  ) {
			size_t hash;
			foreach (char c; name)
				hash = (hash * 9) + c;
			return hash;
		}
		else
			return id.toHash;
	}

	JSONValue toJSON() const {
		JSONValue[string] json;
		json["name"] = name;
		json["id"] = id.toString;
		return JSONValue( json );
	}

	unittest {
		Tag tag1 = new Tag( "tag1" ); 
		tag1 = "tag1";
		assert( tag1.toJSON["name"].str == "tag1" );
	}

	unittest {
		Tag tag1 = new Tag( "tag1" );
		assert( parseJSON(tag1.toJSON()).name == "tag1" );
	}

	static Tag parseJSON( in JSONValue json ) {
		Tag tag = new Tag( json["name"].str ); 
		tag.id = parseUUID( json["id"].str );
		return tag;
	}
	
	unittest {
		// Do uniq and sort work properly?
		Tag tag1 = new Tag( "tag1" ); 
		Tag tag2 = new Tag( "tag2" );

		Tag[] ts = [ tag2, tag1 ];
		sort( ts );
		assert( equal( ts, [ tag1, tag2 ] ) );

		ts = [ tag1, tag2, tag1 ];
		sort( ts );
		assert( equal( ts, [ tag1, tag1, tag2 ] ) );
		assert( equal( uniq(ts).array, [ tag1, tag2 ] ) );

		tag2.id = randomUUID;
		tag1.id = tag2.id;

		ts = [ tag1, tag2, tag1 ];
		sort( ts );
		assert( equal( ts[1].name, "tag2" ) );
		assert( equal( uniq(ts).array, [ tag1 ] ) );
	}

}

struct TagDelta {
	Tags add_tags;
	Tags delete_tags;
}

/// A sorted, unique set implementation for Tags
/// Currently based on simple list, so not very efficient
alias Tags = Set!Tag;

unittest { // Test for doubles
	Tags tgs;
	Tag tag3 = new Tag("tag3");
	tgs.add( tag3 );
	Tag tag4 = new Tag("tag4");
	tgs.add( tag4 );
	assert( equal( tgs.array, [ tag3, tag4 ] ) );
	assert( tgs.length == 2 );

	// Doubles
	tgs.add( tag3 );
	assert( equal( tgs.array, [ tag3, tag4 ] ) );
	assert( tgs.length == 2 );

	// Sorted
	Tag tag2 = new Tag("tag2");
	tgs.add( tag2 );
	assert( equal( tgs.array, [ tag2, tag3, tag4 ] ) );
	assert( tgs.length == 3 );

	// Add tag with same name, but with id set
	Tag tag5 = new Tag("tag2");
	tag5.id = randomUUID;
	assert( tgs.array.front.id.empty );
	tgs.add( tag5 );
	assert( !tgs.array.front.id.empty );
	assert( tgs.length == 3 );
}

unittest {
	Tags tgs;
	Tag tag3 = new Tag("tag3");
	tgs.add( tag3 );
	Tag tag4 = new Tag("tag4");
	tgs.add( tag4 );
	assert( equal( tgs.array, [ tag3, tag4 ] ) );
	assert( tgs.length == 2 );

	tgs.remove( tag4 );
	assert( equal( tgs.array, [ tag3 ] ) );
	assert( tgs.length == 1 );

	tgs.remove( tag4 );
	assert( equal( tgs.array, [ tag3 ] ) );
	assert( tgs.length == 1 );
}

Tags loadTags( GitRepo gr ) {
	Tags tags;

	auto tagsFileName = "tags.json";
	auto content = readFile( gr.workPath, tagsFileName );
	if (content != "")
		tags = jsonToSet!(Tag)( std.json.parseJSON( content ), 
				(js) => Tag.parseJSON(js) );
	return tags;
}

void writeTags( Tags tags, GitRepo gr ) {
	auto tagsFileName = "tags.json";
	JSONValue json = setToJSON!Tag( tags, 
			delegate( in Tag t ) {return t.toJSON();} );
	writeToFile( gr.workPath, tagsFileName, json.toPrettyString );
	commitChanges( gr, tagsFileName, "Updating tags file" );
}
