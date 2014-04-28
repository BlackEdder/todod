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

version (unittest) {
	import std.stdio;
}

struct Tag {
	string name;
	UUID id; /// id is mainly used for syncing with habitrpg

	this( string tag_name ) {
		name = tag_name;
	}

	void opAssign( string tag_name ) {
		name = tag_name;
		id = UUID();
	}

	unittest {
		Tag tag;
		tag.id = randomUUID;
		tag = "tag1";
		assert( tag.name == "tag1" );
		assert( tag.id.empty );
	}

	/// If either id is uninitialized (empty) compare on name, otherwise on id
	bool opEquals()(auto ref const Tag other_tag) const {
		if (id.empty || other_tag.id.empty)
			return name == other_tag.name;
		else
			return id == other_tag.id;
	}

	unittest {
		Tag tag1;
		tag1 = "tag1";

		Tag tag2;
		tag2 = "tag2";

		assert( tag1 != tag2 );
		tag1.id = randomUUID;
		assert( tag1 != tag2 );
		tag2.id = tag1.id;
		assert( tag1 == tag2 );

		tag1 = "tag1";
		tag2 = "tag1";

		assert( tag1 == tag2 );
		tag1.id = randomUUID;
		assert( tag1 == tag2 );
		tag2.id = randomUUID;
		assert( tag1 != tag2 );
	}

	int opCmp(ref const Tag other_tag ) const { 
		if ( this == other_tag )
			return 0;
		else if ( name < other_tag.name )
			return -1;
		return 1;
	}

	unittest {
		Tag tag1;
		tag1 = "tag1";

		Tag tag2;
		tag2 = "tag2";

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
	const nothrow size_t toHash()
	{ 
		size_t hash;
		if ( id.empty  )
			foreach (char c; name)
				hash = (hash * 9) + c;
		else
			id.toHash;
	
		return hash;
	}
	
	unittest {
		// Do uniq and sort work properly?
		Tag tag1;
		tag1 = "tag1";
		Tag tag2;
		tag2 = "tag2";
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

	JSONValue opCast( T : JSONValue )() const {
		JSONValue[string] json;
		json["name"] = name;
		json["id"] = id.toString;
		return JSONValue( json );
	}

	unittest {
		Tag tag1;
		tag1 = "tag1";
		assert( to!JSONValue( tag1 )["name"].str == "tag1" );
	}

	static Tag parseJSON( const JSONValue json ) {
		Tag tag;
		tag.id = parseUUID( json["id"].str );
		tag.name = json["name"].str;
		return tag;
	}

	unittest {
		Tag tag1;
		tag1 = "tag1";
		assert( parseJSON(to!JSONValue( tag1 )).name == "tag1" );
	}
}

struct TagDelta {
	Tags add_tags;
	Tags delete_tags;
}

/// A sorted, unique set implementation for Tags
/// Currently based on simple list, so not very efficient
struct Tags {
	void add( Tag tag ) {
		auto tags = myTags.find( tag );
		if ( tags.empty ) {
			myTags ~= tag;
			sort( myTags );
		} else if (!tag.id.empty) {
			tags[0].id = tag.id; // Prefer the tag if it has an id attached to it
		}
	}

	unittest { // Test for doubles
		Tags tgs;
		Tag tag3 = "tag3";
		tgs.add( tag3 );
		Tag tag4 = "tag4";
		tgs.add( tag4 );
		assert( equal( tgs.array, [ tag3, tag4 ] ) );
		assert( tgs.length == 2 );

		// Doubles
		tgs.add( tag3 );
		assert( equal( tgs.array, [ tag3, tag4 ] ) );
		assert( tgs.length == 2 );

		// Sorted
		Tag tag2 = "tag2";
		tgs.add( tag2 );
		assert( equal( tgs.array, [ tag2, tag3, tag4 ] ) );
		assert( tgs.length == 3 );

		tag2.id = randomUUID;
		assert( tgs.array.front.id.empty );
		tgs.add( tag2 );
		assert( !tgs.array.front.id.empty );
		assert( tgs.length == 3 );
	}

	void add(RANGE)(RANGE tags ) {
		// TODO optimize this since both ranges are sorted
		foreach (tag; tags)
			add( tag );
	}

	void remove( Tag tag ) {
		auto i = countUntil( myTags, tag );
		if (i != -1)
			myTags = myTags[0..i] ~ myTags[i+1..$];
	}

	void remove(RANGE)( RANGE tags ) {
		// TODO optimize this since both ranges are sorted
		foreach (tag; tags)
			remove( tag );
	}


	Tag[] array() {
		return myTags;
	}

	unittest {
		Tags tgs;
		Tag tag3 = "tag3";
		tgs.add( tag3 );
		Tag tag4 = "tag4";
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

	public int opApply(int delegate(ref Tag) dg) {
		int res = 0;
		foreach( ref tag; myTags ) {
			res = dg(tag);
			if (res) return res;
		}
		return res;
	}

	public int opApply(int delegate(ref const Tag) dg) const {
		int res = 0;
		foreach( tag; myTags ) {
			res = dg(tag);
			if (res) return res;
		}
		return res;
	}

	ref Tag opIndex(size_t id) {
		return myTags[id];
	}

	bool canFind( const Tag compareTag ) const {
		foreach ( const tag; this ) {
			if (tag == compareTag )
				return true;
		}
		return false;
	}

	size_t length() {
		return myTags.length;
	}

	private:
		Tag[] myTags;
}
