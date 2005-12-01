# Clase para manejo de un archivo Log en perl.
#
# metodos:
#
#	 * new: Crea un nuevo objeto de la clase.
#	 * filename: Cambia el nombre del archivo de log.
#	 * mode: Establece si la apertura es para sobreescribir o blanquear.
#	 * open: Abre el archivo de log.
#	 * save: Guarda datos en el archivo log. Con un formato especial
#	 * save_error: Guarda datos en el archivo log de un error. Ejecuta un die; luego.
#	 * close: Cierra el archivo de log.
#
# by Damian Nardelli [dnardelli@iplan.com.ar]
# Ultima Modificacion: Fri Nov  4 12:23:51 ART 2005
#
#
# Comienzo del script Logger.pm

package Logger; # >:D

use strict;
use IO::Handle;

my $VERSION = '0.01';

# Metodo new.
sub new
{
	my $this=shift;
	my $class = ref($this) || $this; 
	my $self={};
	$self->{file} = "log_pm.txt";
	$self->{timet} = &GetDate;
	$self->{lastmsg} = undef;
	$self->{mode}  = undef;
	bless $self, $class; 
	return ($self); 
}

#metodo setfilename
sub filename
{
	my $self=shift;
	$self->{file} = shift if(@_);
}

# metodo mode
sub mode
{
	my $self=shift;
	if (@_) {
		if ($_[0] eq 'w' || $_[0] eq 'n') {
			$self->{mode}=shift;
		}
		else {
			print "[!] Modo incorrecto\n";
		}
	}
	else {
		return $self->{mode};
	}
}

# Metodo save
sub save
{
	my $self=shift; 
	my $datenow=&GetDate();
	if (@_) {
		my $lastmsg=shift;
		my $datenow=&GetDate();
		$self->{lastmsg}=$lastmsg;
		print FILE_LOG "$datenow - $lastmsg\n";
		FILE_LOG->flush;
	}
	else {
		return $self->{lastmsg};
	}
}

# Metodo save_error
sub save_error
{
	my $self=shift; 
	my $datenow=&GetDate();
	if (@_) {
		my $lastmsg=shift;
		my $datenow=&GetDate();
		$self->{lastmsg}=$lastmsg;
		print FILE_LOG "$datenow - [ERROR] $lastmsg\n";
		$self->close;
		die;
	}
	else {
		return $self->{lastmsg};
	}
}

# metodo close
sub close
{
	my $datenow=&GetDate();
	print FILE_LOG "$datenow - [AVISO] Se finaliza el procesamiento del programa\n\n";
	FILE_LOG->flush;
	close(FILE_LOG);
}


# metodo init
sub open
{
	my $self=shift;
	my $datenow=&GetDate();
	if (defined($self->{mode})) {
		if ($self->{mode} eq 'n') {
			open(FILE_LOG,">" . $self->{file});
		}
		else {
			open(FILE_LOG,">>" . $self->{file}) || 
			open(FILE_LOG,">" . $self->{file});
		}
		print FILE_LOG "$datenow - [AVISO] Se inicia el procesamiento del programa\n";
	}
	else {
		print "[!] No se ha especificado un modo\n";
	}
}


##
# Devuelve un hash con datos importantes de la fecha y hora actual.
#
# @return HASH Con datos de la fecha.
#

sub GetDate
{
	my ($year,$mon,$day,$hour,$min,$sec) = (localtime(time))[5,4,3,2,1,0];
	
	$mon  = "0$mon"  if ($mon  < 10);
	$day  = "0$day"  if ($day  < 10);
	$hour = "0$hour" if ($hour < 10);
	$min  = "0$min"  if ($min  < 10);
	$sec  = "0$sec"  if ($sec  < 10);
	$year += 1900;
	$mon++;	
	return "[$year-$mon-$day $hour:$min:$sec]";

}

1;

__END__

# Fin del script Logger.pm
