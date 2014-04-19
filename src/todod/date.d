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

module todod.date;

import datetime = std.datetime;
import std.conv;
import std.string;

/// Convenience struct around datetime.Date
struct Date {
	this( string dateStr ) {
		if ( dateStr != "-1" ) {
			auto splitted = split( dateStr, "-" );
			mytime = datetime.Date.fromISOExtString( dateStr );
			init = true;
		}
	}

  bool opEquals()(auto ref const bool v) const {
		return v == init;
	}

	static Date now() {
		Date dt;
		dt.mytime = cast(datetime.Date)(datetime.Clock.currTime);
		dt.init = true;
		return dt;
	}

	/// Returns difference in days
	long substract( const Date other_date ) const {
		return (this.mytime - other_date.mytime).total!"days";
	}

	/// Add given number of days
	void addDays( long days ) {
		mytime += datetime.dur!"days"(days);
	}

	unittest {
		auto dt = Date( "2014-01-16" );
		dt.addDays(4);
		assert( dt.mytime.day == 20 );
		dt.addDays(31);
		assert( dt.mytime.day == 20 );
		assert( dt.mytime.month == 2 );
	}

	Date dup() {
		Date dt;
		dt.mytime = mytime;
		dt.init = true;
		return dt;
	}

	private:
		datetime.Date mytime;
		bool init = false;
}

version( unittest ) {
	import std.stdio;
}

unittest {
	// Test for initialization
	Date dt;
	assert( dt == false );
	dt = Date( "2014-08-01" );
	assert( dt != false );

	dt = Date( "-1" );
	assert( dt == false );

	dt = Date.now;
	assert( dt != false );
}

unittest {
	auto dt = Date( "2014-01-12" );
	assert( dt.substract( Date( "2014-01-16" ) ) == -4 );
	assert( dt.substract( Date( "2014-01-01" ) ) == 11 );
	assert( dt.substract( Date( "2013-01-12" ) ) == 365 );
}


string toString( const Date dt ) {
	if (dt == true)
		return dt.mytime.toISOExtString();
	else
		return "-1";
}

string toStringDate( const Date dt ) {
	return toString( dt );
}

unittest {
	Date dt;
	assert( toString( dt ) == "-1" );
	auto dt_invalid = Date( toString( dt ) );
	assert( dt_invalid == false );

	dt = Date( "2014-01-08" );
	assert( toString( dt ) == "2014-01-08" );

	auto now = datetime.Clock.currTime;
	dt = Date.now;
	assert( now.year == dt.mytime.year );
	assert( now.month == dt.mytime.month );
	assert( now.day == dt.mytime.day );
}


