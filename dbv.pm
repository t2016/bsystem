#!/usr/bin/perl
use strict;
use 5.010;
use DBI;
use Config::YAML;
use Sys::Hostname;
#use Data::Dumper;

package dbv;

sub new {
  # получаем имя класса
  my($class) = @_;
  # создаем хэш, содержащий свойства объекта
  my $config = Config::YAML->new( config => 'config.yaml' );
  my $self = {
    db_host => $config->{'db'}->[0]->{'host'},
    db_name => $config->{'db'}->[1]->{'database'},
    db_user => $config->{'db'}->[2]->{'user'},
    db_pass => $config->{'db'}->[3]->{'pass'},
    db_port => $config->{'db'}->[4]->{'port'},
    db_encoding => $config->{'db'}->[5]->{'encoding'},
    db_table => $config->{'db'}->[6]->{'table'},
    db_options => $config->{'db'}->[7]->{'options'},
    db_err => $config->{'db'}->[8]->{'err'},
    db_ok => $config->{'db'}->[9]->{'ok'},
    dist => $config->{'dist'}
  };
  bless $self, $class;
}

sub add_package {
  my $self = shift;
  my $name = shift;
  my @pkg = ($name, 0, 1, 'BASH', 3, 4, 5, 6, 7); 
  add_new_package($self->{db_name},$self->{db_user},$self->{db_pass},$self->{db_host},$self->{db_port},$self->{db_options},$self->{db_encoding},$self->{db_table},\@pkg);
}

sub add_err {
  my $self = shift;
  my $pkg = shift;
  my @pkgz = @{ $pkg };
  $pkgz[-1] = Sys::Hostname::hostname;
  add_new_err($self->{db_name},$self->{db_user},$self->{db_pass},$self->{db_host},$self->{db_port},$self->{db_options},$self->{db_encoding},$self->{db_err},\@pkgz);
}

sub add_ok {
  my $self = shift;
  my $pkg = shift;
  my @pkgz = @{ $pkg };
  $pkgz[-1] = Sys::Hostname::hostname;
  add_new_ok($self->{db_name},$self->{db_user},$self->{db_pass},$self->{db_host},$self->{db_port},$self->{db_options},$self->{db_encoding},$self->{db_ok},\@pkgz);
}

sub get_realy_need {
	my $self = shift;
	my $srpms = shift;
	return realy_need($self->{db_name},$self->{db_user},$self->{db_pass},$self->{db_host},$self->{db_port},$self->{db_options},$self->{db_encoding},$self->{db_ok},$self->{db_err}, $srpms);
}

sub check_filename {
  my $self = shift;
  my $fname = shift;
  return search_filename($self->{db_name},$self->{db_user},$self->{db_pass},$self->{db_host},$self->{db_port},$self->{db_options},$self->{db_encoding},$self->{db_table}, $fname);
}


sub realy_need {
	my ($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table_ok, $table_err, $srpms) = @_;
	my @fsrpms = @{ $srpms };

	my @fnames_ok = @{ get_tab($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table_ok, 'filename') };
	my @fnames_err = @{ get_tab($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table_err, 'filename') };
	my @bhosts = @{ get_tab($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table_err, 'bhost') };
	my @links = @{ get_tab($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table_err, 'link') };
	my @errs;
	my $id = 0;
	foreach my $ferr(@fnames_err) {
		my $pr = 0;
		foreach my $fok (@fnames_ok) {
			if ("$ferr" eq "$fok") {
				$pr = 1;
				last;
			}
		}
		if ($pr == 0) {
			# push @errs, $ferr.'*'.$bhosts[$id].'*'.$links[$id];
			push @errs, $ferr;
		}
		$id++;
	}
	my @rerrs;
	foreach my $s (@fsrpms) {
		my $fs = $s;
		$fs =~ s/.*\/(.*.src.rpm)/$1/;
		chomp $fs;
		unless ($fs ~~ @fnames_ok) {
			push @rerrs, $s;	
		}
	}
	return \@rerrs;	
}

sub get_tab {
        my ($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table, $tab) = @_;
        
        my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$dbhost;port=$dbport;options=$dboptions;tty=$dbtty","$username","$password",{PrintError => 0});
        if ($DBI::err != 0) {
                print $DBI::errstr . "\n";
                exit($DBI::err);
        }
        my $query = "SELECT $tab FROM $table";
        my $sth = $dbh->prepare($query);
        my $rv = $sth->execute();
        if (!defined $rv) {
                print "При выполнении запроса '$query' возникла ошибка: " . $dbh->errstr . "\n";
                exit(0);
        }
	my @fnames;
	while ( my @row = $sth->fetchrow_array) {
		 push @fnames, join('', @row);
	}
        $sth->finish();
        $dbh->disconnect();
	return \@fnames;
}


# err72 ( id integer NOT NULL PRIMARY KEY, filename text, link text, bhost text)
sub add_new_err {
  my ($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table, $err) = @_;
  my $size = count_packages($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table);
  my $dbhx = DBI->connect("dbi:Pg:dbname=$dbname;host=$dbhost;port=$dbport;options=$dboptions;tty=$dbtty",
          "$username","$password",{PrintError => 0});
  if ($DBI::err != 0) {
    print $DBI::errstr . "\n";
    exit($DBI::err);
  }
  my @args=@$err;
  if ( !defined( search_filename($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table, $args[0]) ) ) {
    my $queryx = "INSERT INTO $table VALUES(
        $size,
	\'$args[0]\',
        \'$args[1]\',
        \'$args[2]\'
    )";

    my $rvx = $dbhx->do($queryx);
    if (!defined $rvx) {
      print "При выполнении запроса '$queryx' возникла ошибка: " . $dbhx->errstr . "\n";
      exit(0);
    }
  }
  $dbhx->disconnect();
}

# ok72 ( id integer NOT NULL PRIMARY KEY, filename text, link text, bhost text)
sub add_new_ok {
  my ($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table, $ok_package) = @_;
  my $size = count_packages($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table);
  my $dbhx = DBI->connect("dbi:Pg:dbname=$dbname;host=$dbhost;port=$dbport;options=$dboptions;tty=$dbtty",
          "$username","$password",{PrintError => 0});
  if ($DBI::err != 0) {
    print $DBI::errstr . "\n";
    exit($DBI::err);
  }
  my @args=@$ok_package;
  if ( !defined( search_filename($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table, $args[0]) ) ) {
    my $queryx = "INSERT INTO $table VALUES(
        $size,
        \'$args[0]\',
        \'$args[1]\',
        \'$args[2]\'
    )";

    my $rvx = $dbhx->do($queryx);
    if (!defined $rvx) {
      print "При выполнении запроса '$queryx' возникла ошибка: " . $dbhx->errstr . "\n";
      exit(0);
    }
  }
  $dbhx->disconnect();
}


# количество записей в $table
sub count_packages {
  my ($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table) = @_;
  my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$dbhost;port=$dbport;options=$dboptions;tty=$dbtty",
          "$username","$password",{PrintError => 0});
  if ($DBI::err != 0) {
    print $DBI::errstr . "\n";
    exit($DBI::err);
  }
  my $query = "SELECT COUNT(*) FROM $table";
  my $sth = $dbh->prepare($query);
  my $rv = $sth->execute();
  if (!defined $rv) {
    print "При выполнении запроса '$query' возникла ошибка: " . $dbh->errstr . "\n";
    exit(0);
  }
  my $size = $sth->fetchrow_array();
  $sth->finish();
  $dbh->disconnect();
  return $size;
}

# количество записей в $table
sub search_filename {
  my ($dbname, $username, $password, $dbhost, $dbport, $dboptions, $dbtty, $table, $fname) = @_;
  my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$dbhost;port=$dbport;options=$dboptions;tty=$dbtty",
          "$username","$password",{PrintError => 0});
  if ($DBI::err != 0) {
    print $DBI::errstr . "\n";
    exit($DBI::err);
  }
  my $query = "SELECT filename FROM $table";
  my $sth = $dbh->prepare($query);
  my $rv = $sth->execute();
  if (!defined $rv) {
    print "При выполнении запроса '$query' возникла ошибка: " . $dbh->errstr . "\n";
    exit(0);
  }
        my @fnames;
        while ( my @row = $sth->fetchrow_array) { 
                 push @fnames, join('', @row);
        }

  $sth->finish();
  $dbh->disconnect();

  foreach my $f (@fnames) {
    if ("$f" eq "$fname") {
       return 1;
    }
  }
  return undef;
}

1;
