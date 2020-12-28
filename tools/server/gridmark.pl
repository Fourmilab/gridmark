#! /usr/bin/perl

    #               Fourmilab Gridmark Log Server

    #   This program is installed in a Web Server's Common Gateway
    #   Interface (CGI) directory and implements a Web service which
    #   allows Gridmark objects in Second Life to log test results
    #   on the server.  Access to the server is via API keys in
    #   the directory declared below.  API keys are just files in
    #   the directory (all that matters is presence; content is
    #   irrelevant).  The API key is specified in a request URL by
    #   the "k=" argument.

    #   Requests implemented by the server are:

    #       l       Add test results to log
    #       dump    Dump entire log file
    #       extract Extract log file by user, start and end time,
    #               test, status, and region
    #       status  Show size of log file in lines and bytes

    #   The program may also be run from the command line on the
    #   server for administrative purposes.  You must have
    #   appropriate permissions on the $logFile declared below
    #   to run these commands.

    #       purge age [ really ]
    #           Purge log items older than age (days by
    #           default, or specify unit: s/m/h/d/w.
    #
    #       status
    #           Show statistics about log file.

    #   Directory containing the API key files
    my $APIkeys = "/server/pub/gridmark/apikeys";

    #   Full path name of log file
    my $logFile = "/server/var/gridmark/gridmark_log.csv";

    #   The following IP addresses are whitelisted and need
    #   not supply an API key to access the server.

    my $ipWhitelist = qr/NO\.IP\.ADDRESS\.WHITELIST/;

    use strict;
    use warnings;

    use Fcntl qw(:DEFAULT :flock :seek);    # Import flock() LOCK_ , O_, and SEEK_ constants
    use URI::Encode qw(uri_decode);
    use POSIX qw(strftime);
    use Time::Local;
    use File::Temp qw(tempfile);
    use Text::CSV_XS;

    my $argc = scalar(@ARGV);
    if ($argc > 0) {
        processCommandLine();
        exit(0);
    }

    binmode(STDOUT, ":utf8");

    print("Content-type: text/plain; charset=utf-8\r\n\r\n");

    #   Decode QUERY_STRING and extract the items into %args

    my %args;

    my $q = $ENV{QUERY_STRING};
    #   Note that colon is not strictly permitted in a URI encoded
    #   string, but it does no harm in a HTTP query string, and
    #   allowing it makes specifying times a HH:MM:SS much more
    #   convenient.  If you prefer to write "%3A", be my guest.
    while ($q =~ s/(\w+)(?:=([\w\-_\.~%:]+))?//) {
        my ($var, $val) = ($1, $2);
        if (!$val) {
            $val = "1";
        }
        $args{$var} = uri_decode($val);
    }

    #   Check if user has access to this service

    if (!(($ENV{REMOTE_ADDR} =~ m/$ipWhitelist/) ||
          ($args{k} && (-f "$APIkeys/$args{k}.api")))) {
        print("403,\"Access denied: API key missing or incorrect\"\n");
        exit(0);
    }

    #   If the record contains a log item, append it to the
    #   log file.

    #   l  --  Add log item

    if ($args{l}) {

        #   Sanity check the log item to reject trash which
        #   may arrive from the random spam spew on the Internet.

        if ($args{l} !~ m/"[^"]+",\d+\.\d+,Gm,\d,/) {
            print("400,\"Incorrectly formatted log item\"\n");
            exit(0);
        }
        open(LOG, "+>>$logFile") || die("Cannot open $logFile");
        flock(LOG, LOCK_EX);
        seek(LOG, SEEK_END, 0);     # In case somebody beat us to the lock
        #   We prefix the record from the client with the IP address
        #   from which it was sent and the date and time of this
        #   log update.
        print(LOG "$ENV{REMOTE_ADDR}," .
            strftime("%FT%T", gmtime(time())) . "," . $args{l} . "\n");
        my $flength = tell(LOG);
        flock(LOG, LOCK_UN);
        close(LOG);
        print("200,$flength\n");
        exit(0);
    }

    #   Check for and process administrative requests

    #   status  --  Show size of log in lines and bytes

    if ($args{status}) {
        my $wc = `wc -cl $logFile`;
        $wc =~ m/^\s*(\d+)\s+(\d+)\s/;
        my ($lines, $bytes) = ($1, $2);
        print("200,bytes,$bytes,lines,$lines\n");
        exit(0);
    }

    #   dump  --  Dump entire log file

    if ($args{dump}) {
        open(LOG, "<$logFile") || die("Cannot open $logFile");
        flock(LOG, LOCK_SH);
        my $flength = -s $logFile;
        print("200,$flength\n");
        while (my $l = <LOG>) {
            print($l);
        }
        flock(LOG, LOCK_UN);
        close(LOG);
        exit(0);
    }

    #   extract  --  Extract data from log file

    if ($args{extract}) {
        my $user = $args{user};
        my $start = $args{start};
        my $end = $args{end};
        my $stat = $args{stat};
        my $test = $args{test};
        my $region = $args{region};

        open(LOG, "<$logFile") || die("Cannot open $logFile");
        flock(LOG, LOCK_SH);
        my $flength = -s $logFile;
        print("200,$flength\n");
        while (my $l = <LOG>) {
            chomp($l);
            my $csv = Text::CSV_XS->new({binary => 1});
            $csv->parse($l);
            my @r = $csv->fields;
            #   Apply filters to choose data extracted:
            #       user=Second Life username
            #       start=YYYY-MM-DDThh:mm:ss Date and time started
            #       end=YYYY-MM-DDThh:mm:ss Date and time ended
            #       stat=n Test status (0 fail, 1 succeed)
            #       test=Test name
            #       region=Region in which test run
            if (((!$user) || ($user eq $r[2])) &&
                ((!$start) || (datecomp($start, $r[1]) <= 0)) &&
                ((!$end) || (datecomp($end, $r[1]) >= 0)) &&
                (($stat eq "") || ($stat eq $r[5])) &&
                ((!$test) || ($test eq $r[6])) &&
                ((!$region) || ($region eq $r[7]))
                ) {
                print("$l\n");
            }
        }
        flock(LOG, LOCK_UN);
        close(LOG);
        exit(0);
    }

    #   Compare two dates to the precision of the shorter

    sub datecomp {
        my ($d1, $d2) = @_;

        my ($l1, $l2) = (length($d1), length($d2));
        my $ls = ($l1 < $l2) ? $l1 : $l2;
        return substr($d1, 0, $ls) cmp substr($d2, 0, $ls);
    }

    #   Process command line operations.  Note that these
    #   cannot be accessed via CGI and hence may include
    #   administrative operations such as purging the
    #   database.

    sub processCommandLine {

        #   Purge duration [ really ]

        if ($ARGV[0] eq "purge") {
            if ($argc > 1) {
                my $purgeAge = $ARGV[1];    # Purge age in days
                my $really = ($argc > 2) && ($ARGV[2] eq "really");

                my $day = 24 * 60 * 60;
                #   Parse duration.  Suffixes are:
                #       s   Seconds
                #       h   Hours
                #       d   Days
                #       w   Weeks
                if ($purgeAge =~ s/([smhdw])$//) {
                    my $interval = $1;
                    if ($interval eq "m") {
                        $purgeAge *= 60;
                    } elsif ($interval eq "h") {
                        $purgeAge *= 60 * 60;
                    } elsif ($interval eq "d") {
                        $purgeAge *= $day;
                    } elsif ($interval eq "w") {
                        $purgeAge *= 7 * $day;
                    }
                } else {
                    $purgeAge *= $day;
                }

                my $now = time();

                my ($deleted, $preserved) = (0, 0);
                open(LOG, "+<$logFile") || die("Cannot open $logFile");
                flock(LOG, LOCK_EX);
                seek(LOG, SEEK_SET, 0);
                my $olog;
                my $n = 0;
                my $presItems;
                if ($really) {
                    $presItems = tempfile();
                }
                while (my $l = <LOG>) {
                    $n++;
                    $l =~ m/,([^,]+),/ || die("Cannot parse log record");
                    my $dt = $1;
                    $dt =~ m/(\d+)\-(\d+)\-(\d+)T(\d+):(\d+):(\d+)/;
                    my ($YYYY, $MM, $DD, $hh, $mm, $ss) = ($1, $2, $3, $4, $5, $6);
                    my $rtime = timegm($ss, $mm, $hh, $DD, $MM - 1, $YYYY);
                    my $age = $now - $rtime;
                    my $purge = $age > $purgeAge;
                    my $sflag = $purge ? "-" : ".";
                    if ($purge) {
                        $deleted++;
                    } else {
                        $preserved++;
                        if ($really) {
                            print($presItems $l);
                        }
                    }
                }

                #   If this is a real purge and we deleted any records,
                #   truncate the log and copy the file of preserved
                #   records over top of it.

                if ($really && ($deleted > 0)) {
                    seek($presItems, SEEK_SET, 0);
                    seek(LOG, SEEK_SET, 0);
                    truncate(LOG, 0);
                    while (my $l = <$presItems>) {
                        print(LOG $l);
                    }
                    close($presItems);          # Deletes temporary file
                }
                flock(LOG, LOCK_UN);
                close(LOG);
                if ($really) {
                    print("Purge complete.  $deleted deleted, $preserved preserved.\n");
                } else {
                    print("Purge would delete $deleted items, preserve $preserved.\n");
                }
            } else {
                print("Purge time in days unspecified.\n");
                exit(1);
            }

        #   status

        } elsif ($ARGV[0] =~ m/^stat/) {
            open(LOG, "<$logFile") || die("Cannot open $logFile");
            flock(LOG, LOCK_SH);
            my $flength = -s $logFile;
            my $nitems = 0;
            my (%users, %dates, %tests, %regions);
            while (my $l = <LOG>) {
                $nitems++;
                chomp($l);
                my $csv = Text::CSV_XS->new({binary => 1});
                $csv->parse($l);
                my @r = $csv->fields;

                $users{$r[2]}++;
                my $d = $r[1];
                $d =~ s/T.*$//;
                $dates{$d}++;
                $tests{$r[6]}++;
                $regions{$r[7]}++;
            }
            my $lsize = tell(LOG);
            flock(LOG, LOCK_UN);
            close(LOG);

            print("Log items: $nitems, log file size $lsize.\n");
            print("Users:\n");
            foreach my $k (sort(keys(%users))) {
                printf("    %-16s  %4d\n", $k, $users{$k});
            }
            print("Dates:\n");
            foreach my $k (sort(keys(%dates))) {
                printf("    %-16s  %4d\n", $k, $dates{$k});
            }
            print("Tests:\n");
            foreach my $k (sort(keys(%tests))) {
                printf("    %-16s  %4d\n", $k, $tests{$k});
            }
            print("Regions:\n");
            foreach my $k (sort(keys(%regions))) {
                printf("    %-24s  %4d\n", $k, $regions{$k});
            }
        }
    }
