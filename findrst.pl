#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    use FindBin '$Bin';
}

if ($#ARGV < 1) {
    print "usage: ./findrst.pl name chr1.fa <chr2.fa ... chrN.fa>\n"
	, "  output will be printed on console\n"
	, "  (redirect to a file with \"> filename\")\n";
    exit;
}

my $name = $ARGV[0];
my @chrfiles = @ARGV;
shift @chrfiles;
my $numfiles = $#ARGV;

my @chrnames = @chrfiles;
for (@chrnames) {
    s{.*/}{};      # removes path (warning: not in Windows)
    s{\.[^.]+$}{}; # removes extension
}

# Get restriction factor code
open REBASE, "< $Bin/share/bionetc.txt";
my @rebaselines = grep(/^$name /, <REBASE>);
die "Restriction factor search error, not found" if ($#rebaselines < 0);
die "More than one restriction factor found in search" if ($#rebaselines > 0);
my $rebaseline = shift @rebaselines;
close REBASE;
(my $rstcode = $rebaseline) =~ s{.* }{}; chomp($rstcode);
my $cutsite = index($rstcode, '^');

if ($cutsite < 0) {
    warn "No cutsite in rstcode: $rstcode\n";
    $cutsite = int(length($rstcode) / 2);
} else {
    $rstcode =~ s{\^}{};
}

# Build the regex string
$rstcode =~ s{R}{[AGR]}g;
$rstcode =~ s{Y}{[TCY]}g;
$rstcode =~ s{W}{[ATW]}g;
$rstcode =~ s{S}{[GCS]}g;
$rstcode =~ s{M}{[ACM]}g;
$rstcode =~ s{K}{[GTK]}g;
$rstcode =~ s{H}{[ATCHMWY]}g;
$rstcode =~ s{B}{[GCTBKSY]}g;
$rstcode =~ s{V}{[GACVMSR]}g;
$rstcode =~ s{D}{[GATDKWR]}g;
$rstcode =~ s{N}{[GATCNDVBHKMSWYR]}g;

my $index = 0;
# Let's search the string in every file
for (my $i = 0; $i <  $numfiles; $i++) {
    open FILE, "< $chrfiles[$i]" or die "could not open $chrfiles[$i]: $!"; 
    my @content = <FILE>;
    close FILE;

    my @splicelist;
    for (@content) {
	chomp;
	if ( $_ =~ /^!/ ) {
	    push @splicelist, $. ;
	}
	if ( $_ =~ /^>/ ) {
	    $_ =~ m/^>(\w+)/;
	    my $readname = $1;
	    if (!($chrnames[$i] eq $readname)) {
		warn "Fasta id doesn't matches filename: $chrnames[$i] "
		    ,"vs. $readname\n";
		$chrnames[$i] = $readname;
	    }
	    push @splicelist, $. ;
	}
    }

    for (@splicelist) {
	splice @content, $_, 1;
    }
    my $contentstr = uc(join("", @content));
    my $chrlength = length($contentstr);

    my @matches;
    while ($contentstr =~ /$rstcode/g) {
	push @matches, $-[0] + $cutsite + 1; # 1-based coordinate
    }

    my $old = 1;
    my $discarded = 0;
    for my $j (0 .. $#matches) {
	if ($old == $matches[$j]) {
	    $discarded++;
	    next;
	}
	print join("\t", $index, $chrnames[$i],
		   $j - $discarded, $old, $matches[$j], "\n");
	$old = $matches[$j];
	$index++;
    }
    print join("\t", $index, $chrnames[$i],
	       @matches - $discarded, $old, $chrlength + 1, "\n");
    $index++;
}
