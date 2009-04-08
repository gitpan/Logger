package Logger;

#  $Id: Logger.pm,v 1.4 2009-04-08 18:57:56 ed Exp $

use strict;
use warnings;
use Time::HiRes qw( gettimeofday tv_interval );
use POSIX qw( strftime );
use Carp;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( 
    timenow 
    logmsg 
    logwarn 
    logerr 
    loginfo 
    lograw 
    lograwerr 
    logstamp 
    timestamp 
    logdbg 
    mark_time 
    elapsed_time 
    $VERSION
);

our $VERSION = '0.15';

our $LOG_TIMESTAMP = 1;
our $LOG_STDERR = 1;
our $LOG_PID = 1;
our $LOG_PROG = 1;
our $TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:%S.mmm %Z";
our $LOG = 1;
our $LOGGING = 1;
our $VERBOSITY = 1;
our $PROGNAME;
my %TimerCache;

##########################################################################
sub timenow {
    my ($seconds, $useconds) = Time::HiRes::gettimeofday;
    return $seconds + $useconds / 1000000;
}

##########################################################################
sub timestamp {
    return "" if ! $LOG_TIMESTAMP;
    my ($secs,$usecs) = Time::HiRes::gettimeofday;
    my $timestamp = POSIX::strftime($TIMESTAMP_FORMAT, localtime($secs));
    $timestamp =~ s:mmm:sprintf("%03d", $usecs/1000):e;
    return $timestamp;
}


##########################################################################
sub progname {
    if ( ! $PROGNAME ) {
        $PROGNAME = $0;
        $PROGNAME =~ s:^.*/(.*?)$:$1:g;
        if ( ! $PROGNAME || $PROGNAME eq 'null' ) {
            return "";
        }
    }
    return $PROGNAME;
}

##########################################################################
sub logstamp {
    my $logstamp = timestamp()." ";
    $logstamp .= progname()." " if $LOG_PROG;
    $logstamp .= "[$$] " if $LOG_PID;
    return $logstamp;
}

##########################################################################
sub lograw {
    
    if ( $LOG_STDERR ) {
        print STDERR @_ if $LOGGING;
    } else {
        print @_ if $LOGGING;
    }
}

##########################################################################
sub lograwerr {
    print STDERR @_;
}

##########################################################################
sub logmsg {
    if ( $LOG_STDERR ) {
        print STDERR logstamp(), @_, "\n" if $LOGGING;
    } else {
        print logstamp(), @_, "\n" if $LOGGING;
    }
}

##########################################################################
sub loginfo {
    logmsg;
}

##########################################################################
sub logdbg {
    if ( scalar(@_) > 1 && $_[0] =~ /^\d+$/ ) {
        # interpret first arg as verbosity level
        my $level = shift;
        logmsg "DEBUG$level: ", @_ if $level >= $VERBOSITY;
    } else {
        logmsg "DEBUG:  ", @_;
    }
}

##########################################################################
sub logerr {
    logmsg "ERROR:  ", @_, ";  CONTEXT: ", Carp::longmess;
}

##########################################################################
sub logwarn {
    logmsg "WARNING:  ", @_;
}

##########################################################################
sub setopt {
    my ($key, $val) = @_;

    return undef if ( ! defined($key) || ! defined($val) );

    if ( $key eq 'LOG_TIMESTAMP' ) {
        if ( $val =~ /^1|on|yes$/i ) {
            $LOG_TIMESTAMP = 1;
        } elsif ( $val =~ /^0|off|no$/i ) {
            $LOG_TIMESTAMP = 0;
        } else {
            print STDERR "Bogus value [$val] passed to setopt for $key";
            return undef;
        }
    } elsif ( $key eq 'LOG_PID' ) {
        if ( $val =~ /^1|on|yes$/i ) {
            $LOG_PID = 1;
        } elsif ( $val =~ /^0|off|no$/i ) {
            $LOG_PID = 0;
        } else {
            print STDERR "Bogus value [$val] passed to setopt for $key";
            return undef;
        }
    } elsif ( $key eq 'LOG_STDERR' ) {
        if ( $val =~ /^1|on|yes$/i ) {
            $LOG_STDERR = 1;
        } elsif ( $val =~ /^0|off|no$/i ) {
            $LOG_STDERR = 0;
        } else {
            print STDERR "Bogus value [$val] passed to setopt for $key";
            return undef;
        }
    } elsif ( $key eq 'LOG_PROG' ) {
        if ( $val =~ /^1|on|yes$/i ) {
            $LOG_PROG = 1;
        } elsif ( $val =~ /^0|off|no$/i ) {
            $LOG_PROG = 0;
        } else {
            print STDERR "Bogus value [$val] passed to setopt for $key";
            return undef;
        }
    } elsif ( $key eq 'VERBOSITY' ) {
        if ( $val =~ /^(\d+)$/i ) {
            $VERBOSITY = $1;
        } else {
            print STDERR "Bogus value [$val] passed to setopt for $key";
            return undef;
        }
    } elsif ( $key eq 'TIMESTAMP_FORMAT' ) {
        if ( POSIX::strftime($val, localtime(time)) ) {
            $TIMESTAMP_FORMAT = $val;
        } else {
            print STDERR "Bogus format [$val] passed to setopt for $key";
            return undef;
        }
    } else {
        print STDERR "Bogus option key [$key] passed to setopt";
        return undef;
    }
    return 1;
}

##########################################################################
sub mark_time {
    my ($key) = @_;

    if ( ! $key ) {
        logwarn "NULL key passed to Logger::marktime";
        return undef;
    }

    $TimerCache{$key} = [ Time::HiRes::gettimeofday ];

    return ($TimerCache{$key}->[0], $TimerCache{$key}->[1]);
}

##########################################################################
sub elapsed_time {
    my ($key) = @_;

    if ( ! $key ) {
        logwarn "NULL key passed to Logger::marktime";
        return undef;
    }

    if ( ! $TimerCache{$key} ) {
        logwarn "No time marker for key [$key] in Logger";
        return undef;
    }

    return sprintf("%.6f", Time::HiRes::tv_interval( $TimerCache{$key} ));
}



1;
__END__

=head1 NAME

Logger - Configurable time-stamped logging module with timing utility

=head1 SYNOPSIS

=head2 BASIC USAGE

  use Logger;

  logmsg "This is a log message";
  logdbg "This is a standard debug message";

 Default output:

  2001-04-19 13:15:23.062 MDT [9153] This is a log message

=head2 TIMING USAGE

  mark_time("time0");
  #  Do something you want to time
  logmsg sprintf("Elapsed time since time0:  %.3f", 
                  Logger::elapsed_time("time0"));

=head2 CUSTOM CONFIGURATION

  setopt("LOG_TIMESTAMP", 1).
  setopt("LOG_PID", 1).
  setopt("LOG_STDERR", 1).
  setopt("LOG_PROG", 0).
  setopt("TIMESTAMP_FORMAT", "%Y-%m-%d %H:%M:%S.mmm %Z");
  setopt("LOGGING", 0).
  setopt("VERBOSITY", 2).

=head1 DEPENDENCIES

  use Time::HiRes;
  use POSIX;
  use Carp;

=head1 DESCRIPTION

This module optionally prefixes log messages with the current 
date/time/timezone, process ID, and a label such as "ERROR",
and adds a newline.  It's perhaps useful if you want a simple,
consistent logfile format for all perl programs with fine-
grained timestamps.  It does absolutely nothing in the way of
a log rotation scheme.

There are newer, more sophisticated (and more complex) ways 
to handle logging (see log4perl); this is a middleground module.

The logmsg, lograw, and loginfo routines write to STDOUT.
The logerr, logwarn, and lograwerr routines write to STDERR.
The logerr and lograwerr routines do not prefix anything, they
just spit out what was passed in.

To turn on/off any of the following options, use the 
Logger::setopt() function.  For example, to turn on timestamp
logging, call Logger::setopt("LOG_TIMESTAMP", 1):

    Option              Meaning
    ===============     ==========================================
    LOG_PID             Log the process ID of the caller
    LOG_TIMESTAMP       Log timestamp (see TIMESTAMP_FORMAT below)
    LOG_PROG            Log the current program name 
    LOG_STDERR          Send log output only to STDERR

To control the timestamp format, call Logger::setopt() with the
"TIMESTAMP_FORMAT" and a format string compatible with strftime().  
If you want milliseconds to also be logged, include "mmm" in your 
format string where you want the millisconds to be logged.  For
example, here's the default:

    Logger::setopt("TIMESTAMP_FORMAT", "%Y-%m-%d %H:%M:%S.mmm %Z");

To toggle non-error logging off, call Logger::setopt("LOGGING", 0).
To toggle non-error logging on, call Logger::setopt("LOGGING", 1).
To set debug message verbosity level = 2, call Logger::setopt("VERBOSITY", 2).

Logger::setopt() returns 1 if successful and undef if not.

=head1 EXPORT

logmsg loginfo logwarn logerr lograw lograwerr

=head1 AUTHOR

Ed Loehr, cpan at bluepolka dot net

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2001 by Ed Loehr

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
