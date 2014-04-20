module todod.habitrpg;

version (unittest) {
	import std.stdio;
}

struct Bla {
	this( const bool bl ){
		blaat = bl;
	}

	bool opCast(T : bool)() {
		return blaat;
	}

	public:
	bool blaat = false;
}



unittest {
	Bla bl;
	assert( !bl );
	bl = Bla( true );
	assert( bl == false );
}
