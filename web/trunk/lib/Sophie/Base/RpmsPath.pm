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

sub new {
    my ($class, $pathkey) = @_;

    bless(\$pathkey, $class);
}

sub path {
    my ($self) = @_;
    
    my $sth = $self->db->prepare_cached(
        q{select path from d_path where d_path_key = ?}
    );
    $sth->execute($$self);
    my $res = $sth->fetchrow_hashref;
    $sth->finish;
    return $res->{path}
}

sub ls_rpms {
    my ($self) = @_;

    my $sth = $self->db->prepare_cached(
        q{select * from rpmfiles where d_path = ?}
    );
    $sth->execute($$self);
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

sub update_content {
    my ($self) = @_;

    warn $self->path;

    my $localrpms = $self->local_ls_rpms || {};
    my $baserpms  = $self->ls_rpms;

    my %list;
    foreach (keys %{ $localrpms }, keys %{ $baserpms }) {
        $list{$_} = 1;
    }

    foreach my $rpm (sort { $b cmp $a } keys %list) {
        if ($localrpms->{$rpm} && $baserpms->{$rpm}) {
            # nothing to do
        } elsif ($localrpms->{$rpm}) {
            warn "adding $rpm";
            $self->add_rpm($rpm);
        } elsif ($baserpms->{$rpm}) {
            my $remove = $self->db->prepare_cached(
                q{
                DELETE FROM rpmfiles where d_path = ? and filename = ?
                }
            );
            $remove->execute($$self, $rpm);
            warn "deleting $rpm";
        }
    }

}

sub add_rpm {
    my ($self, $rpm) = @_;

    if (my $pkgid = $self->_add_header($rpm)) {
        my $register = $self->db->prepare_cached(
            q{
            INSERT INTO rpmfiles (d_path, filename, pkgid)
            values (?,?,?)
            }
        );
        $register->execute($$self, $rpm, $pkgid);

    } else {
    }
    $self->db->commit;
}

sub _add_header {
    my ($self, $rpm) = @_;

    my $header;
    eval {
        $header = RPM4::Header->new($self->path . '/' . $rpm) 
    };
    $header or do {
        warn "Cannot read " . $self->path . '/' . $rpm;
        return;
    };

    {
        my $find = $self->db->prepare_cached(q{
            select pkgid from rpms where pkgid = ?
        });
        $find->execute($header->queryformat('%{PKGID}'));
        my $rows = $find->rows;
        $find->finish;
        if ($rows) {
            warn "Find";
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
        INSERT into rpms (pkgid, header, evr, issrc, description, summary)
        values (?,rpmheader_in(decode(?, 'hex')::bytea),?,?,?,?)
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
        unpack('H*', $string),
        $header->queryformat('%|EPOCH?{%{EPOCH}:}:{}|%{VERSION}-%{RELEASE}'),
        $header->hastag('SOURCERPM') ? 'f' : 't',
        $description,
        $summary,
    );
    my $index_tag = $self->db->prepare_cached(
        q{
        select index_rpms(?);
        }
    );
    $index_tag->execute($header->queryformat('%{PKGID}'));
    $index_tag->finish;
    Sophie::Base::Header->new($header->queryformat('%{PKGID}'))
        ->addfiles_content({ path => $self->path, filename => $rpm});

    $header->queryformat('%{PKGID}');
}

1;
