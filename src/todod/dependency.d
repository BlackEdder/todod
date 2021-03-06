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
import std.json;
import std.uuid;

import todod.storage;

version( unittest ) {
	import std.stdio;
}

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

JSONValue toJSON( Link link ) {
	JSONValue[string] jsonLink;
	jsonLink["parent"] = link._parent.toString;
	jsonLink["child"] = link._child.toString;
	return JSONValue( jsonLink );	
}

Link toLink( const JSONValue json ) {
	Link link = Link( UUID(), UUID() );
	const JSONValue[string] jsonAA = json.object;
	if ("parent" in jsonAA)
		link._parent = UUID( jsonAA["parent"].str );
	if ("child" in jsonAA)
		link._child = UUID( jsonAA["child"].str );
	return link;
}

unittest {
	Link orig = Link( randomUUID, randomUUID );
	auto json = toJSON( orig );
	Link link = toLink( json );
	assert( link._parent == orig._parent );
	assert( link._child == orig._child );
}

alias Dependencies = Link[];

/// Is given uuid a child of anyone
bool isAChild( in Dependencies deps, in UUID child ) {
	return canFind!( (a,b) => a._child == b )( deps, child );
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
	Dependencies result;
	foreach( lnk; deps ) // Ideally use remove!pred, but for some reason that did
											 // not work properly
		if ( lnk._child != theUUID && lnk._parent != theUUID )
			result ~= lnk;
	return result; 
}

unittest {
	Dependencies deps;
	auto child = randomUUID;
	auto parent = randomUUID;
	deps ~= Link( randomUUID, child );
	deps ~= Link( parent, randomUUID );
	deps ~= Link( randomUUID, randomUUID );
	assert( deps.length == 3 );
	deps = removeUUID( deps, child );
	assert( deps.length == 2 );
	assert( removeUUID( deps, parent ).length == 1 );
}

/// Group the parents in the dependencies by child.
UUID[][UUID] groupByChild( in Dependencies deps ) pure nothrow {
	UUID[][UUID] groups;
	foreach( link; deps )
		groups[link._child] ~= link._parent;
	return groups;
}

unittest {
	Dependencies deps;
	auto child = randomUUID;
	deps ~= Link( randomUUID, child );
	deps ~= Link( randomUUID, child );
	deps ~= Link( randomUUID, randomUUID );
	auto groups = groupByChild( deps );
	assert( child in groups );
	assert( groups[child].length == 2 );
}

JSONValue toJSON(T)( in T[] range ) {
	JSONValue[] json;
	foreach (e; range) 
		json ~= toJSON( e );
	return JSONValue( json );
}

Dependencies toDependencies( JSONValue json ) {
	Dependencies deps;
	foreach ( js; json.array )
		deps ~= toLink(js);
	return deps;
}

unittest {
	Dependencies deps;
	auto child = randomUUID;
	auto parent = randomUUID;
	deps ~= Link( randomUUID, randomUUID );
	deps ~= Link( parent, child );
	deps ~= Link( randomUUID, randomUUID );
	auto json = toJSON( deps );
	auto dps = toDependencies( json );
	assert( dps.length == 3 );
	assert( dps[1]._parent == parent );
	assert( dps[1]._child == child );
}

Dependencies loadDependencies( GitRepo gr ) {
	Dependencies deps;
	auto dependenciesFileName = "dependencies.json";
	auto content = readFile( gr.workPath, dependenciesFileName );
	if (content != "")
		deps = toDependencies( parseJSON( content ) );
	return deps;
}

void writeDependencies( Dependencies deps, GitRepo gr ) {
	auto dependenciesFileName = "dependencies.json";
	writeToFile( gr.workPath, dependenciesFileName, toJSON( deps ).toPrettyString );
	commitChanges( gr, dependenciesFileName, "Updating dependencies file" );
}
