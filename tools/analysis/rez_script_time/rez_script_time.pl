#! /usr/bin/perl

    #   Compute statistics from a series of Fourmilab Gridmark
    #   reports copied and pasted from local chat.  This can
    #   read a chat transcript from a test like the included
    #   notecard script: "Script: Rez time", ignoring any
    #   extraneous matter in the transcript.  It can also
    #   process a log from the Gridmark HTTP server.

    #   This program requires the Statistics::Descriptive
    #   package, which can be installed on Xubuntu systems
    #   with:
    #       apt-get install libstatistics-descriptive-perl
    #   Since the CSV output generated by the rezscript test
    #   is very simple, we don't bother with Text::CSV but
    #   instead roll our own parser here.

    use strict;
    use warnings;

    use Statistics::Descriptive;
    use POSIX qw(strftime);

    my $slow = 1.8;         # Criterion for considering a region "slow"

    my %regcodes = (        # Codes for region types
        "Estate / Full Region" => "ER",
        "Estate / Full Region 30k" => "ER30",
        "Estate / Homestead" => "EH",
        "Estate / Openspace" => "EOS",
        "Estate / Full Region - Skill Gaming" => "ESG",
        "Mainland / Full Region" => "MR",
        "Mainland / Homestead" => "MH",
        "Linden Homes / Full Region" => "LHR"
    );

    my $currRegion = "";
    my ($firsTime, $lasTime) = (0, 0);
    my $upTime;
    my ($regtype, $regcode);
    my $teleports = 0;

    my ($tFast, $nFast, $tSlow, $nSlow) = (0, 0, 0, 0);

    #   Read until we find the first record of a rezscript test report

    my $header = 0;
    my ($nreg, $slowreg) = (0, 0);
    my $l;

    while (my $l = <>) {
        chomp($l);

        if ($l =~ m/Gm,1,time,.*?,(\d+)$/) {
            $lasTime = $1;
            if ($firsTime == 0) {
                $firsTime = $lasTime;
            }
        } elsif ($l =~ m/Gm,1,teleport,/) {
            $teleports++;
        } elsif ($l =~ m/Gm,1,info,[^,]*,regenv(?:,[^,]*){7},"?([^",]*)"?(?:,[^,]*){2},(\d+)/) {
            ($regtype, $upTime) = ($1, $2);
            $upTime /= 24 * 60 * 60;        # Express uptime as days
            $regcode = $regcodes{$regtype};
            if (!$regcode) {
                print(STDERR "Unknown region type \"$regtype\" in record:\n    $l\n");
                $regcode = "??";
            }
        } elsif ($l =~ m/Gm,1,rezscript,"([^"]+)",test,1,ntests,/) {
            #   We've found the first record of a rezscript test run.  Since
            #   there are start-up perturbations in this measurement,
            #   we "burn" the first record and compute statistics
            #   only for 2 through n.
            my $region = $1;
            $nreg++;
            my $s = Statistics::Descriptive::Sparse->new();
            while (my $l = <>) {
                chomp($l);

                if ($l =~ m/Gm,1,rezscript,"?([^",]+)"?,test,\d+,ntests,\d+,delay,(\d+\.\d+)/) {
                    my ($r, $delay) = ($1, $2);
                   if ($r ne $region) {
                        print(STDERR "Data sequencing error.  Skipped from region " .
                            "$region to $r without end of test.\n");
                            last;
                    }
                    $s->add_data($delay);
                } elsif ($l =~ m/Gm,1,"?([^",]+)"?,"?[^"]+"?,/) {
                    my $testname = $1;
                    #   We assume the terminating item is not the next "time" record
                    if ($testname eq "teleport") {
                        $teleports++;
                    }
                    if (!$header) {
                        $header = 1;
                        my $td = strftime("%F %R", gmtime($firsTime));
                        print <<"EOF";
                         $td UTC

  Region                           Delay    n   Std. dev  Uptime  Type
  ----------------------------    ------   ---  --------  ------  ----
EOF
                    }
                    if ($s->mean() >= $slow) {
                        $slowreg++;
                    }
                    my $slow = $s->mean() >= $slow;
                    printf("  %-28s  %8.4f  %3d  %8.4f  %6.1f    %s %s\n",
                        $region, $s->mean(), $s->count(), $s->standard_deviation(),
                        $upTime, $regcode,
                        $slow ? "  Slow" : "");
                    if ($slow) {
                        $tSlow += $upTime;
                        $nSlow++;
                    } else {
                        $tFast += $upTime;
                        $nFast++;
                    }
                    #   Done with analysis of this region.  Resume search for next.
                    last;
                }
            }
        }
    }

    #   Global analysis

    print("\nRegions: $nreg, " . ($nreg - $slowreg) . " fast, $slowreg slow.\n");
    printf("Mean uptime (days): Fast regions %.1f, Slow regions %.1f\n",
        $nFast ? ($tFast / $nFast) : 0, $nSlow? ($tSlow / $nSlow) : 0);
    printf("Total test time %.1f minutes, %d teleports.\n", ($lasTime - $firsTime) / 60, $teleports);
