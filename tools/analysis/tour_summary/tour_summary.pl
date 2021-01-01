#! /usr/bin/perl

    #   Compute statistics from a series of Fourmilab Gridmark
    #   reports copied and pasted from local chat.  This can
    #   read a chat transcript from a test like the included
    #   notecard script: "Script: Tour", ignoring any
    #   extraneous matter in the transcript.

    #   The Text::CSV module is used to parse the test info
    #   result records.
    use strict;
    use warnings;

    use Text::CSV;
    use POSIX qw(strftime);

    #   %merit is a hash of hashes which is indexed first by the
    #   region and second by the extended test name.  The value
    #   is the figure of merit for the test in that region
    my %merit;

    #   The first region on the tour is used as the reference
    #   for figure of merit computations.  The displayed performance
    #   scores are the figures of merit from %merit normalised
    #   by the reference from this hash, which is indexed by the
    #   extended test name.
    my $refReg;
    my %refFig;

    #   These hashes are used to accumulate lists of tests,
    #   extended tests (test:subtest), and regions from the
    #   transcript.  There is no guarantee that all tests will
    #   have been run in all regions.
    my (%tests, %extests, %regions);

    #   These hashes are used to compute the figure of merit
    #   from a series of rezscript tests run within a region.
    #   The hold the number of tests run and the sum of their
    #   figures of merit, allowing computation of the mean value.
    #   They are indexed by the region name.
    my (%rezscN, %rezscS);

    #   Time we ran the test (first time stamp in chat transcript)
    my $testTime;

    #   Hashes of information about regions and parcels visited
    my (%region, %parcel);

    #   Read the chat transcript and extract the log records for
    #   successful tests.  The reports from the tests are stored
    #   in two hashes, indexed by the extended task name and the
    #   region in which the test was run.

    my $l;
    my $ureg;

    binmode(STDIN, ":utf8");
    binmode(STDOUT, ":utf8");

    #   This regular expression provides a "quick reject" of lines
    #   from the chat transcript which obviously not our log items.
    #   This avoids passing arbitrary material to the CSV parser
    #   which might befuddle it.  If something slips past this
    #   test, we'll still catch it later as not conforming to
    #   our expectations for known tests.
    my $logItem = qr/[\s,](Gm,1,\w+,"?[^",]+"?,.*)$/;

    #   Tests we process.  Any others are ignored.

    my $knownTests = qr/(?:time|info|compute|message|rezscript|teleport)/;

    while (my $l = <>) {
        chomp($l);

        if ($l =~ m/$logItem/) {
            my $record = $1;

            #   We now have something that looks plausibly like
            #   one of our log entries.  Now pass it to the CSV
            #   parser and crack it into fields.

            my $csv = Text::CSV->new({binary => 1});
            $csv->parse($record);
            my @r = $csv->fields;

            #   Next, sanity check the parsed record to verify
            #   it conforms to our expectations.  This should get
            #   rid of almost all false positives except
            #   maliciously-constructed spoofing.

            if (($r[0] eq "Gm") && ($r[1] == 1) &&
                ($r[2] =~ m/$knownTests/)) {
                my ($testname, $region) = ($r[2], $r[3]);

                splice(@r, 0, 4);
                if ($testname eq "info") {
                    processInfoRecord($region, \@r);
                } elsif ($testname eq "time") {
                    if (!$testTime) {
                        $testTime = $r[1];          # Unix time of test
                    }
                } elsif ($testname eq "teleport") {
##
                } else {
                    my $ext = exTest($testname, \@r);
                    my $mer = fMerit($testname, $region, \@r);

                    $tests{$testname}++;
                    $extests{$ext}++;
                    $regions{$region}++;

                    #   If this is the first result for this test, save it
                    #   as the reference figure of merit for the report.
                    if (!$refReg) {
                        $refReg = $region;
                    }
                    if ((!$refFig{$ext}) ||
                        (($region eq $refReg) && ($ext eq "rezscript"))) {
                        $refFig{$ext} = $mer;
                    }

                    #   Record the figure of merit for the region and test
                    $merit{$region}{$ext} = $mer;
                }

            }
else { die("Bogus record!"); }
        }
    }

    my %nrreg = %regions;
    delete($nrreg{$refReg});
    my @nrregs = $refReg;
    push(@nrregs, sort(keys(%nrreg)));

    #   Edit and print the test summary

    my $td = strftime("%F %R", gmtime($testTime));
    print <<"EOF";
                                    $td UTC

 _________ C O M P U T E ________   ___ M E S S A G E ___   REZ
 float list  prim  string texture   link  region regionto  rezscr      Region
EOF
    for my $kreg (@nrregs) {
        $ureg = $kreg;
        printf("  %3s   %3s   %3s   %3s   %3s        %3s   %3s   %3s        %4s       %s\n",
            pt("compute:float"), pt("compute:list"), pt("compute:prim"), pt("compute:string"), pt("compute:texture"),
            pt("message:link"), pt("message:region"), pt("message:regionto"),
            pti("rezscript"), $ureg);
    }

    #   Print table of information about regions

    print <<"EOF";

  Region                   Agents  FPS  Dila CPU Prims Parcel Region DaysUp
EOF

    for my $kreg (@nrregs) {
        printf("%-24s  %3d/%-3d %4.f  %4.2f  %1d   %5d/%-5d  %5d  %4.1f  %s\n",
            $kreg, $region{$kreg}{agents}, $region{$kreg}{agent_limit},
            $region{$kreg}{framesSec},
            $region{$kreg}{timeDilation}, $region{$kreg}{region_cpu_ratio},
            $parcel{$region{$kreg}{parcel}}{primsUsed},
            $parcel{$region{$kreg}{parcel}}{primsMax},
            $region{$kreg}{region_max_prims},
            $region{$kreg}{region_up_time} / (24 * 60 * 60),
            $region{$kreg}{region_product_name}
        );
    }



    #   pt  --  Format a figure of merit

    sub pt {
        my ($tst) = @_;

        my $fom = $merit{$ureg}{$tst} ?
            sprintf("%.0f", ($merit{$ureg}{$tst} / $refFig{$tst}) * 100) : "";
        return $fom;
    }

    #   pti  --  Format an inverse figure of merit

    sub pti {
        my ($tst) = @_;

        my $fom = $merit{$ureg}{$tst} ?
            sprintf("%.3g", (1 / ($merit{$ureg}{$tst} / $refFig{$tst})) * 100) : "";
        return $fom;
    }

    #   exTest  --  Return the extended test name (test:subtest)
    #               from the test name and results.

    sub exTest {
        my ($testname, $results) = @_;

        if ($testname eq "compute") {
            my $task = $results->[1];
            $testname = "$testname:$task";
        } elsif ($testname eq "message") {
            my $type = $results->[1];
            $testname = "$testname:$type";
        }

        return $testname;
    }

    #   fMerit  --  Extract figure of merit from test results

    sub fMerit {
       my ($testname, $region, $results) = @_;

        my $merit;

        if ($testname eq "compute") {
             $merit = $results->[3];        # ips (iterations/second)
        } elsif ($testname eq "message") {
            $merit = $results->[13];        # bytes/sec
        } elsif ($testname eq "rezscript") {
            #   Computation of the figure of merit for the rezscript
            #   test is somewhat tricky, as we want to ignore the first
            #   iteration, which is sometimes an outlier, and then
            #   compute the mean over the subsequent iterations.  We
            #   do this by using auxiliary hashes to sum and count
            #   the iterations, then report the mean as iterations
            #   arrive, counting on the callers to use only the last
            #   reported.
            $merit = $results->[5];         # delay
            if ($rezscN{$region}) {
                $rezscN{$region}++;
                $rezscS{$region} += $merit;
                return $rezscS{$region} / $rezscN{$region};
            } else {
                $rezscN{$region} = 0;
                $rezscS{$region} = 0;
            }
        }

        return $merit;
    }

    #   processInfoRecord  --  Process an info record, extracting region
    #                          and parcel information into a location
    #                          record.  We don't assume that these records
    #                          appear in any particular order, just that
    #                          we've seen them all before we need the
    #                          complete information.

    sub n {                 # Helper to convert strings to numbers
        my ($s) = @_;

        return 0 + $s;
    }

    sub v {                 # Helper to convert vectors to arrays
        my ($s) = @_;

        $s =~ m/<(.*?),(.*?),(.*?)>/;
        my ($x, $y, $z) = ($1, $2, $3);
        return [ n($x), n($y), n($z) ];
    }

    sub processInfoRecord {
        my ($region, $r) = @_;

        my $kind = $r->[0];
        if ($kind eq "region") {
            my %regrec = (
                gridLoc => v($r->[2]),
                hostName => $r->[3],
                framesSec => n($r->[4]),
                timeDilation => n($r->[5]),
                flags => n($r->[6]),
                agents => n($r->[7]),
                wind  => v($r->[8])
            );
            foreach my $k (keys(%regrec)) {
                $region{$region}{$k} = $regrec{$k};
            }
        } elsif ($kind eq "regenv") {
            my %regenv = (
                #   Field names are as in llGetEnv() calls
                agent_limit => n($r->[1]),
                dynamic_pathfinding => $r->[2],
                estate_id => n($r->[3]),
                estate_name => $r->[4],
                frame_number => n($r->[5]),
                region_cpu_ratio => n($r->[6]),
                region_idle => n($r->[7]),
                region_product_name => $r->[8],
                region_product_sku => $r->[9],
                region_start_time => n($r->[10]),
                region_up_time => n($r->[11]),          # One of our own
                sim_channel => $r->[12],
                sim_version => $r->[13],
                simulator_hostname => $r->[14],
                region_max_prims => n($r->[15]),
                region_object_bonus => n($r->[16]),
                whisper_range => n($r->[17]),
                chat_range => n($r->[18]),
                shout_range => n($r->[19])
            );
            foreach my $k (keys(%regenv)) {
                $region{$region}{$k} = $regenv{$k};
            }
        } elsif ($kind eq "regrate") {
            $region{$region}{"sim_rating"} = $r->[1];
        } elsif ($kind eq "parcel") {
            $parcel{$r->[1]} = {
                region => $region,
                description => $r->[2],
                ownerKey => $r->[3],
                ownerType => $r->[4],
                ownerName  => $r->[5],
                area => n($r->[6]),
                primsUsed  => n($r->[7]),
                primsMax  => n($r->[8]),
                flags => n($r->[9])
            };
            #   Cross-link parcel tested to region
            $region{$region}{parcel} = $r->[1];
        }
else { die("Blooie!"); }
    }
