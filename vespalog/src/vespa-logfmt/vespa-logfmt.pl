#!/usr/bin/env perl
# Copyright 2017 Yahoo Holdings. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

# BEGIN perl environment bootstrap section
# Do not edit between here and END as this section should stay identical in all scripts

use File::Basename;
use File::Path;

sub findpath {
    my $myfullname = ${0};
    my($myname, $mypath) = fileparse($myfullname);

    return $mypath if ( $mypath && -d $mypath );
    $mypath=`pwd`;

    my $pwdfullname = $mypath . "/" . $myname;
    return $mypath if ( -f $pwdfullname );
    return 0;
}

# Returns the argument path if it seems to point to VESPA_HOME, 0 otherwise
sub is_vespa_home {
    my($VESPA_HOME) = shift;
    my $COMMON_ENV="libexec/vespa/common-env.sh";
    if ( $VESPA_HOME && -d $VESPA_HOME ) {
        my $common_env = $VESPA_HOME . "/" . $COMMON_ENV;
        return $VESPA_HOME if -f $common_env;
    }
    return 0;
}

# Returns the home of Vespa, or dies if it cannot
sub findhome {
    # Try the VESPA_HOME env variable
    return $ENV{'VESPA_HOME'} if is_vespa_home($ENV{'VESPA_HOME'});
    if ( $ENV{'VESPA_HOME'} ) { # was set, but not correctly
        die "FATAL: bad VESPA_HOME value '" . $ENV{'VESPA_HOME'} . "'\n";
    }

    # Try the ROOT env variable
    $ROOT = $ENV{'ROOT'};
    return $ROOT if is_vespa_home($ROOT);

    # Try the script location or current dir
    my $mypath = findpath();
    if ($mypath) {
        while ( $mypath =~ s|/[^/]*$|| ) {
            return $mypath if is_vespa_home($mypath);
        }
    }
    die "FATAL: Missing VESPA_HOME environment variable\n";
}

BEGIN {
    my $tmp = findhome();
    $ENV{'VESPA_HOME'} = $tmp;
}
my $VESPA_HOME = $ENV{'VESPA_HOME'};

# END perl environment bootstrap section

use 5.006_001;
use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case);

my %showflags = (
	time => 1,
	fmttime => 1,
	msecs => 1,
	usecs => 0,
	host => 0,
	level => 1,
	pid => 0,
	service => 1,
	component => 1,
	message => 1
);

my %levelflags = (
	fatal => 1,
	error => 1,
	warning => 1,
	info => 1,
	config => 0,
	event => 0,
	debug => 0,
	spam => 0
);

# Do not buffer the output
$| = 1;

my $compore;
my $msgtxre;
my $onlypid;
my $onlysvc;
my $onlyhst;

my $shortsvc;
my $shortcmp;

my @optlevels;
my @optshow;
my $optlevels;
my $optfollow;
my $optnldequote;
my $optreplication;
my $opthelp = '';

my $bad = 0;

GetOptions ('level|l=s' => \@optlevels,
            'service|S=s'  => \$onlysvc,
            'show|s=s'  => \@optshow,
            'pid|p=s'  => \$onlypid,
            'component|c=s'  => \$compore,
            'message|m=s'  => \$msgtxre,
            'help|h' => \$opthelp,
            'follow|f' => \$optfollow,
            'livestream|L' => \$optreplication,
            'nldequote|N' => \$optnldequote,
            'host|H=s' => \$onlyhst,
            'truncateservice|ts' => \$shortsvc,
            'truncatecomponent|tc|t' => \$shortcmp,
) or $bad=1;

if ( $optreplication ) {
        open(STDIN, "vespa-replicate-log-stream |");
        $showflags{'host'} = 1;
} elsif ( @ARGV == 0 and ! -p STDIN) {
        push(@ARGV, "$VESPA_HOME/logs/vespa/vespa.log");
}

if ( $optfollow ) {
    my $filearg = "";
    if ( @ARGV > 1 ) {
	print STDERR "ERROR: Cannot follow more than one file\n\n";
	$bad=1;
    } else {
	$filearg = shift @ARGV if (@ARGV > 0);
	open(STDIN, "tail -F $filearg |")
	    or die "cannot open 'tail -F $filearg' as input pipe\n";
    }
}

if ( $opthelp || $bad ) {
    print STDERR "Usage: $0 [options] [inputfile ...]\n",
	"Options:\n",
	"  -l LEVELLIST\t--level=LEVELLIST\tselect levels to include\n",
	"  -s FIELDLIST\t--show=FIELDLIST\tselect fields to print\n",
	"  -p PID\t--pid=PID\t\tselect messages from given PID\n",
	"  -S SERVICE\t--service=SERVICE\tselect messages from given SERVICE\n",
	"  -H HOST\t--host=HOST\t\tselect messages from given HOST\n",
	"  -c REGEX\t--component=REGEX\tselect components matching REGEX\n",
	"  -m REGEX\t--message=REGEX\t\tselect message text matching REGEX\n",
	"  -f\t\t--follow\t\tinvoke tail -F to follow input file\n",
        "  -L\t\t--livestream\t\tfollow log stream from logserver\n",
	"  -N\t\t--nldequote\t\tdequote newlines in message text field\n",
	"  -t\t--tc\t--truncatecomponent\tchop component to 15 chars\n",
	"  --ts\t\t--truncateservice\tchop service to 9 chars\n",
	"\n",
	"FIELDLIST is comma separated, available fields:\n",
	"\t time fmttime msecs usecs host level pid service component message\n",
	"Available levels for LEVELLIST:\n",
	"\t fatal error warning info event debug spam\n",
	"for both lists, use 'all' for all possible values, and -xxx to disable xxx.\n";
    exit $bad;
}


$optlevels = join(",", @optlevels );
if ( $optlevels ) {
	my $k;
	unless ( $optlevels =~ s/^\+// or $optlevels =~ m/^-/ ) {
		$levelflags{$_} = 0 foreach ( keys %levelflags );
	}
	my @l = split(/,|(?=-)/, $optlevels);
	my $l;
	foreach $l ( @l ) {
		my $v = 1;
		my $minus = "";
		if ( $l =~ s/^-// ) { $v = 0; $minus = "-"; }
		if ( $l eq "all" ) {
			foreach $k ( keys %levelflags ) {
				$levelflags{$k} = $v;
			}
		} elsif ( defined $levelflags{$l} ) {
			$levelflags{$l} = $v;
		} else {
			print STDERR "bad level option '$minus$l'\n";
			exit 1;
		}
	}
# 	print STDERR "select level $_ => $levelflags{$_}\n"
# 		foreach ( keys %levelflags );
}

my $optshow;
$optshow = join(",", @optshow );
if ( $optshow ) {
	my $k;
	unless ( $optshow =~ s/^\+// or $optshow =~ m/^-/ ) {
		$showflags{$_} = 0 foreach ( keys %showflags );
	}
	my @l = split(/,|(?=-)/, $optshow);
	my $l;
	foreach $l ( @l ) {
		my $v = 1;
		my $minus = "";
		if ( $l =~ s/^-// ) { $v = 0; $minus = "-"; }
		if ( $l eq "all" ) {
			foreach $k ( keys %showflags ) {
				$showflags{$k} = $v;
			}
		} elsif ( defined $showflags{$l} ) {
			$showflags{$l} = $v;
		} else {
			print STDERR "bad show option '$minus$l'\n";
			exit 1;
		}
	}
#	print STDERR "show field $_ => $showflags{$_}\n"
#		foreach ( keys %showflags ) ;
}

while (<>) {
	chomp;
	if ( /^
		(\d+)\.?(\d*)	# seconds, optional fractional seconds
		\t
		([^\t]*)	# host
		\t
		(\d+\/?\d*|\-\/\d+)	# pid, optional tid
		\t
		([^\t]*)	# servicename
		\t
		([^\t]*)	# componentname
		\t
		(\w+)		# level
		\t
		(.*)		# message text
             $/x )
	{
		my $secs = $1;
		my $usec = $2 . "000000";  # make sure we have atleast 6 digits
		my $host = $3;
		my $pidn = $4;
		my $svcn = $5;
		my $comp = $6;
		my $levl = $7;
		my $msgt = $8;

		if ( ! defined $levelflags{$levl} ) {
			print STDERR "Warning: unknown level '$levl' in input\n";
			$levelflags{$levl} = 1;
		}
		next unless ( $levelflags{$levl} );

		if ($compore && $comp !~ m/$compore/o) { next; }
		if ($msgtxre && $msgt !~ m/$msgtxre/o) { next; }
		if ($onlypid && $pidn ne $onlypid) { next; }
		if ($onlysvc && $svcn ne $onlysvc) { next; }
		if ($onlyhst && $host ne $onlyhst) { next; }

		$levl = "\U$levl";

		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday);
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday)=localtime($secs);
		my $datestr = sprintf("%04d-%02d-%02d",
				      1900+$year, 1+$mon, $mday);
		my $timestr = sprintf("%02d:%02d:%02d",
				      $hour, $min, $sec);

		if ( $showflags{"time"} || $showflags{"fmttime"} ) {
			if ($showflags{"fmttime"} ) {
				print "[$datestr $timestr";
				if ( $showflags{"usecs"} ) {
					printf ".%.6s", $usec;
				} elsif ( $showflags{"msecs"} ) {
					printf ".%.3s", $usec;
				}
				print "] ";
			} else {
				printf "%s.%.6s ", $secs, $usec;
			}
		}
		if ( $showflags{"host"} ) {
			printf "%-8s ", $host;
		}
		if ( $showflags{"level"} ) {
			printf "%-7s : ", $levl;
		}
		if ( $showflags{"pid"} ) {
			printf "%5s ", $pidn;
		}
		if ( $showflags{"service"} ) {
			if ( $shortsvc ) {
				printf "%-9.9s ", $svcn;
			} else {
				printf "%-16s ", $svcn;
			}
		}
		if ( $showflags{"component"} ) {
			if ( $shortcmp ) {
				printf "%-15.15s ", $comp;
			} else {
				printf "%s\t", $comp;
			}
		}
		if ( $showflags{"message"} ) {
			if ( $optnldequote ) {
				my $did_dequote_1 = ( $msgt =~ s/\\n\\t/\n\t/g );
				my $did_dequote_2 = ( $msgt =~ s/\\n/\n\t/g );
				$msgt = "\n\t${msgt}" if ( $did_dequote_1 || $did_dequote_2 );
				$msgt =~ s/\\t/\t/;
			}
			print $msgt;
		}
		print "\n";
	} else {
		print STDERR "bad log line: '$_'\n";
	}
}
