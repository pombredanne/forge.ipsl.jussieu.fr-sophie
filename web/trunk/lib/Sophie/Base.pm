package Sophie::Base;

use strict;
use warnings;
use DBI;
use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_namespaces();

sub connection {
    my ($class) = @_;
    $class->SUPER::connection(
        sub { __PACKAGE__->db },
   )
}

sub db {
   my ($self) = @_;
   require Sophie;

   DBI->connect_cached(
       'dbi:Pg:' . Sophie->config->{dbconnect},
       Sophie->config->{dbuser},
       Sophie->config->{dbpassword},
       {
           AutoCommit => 0,
       }
   ); 
}



1;
