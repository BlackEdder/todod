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
import std.regex;

/// Convenience struct around datetime.Date
struct Date {
	this( string dateStr ) {
		if ( dateStr != "-1" ) {
			if (dateStr.match( r"^\d\d\d\d-\d\d-\d\d$" ) ) {
				mytime = 
					cast(datetime.SysTime)(datetime.Date.fromISOExtString( dateStr ));
			} else {
				mytime = datetime.SysTime.fromISOExtString( dateStr );
			}
			init = true;
		}
	}

	bool opCast( T : bool )() const {
		return init;
	}

	static Date now() {
		Date dt;
		dt.mytime = datetime.Clock.currTime;
		dt.init = true;
		return dt;
	}

	/// Returns difference in days
	long substract( const Date otherDate ) const {
		// First cast to dates, so that we work on actual dates, 
		// not number of 24 hours, i.e. the day before, but within 24 hours should
		// still count as a day.
		auto date1 = cast( datetime.Date )( this.mytime );
		auto date2 = cast( datetime.Date )( otherDate.mytime );
		return (date1 - date2).total!"days";
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
		datetime.SysTime mytime;
		bool init = false;
}

version( unittest ) {
	import std.stdio;
}

unittest {
	// Test for initialization
	Date dt;
	assert( !dt );
	dt = Date( "2014-08-01" );
	assert( dt );

	dt = Date( "-1" );
	assert( !dt );

	dt = Date.now;
	assert( dt );
}

unittest {
	auto dt = Date( "2014-01-12T00:01:01" );
	assert( dt.substract( Date( "2014-01-16T00:02:01" ) ) == -4 );
	assert( dt.substract( Date( "2014-01-01T00:02:01" ) ) == 11 );
	assert( dt.substract( Date( "2013-01-12T00:02:01" ) ) == 365 );
}


string toString( const Date dt ) {
	if (dt)
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
	assert( !dt_invalid );

	dt = Date( "2014-01-08" );
	assert( toString( dt ) == "2014-01-08T00:00:00" );

	dt = Date( "2014-01-08T08:01:01" );
	assert( toString( dt ) == "2014-01-08T08:01:01" );

	auto now = datetime.Clock.currTime;
	dt = Date.now;
	assert( now.year == dt.mytime.year );
	assert( now.month == dt.mytime.month );
	assert( now.day == dt.mytime.day );
}


