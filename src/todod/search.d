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

module todod.search;

import std.algorithm;
import std.string;

version( unittest ) {
	import std.stdio;
}

double weightSearchString( string searchString, string compare ) {
	double scalar = levenshteinDistance( searchString, compare );
	double scalarLowercase = levenshteinDistance( 
			searchString.toLower, compare.toLower );
	size_t maxWeight = max( searchString.length, compare.length);
	// Weigh to be between 1 and 12.0. 
	// 6.0 is actually 12/2, with the 2 due to averaging lowercasing
	return 11.0 - 5.5*(scalar+scalarLowercase)/(maxWeight)+1;
}

// Simple comparisons
unittest {
	double w1 = weightSearchString( "bla", "bla" );
	assert( w1 > 1.0 );
	double w2 = weightSearchString( "Bla", "bla" );
	assert( w2 < w1 );
	double w3 = weightSearchString( "vla", "bla" );
	assert( w3 < w2 );
}

// Lower limit >= 1
unittest {
	double w = weightSearchString( "abcdefghijklmnopqrstuvwxyz", 
			"123456789012345678901234567890" );
	assert( w == 1.0 );
	w = weightSearchString( 
			"123456789012345678901234567890", "abcdefghijklmnopqrstuvwxyz" );
	assert( w == 1.0 );
}
	
// Search in sentence ( compare every word of sentence separate )

// Multiple search terms
