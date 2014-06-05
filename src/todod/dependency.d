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

/// Manage dependencies between Todos (identified by their uuid)
module todod.dependency;

import std.algorithm;
import std.uuid;

/// Contains one link between child which depends on parent
struct Link {
	@disable this();

	UUID _parent; /// uuid of the parent
	UUID _child; /// uuid of the child

	/**
		Set the link with @child depending on @parent
		*/
	this( UUID parent, UUID child ) {
		_parent = parent;
		_child = child;
	}

	unittest {
		auto prnt = randomUUID;
		auto chld = randomUUID;
		auto lnk = Link( prnt, chld );
		assert( lnk._parent == prnt );
		assert( lnk._child == chld );
	}
}

alias Link[] Dependencies;

/// Is given uuid a child of anyone
bool isAChild( Dependencies deps, UUID child ) {
	return canFind!( a._child == b )( deps, child );
}

unittest {
	Dependencies deps;
	auto child = randomUUID;
	deps ~= Link( randomUUID, child );
	deps ~= Link( randomUUID, randomUUID );
	deps ~= Link( randomUUID, randomUUID );
	assert( deps.isAChild( child ) );
	assert( !deps.isAChild( randomUUID ) );
	auto child2 = randomUUID;
	deps ~= Link( randomUUID, child2 );
	deps ~= Link( randomUUID, randomUUID );
	assert( deps.isAChild( child ) );
	assert( deps.isAChild( child2 ) );
	assert( !deps.isAChild( randomUUID ) );
}

/// Remove given uuid completely from the dependencies
Dependencies removeUUID( ref Dependencies deps, UUID theUUID ) {
	return deps;
}
