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

module todod.random;

import std.algorithm;
import std.conv;
import std.file;
import std.json;
import std.math;
import std.random;
import std.stdio;

import stochastic.gillespie;

import todod.todo;
import todod.date;
import todod.dependency;
import todod.search;
import todod.tag;

version( unittest ) {
	import std.stdio;
}


double[string] setDefaultWeights() {
	return [ "defaultTagWeight": 0.0, "selectedTagWeight": 12.0,
				 "deselectedTagWeight": 0.0];
}

double[string] loadDefaultWeights( string fileName ) { 
	auto weights = setDefaultWeights;
	bool needUpdate = !exists( fileName );
	if (!needUpdate) {
		File file = File( fileName, "r" );
		string content;
		foreach( line; file.byLine() )
			content ~= line;
		if (content != "") {
			JSONValue[string] json = parseJSON( content ).object;
			foreach( k, v ; weights ) {
				if ( k in json ) {
					if (json[k].type == JSON_TYPE.INTEGER)
						weights[k] = to!double(json[k].integer);
					else
						weights[k] = json[k].floating;
				} else {
					needUpdate = true; // Missing value in weights file
				}
			}
		} else {
			needUpdate = true;
		}
	} 
	if (needUpdate) {
		// Create or update incomplete config file.
		JSONValue[string] jsonW;
		foreach( k, v ; weights ) {
			jsonW[k] = JSONValue( v );
		}
		auto json = JSONValue( jsonW );
		File file = File( fileName, "w" );
		file.writeln( json.toPrettyString );
	}
	return weights; }

/// Calculate due weight based on number of dates till due
auto dueWeight( long days ) {
	double baseDays = 7; // if days == baseDays weight should return 1
	if ( days < 0 )
		return 16.0;
	else
		return exp( (log(16.0)/baseDays) * (baseDays - to!double(days)) );
}

unittest {
	assert( dueWeight( -1 ) == 16.0 );
	assert( dueWeight( 8 ) < 1.0 );
	assert( dueWeight( 7 ) == 1.0 );
	assert( dueWeight( 0 ) == 16.0 );
}

/// Weight due to progress
auto progressWeight( long days ) {
	double max = 4.0; // days is infinite
	double min = 0.5; // At days since last progress is 0
	double baseDays = 7.0; // if days == baseDays weight should return 1
	return max+(min-max)*exp(days*log( -(max-1)/(min-max) )/baseDays); 
}

unittest {
	assert( progressWeight( 0 ) > 0.49 );
	assert( progressWeight( 0 ) < 0.51 );
	assert( progressWeight( 7 ) > 0.99 );
	assert( progressWeight( 7 ) < 1.01 );
	assert( progressWeight( 100 ) > 3.5 && progressWeight( 100 ) < 4.0 );
}

/// Weight due to tag selection
auto tagWeightScalar( Tags tags, TagDelta selected,
	size_t noTodos, size_t[Tag] tagNo, in double[string] defaultWeights ) {
	foreach ( tag; tags ) {
		if (selected.delete_tags.canFind( tag ))
			return defaultWeights["deselectedTagWeight"];
	}

	double scalar = 0;
	if (tags.length == 0 && selected.add_tags.length == 0 
			&& defaultWeights["defaultTagWeight"] == 0)
		scalar = 1;
	foreach ( tag; tags ) {
			// If no tags are selected and default weight is zero set tag weight to 1. This means that if nothing is selected we will get
		// random normal flags
		if (selected.add_tags.length == 0 && defaultWeights["defaultTagWeight"] == 0) {
			scalar = 1;
		} else if (selected.add_tags.canFind( tag )) {
			if (scalar == 0) {
				scalar = defaultWeights["selectedTagWeight"]*
					(to!double(noTodos))/tagNo[ tag ];
			} else {
				scalar = scalar*defaultWeights["selectedTagWeight"]*
					(to!double(noTodos))/tagNo[ tag ];
			}
		}
	}
	if (scalar == 0)
		scalar = defaultWeights["defaultTagWeight"];

	return scalar;
}

unittest {
	Tags tags;
	TagDelta selected;
	size_t[Tag] noTags;
	assert( tagWeightScalar( tags, selected, 3, noTags, setDefaultWeights ) > 0 );
	selected.add_tags.add(new Tag("bla"));
	assert( tagWeightScalar( tags, selected, 3, noTags, setDefaultWeights ) == 0 );
}

/// Associate a weight to a Todo depending on last progress and todo dates
auto weight( Todo t, TagDelta selected, string searchString,
		size_t noTodos, size_t[Tag] tagNo, in Dependencies deps,
		in double[string] defaultWeights ) {
	if ( deps.isAChild( t.id ) )
		return 0;
	double tw = t.weight*tagWeightScalar( t.tags, selected, noTodos, tagNo, 
			defaultWeights );
	// Search by string;
	tw *= pow( defaultWeights["selectedTagWeight"], weightSearchSentence( searchString, t.title ) );

	if ( t.due_date )
		return tw * dueWeight( t.due_date.substract( Date.now ) );
	return tw * progressWeight( lastProgress( t ) );
}

/** 
	Randomly draw todos from the given Todo list.

	Todos with a higher weight (influenced by due date, currently selected tags and
	last progress) have a higher probability of being drawn.
	*/
Todo[] randomGillespie( Todos ts, Tags allTags, TagDelta selected,
		string searchString,
		in Dependencies deps,
		in double[string] defaultWeights,
		size_t no = 5 ) 
in {
	assert( ts.length >= no );
}
body {
	Todo[] selectedTodos;
	auto gen = Random( unpredictableSeed );
	auto eventTodo(T)( Gillespie!(T) gillespie, Todo t, EventId id ) {
		return { gillespie.delEvent( id );
			selectedTodos ~= t; };
	}

	//Random gen = rndGen();
	auto gillespie = new Gillespie!(void delegate())();
	foreach( t; ts ) {
		auto e_id = gillespie.newEventId;
		gillespie.addEvent( e_id, 
				to!real( weight( t, selected, searchString, ts.length, 
						ts.tagOccurence( allTags ), deps,
						defaultWeights ) ),
				eventTodo( gillespie, t, e_id ) );
	}

	if (gillespie.rate == 0)
		return selectedTodos;

	auto sim = gillespie.simulation( gen );

	for (size_t i = 0; i < no; i++) {
		auto state = sim.front;
		state[1]();
		if (gillespie.rate == 0)
			break;
		sim.popFront;
	}


	return selectedTodos;
}

unittest {
	Todos ts;
	ts.add( new Todo( "Todo1" ) );
	ts.add( new Todo( "Todo2" ) );
	ts.add( new Todo( "Todo3" ) );
	TagDelta selected;
	Dependencies deps;
	assert( randomGillespie( ts, ts.allTags, selected, "", deps, 
				setDefaultWeights(), 2 ).length == 2 );
}
