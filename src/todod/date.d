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


