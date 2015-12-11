#!/usr/bin/perl -w
#
# $jwk: bind96-stats-parse.pl,v 1.4 2011/08/22 16:11:13 jwk Exp $
#
# Parse the statistics file produced by BIND 9.6 and higher. Output
# the statistics in format that's easily parseable by a
# script/program/whatever.
#
# Joel Knight
# knight.joel gmail.com
# 2010.12.26
#
# http://www.packetmischief.ca/monitoring-bind9/


use strict;
use warnings;

# how often are you pulling statistics?
my $INTERVAL = 300;

my $prefix;
my $view;
my $item;
my $cnt;

my $now = time;

my $go = 0;

while (<>) {
	chomp;
	# +++ Statistics Dump +++ (1293358206)
	if (m/^\+\+\+ Statistics Dump \+\+\+ \((\d+)\)/) {
		my $d = $now - $1;
		# stats that are older than $INTERVAL seconds are ones that we've
		# already processed
		if ($d >= $INTERVAL) {
			next;
		} else {
			print scalar localtime $1, "\n";
			$go++;
		}
	}

	next unless $go;

	# ++ Incoming Requests ++
	# ++ Socket I/O Statistics ++
	if (m/^\+\+ ([^+]+) \+\+$/) {
		($prefix = lc $1) =~ s/[\s\>\<\/\(\)]/_/g;
		$view = $item = $cnt = "";
	}
	# [View: custom_view_name]
	# we ignore the view name "default" so that the word "default" is not
	# inserted into the output.
	if (m/^\[View: (\w+)(| .*)\]/) {
		next if $1 eq "default";
		$view = $1;
	}

	#               407104 QUERY
	#                 3379 EDNS(0) query failures
	#                  134 queries with RTT < 10ms
	if (m/^\s+(\d+) ([^\n]+)/) {
		($cnt = lc $1) =~ s/[\s\>\<\/\(\)]/_/g;
		($item = lc $2) =~ s/[\s\>\<\/\(\)]/_/g;

		if ($view) {
			print "$prefix\+$view:$item=$cnt\n";
		} else {
			print "$prefix:$item=$cnt\n";
		}
	}
}
