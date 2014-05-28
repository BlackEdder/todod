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

import std.container;

class Set(T) {
	this() {
		_tree = new RedBlackTree!(T)();
	}


	void add( T item ) {
		_tree.insert( item );
	}
	
	T[] array() {
		return _tree.array;
	}

	auto length() {
		return _tree.length();
	}

	private:
		RedBlackTree!(T) _tree;
}

version( unittest ) {
	import std.algorithm;
	import std.array;
	import std.conv;
	import std.range;
	import std.stdio;
}

unittest {
	auto set1 = new Set!string();
	set1.add( "ab" );
	assert( equal( set1.array, ["ab"] ) );
	auto set2 = new Set!string();
	assert( set2.length() == 0 );
}
