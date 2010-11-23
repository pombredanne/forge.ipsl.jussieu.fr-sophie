package Sophie::Base;

use strict;
use warnings;
use DBI;
use base qw/DBIx::Class::Schema/;
use FindBin qw($Bin);

__PACKAGE__->load_namespaces();

sub connection {
    my ($class) = @_;
    $class->SUPER::connection(
        sub { __PACKAGE__->db },
   )
}

sub db {
   my ($self) = @_;
   require Config::General;
   my $config;
   foreach my $file ('sophie.conf', "$Bin/../sophie.conf",
       '/etc/sophie/sophie.conf') {
       -f $file or next;
        my $cg = Config::General->new($file);
        $config = { $cg->getall() };
    }
    $config or die "No config found";

   DBI->connect_cached(
       'dbi:Pg:' . $config->{dbconnect},
       $config->{dbuser},
       $config->{dbpassword},
       {
           AutoCommit => 0,
           PrintError => 1,
       }
   ); 
}



1;
