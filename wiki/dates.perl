# A few utilities for dealing with dates - esp HTTP headers.

# year index - an easily comparable value
# Sort of a precomputed lexicographic index. I don't use the year in the
# computation - numbers get really big - but instead return a list of the
# year, and an index _within_ the year.
#
# Given two dates, if date1 is later than date2, then
#   year1 > year2 or ((year1 == year2) and (index > index2))

# Input in same order as what gmtime() returns.
sub year_index {
    my ($sec, $min, $hour, $mday, $mon, $year) = @_;
    my $totaldays  = ($mon        * 32) + $mday;            # mday is 01-31
    my $totalhours = ($totaldays  * 24) + $hour;
    my $totalmins  = ($totalhours * 60) + $min;
    my $totalsecs  = ($totalmins  * 62) + $sec;             # 2 leap seconds!
    return ($totalsecs, $year + 1900);
}

# It seems that Perl carefully specifies symmetric division, although it's
# hard to tell from the man page (perlop). I tried it and compared it to
# Forth, and got different answers.
#
# Fortunately we're dividing non-negative numbers in this case.
sub divmod {
    use integer;
    my ($dividend, $divisor) = @_;
    return ($dividend % $divisor, $dividend / $divisor);
}

# do the reverse of year_index
sub unyear_index {
    my ($index, $year) = @_;
    my ($sec,  $totalmins)  = divmod($index,      62);      # 2 leap seconds!
    my ($min,  $totalhours) = divmod($totalmins,  60);
    my ($hour, $totaldays)  = divmod($totalhours, 24);
    my ($mday, $mon)        = divmod($totaldays,  32);      # mday is 01-31
    return ($sec, $min, $hour, $mday, $mon, $year - 1900);
}

# Some nice names.
my @long_month  = qw(January February March April May June July
                     August September October November December);
my @long_weekday = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);

my @short_month   = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my @short_weekday = qw(Sun Mon Tue Wed Thu Fri Sat);
my %index_of_month = (
    Jan => 0,      # zero-based indexing!!
    Feb => 1,
    Mar => 2,
    Apr => 3,
    May => 4,
    Jun => 5,
    Jul => 6,
    Aug => 7,
    Sep => 8,
    Oct => 9,
    Nov => 10,
    Dec => 11
);

# Convert the date into a simple "standard" format.
sub simple_date {
    my ($sec, $min, $hour, $mday, $mon, $year) = @_;

    return sprintf("%04u-%02u-%02u %02u:%02u:%02u",
                    $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
}

# Convert the date to a reader-friendly format. This spells out the month
# in full, and elides the seconds. It is used for the "Last modified" page
# footer.
sub friendly_date {
    my ($sec, $min, $hour, $mday, $mon, $year) = @_;
    $year += 1900;
    my $month = $long_month[$mon];
    return sprintf("$year $month %02u %02u:%02u", $mday, $hour, $min);
}

# RFC1123 date headers look like this:
# Date: Sat, 23 Jun 2007 02:00:52 GMT

sub rfc1123_from_seconds {
    my ($seconds) = @_;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime($seconds);
    $mon = $short_month[$mon];
    $wday = $short_weekday[$wday];
    $year += 1900;

    return sprintf("$wday, %02u $mon $year %02u:%02u:%02u GMT",
                    $mday, $hour, $min, $sec);
}

# Parse RFC1123 string; return values in same order as gmtime
# NOTE: we don't capture weekday
# $year = $trueyear - 1900
sub parse_rfc1123 {
    my ($rfc1123) = @_;
    my ($mday, $short_month, $year, $hour, $min, $sec) = $rfc1123 =~
         m/..., (\d\d) (...) (\d\d\d\d) (\d\d):(\d\d):(\d\d)/;
    my $mon = $index_of_month{$short_month};
    $year -= 1900;
    return ($sec, $min, $hour, $mday, $mon, $year);
}

# Parse RFC1123 string; convert to time index
sub index_from_rfc1123 {
    my ($rfc1123) = @_;
    return year_index(parse_rfc1123($rfc1123));
}

sub index_from_seconds {
    my ($seconds) = @_;
    return year_index(gmtime($seconds));
}

