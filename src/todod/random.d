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

version( unittest ) {
	import std.stdio;
}

/// Calculate due weight based on number of dates till due
auto dueWeight( long days ) {
	double baseDays = 7; // if days == baseDays weight should return 1
	if ( days < 0 )
		return 100.0;
	else
		return exp( (log(100.0)/baseDays) * (baseDays - to!double(days)) );
}

unittest {
	assert( dueWeight( -1 ) == 100.0 );
	assert( dueWeight( 8 ) < 1.0 );
	assert( dueWeight( 7 ) == 1.0 );
	assert( dueWeight( 0 ) == 100.0 );
}

/// Weight due to progress
auto progressWeight( long days ) {
	double baseDays = 7.0; // if days == baseDays weight should return 1
	return 1.0 + (days-baseDays)*0.5/baseDays;
}

unittest {
	assert( progressWeight( 0 ) == 0.5 );
	assert( progressWeight( 7 ) == 1 );
	assert( progressWeight( 14 ) == 1.5 );
}

/// Associate a weight to a Todo depending on last progress and todo dates
auto weight( const Todo t ) {
	if ( t.due_date == true )
		return dueWeight( t.due_date.substract( Date.now ) );
	return progressWeight( lastProgress( t ) );
}

Random gen;

Todos randomGillespie( Todos ts, size_t no = 5 ) {
	void eventTodo( Gillespie gillespie, ref Todo t, event_id id ) {
		gillespie.del_event( id );
		t.random = true; 
	}

	if (ts.walkLength <= no)
		return ts;
	//Random gen = rndGen();
	auto gillespie = new Gillespie();
	foreach( ref t; ts ) {
		auto e_id = gillespie.new_event_id;
		gillespie.add_event( e_id, to!real( weight( t ) ),
				delegate() => eventTodo( gillespie, t, e_id ) );
	}

	auto sim = gillespie.simulation( gen );

	for (size_t i = 0; i < no; i++) {
		auto state = sim.front;
		state[1]();
		sim.popFront;
	}


	return ts;
}
