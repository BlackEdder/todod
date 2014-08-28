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
import std.math;
import std.string;

version( unittest ) {
	import std.stdio;
}

/** 
	Match word to word and return a weight based on match

	Weight is between 1.0 (exact match) and 0.0 (no match)
	*/
double matchWordToWord( string searchString, string compareWord ) {
	double scalar = levenshteinDistance( searchString, compareWord );
	double scalarLowercase = levenshteinDistance( 
			searchString.toLower, compareWord.toLower );
	size_t maxWeight = max( searchString.length, compareWord.length);
	// Weigh to be between 0 and 1.0. 
	return pow(1.0 - (scalar+scalarLowercase)/(2.0*maxWeight),4);
}

// Simple comparisons
unittest {
	double w1 = matchWordToWord( "bla", "bla" );
	assert( w1 == 1.0 );
	double w2 = matchWordToWord( "Bla", "bla" );
	assert( w2 < w1 );
	double w3 = matchWordToWord( "vla", "bla" );
	assert( w3 < w2 );
}

// Lower limit >= 0
unittest {
	double w = matchWordToWord( "abcdefghijklmnopqrstuvwxyz", 
			"123456789012345678901234567890" );
	assert( w == 0.0 );
	w = matchWordToWord( 
			"123456789012345678901234567890", "abcdefghijklmnopqrstuvwxyz" );
	assert( w == 0.0 );
}

/// Break sentence into words
string[] byWord( string sentence ) {
	return sentence.split( " " );
}
	
/// Search for term in sentence and return a weight based on match
///
/// Split sentence into words and apply matchWordToWord
double weightTermSentence( string searchString, string compareSentence ) {
	double sum = 0.0;
	foreach( word; compareSentence.byWord ) {
		sum += matchWordToWord( searchString, word );
	}
	return sum;
}

// Test search in sentence
unittest {
	assert( matchWordToWord( "bla", "bla" ) ==
			weightTermSentence( "bla", "How is bla" ) );
	assert( matchWordToWord( "bla", "bla" )+matchWordToWord( "bla", "Bla" ) ==
			weightTermSentence( "bla", "Bla is bla" ) );

	assert( weightTermSentence( "abc", "def fgh" ) == 0.0 );
}

/// Search for term(s) in sentence and return a weight based on match
double weightSearchSentence( string searchString, string compareSentence ) {
	double sum = 0.0;
	foreach( term; searchString.byWord ) {
		sum += weightTermSentence( term, compareSentence );
	}
	return sum;
}

// Multiple search terms
unittest {
	assert( matchWordToWord( "bla", "bla" )+matchWordToWord( "is", "is" ) ==
			weightSearchSentence( "bla is", "How is bla" ) );
}

// Long sentences
unittest {
	auto w1 = weightSearchSentence( "line plusnet", "line rental plusnet" );
	auto w2 = weightSearchSentence( "line plusnet", "This is a strange long sentence that should not match very well but will match very well due to the longness of it" );
	assert( w1 > 10*w2 );
}
