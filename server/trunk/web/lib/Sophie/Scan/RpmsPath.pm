package Sophie::Scan::RpmsPath;

use strict;
use warnings;
use RPM4;
use File::Temp;
use File::Copy;
use Archive::Cpio;
use Encode::Guess;
use Encode;
use Time::HiRes;
use DBD::Pg qw(:pg_types);

sub new {
    my ($class, $pathkey, $db) = @_;

    bless({ key => $pathkey, db => $db }, $class);
}

sub key { $_[0]->{key} } 
sub db { 
    $_[0]->{db}
} 

sub path {
    my ($self) = @_;
    
    $self->db->base->resultset('Paths')->find(
        { d_path_key => $self->key }
    )->path;
}

sub ls_rpms {
    my ($self) = @_;

    my %list;
    foreach ($self->db->base->resultset('RpmFile')->search(
        { d_path => $self->key },
        { 'select' => [ qw(filename mtime) ], as => [ qw(filename mtime) ] },
    )->all) {
        $list{$_->get_column('filename')} = $_->get_column('mtime') || 1;
    }
    return \%list;
}

sub local_ls_rpms {
    my ($self) = @_;
    my $path = $self->path;

    if (opendir(my $dh, $path)) {
        my %list;
        while (my $entry = readdir($dh)) {
            $entry eq '.' and next;
            $entry eq '..' and next;
            $list{$entry} = (stat("$path/$entry"))[9];
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
            push(@delta, { rpm => $rpm, delta => 'A', mtime => $localrpms->{$rpm} });
        } elsif ($baserpms->{$rpm}) {
            push(@delta, { rpm => $rpm, delta => 'R', mtime => $baserpms->{$rpm} });
        }
    }
    sort { $a->{delta} eq $b->{delta} 
        ? ($a->{mtime} <=> $b->{mtime})
        : ($a->{delta} cmp $b->{delta})
    } @delta;
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
    $self->db->base->resultset('Paths')->find(
        { d_path_key => $self->key }
    )->update({ 'exists' => ($exists ? 1 : 0) });
    $self->db->commit;
}

sub set_updated {
    my ($self) = @_;
    warn "$$ UPD";
    $self->db->base->resultset('Paths')->find(
        { d_path_key => $self->key }
    )->update({ 'updated' => \'now()' });
    $self->db->commit;
}

sub remove_rpm {
    my ($self, $rpm) = @_;
    warn "$$ deleting $rpm";
    $self->db->base->storage->txn_do(
        sub {

            $self->db->base->resultset('RpmFile')->search(
                { d_path => $self->key, filename => $rpm }
            )->delete;
        }
    );
}

sub add_rpm {
    my ($self, $rpm) = @_;

    warn "$$ adding $rpm";
    my @stat = stat($self->path . '/' . $rpm);
    eval {
        my ($pkgid, $new) = $self->db->base->storage->txn_do(
            sub {
                my ($pkgid, $new) = $self->_add_header($rpm);
                if (defined($pkgid)) {
                    $pkgid or return;
                    $self->db->base->resultset('RpmFile')->create(
                        {
                            d_path => $self->key,
                            filename => $rpm,
                            pkgid => $pkgid,
                            mtime => $stat[9],
                            size  => $stat[7],
                        }
                    ); 
                    return $pkgid, $new;
                }
            },
        );
        $self->db->call_plugins_parser($self->path . '/' . $rpm, $pkgid, $new);
    };
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
        my $find = $self->db->base->resultset('Rpms')->search(
            { pkgid => $header->queryformat('%{PKGID}') }
        )->get_column('pkgid')->all;
        if ($find) {
            warn "$$ Find";
            return($header->queryformat('%{PKGID}'), 0);
        }
    }
    my $tmp = File::Temp->new( UNLINK => 1, SUFFIX => '.hdr' );
    unlink($tmp->filename);
    $header->write($tmp, 0);
    seek($tmp, 0, 0);
    my $string = '';
    while (read($tmp, my $str, 1024)) { $string .= $str }
    $tmp = undef;
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

    $self->db->base->resultset('Rpms')->create({
        pkgid  => $header->queryformat('%{PKGID}'),
        name   => $header->queryformat('%{name}'),
        header => \sprintf(qq{rpmheader_in(decode('%s', 'hex')::bytea)}, unpack('H*', $string)),
        evr    => $header->queryformat('%|EPOCH?{%{EPOCH}:}:{}|%{VERSION}-%{RELEASE}'),
        arch   => $header->queryformat('%{ARCH}'),
        issrc  => $header->hastag('SOURCERPM') ? 'f' : 't',
        description => $description,
        summary => $summary,
    });
    my $index_tag = $self->db->base->storage->dbh->prepare_cached(
        q{
        select index_rpms(?);
        }
    );
    $index_tag->execute($header->queryformat('%{PKGID}')) or return;
    $index_tag->finish;

    return($header->queryformat('%{PKGID}'), 1);
}

1;
