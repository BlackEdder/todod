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

import std.math;
import std.conv;
import std.random;

import stochastic.gillespie;

import todod.todo;
import todod.date;
import todod.tag;

version( unittest ) {
	import std.stdio;
}

debug import std.stdio;

/// Calculate due weight based on number of dates till due
auto dueWeight( long days ) {
	double baseDays = 7; // if days == baseDays weight should return 1
	if ( days < 0 )
		return 5.0;
	else
		return exp( (log(5.0)/baseDays) * (baseDays - to!double(days)) );
}

unittest {
	assert( dueWeight( -1 ) == 5.0 );
	assert( dueWeight( 8 ) < 1.0 );
	assert( dueWeight( 7 ) == 1.0 );
	assert( dueWeight( 0 ) == 5.0 );
}

/// Weight due to progress
auto progressWeight( long days ) {
	double max = 3.0; // days is infinite
	double min = 0.5; // At days since last progress is 0
	double baseDays = 7.0; // if days == baseDays weight should return 1
	return max+(min-max)*exp(days*log( -(max-1)/(min-max) )/baseDays); 
}

unittest {
	assert( progressWeight( 0 ) == 0.5 );
	assert( progressWeight( 7 ) == 1 );
	assert( progressWeight( 100 ) > 2.8 && progressWeight( 100 ) < 3.0 );
}

/// Weight due to tag selection
auto tagWeightScalar( const Tags tags, TagDelta selected, double defaultScale ) {
	foreach ( tag; tags ) {
		if (selected.delete_tags.canFind( tag ))
			return 0.0;
	}
	
	double noOfTags = 0;
	foreach ( tag; tags ) {
		if (selected.add_tags.canFind( tag ))
			noOfTags++;
	}

	if (noOfTags>0) {
		double max = 3; // days is infinite
		double min = 0.75; // At days since last progress is 0
		double baseTags = 2.0; // if days == baseDays weight should return 1
		return 10.0*(max+(min-max)*exp(noOfTags*log( -(max-1)/(min-max) )/baseTags));
	}
	else return
		defaultScale;
}

/// Associate a weight to a Todo depending on last progress and todo dates
auto weight( const Todo t, TagDelta selected, double defaultScale ) {
	double tw = tagWeightScalar( t.tags, selected, defaultScale );
	if ( t.due_date )
		return tw * dueWeight( t.due_date.substract( Date.now ) );
	return tw * progressWeight( lastProgress( t ) );
}


Todo[] randomGillespie( Todos ts, TagDelta selected, size_t no = 5 ) 
in {
	assert( ts.length >= no );
}
body {
	Todo[] selectedTodos;
	auto gen = Random( unpredictableSeed );
	void eventTodo( Gillespie gillespie, ref Todo t, event_id id ) {
		gillespie.del_event( id );
		selectedTodos ~= t;
	}

	//Random gen = rndGen();
	auto gillespie = new Gillespie();
	foreach( ref t; ts ) {
		auto e_id = gillespie.new_event_id;
		gillespie.add_event( e_id, 
				to!real( weight( t, selected, 1.0/ts.length ) ),
				delegate() => eventTodo( gillespie, t, e_id ) );
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
