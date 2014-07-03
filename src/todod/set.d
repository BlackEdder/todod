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

module todod.set;
import std.algorithm;
import std.array;
import std.container;
import std.json;

/// Set implemented on top of ranges. Unique and ordered (at time of adding)
struct Set(T) {
	/// Add an element to the set
	void add( E : T )( E element ) {
		auto elements = _array.find( element  );
		if ( elements.empty ) {
			_array ~= element;
			sort( _array );
		} else {
			if (!element.id.empty) // Will automatically cause sync to HabitRPG id
				elements[0].id = element.id;
		}
	}

	/// Add a range of elements
	void add(RANGE)(RANGE elements ) {
		// TODO optimize this since both ranges are sorted
		foreach (element; elements)
			add( element );
	}

	/// Remove an element from the set
	void remove(E : T)( E element ) {
		auto i = countUntil( _array, element );
		if (i != -1)
			_array = _array[0..i] ~ _array[i+1..$];
	}

	/// Remove a range of elements
	void remove(RANGE)( RANGE elements ) {
		// TODO optimize this since both ranges are sorted
		foreach (element; elements)
			remove( element );
	}

	/// Returns the front/first element of the set
	T front() {
		return _array.front;
	}

	/// Removes the front element from the set
	void popFront() {
		_array.popFront;
	}

	/// Returns true when the set is empty
	bool empty() const {
		if (_array.length > 0)
			return false;
		return true;
	}

	/// Return an array version of the set
	T[] array() {
		return _array;
	}

	/// Number of elements in the set
	size_t length() const {
		return _array.length;
	}

	/// Access by id. 
	T opIndex(size_t id) {
		return _array[id];
	}

	private:
		T[] _array;
}

unittest {
	import std.uuid;
	class Test {
		UUID id;
		this() {
			id = randomUUID;
		}

		override int opCmp( Object t ) const {
			return this.id < (cast(Test)(t)).id;
		}
	}

	Set!Test set;
	set.add( new Test );
	assert( set.length == 1 );
	set.add( [ new Test, new Test ] );
	assert( set.length == 3 );
}


/// Convert set to json array. The element needs to implement a toJSON function
JSONValue[] toJSON(T)( Set!T set ) {
	JSONValue[] json;
	foreach (t; set) 
		json ~= t.toJSON;
	return json;	
}

/// Load set from JSON, needs delegate to convert json into the element type
Set!T jsonToSet(T)( in JSONValue json, T delegate( in JSONValue ) convert ) {
	Set!T set;
	assert( json.type == JSON_TYPE.ARRAY );
	foreach ( js; json.array )
		set.add( convert( js ) );
	return set;
}

/// Convert Set to JSON given a function to convert the element type to JSON
JSONValue setToJSON( T )( Set!T set, JSONValue delegate( in T  ) convert ) {
	JSONValue[] json;
	foreach ( el; set ) {
		json ~= convert( el );
	}
	return JSONValue(json);
}
