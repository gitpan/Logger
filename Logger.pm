
BEGIN { $diagnostics::PRETTY = 1 }

package Logger::Logger;
our $VERSION = '3.42';

use Time::localtime;

use strict;
use diagnostics;
use Fcntl ':flock';
use Term::ANSIColor qw (:constants);

use fields qw (msg_split_width Mode Error_Message Error_Color Debug_Log First_Message Separator time_pack sub_pack line_pack msg_pack );


# ------------------------
# subroutine declorations:
#-------------------------
sub new($);
sub debug_message($);
sub separate();


sub eval_time();
sub _get_header();
sub _pack_str($$$);
sub _print_to_file($);
sub _split_message( $ );
sub _get_debug_params( );


# Global variables:
my $time_pack = 'A18';
my $sub_pack  = 'A39';
my $line_pack = 'A6';
my $msg_pack  = 'A97';

my $separator = "\n\n";
$separator .= '-' x substr $time_pack, 1;
$separator .= '-' x substr $sub_pack , 1;
$separator .= '-' x substr $line_pack, 1;
$separator .= '-' x substr $msg_pack , 1;
$separator .= "\n\n";


# -----------------------------------------------------------------
# Name         : new() (constructor).
# Description  : Simple constructor that sets the unique_id value
# Recives      : File to hold all debugging messages ( optional ).
#                If parameter is not passed - output will be sent to STDERR.
# Returns      : FALSE/TRUE
# Algorithm    : Trivial.
# Dependencies : None.
# -----------------------------------------------------------------
sub new($)
{
    my ( $class, $debug_file ) = @_;
    my $self;
   
   
    # Bless object:    
    $self = fields::new $class;
    die "Can't create Logger object" unless defined $self;

    $self->{Debug_Log}	    = $debug_file if defined $debug_file;
    $self->{First_Message}  = 1;
    $self->{Separator}	    = $separator;
    
    $self->{Error_Message}  = 0; # Indicates this is an error message - it will be colored red.
    $self->{Error_Color}    = ' RED ';
    
    $self->{time_pack} = $time_pack;
    $self->{sub_pack}  = $sub_pack;
    $self->{line_pack} = $line_pack;
    $self->{msg_pack}  = $msg_pack;
    
    foreach ( $time_pack, $sub_pack, $line_pack )
    {
        $_ =~ /^\w(\d+)$/;
        $self->{msg_split_width} += $1;
    }
    
    #print "Msg length is $self->{msg_split_width}\n";
    return $self;
}




# -----------------------------------------------------------------
# Name         : debug_message().
# Description  : Simple Debugging method, using Format.
# Recives      : 1st - Subroutine in which the message originated.
#                2nd - Body of debugging message.
# Returns      : Void.
# Algorithm    : Trivial.
# Dependencies : None.
# -----------------------------------------------------------------
sub debug_message($)
{  
    my $self = shift;
    my $message = shift;
    my $error_flag = shift;    # indicates this is an error message
    
    my ( $package, $sub, $line, $time ) ;
    my $debug_message = '';
    my $rc;
    my @split_message;
    
    # If it's an error message, we raise the flag.
    $self->{Error_Message} = 1 if defined $error_flag;
   
    
    # Bad call to method?
    unless ( defined $message )
    {
	return warn "No debug message defined";
    }

    chomp $message; #Just in case;        

    # In this part we gather all the information relevant for this debug message:
    ( $package, $sub, $line, $time ) = $self->_get_debug_params();  


    # It's the first time we print a message, so let's create the headers:
    $debug_message  = $self->_get_header() if $self->{First_Message};
    $self->_print_to_file( $debug_message ) if defined $self->{Debug_Log};
    print STDERR $debug_message;

    # Now the message parameters;
    $debug_message = $self->_pack_str( $time, $package, $sub, $line );
    $self->_print_to_file( $debug_message ) if defined $self->{Debug_Log};
    print STDERR $debug_message;
   
    
    # Now we pack and print the actual message.
    # We do this here because we want to play with the colors:
    @split_message = $self->_split_message( $message );
    $message = shift @split_message;
    $message .= "\n";
    
    if ( $self->{Error_Message} ) {
        print STDERR BLINK RED $message, RESET;
    } else {
        print STDERR $message;
    }
    $self->_print_to_file( $message ) if defined $self->{Debug_Log};
    

    
    my $gap = ' ' x $self->{msg_split_width};
    foreach $message ( @split_message )
    {
        $message .= "\n";
        if ( $self->{Error_Message} ) {
            print STDERR BLINK RED  $gap . $message   , RESET;
        } else {
            print STDERR $gap . $message   ;
        }
        $self->_print_to_file( $gap . $message   ) if defined $self->{Debug_Log};
    }
    
    
    
    #$debug_message = pack ( $self->{msg_pack} , $message ) . "\n";
    #$self->_print_to_file( $debug_message ) if defined $self->{Debug_Log};
    
    #if ( $self->{Error_Message} ) {
    #    print STDERR BLINK RED $debug_message, RESET;
    #} else {
    #    print STDERR $debug_message;
    #}
   

    # Reset error flag:
    $self->{Error_Message} = 0; 
    

    return 1;    
}



sub _split_message( $ )
{
    my $self = shift;
    my $message = shift;
    my @split_message;
    
    my $length = $1 if ( $self->{msg_pack} =~ /^.(\d+)$/ );
    if ( length $message > $length )
    {
        my $tmp_1;
        my $tmp_2;
        

        while ( $message =~ /^(.{$length})(.*)$/ )
        {
            $tmp_1 = $1;
            $tmp_2 = $2;

            unless ( $tmp_2 =~ /^\s/ )
            {
                if ( $tmp_1 =~ /^(.*)\s+(.*)$/ )
                {
                    $tmp_1 = $1;
                    $tmp_2 = $2 . $tmp_2;
                }
            }
            $tmp_2 =~ s/^\s+//;
            
            push @split_message, $tmp_1;
            $message = $tmp_2;
        }
        push @split_message, $message;
    }
    else
    {
        push @split_message, $message;
    }
    
    return @split_message;
}




sub _print_to_file($)
{
    no strict 'refs';
    
    my $self = shift;
    my $message = shift;
    my $FH = $$;
    
    # we are using a log file, so let's create a file handle to it:
    if (  defined $self->{Debug_Log} )
    {
	# Create File handle to log file:   
	if (! open ($FH, ">> $self->{Debug_Log}") )
	{
	    print "Can't open $self->{Debug_Log}: $!\n";
	    return 0;
	}
	else
	{
	    # We lock the file for security reasons:
	    flock $FH, LOCK_EX;
	    print $FH $message;
	    close $FH;
	}
	    
    }
    return 1; 
}



sub _get_header()
{
    my $self = shift;

    $self->{First_Message} = 0;
 
    
    my $headers = $self->{Separator};
    
    $headers .= pack $self->{time_pack}, ' TIME';
    $headers .= pack $self->{sub_pack},  'METHOD';
    $headers .= pack $self->{line_pack}, 'LINE';
    $headers .= pack $self->{msg_pack},  'MESSAGE';
    #$headers .= "\n";
    
    $headers .= $self->{Separator};
    
    return $headers;
}


sub separate()
{
    my $self = shift;

    $self->_print_to_file( $self->{Separator} ) if defined $self->{Debug_Log};
    print $self->{Separator};
    
    return 1; 
}   





sub _pack_str( $$$ )
{
    my $self = shift;
    my ( $time, $package, $sub, $line ) = @_;
    my $pid;
    my $result = '';
    
 
    #print "I got $time, $package, $sub, $line, $message\n";

    $result  = pack ( $self->{time_pack}, " $time" );
    $result .= pack ( $self->{sub_pack} , $package .'::' . $sub );
    $result .= pack ( $self->{line_pack}, $line );
    #$result .= pack ( $self->{msg_pack} , $message );
    #$result .= "\n";
    
    return $result;   
}




sub _get_debug_params()
{
    my $self = shift;
    my ( $package, $sub, $line, $time );
    
    $time = $self->eval_time();
    
    my @caller_param_1 = caller(1);
    my @caller_param_2 = caller(2);

    $package = $caller_param_1[0];
    $line    = $caller_param_1[2];

    my @package = ( split '::', $package );
    $package = $package[ $#package ];

    # Sub may be the main of a package (which will not show up in caller).
    if ( defined $caller_param_2[3] )
    {
	# if it's an eval, we have to see who called it.
	( $caller_param_2[3] =~ /eval/ ) ?  ( $sub = (caller(3))[3] ) : ( $sub = $caller_param_2[3] );
	
	$sub =~ s/^.*?::(.*)$/$1/;
    } else {
	 $sub = 'main';
    }

    my @subroutine = ( split '::', $sub );
    $sub = $subroutine[ $#subroutine ];


    return ( $package, $sub, $line, $time );
}


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
# Dependencies  : localtime.
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




return 1;





__END__

=head1 NAME

 Logger - Debugging tool which outputs logging messages in a nifty format.

=head1 SYNOPSIS

=over

=item * Print messages to both STDERR and a file:

=back
    
=head1

    use Logger::Logger;
    $debug_file = '/tmp/foo.log';
    eval { $logger = new Logger::Logger ( $debug_file ) };
    die $@ if $@;

    $logger->debug_message ( 'Logger will tell you the package, subroutine, line number and the time your debug message originated from' );
    $logger->separate;
    $logger->debug_message ( 'This line is separated from the previous one' );
    $logger->debug_message ( "An error occured", 'ERROR' ); # This message will blink in Red.
    $logger->debug_message ( "This line is much longer to fit in a single row. Logger will split it nicely, without chopping off words and display it in multiple rows" );
     

=head1 DESCRIPTION

    The Logger module is a nifty tool to organaize your debug messages, and thus your program flow.

    While writing your code you need a tool to output your debug messages.
    You want to see where the message originated from ( which module, which subroutine and line number and at what time ),
    so you can proceed directly to solving the matter, rather than search for it's location.
    You want to destinguish between an error message, and yet another flow control message.
    Not only you want to see the messages on screen, you want to have them in a local file as well.
    Logger does just that.

    There are two working modes for Logger:

    (1) Debugging to STDERR+file.
    (2) Debugging to STDERR only.

=over

=item  * B<new($)>

    This constructor expects a file name to output all message to.
    Upon success, a blessed hash reference will be returned.
    Upon failure the method dies, and $@ will hold the error message.
    
    If a file name is not passed, Logger will output all messages to STDERR only.


=item * B<debug_message($)>

    This method takes two argument - the debug message you wish to log, and the type of the message.
    Currently supported type is 'ERROR'. When the second argument is 'ERROR', the debug message willl appear
    in blinking Red color ( in case your Terminal supports it ).
    
    Upon success - the method returns 1.
    Upon failre  - the method returns 0.
    
    The Logger object does all the work behind the scenes:
    (1) Grab the time, package, subroutine name and line number which the message originated from.
    (2) Create a nice format with the parameters aforementioned.
    (3) Output it according to object type.

=item * B<separate()>

    You may wish to create visual separation between messages.
    When you invoke separate(), a line consistant of '-' will be outputed.

    This length is automatically calculated by Logger.
    
=head1 WIDTH CONTROL

    The Logger module uses pack() to indent the output.
    You can control the  width of each field by altering the code:
                         
    my $time_pack = 'A18'; This mean the 'TIME' column is 18 byte long.
    my $sub_pack  = 'A39';
    my $line_pack = 'A6';
    my $msg_pack  = 'A97';
                         
    Upon modification of this fields, Logger automatically calculates the new scheme,
    and adjusts all relevant fields accordingly, to your convenience.

 

=head1 BUGS

    None at the moment. 
    If you have any question or comment - pengas@cpan.org


=head1 COPYRIGHT

    Copyright 2001-2002, Pengas Nir

    This library is free software - you can redistribute 
    it and/or modify it under the same terms as Perl itself.


=cut