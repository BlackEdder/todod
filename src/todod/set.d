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
