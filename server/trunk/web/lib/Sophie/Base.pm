package Sophie::Base;

use strict;
use warnings;
use DBI;
use base qw/DBIx::Class::Schema/;
use FindBin qw($Bin);
use Config::General;

__PACKAGE__->load_namespaces();

sub default_config {
   my $config;
   foreach my $file ('sophie.conf', "$Bin/../sophie.conf",
       '/etc/sophie/sophie.conf') {
       -f $file or next;
        my $cg = Config::General->new($file);
        $config = { $cg->getall() };
    }
    $config or die "No config found";
    return $config;
}

sub connection {
    my ($class, $connect_info) = @_;
    if (! $connect_info->{dsn}) {
        my $config = default_config();
        $connect_info->{dsn} = 'dbi:Pg:' . $config->{dbconnect};
        $connect_info->{user} = $config->{dbuser};
        $connect_info->{password} = $config->{dbpassword};
        $connect_info->{unsafe} = 1;
    }
    $connect_info->{PrintError} = 0;
    $connect_info->{RaiseError} = 0;
    exists($connect_info->{AutoCommit}) or $connect_info->{AutoCommit} = 0;
    $class->SUPER::connection(
        $connect_info,
   )
}

sub db {
   my ($self) = @_;

   $self->connect->storage->dbh;
}



1;
