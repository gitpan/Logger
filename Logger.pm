
BEGIN { $diagnostics::PRETTY = 1 }

package Pat::Logger;
our $VERSION = '3.1';

use lib qw( /Eng );

use strict;
use diagnostics;
use Fcntl ':flock';
use Pat::General;

use fields qw ( Debug_Log First_Message Separator time_pack sub_pack line_pack msg_pack );


# ------------------------
# subroutine declorations:
#-------------------------
sub new($);
sub new_stdout();
sub debug_message($);
sub separate();


sub _get_header();
sub _pack_str($$$$);
sub _print_to_file($);
sub _get_debug_params();


# Global variables:
my $time_pack = 'A22';
my $sub_pack  = 'A29';
my $line_pack = 'A10';
my $msg_pack  = 'A99';

my $separator = "\n";
$separator  = '-' x substr $time_pack, 1;
$separator .= '-' x substr $sub_pack , 1;
$separator .= '-' x substr $line_pack, 1;
$separator .= '-' x substr $msg_pack , 1;
$separator .= "\n";


# -----------------------------------------------------------------
# Name         : new() (constructor).
# Description  : Simple constructor that sets the unique_id value
# Recives      : File to hold all debugging messages.
# Returns      : FALSE/TRUE
# Algorithm    : Trivial.
# Dependencies : None.
# -----------------------------------------------------------------
sub new($)
{
    my ( $class, $debug_file ) = @_;
    my $self;

    # Validate  call to c'tor:
    die 'Bad call to constructor - check argument' unless defined $debug_file;
    

   
    # Bless object:    
    $self = fields::new $class;
    die "Can't create Logger object" unless defined $self;

    $self->{Debug_Log}	    = $debug_file;
    $self->{First_Message}  = 1;
    $self->{Separator}	    = $separator;
    
    $self->{time_pack} = $time_pack;
    $self->{sub_pack}  = $sub_pack;
    $self->{line_pack} = $line_pack;
    $self->{msg_pack}  = $msg_pack;

    return $self;
}



# -----------------------------------------------------------------
# Name         : new_stdout() (constructor).
# Description  : Simple constructor that sets the unique_id value
#		 that prints only to STDERR.
# Recives      : Unique_id.
# Returns      : FALSE/TRUE
# Algorithm    : Trivial.
# Dependencies : None.
# -----------------------------------------------------------------
sub new_stdout()
{
    my $class = shift;
    my $self;

  
    # Bless object:    
    $self = fields::new $class; 
    die "Can't create Logger object" unless defined $self;

    $self->{First_Message} = 1;
    $self->{Separator}	   = $separator;
    
    $self->{time_pack} = $time_pack;
    $self->{sub_pack}  = $sub_pack;
    $self->{line_pack} = $line_pack;
    $self->{msg_pack}  = $msg_pack; 
    
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
    my ( $self, $message ) = @_;
    my ( $package, $sub, $line, $time ) ;
    my $debug_message = '';
    my $rc;

    
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

    
    $debug_message .= $self->_pack_str( $time, $package, $sub, $line, $message );
    
    
    $self->_print_to_file( $debug_message ) if defined $self->{Debug_Log};
    print STDERR $debug_message;
    

    return 1;    
}




sub _print_to_file($)
{
    my $self = shift;
    my $message = shift;
    
    # we are using a log file, so let's create a file handle to it:
    if (  defined $self->{Debug_Log} )
    {
	# Create File handle to log file:   
	if (! open (LOG, ">> $self->{Debug_Log}") )
	{
	    print "Can't open $self->{Debug_Log}: $!\n";
	    return 0;
	}
	else
	{
	    # We lock the file for security reasons:
	    flock LOG, LOCK_EX;
	    print LOG $message;
	    close LOG;
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
    $headers .= pack $self->{sub_pack}, 'METHOD';
    $headers .= pack $self->{line_pack}, 'LINE';
    $headers .= pack $self->{msg_pack}, 'MESSAGE';
    $headers .= "\n";
    
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





sub _pack_str( $$$$ )
{
    my $self = shift;
    my ( $time, $package, $sub, $line, $message ) = @_;
    my $pid;
    my $result = '';
    
 
    #print "I got $time, $package, $sub, $line, $message\n";

    $result  = pack ( $self->{time_pack}, " $time" );
    $result .= pack ( $self->{sub_pack} , $package .'::' . $sub );
    $result .= pack ( $self->{line_pack}, $line );
    $result .= pack ( $self->{msg_pack} , $message );
    $result .= "\n";
    
    return $result;
    

#<<<<<<<<<<<<<<< - $package
#<<<<<<<<<<<<<<<<<<<<<<<<<<<< - $sub
#<<<<<<<<< - $line
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< -   $message  
}




sub _get_debug_params()
{
    my $self = shift;
    my ( $package, $sub, $line, $time );
    
    $time = Pat::General::eval_time();
    
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


return 1;





__END__

=head1 NAME

 Logger - Debugging tool which outputs logging messages in a nifty format.

=head1 SYNOPSIS

=over

=item * Print messages to both STDERR and a file:

=back
    
=head1

    use Pat::Logger;
    $debug_file = '/tmp/foo.log';
    eval { $logger = new Pat::Logger ( $debug_file ) };
    die $@ if $@;

    $logger->debug_message ( "Logger will tell you the package, subroutine and line number" );
    $logger->debug_message ( 'your debug message originated from' );
    $logger->debug_message ( "This line will blink in RED!", 'ERROR' ); # A second argument wil make the message appear in blinking red color.

=over

=item * Print to STDERR only:

=back

=head1

    use Pat::Logger;
    eval { $logger = new Pat::Logger() };
    die $@ if $@;

    $logger->debug_message ( "This line will go to STDERR only" );
    $logger->separate;
    $logger->debug_message ( "This line is separated from the previous one" );

    
   

=head1 DESCRIPTION

    The Logger module is a nifty tool to organaize your debug messages.

    While writing your code you need a tool to output your debug messages.
    You want to see where the message originated from (which module, which subroutine and line number),
    so you can proceed directly to solving the matter, rather than search for it's location.
    Not only you want to see the messages on screen, you want to have them in a local file as well.
    Logger does just that.

    There are two working modes for Logger:
    (1) Debugging to STDERR+file.
    (2) Debugging to STDERR only.

=over

=item  * B<new($)> ( With or without parameter )

    This constructor can receive a file name to output all message to.
    Upon success, a blessed hash reference will be returned.
    Upon failure the method dies, and $@ will hold the error message.

    If a parameter is not passed, Logger will output all the debug messages to STDERR.


=item * B<debug_message($$)>

    This method takes two argument - the debug message you wish to log and it's severity.

    For example:
    $logger->debug_message ( "This is a regular message" );
    $logger->debug_message ( "I cought an exception: $@", 'ERROR' ); # This message will stand out from the others,
								     # As it will blink in red color.  
    Upon success - the method returns 1.
    Upon failre  - the method returns 0.

    The Logger object does all the work behind the scenes:
    (1) Grab the package, subroutine name and line number which the message originated from.
    (2) Create a nice format with the parameters aforementioned.
    (3) Output it according to object type.

=item * B<separate()>

    You may wish to create visual separation between messages.
    This length is coherent with the length of the format.
 

=head1 CONTROLING LENGTHS

    It is possible to control the space of each field ( Time, Message, etc ).
    At the top of the module, you need to adjust the gloabl Variables' value.

    For example, if you wish to donate 50 characters to the message itself,
    simply modify the $msg_pack from 'A99' to 'a50'. The same goes for the other fields.

    the module automatically adjusts the header and separation when you modify the length of the fields.

    # Global variables:
    my $time_pack = 'A22';	# Control length of time field ( No real need to do so - It's optimized ).
    my $sub_pack  = 'A29';	# Control length of subroutine field. 
    my $line_pack = 'A10';	# Control length of line number fiekd.
    my $msg_pack  = 'A99';	# Control length of message field.


=head1 BUGS

    None at the moment. 
    If you have any question or comment - pengas@cpan.org


=head1 COPYRIGHT

    Copyright 2001-2002, Pengas Nir

    This library is free software - you can redistribute 
    it and/or modify it under the same terms as Perl itself.


=cut
