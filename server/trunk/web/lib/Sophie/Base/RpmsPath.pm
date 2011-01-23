package Sophie::Base::RpmsPath;

use strict;
use warnings;
use base qw(Sophie::Base);
use Sophie::Base::Header;
use RPM4;
use File::Temp;
use File::Copy;
use Archive::Cpio;
use Encode::Guess;
use Encode;
use Time::HiRes;

sub new {
    my ($class, $pathkey, $db) = @_;

    bless({ key => $pathkey, db => $db }, $class);
}

sub key { $_[0]->{key} } 
sub db { 
    $_[0]->{db}->storage->dbh
} 

sub path {
    my ($self) = @_;
    
    my $sth = $self->db->prepare_cached(
        q{select path from d_path where d_path_key = ?}
    );
    $sth->execute($self->key);
    my $res = $sth->fetchrow_hashref;
    $sth->finish;
    return $res->{path}
}

sub ls_rpms {
    my ($self) = @_;

    my $sth = $self->db->prepare_cached(
        q{select * from rpmfiles where d_path = ?}
    );
    $sth->execute($self->key);
    $sth->fetchall_hashref([ 'filename' ]);
}

sub local_ls_rpms {
    my ($self) = @_;

    if (opendir(my $dh, $self->path)) {
        my %list;
        while (my $entry = readdir($dh)) {
            $entry eq '.' and next;
            $entry eq '..' and next;
            $list{$entry} = 1;
        }
        closedir($dh);
        return \%list;
    } else {
        return;
    }
}

sub find_delta {
    my ($self) = @_;

    warn "$$ " . $self->path;

    my @delta;
    my $localrpms = $self->local_ls_rpms;
    my $baserpms  = $self->ls_rpms;

    if ($localrpms) {
        push(@delta, { delta => 'DE' });
    } else {
        push(@delta, { delta => 'DM' });
    }


    my %list;
    foreach (keys %{ $localrpms || {} }, keys %{ $baserpms }) {
        $list{$_} = 1;
    }

    foreach my $rpm (sort { $b cmp $a } keys %list) {
        if ($localrpms->{$rpm} && $baserpms->{$rpm}) {
            # nothing to do
        } elsif ($localrpms->{$rpm}) {
            push(@delta, { rpm => $rpm, delta => 'A' });
        } elsif ($baserpms->{$rpm}) {
            push(@delta, { rpm => $rpm, delta => 'R' });
        }
    }
    @delta;
}
sub update_content {
    my ($self, @delta) = @_;
    foreach (@delta) {
        if (!$_->{delta}) {
        }
        elsif ($_->{delta} eq 'A') {
            $self->add_rpm($_->{rpm});
            #sleep(1);
            #Time::HiRes::usleep(750);
        }
        elsif ($_->{delta} eq 'R') {
            $self->remove_rpm($_->{rpm});
        } elsif ($_->{delta} eq 'DM') {
            $self->set_exists(0);
        } elsif ($_->{delta} eq 'DE') {
            $self->set_exists(1);
        }
    }
}

sub set_exists {
    my ($self, $exists) = @_;
    $self->db->prepare_cached(q{
        update d_path set exists = ? where d_path_key = ?
        })->execute(($exists ? 1 : 0), $self->key);
    $self->db->commit;
}

sub set_updated {
    my ($self) = @_;
    warn "$$ UPD";
    $self->db->prepare_cached(q{
        update d_path set updated = now() where d_path_key = ?
        })->execute($self->key);
    $self->db->commit;
}


sub remove_rpm {
    my ($self, $rpm) = @_;
    warn "$$ deleting $rpm";
    my $remove = $self->db->prepare_cached(
        q{
        DELETE FROM rpmfiles where d_path = ? and filename = ?
        }
    );
    for (1 .. 3) {
        if ($remove->execute($self->key, $rpm)) { 
            $self->db->commit;
            return 1;
        }
        $self->db->rollback;
    }
}

sub add_rpm {
    my ($self, $rpm) = @_;

    warn "$$ adding $rpm";
    for (1 .. 3) {
        if (defined(my $pkgid = $self->_add_header($rpm))) {
            $pkgid or return;
            my $register = $self->db->prepare_cached(
                q{
                INSERT INTO rpmfiles (d_path, filename, pkgid)
                values (?,?,?)
                }
            );
            $register->execute($self->key, $rpm, $pkgid) and do {
                $self->db->commit;
                return 1;
            }

        }
        $self->db->rollback;
    }
}

sub _add_header {
    my ($self, $rpm) = @_;

    my $header;
    eval {
        $header = RPM4::Header->new($self->path . '/' . $rpm, $self->{db}) 
    };
    $header or do {
        warn "$$ Cannot read " . $self->path . '/' . $rpm;
        return "";
    };

    {
        my $find = $self->db->prepare_cached(q{
            select pkgid from rpms where pkgid = ?
        });
        $find->execute($header->queryformat('%{PKGID}'));
        my $rows = $find->rows;
        $find->finish;
        if ($rows) {
            warn "$$ Find";
            return $header->queryformat('%{PKGID}');
        }
    }
    my $tmp = File::Temp->new( UNLINK => 1, SUFFIX => '.hdr' );
    unlink($tmp->filename);
    $header->write($tmp, 0);
    seek($tmp, 0, 0);
    my $string = '';
    while (read($tmp, my $str, 1024)) { $string .= $str }
    $tmp = undef;
    my $add_header = $self->db->prepare_cached(
        q{
        INSERT into rpms (pkgid, name, header, evr, arch, issrc, description, summary)
        values (?,?,rpmheader_in(decode(?, 'hex')::bytea),?,?,?,?,?)
        }
    );
    my $description = $header->queryformat('%{DESCRIPTION}');
    {
        my $enc = guess_encoding($description, qw/latin1/);
        $description = $enc->decode($description) if ($enc && ref $enc);
    }
    my $summary = $header->queryformat('%{SUMMARY}');
    {
        my $enc = guess_encoding($summary, qw/latin1/);
        $summary = $enc->decode($summary) if ($enc && ref $enc);
    }

    $add_header->execute(
        $header->queryformat('%{PKGID}'),
        $header->queryformat('%{name}'),
        unpack('H*', $string),
        $header->queryformat('%|EPOCH?{%{EPOCH}:}:{}|%{VERSION}-%{RELEASE}'),
        $header->queryformat('%{ARCH}'),
        $header->hastag('SOURCERPM') ? 'f' : 't',
        $description,
        $summary,
    ) or return;
    my $index_tag = $self->db->prepare_cached(
        q{
        select index_rpms(?);
        }
    );
    $index_tag->execute($header->queryformat('%{PKGID}')) or return;
    $index_tag->finish;
    if (!$header->hastag('SOURCERPM')) {
        Sophie::Base::Header->new($header->queryformat('%{PKGID}'), $self->{db})
            ->addfiles_content({ path => $self->path, filename => $rpm}) or return;
    }

    $header->queryformat('%{PKGID}');
}

1;
