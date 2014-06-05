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
struct Set(T) {
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

	void add(RANGE)(RANGE elements ) {
		// TODO optimize this since both ranges are sorted
		foreach (element; elements)
			add( element );
	}

	void remove(E : T)( E element ) {
		auto i = countUntil( _array, element );
		if (i != -1)
			_array = _array[0..i] ~ _array[i+1..$];
	}

	void remove(RANGE)( RANGE elements ) {
		// TODO optimize this since both ranges are sorted
		foreach (element; elements)
			remove( element );
	}

	T front() {
		return _array.front;
	}

	void popFront() {
		_array.popFront;
	}

	bool empty() const {
		if (_array.length > 0)
			return false;
		return true;
	}

	T[] array() {
		return _array;
	}

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

