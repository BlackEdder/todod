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

module todod.shell;

import std.stdio;
import std.array;
import std.range;

import std.string;
import std.regex;
import std.container;
import std.algorithm;
import std.conv;

import todod.commandline;
import todod.date;
import todod.dependency;
import todod.random;
import todod.state;
import todod.tag;
import todod.todo;

auto addTagRegex = regex(r"(?:^|\s)\+(\w+)");
auto delTagRegex = regex(r"(?:^|\s)\-(\w+)");
auto allTagRegex = regex(r"(?:^|\s)[+-](\w+)");

unittest {
	assert( match( "+tag", addTagRegex ) );
	assert( !match( "-tag", addTagRegex ) );
	assert( match( "bla +tag bla", addTagRegex ) );
	assert( !match( "bla+tag", addTagRegex ) );

	assert( !match( "+tag", delTagRegex ) );
	assert( match( "-tag", delTagRegex ) );
	assert( match( "bla -tag blaat", delTagRegex ) );
	assert( !match( "bla-tag", delTagRegex ) );

	assert( match( "+tag", allTagRegex ) );
	assert( match( "-tag", allTagRegex ) );
	assert( match( "bla -tag", allTagRegex ) );
	assert( !match( "bla-tag", allTagRegex ) );
}

auto parseAndRemoveTags( string str ) {
	TagDelta td;
	auto m = matchAll( str, addTagRegex );
	foreach ( hits ; m ) {
		td.add_tags.add( new Tag( hits[1] ) );
	}
	m = matchAll( str, delTagRegex );
	foreach ( hits ; m ) {
		td.delete_tags.add( new Tag( hits[1] ) );
	}
	
	// Should be possible to do matching 
	// and replacing with one call to replaceAll!( dg ) but didn't
	// work for me
	str = replaceAll( str, allTagRegex, "" );
	// Replace multiple spaces
	str = replaceAll( str, regex(r"(?:^|\s) +"), "" );
	return tuple(td, str);
}



TagDelta parseTags( string str ) {
	TagDelta td;
	auto m = matchAll( str, addTagRegex );
	foreach ( hits ; m ) {
		td.add_tags.add( new Tag( hits[1] ) );
	}
	m = matchAll( str, delTagRegex );
	foreach ( hits ; m ) {
		td.delete_tags.add( new Tag( hits[1] ) );
	}
	return td;
}

unittest {
	auto td = parseTags( "+tag1" );
	assert( std.algorithm.equal(td.add_tags.array, [new Tag("tag1")]) );
	td = parseTags( "+tag1 +tag2" );
	assert( std.algorithm.equal(td.add_tags.array, [new Tag("tag1"),
				new Tag("tag2")]) );
	td = parseTags( "+tag1+tag2" );
	assert( std.algorithm.equal(td.add_tags.array, [new Tag("tag1")]) ); 

	// Same for negative tags
	td = parseTags( "-tag1" );
	assert( std.algorithm.equal(td.delete_tags.array, [new Tag("tag1")]) );
	td = parseTags( "-tag1 -tag2" );
	assert( std.algorithm.equal(td.delete_tags.array, [new Tag("tag1"), 
				new Tag("tag2")]) );
	td = parseTags( "-tag1-tag2" );
	assert( std.algorithm.equal(td.delete_tags.array, [new Tag("tag1")]) );

	td = parseTags( "-tag1+tag2" );
	assert( std.algorithm.equal(td.delete_tags.array, [new Tag("tag1")]) );
	assert( td.add_tags.length == 0 );
	td = parseTags( "+tag1-tag2" );
	assert( std.algorithm.equal(td.add_tags.array, [new Tag("tag1")]) );
	assert( td.delete_tags.length == 0 );

	td = parseTags( "-tag1 +tag2" );
	assert( std.algorithm.equal(td.delete_tags.array, [new Tag("tag1")]) );
	assert( std.algorithm.equal(td.add_tags.array, [new Tag("tag2")]) ); 
	td = parseTags( "+tag1 -tag2" );
	assert( std.algorithm.equal(td.delete_tags.array, [new Tag("tag2")]) );
	assert( std.algorithm.equal(td.add_tags.array, [new Tag("tag1")]) ); 
}

/// Return tuple witch string with due date removed. Due date is something along
/// D2014-01-12
auto parseAndRemoveDueDate( string str ) {
	// Due dates
	auto date_regex = regex( r"D(\d\d\d\d-\d\d-\d\d)" );
	Date dt;
	auto due_m = matchFirst( str, date_regex );
	if (due_m) {
		dt = Date( due_m.captures[1] );
		str = replaceAll( str, date_regex, "" );
	} else {
		date_regex = regex( r"(?:^|\s)D\+(\d+)" );
		due_m = matchFirst( str, date_regex );
		if (due_m) {
			dt = Date.now;
			dt.addDays( to!long( due_m.captures[1] ) );
			str = replaceAll( str, date_regex, "" );
		}
	}
	// Replace multiple spaces
	str = replaceAll( str, regex(r"(?:^|\s) +"), "" );
	return tuple( dt, str );
}

unittest {
	auto tup = parseAndRemoveDueDate( "D2014-01-12" );
	assert( tup[0].substract( Date( "2014-01-08" ) ) == 4 );
	assert( tup[1] == "" );

	tup = parseAndRemoveDueDate( "Bla D2014-01-12" );
	assert( tup[0].substract( Date( "2014-01-08" ) ) == 4 );
	assert( tup[1] == "Bla " );

	tup = parseAndRemoveDueDate( "Bla" );
	assert( !tup[0] );
	assert( tup[1] == "Bla" );
}

/// Return date from string. Date is something along 2014-01-12
auto parseDate( string str, Date from = Date.now ) {
	// Due dates
	auto date_regex = regex( r"(\d\d\d\d-\d\d-\d\d)" );
	Date dt;
	auto due_m = matchFirst( str, date_regex );
	if (due_m) {
		dt = Date( due_m.captures[1] );
		return dt;
	} else {
		due_m = matchFirst( str, r"(?:^|\s|D)\+(\d+)" );
		if (due_m) {
			from.addDays( to!long( due_m.captures[1] ) );
		}
		return from.dup;
	}
}

unittest {
	auto fromDate = Date("2014-01-16");
	auto dt = parseDate( "Bla +4 Bla", fromDate );
	assert( dt.substract( fromDate ) == 4 );

	dt = parseDate( "Bla D+31 Bla", fromDate );
	assert( dt.substract( fromDate ) == 31 );

	dt = parseDate( "+11 Bla", fromDate );
	assert( dt.substract( fromDate ) == 11 );
}



Todo applyTags( Todo td, TagDelta delta ) {
	td.tags.add( delta.add_tags );
	td.tags.remove( delta.delete_tags );
	return td;
}

unittest {
	TagDelta delta;
	delta.add_tags.add( [new Tag("tag2"), new Tag("tag1")] );
	Todo td = new Todo("Todo1"); 
	td = applyTags( td, delta );
	assert( equal( td.tags.array, [new Tag("tag1"), new Tag("tag2")] ) );
	td = applyTags( td, delta );
	assert( equal( td.tags.array, [new Tag("tag1"), new Tag("tag2")] ) );
	delta.delete_tags.add( [new Tag("tag3"), new Tag("tag1")] );
	td = applyTags( td, delta );
	assert( equal( td.tags.array, [new Tag("tag2")] ) );
}

/// Wrap string in color used for tags
string tagColor( string str ) {
	return "\033[1;31m" ~ str ~ "\033[0m";
}

/// Wrap string in color used for emphasizing titles 
string titleEmphasize( string str ) {
	return "\033[3;32m" ~ str ~ "\033[0m";
}

/// Produce colored string from tags
string prettyStringTags( Tags tags ) {
	string line;
	foreach( tag; tags ) {
		line ~= tag.name ~ " ";
	}
	return tagColor( line );
}

string prettyStringTodo( Todo t ) {
	Date currentDate = Date.now;
	string description = titleEmphasize(t.title) ~ "\n";
	description ~= "\t  Tags:       " ~ prettyStringTags( t.tags ) ~"\n";
	description ~= "\t  " ~ "Last progress    " 
		~ tagColor(to!string( lastProgress( t ) ).rightJustify( 4 )) ~
		" days ago\n";

	if ( t.due_date )
		description ~= "\t  " ~ "Due in           " ~ tagColor( 
				to!string( t.due_date.substract( currentDate ) ).rightJustify( 4 ) ) 
			~ " days\n";

	return description;
}

string prettyStringTodos(RANGE)( RANGE ts, Todos allTodos, Tags allTags,
		TagDelta selected, in Dependencies deps, in double[string] defaultWeights,
		bool showWeight = false ) {
	string str;
	size_t id = 0;
	foreach( t; ts ) {
		str = str ~ to!string( id ) ~ "\t" ~ prettyStringTodo( t );
		if (showWeight)
			str ~= "Weight: " ~ to!string( weight( t, selected, allTodos.length, 
					allTodos.tagOccurence( allTags ), deps, defaultWeights ) ) ~ "\n";
		str ~= "\n";
		id++;
	}
	return str;
}

Commands!( State delegate( State, string) ) addShowCommands( 
		ref Commands!( State delegate( State, string) ) main, ref TagDelta selected, 
		in ref double[string] defaultWeights ) {
	auto showCommands = Commands!( State delegate( State, string) )(
			"Show different views. When called without parameters shows a (randomly) selected list of Todos.");

	showCommands.add( 
			"tags", delegate( State state, string parameter ) {
				writeln( prettyStringTags( state.tags ) );
				return state;
			}, "List of tags" );

	showCommands.add( 
			"dependencies", delegate( State state, string parameter ) {
				auto groups = groupByChild( state.dependencies );
				foreach ( child, parents; groups ) {
					auto childT = state.todos.find!( (a) => a.id == child );
					writeln( prettyStringTodo(childT[0]) );
					writeln( "depends on:" );
					foreach( parent; parents ) {
						auto parentT = state.todos.find!( (a) => a.id == parent );
						writeln( prettyStringTodo(parentT[0]) );
					}
					writeln("");
				}
			return state;
		}, "Show list of current dependencies." );

	showCommands.add( 
			"help", delegate( State state, string parameter ) {
			state = main["clear"]( state, "" ); 
			writeln( showCommands.toString );
			return state;
		}, "Print this help message" );

	showCommands.add(
			"weight", delegate( State state, string parameter ) {
			// Weight is actually captured in main["show"].
			// This is a dummy for help and tabcompletion
			return state; }, "Show weights for selected Todos" );

	main.add( 
			"show", delegate( State state, string parameter ) {
			state = main["clear"]( state, "" ); 
			if ( parameter == "" || parameter == "weight" ) {
				writeln( "Tags and number of todos associated with that tag." );
				auto tags = state.todos.tagOccurence( state.tags );
				foreach( tag, count; tags ) {
					if (!selected.delete_tags.canFind( tag )) {
						if (selected.add_tags.canFind( tag ))
							write( tagColor(tag.name), " (", count, "),  " );
						else
							write( tag.name, " (", count, "),  " );
					}
				}
				writeln();
				writeln();
				bool show_weight = false;
				if (parameter == "weight")
					show_weight = true;
				write( prettyStringTodos( state.selectedTodos, state.todos, state.tags, 
						selected, state.dependencies, defaultWeights, show_weight ) );
				debug {
					writeln( "Debug: Selected ", selected.add_tags );
					writeln( "Debug: Deselected ", selected.delete_tags );
				}
			}
			else {
				auto split = parameter.findSplit( " " );
				state = showCommands[split[0]]( state, split[2] );
			}
			return state;
		}, "Show different views. When called without parameters shows a (randomly) selected list of Todos. See show help for more options" );

	main.addCompletion( "show",
		delegate( string cmd, string parameter ) {
			string[] results;
			auto m = match( parameter, "^([A-z]*)$" );
			if (m) {
				// Main commands
				string[] command_keys = showCommands.commands;
				auto matchingCommands =
				filter!( a => match( a, m.captures[1] ))( command_keys );
				foreach ( com; matchingCommands ) {
					results ~= [cmd ~ " " ~ com];
				}
				}
			return results;
		}
	);
	return main;
}

/// Range that either returns elements from the array targets or returns infinitively increasing range (when all is set)
struct Targets {
	bool all = false;
	int[] targets;
	int count = 0;

	@property bool empty() const
	{
		if (all)
			return false;
		else 
			return targets.empty;
	}

	@property int front()  const
	{
		if (all)
			return count;
		else
			return targets.front();
	}
	void popFront() 
	{
		if (all)
			count++;
		else
			targets.popFront;
	}

	/// Apply a delegate to all todos specified by targets
	void apply( void delegate( ref Todo ) dg, Todo[] selectedTodos  ) {
		auto first = front;
		size_t count = 0;
		popFront;
		foreach ( ref t; selectedTodos ) {
			if (count == first) {
				dg( t );
				if ( empty )
					break;
				else {
					first = front;
					popFront;
				}
			}
			count++;
		}
	}
}

/// Convert all or 1,.. into Targets
Targets parseTarget( string target ) {
	int[] targets;
	Targets ts;
	auto last_term = matchFirst( target, r"\S+$" )[0];
	if (match(last_term, r"(\d+,*){1,}$")) {
		auto map_result = (map!(a => to!int( a ))( split( last_term, regex(",")) ));
		foreach( a; map_result )
			targets ~= a;
		targets.sort;
	} else if ( last_term == "all" ) {
		ts.all = true;
		return ts;
	}
	ts.targets = targets;
	return ts;
}

unittest {
	auto targets = parseTarget( "bla 2" );
	assert( equal( targets.take(2), [2] ) );
	targets = parseTarget( "bla 2,1" );
	assert( equal( targets, [1,2] ) );

	targets = parseTarget( "bla 2,a" );
	assert( targets.walkLength == 0 );
	targets = parseTarget( "bla all" );
	assert( equal(targets.take(5), [0,1,2,3,4]) );

	targets = parseTarget( "bla" );
	assert( targets.take(5).walkLength == 0 );
}


