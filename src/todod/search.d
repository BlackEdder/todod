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

/// Match term to word  and return a weight based on match
double weightTermWord( string searchString, string compareWord ) {
	double scalar = levenshteinDistance( searchString, compareWord );
	double scalarLowercase = levenshteinDistance( 
			searchString.toLower, compareWord.toLower );
	size_t maxWeight = max( searchString.length, compareWord.length);
	// Weigh to be between 1 and 12.0. 
	// 6.0 is actually 12/2, with the 2 due to averaging lowercasing
	return 11.0 - 5.5*(scalar+scalarLowercase)/(maxWeight)+1;
}

// Simple comparisons
unittest {
	double w1 = weightTermWord( "bla", "bla" );
	assert( w1 > 1.0 );
	double w2 = weightTermWord( "Bla", "bla" );
	assert( w2 < w1 );
	double w3 = weightTermWord( "vla", "bla" );
	assert( w3 < w2 );
}

// Lower limit >= 1
unittest {
	double w = weightTermWord( "abcdefghijklmnopqrstuvwxyz", 
			"123456789012345678901234567890" );
	assert( w == 1.0 );
	w = weightTermWord( 
			"123456789012345678901234567890", "abcdefghijklmnopqrstuvwxyz" );
	assert( w == 1.0 );
}

/// Break sentence into words
string[] byWord( string sentence ) {
	return sentence.split( " " );
}
	
/// Search for term in sentence and return a weight based on match
///
/// Split sentence into words and apply weightTermWord
double weightTermSentence( string searchString, string compareSentence ) {
	double scalar = 1.0;
	foreach( word; compareSentence.byWord ) {
		scalar *= weightTermWord( searchString, word );
	}
	return scalar;
}

// Test search in sentence
unittest {
	assert( weightTermWord( "bla", "bla" ) ==
			weightTermSentence( "bla", "How is bla" ) );
	assert( weightTermWord( "bla", "bla" )*weightTermWord( "bla", "Bla" ) ==
			weightTermSentence( "bla", "Bla is bla" ) );

	assert( weightTermSentence( "abc", "def fgh" ) == 1.0 );
}

/// Search for term(s) in sentence and return a weight based on match
double weightSearchSentence( string searchString, string compareSentence ) {
	double scalar = 1.0;
	foreach( term; searchString.byWord ) {
		scalar *= weightTermSentence( term, compareSentence );
	}
	return scalar;
}

// Multiple search terms
unittest {
	assert( weightTermWord( "bla", "bla" )*weightTermWord( "is", "is" ) ==
			weightSearchSentence( "bla is", "How is bla" ) );
}
