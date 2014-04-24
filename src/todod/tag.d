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

version (unittest) {
	import std.stdio;
}

struct Tag {
	string name;
	string id = "-1";

	void opAssign( string tag_name ) {
		name = tag_name;
		id = "-1";
	}

	unittest {
		Tag tag;
		tag.id = "1";
		tag = "tag1";
		assert( tag.name == "tag1" );
		assert( tag.id == "-1" );
	}

	bool opEquals()(auto ref const Tag other_tag) const {
		if (id == "-1" || other_tag.id == "-1")
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
		tag1.id = "1";
		assert( tag1 != tag2 );
		tag2.id = "1";
		assert( tag1 == tag2 );

		tag1 = "tag1";
		tag2 = "tag1";

		assert( tag1 == tag2 );
		tag1.id = "1";
		assert( tag1 == tag2 );
		tag2.id = "2";
		assert( tag1 != tag2 );
	}

}



