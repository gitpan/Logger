#!/usr/bin/perl -w

BEGIN { $diagnostics::PRETTY = 1 }

package Pat::General;


use strict;
use diagnostics;

use Time::localtime;


# ------------------------
# Subroutine declorations
# ------------------------
sub eval_time();



# *******************************************************************************************************
# Name          : eval_time()
#                 This subroutine evaluates an output file-name according to the follwoing format:
#		  'DMYHMS'.
# Parameters    : None.
#
# Algorithm     : (1) Obtain Current date and time from time2str() function.
#                 (2) Create string matching format.
#
# Return value  : String holding the outpfile.
#
# Dependencies  : HTTP::Date.
# ********************************************************************************************************
sub eval_time()
{
	my $tm = localtime;
	my ( $DAY, $MONTH, $YEAR, $HOUR, $MINUTE, $SECOND ) = ( $tm->mday, $tm->mon, $tm->year, $tm->hour, $tm->min, $tm->sec );
	$MONTH++;
	$YEAR += 1900;
	$YEAR = substr( $YEAR, 2, 2);
	my $time_and_date = $DAY . '/' . $MONTH . '/' . $YEAR . '-' . $HOUR . ':' . $MINUTE . ':' . $SECOND;

	return $time_and_date;
}
1;




















