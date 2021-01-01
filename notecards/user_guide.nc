
                            Fourmilab Gridmark

                                 User Guide

Fourmilab Gridmark is a wearable accessory or stand-alone object which
provides a variety of performance benchmark tests for the Second Life
virtual world.  By wearing the accessory and launching tests via
commands in local chat, developers can run tests which measure the
speed of scripts written in the Linden Scripting Language (LSL).  Since
Gridmark is an attachment which may be worn by an avatar, its users are
able to visit various Second Life regions to measure and compare the
performance of scripts, discovering how load on the simulator running
the region affects scripts within them.  A scripting facility permits
automating the process of running a series of tests, including
automatically teleporting the wearer to different locations in Second
Life to run tests in multiple regions.

Fourmilab Gridmark is supplied with three built-in tests measuring
different aspects of performance.  Developers may add their own custom
tests, which can be run under Fourmilab Gridmark and take advantage of
its scripting and reporting facilities.

Running Tests

Tests are launched from local chat using the “Test” command.  The
default chat channel is 76.

    compute             Script execution performance
        This test includes five sub-tests which perform different
        compute-bound operations.
            float   Floating point (Leibniz's series for Pi)
            list    List shuffling
            prim    Manipulation of prim properties
            string  String concatenation (and garbage collection)
            texture Changing texture on the attached object
        Each sub-test is scaled so one iteration runs for around one
        second in an idle simulation.  Results are reported in local
        chat in CSV format.  Here is an example of running the five
        sub-tests in a near-idle sandbox region.
            /76 test compute float 10
            Gm,1,compute,"Magnum Sandbox A",task,float,ips,133062,iter,1180000,time,8.868044
            /76 test compute list 10
            Gm,1,compute,"Magnum Sandbox A",task,list,ips,5293,iter,42230,time,7.979105
            /76 test compute prim 10
            Gm,1,compute,"Magnum Sandbox A",task,prim,ips,402,iter,3600,time,8.957100
            /76 test compute string 10
            Gm,1,compute,"Magnum Sandbox A",task,string,ips,7750,iter,82000,time,10.580360
            /76 test compute texture 10
            Gm,1,compute,"Magnum Sandbox A",task,texture,ips,377,iter,3150,time,8.357465
        When comparing performance from region to region, run the same
        test in the two regions and then compare the iterations per
        second (“ips”) between the two regions.  So now, let's go to a
        busy region, London City, which had 83 avatars present when I
        ran the tests, receiving the following results:
            Gm,1,compute,"London City",task,float,ips,22385,iter,1180000,time,52.715010
            Gm,1,compute,"London City",task,list,ips,727,iter,42230,time,58.091270
            Gm,1,compute,"London City",task,prim,ips,77,iter,3600,time,46.988560
            Gm,1,compute,"London City",task,string,ips,1716,iter,82000,time,47.780540
            Gm,1,compute,"London City",task,texture,ips,69,iter,3150,time,45.621810

    info                Parcel and Region information
        This “test” retrieves and displays information about the parcel
        and region in which it is run.  You select which by the
        argument, which should be “parcel” or “region”.  The results
        field provides detailed information encoded in Comma-Separated
        Value (CSV) fields.  The fields in the records are documented
        below in the “Info Test Record Format” section.

    message             Message exchange
        Tests scripted message sending and receiving with three
        different mechanisms: llMessageLinked(), llRegionSay(), and
        llRegionSayTo(), via tasks invoked as in the following
        examples.  The number specifies how many messages are sent to
        the built-in transponder object (which appears as a golden disc
        on top of the anvil while active).  Since each message is sent
        to the transponder then echoed back to the sender, the actual
        message traffic is twice the number of iterations specified.
        Here are examples of the three tests run at Fourmilab.
            /76 test message link 500
            Gm,1,message,"Fourmilab",type,link,messages,1000,length,128,bytes,128000,time,11.134140,"msg/sec",89.813840,"bytes/sec",11496.170000
            /76 test message region 500
            Gm,1,message,"Fourmilab",type,region,messages,1000,length,128,bytes,128000,time,11.133880,"msg/sec",89.815970,"bytes/sec",11496.440000
            /76 test message regionto 500
            Gm,1,message,"Fourmilab",type,regionto,messages,1000,length,128,bytes,128000,time,11.111410,"msg/sec",89.997570,"bytes/sec",11519.690000
        Here, the interesting numbers are the number of messages per
        second and the bytes per second transferred.  These tests used
        the default message length of 128 bytes.  Let's try increasing
        the message length to 1024 [the maximum for llRegionSay() and
        llRegionSayTo()] and see how that affects performance.
            /76 test message region 500 1024
            Gm,1,message,"Fourmilab",type,region,messages,1000,length,1024,bytes,1024000,time,11.112130,"msg/sec",89.991710,"bytes/sec",92151.520000
        We can see that the rate at which messages were sent and
        received was almost unchanged, while the data transfer rate
        increased by a factor of almost 8, corresponding to the the
        packet size.  Thus, given a choice, for best performance you
        should send large messages rather than many small ones.

    rezscript           Rez to script delay measurement
        When a script uses llRezObject() to instantiate an object from
        its inventory into the world, there is a delay between the time
        the call to create the object is made and when the scripts
        within the object begin to run.  This can cause a variety of
        problems with scripts that create objects (for example,
        projectile launchers which need to communicate with objects
        they launch).  If a script sends a message to the newly-created
        object immediately with llRegionSayTo(), for example, the
        message may be lost because the object's script has not yet
        started to run and listen for such messages.  A physical object
        may fall to the ground before its script gets a chance to
        launch it toward its destination.  Starting in early 2020,
        something changed in Second Life which caused the delay in rez
        to script time to dramatically increase, but only in certain
        regions, and occasionally changing within the same region.  For
        example, a region which was “fast” (delay less than a tenth of
        a second) may become “slow” (delay around two seconds) after
        running for some time, and then return to being “fast” when
        restarted.  The delay appears to be bimodal: you'll always see
        around the same time: “fast” or “slow", within the same region
        at a given time.

        The rezscript test creates a specified number of objects in
        front of the avatar and, through a handshaking process,
        measures how long it took for the script within the object to
        receive control.  After exchanging the handshake, each
        newly-created object self-destructs.  In order to run this test
        in a region, you must have permission to create objects there
        (for example, on your own land or in a public sandbox): if you
        don't have permission the test will fail.  Here is a sample run
        for five iterations at Fourmilab, which was “fast” when I ran
        this test.
            /76 test rezscript 5
            Gm,1,rezscript,"Fourmilab",test,1,ntests,5,delay,0.029541
            Gm,1,rezscript,"Fourmilab",test,2,ntests,5,delay,0.023979
            Gm,1,rezscript,"Fourmilab",test,3,ntests,5,delay,0.024902
            Gm,1,rezscript,"Fourmilab",test,4,ntests,5,delay,0.023457
            Gm,1,rezscript,"Fourmilab",test,5,ntests,5,delay,0.030685
        Next, we'll repeat the test at the public sandbox in the Mauve
        region (note that you'll have to walk a bit from the region's
        landing zone to get to the sandbox).
            Gm,1,rezscript,"Mauve",test,1,ntests,5,delay,2.033025
            Gm,1,rezscript,"Mauve",test,2,ntests,5,delay,2.028855
            Gm,1,rezscript,"Mauve",test,3,ntests,5,delay,2.046095
            Gm,1,rezscript,"Mauve",test,4,ntests,5,delay,2.043344
            Gm,1,rezscript,"Mauve",test,5,ntests,5,delay,2.053627
        This region was “slow” when I ran the test, having been up for
        almost five days since its last restart.

Other Chat Commands

In addition to the “Test” command, the following additional commands
may be entered in local chat.  All commands may be abbreviated to
as few as two letters.  Arguments to the “Test” command, script names,
and Beam destinations may not be abbreviated.

    Beam slURL
        Teleport to the destination specified by the Second Life
        destination slURL.  You may teleport either to a different
        location in the same region or to a different region (if the
        destination region has a “landing zone”, you may not be able to
        override where you arrive in the region).  You can specify the
        destination in any of the following forms:
            secondlife://Fourmilab/128/122/28
            http://maps.secondlife.com/secondlife/Fourmilab/120/122/28
            Fourmilab Island, Fourmilab (120, 122, 28) - Moderate
        When on the Beta Grid, destinations may be specified in its
        format:
            secondlife://Aditi/secondlife/Astutula/207/247/22

        You can specify a destination at the avatar's current position
        with:
            here://
        This is useful in conjunction with the “Set mark at” command to
        save a position to return to later.

        To set the destination to a mark previously stored with
        “Set mark at Name”, use:
            mark://Name

        The Beam command logs teleports in local chat with a CSV record
        identifying the destination and source location.  For example:
            /76 beam http://maps.secondlife.com/secondlife/London%20City/85/223/24
            Gm,1,teleport,"London City","<85.00000, 223.00000, 24.00000>","Fourmilab","<94.73176, 166.21310, 750.90120>"
        Teleports initiated directly by the user or another object are
        logged with a blank source location.

    Boot
        Restart the script, terminating any tests which may be running.

    Clear
        Send white space to local chat to visually separate test
        sequences.

    Echo text
        Echo the text in local chat.  This allows scripts to send
        messages to those running them to let them know what they're
        doing.

    Help
        Send this notecard to the requester.

    Moveto [+]<x,y,z> [ speed ]
        Moves the avatar within the current region to the location
        specified by <x,y,z> in region co-ordinates or, if prefixed by
        a plus sign, relative to the avatar's current position, at a
        speed specified as a damping time in seconds.  Very high speeds
        (small damping time) and long distances may be dangerous:
        avatars who attempt it are prone to sudden death and being
        teleported back to their home location.  The Moveto command is
        useful in scripts that teleport to parcels with a “landing
        zone” different from where the tests should be run (for
        example, a designated rez area).  A single Moveto command is
        limited to a distance of 65 metres from the avatar's original
        position.

    Script
        These commands control the running of scripts stored in
        notecards in the inventory of the Gridmark object.  Commands in
        scripts are identical to those entered in local chat (but, of
        course, are not preceded by a slash and channel number).  Blank
        lines and those beginning with a “#” character are treated as
        comments and ignored.

        Script list
            Print a list of scripts in the inventory.  Only scripts
            whose names begin with “Script: ” are listed and may be
            run.

        Script run [ Script Name ]
            Run the specified Script Name.  The name must be specified
            exactly as in the inventory, without the leading “Script: ”.
            Scripts may be nested, so the “Script run” command may
            appear within a script.  Entering “Script run” with no
            script name terminates any running script(s).

            The following commands may be used only within scripts.

            Script loop [ n ]
                Begin a loop within the script which will be executed n
                times, or forever if n is omitted.  Loops may be
                nested, and scripts may run other scripts within loops.
                An infinite loop can be terminated by “Script run” with
                no script name or by the “Boot” command.

            Script end
                Marks the end of a "Script loop".  If the number of
                iterations has been reached, proceeds to the next
                command.  Otherwise, repeats, starting at the top of
                the loop.

            Script pause [ n/touch ]
                Pauses execution of the script for n seconds.  If the
                argument is omitted, the script is paused for one
                second.  If “touch” is specified, the script will be
                paused until the object is touched or a “Script resume”
                command is entered from chat.  Pausing a script until
                touched is handy in cases where, for example, a script
                teleports to a parcel with a “landing zone” and
                requests the user to walk to a sandbox or rez zone
                before running a test.

            Script resume
                Resumes a paused script, whether due to an unexpired
                timed pause or a pause until touched or resumed.

            Script wait n[unit] [ offset[unit] ]
                Pause the script until the start of the next n units of
                time, where unit may be “s”=seconds, “m”=minutes,
                “h“=hours, or ”d”=days, plus the offset time, similarly
                specified.  This can be used in loops to periodically
                run tests at specified intervals.  For example, the
                following script reports parcel and region statistics
                once an hour at 15 minutes after the hour.
                    Script loop
                        Script wait 1h 15m
                        Time
                        Test info parcel
                        Test info region
                    Script end
                A script like this, combined with logging via Instant
                Message, to an external HTTP server, or via E-mail,
                allows placing Gridmark objects in properties you
                control and having them automatically report
                performance to you, wherever you are.

        Set
            Sets a variety of parameters.

            Set channel n
                Sets the channel on which the attachment listens for
                commands in local chat.  The default is 76.  Note that
                the channel number will revert to the default if you
                reset the script with the edit menu or Boot command.

            Set echo on/off
                Controls whether commands from local chat and scripts
                are echoed to local chat.

            Set glow n
                Set the intensity with which the anvil will glow while
                running a test.  The default is 0.25, a mild, but
                apparent glow.  Setting the intensity to 0 disables the
                glow entirely.  The glow is turned on and off outside
                the timing of the test and should not affect it.

            Set log
                Sets parameters affecting the distribution of log items
                recording the results of tests.

                Set log channel n
                    Sets the local chat channel on which test results
                    are logged.  The default is 0 (PUBLIC_CHANNEL),
                    which will appear in local chat to the avatar which
                    ran the test.  If you wish to send the log items to
                    another channel (for example, a log manager in
                    another object), specify its number, positive or
                    negative.  Sending log items to a nonzero channel
                    will cause them to not appear in the local chat
                    window.  Setting the log channel to -1 completely
                    suppresses sending log items to chat.

                Set log email
                    Controls delivery of log messages to the owner of
                    the attachment via E-mail.  If you wish to install
                    Gridmark devices in one or more of your properties
                    to periodically monitor their performance (for
                    example, run compute and message benchmarks once an
                    hour to observe how load changes over the day),
                    you can configure Gridmark to deliver the log
                    entries from the tests to you via E-mail, allowing
                    you to receive them when you aren't in Second Life.
                    Due to restrictions on the length and number of
                    messages that can be sent, this is best for
                    infrequent runs of limited tests and should not be
                    used for bulk testing across the grid.

                        Set log email collect on/off
                            Enables or disables collection of log
                            messages for E-mail delivery.  This is
                            independent of other options such as local
                            chat, Instant Message, or HTTP, and may be
                            enabled along with them.  Once you set
                            collect on, subsequent log messages from
                            tests will be saved to be sent in a later
                            E-mail.  Turning collect off stops the
                            collection of further messages but does not
                            affect those already collected.

                        Set log email send
                            The collected log entries are sent via
                            E-mail to the registered E-mail account of
                            the owner of the object.  To avoid spamming
                            third parties, it is not possible to send
                            E-mail to people other than the owner.  The
                            maximum length of an individual E-mail is
                            around 3600 characters, and if more than
                            that volume of messages are queued,
                            multiple E-mails will be sent.  But Second
                            Life only allows sending one E-mail every
                            twenty seconds, so if you queue lots of log
                            items, this can take a long time.  That's
                            why E-mail delivery of log items is best
                            used sparingly and infrequently.

                            For example, a script might run compute and
                            message benchmarks at the top of every hour
                            and send the reports to its owner via
                            E-mail with:
                                    Set log email collect on
                                    Script loop
                                        Script wait 1 hour
                                        Time
                                        Test compute float 10
                                        Test message regionto 500
                                        Set log email send
                                    Script end
                            This script will run until it is manually
                            stopped by a “Script run” or “Boot” command
                            from local chat.

                        Set log email clear
                            Discard all log items queued for E-mail.

                Set log IM on/off
                    Controls whether test log items are sent to the
                    owner of the object as Instant Messages.  Sending
                    of Instant Messages is independent of logging to
                    local chat: you can enable both if you wish.
                    Instant Messages can be received by avatars not in
                    the same region as the sending object, so logging
                    by Instant Message allows, for example, a Gridmark
                    object placed in the owner's property to
                    periodically run tests and report them to its
                    owner, regardless of where they may be.

                Set log HTTP [ URL [ API_key ] ]
                    Send log items via HTTP (World-Wide Web transfer
                    protocol) to an external server running at the
                    specified URL.  If the server requires an "API_key"
                    to prevent abuse, it may be specified after the
                    URL. A sample server, implemented as a Common
                    Gateway Interface (CGI) application in the Perl
                    language is included with the product in the
                    Tools/Server folder or may be downloaded from the
                    project's Git repository cited at the end of this
                    document.

            Set mark at/clear/list
                The Beam command allows you to specify named
                destinations called “marks”.  To create a mark use:
                    Set mark at Name Dest
                where Dest is a destination specified in any of the
                forms accepted by the “Beam” command and Name is an
                alphanumeric name which is case sensitive.  A
                particularly handy Dest specification is “here://”,
                which defines a mark at the avatar's current position.
                A list of all marks is displayed with “Set mark list”.
                To clear a mark by name, use “Set mark clear Name”;
                omitting the name deletes all marks.  To reference a
                mark in the “Beam” command use “mark://Name”, where the
                Name was that given when you created it.

            Set trace on/off
                Controls whether internal debugging information is
                sent to local chat.  This information is generally only
                of interest to developers.

        Status
            Prints status of the main Gridmark script and all
            associated scripts, including their memory usage.

        Test testname arguments...
            Runs a test defined by a script in the inventory.  The
            arguments which follow are passed to the test script and
            interpreted as it defines them.  You can list all of the
            available tests by entering “Test” with no arguments.

        Time
            Show a time stamp in the local chat in the form of a test
            log entry from a built-in “time” test.  The log entry shows
            the current region and in its results field the time, both
            as a Second Life timestamp and Unix time() value.  Both
            represent Universal Time (UTC).  A log entry looks like:
                Gm,1,time,"Fourmilab",2020-12-24T12:18:57.149372Z,1608812337
            If the time stamp was generated just at the tick of a
            second, the seconds value may differ in the two formats:
            if this matters to you, just re-generate the other from the
            one you prefer in your analysis program.

Scripting Tests

You can automate tests by creating scripts of Gridmark commands (not to
be confused with Linden Scripting Language programs) in notecards
placed in the attachment's inventory.  These scripts contain commands
in exactly the same form as entered in local chat (except for the
channel number, which doesn't apply to a script).  Names of all scripts
must begin with “Script: ” to distinguish them from other notecards.
To run a script, enter the “Script run” command with the name of the
script (excluding the “Script: ” prefix).  You can list all scripts in
the attachment with the “Script list” command.  Special commands can be
used within a script to repeat a sequence of commands multiple times
and insert pauses of a specified length—see the documentation of the
Script command for details.  You can stop a running script by entering
“Script run” with no script name.

Scripts may be nested: one script can run another.  This is
particularly handy when you want to run the same sequence of tests in a
series of different regions.

Info Test Record Format

The “info” test allows you to query a variety of information about the
parcel and region in which you're running tests, both static
(size, type, capacity) and dynamic (number of objects and avatars
present, script time dilation).  Here are the fields returned by the
queries in this test.

The “Test info parcel” command returns a single log item as follows.
    "Gm"            Identifier for Gridmark log items
    1/0             Success/failure status
    "info"          Test name
    Region name
    "parcel"        Identifier for parcel record
    Parcel name
    Parcel description  This may be long and contain (escaped) new line characters
    Owner key       Key (UUID) for owner of parcel
    Owner type      "A" for avatar, "G" for group ownership
    Owner name      Name of avatar or group owner, if available
    Area            Area in square metres
    Prims used      Land impact of objects on parcel
    Prims max       Parcel's maximum land impact capacity
    Flags           Parcel flags [see llGetParcelFlags() for details]

The "Test info region" command returns three log items describing the
region.  The first is the "region" record, which returns mostly
dynamic information.
    "Gm"            Identifier for Gridmark log items
    1/0             Success/failure status
    "info"          Test name
    Region name
    "region"        Identifier for region record
    Region name     Yes, again
    Grid location   Absolute location on grid (Z co-ordinate always 0)
    Simulator host name
    Frames per second
    Time dilation
    Flags           Region flags [see llGetRegionFlags() for details]
    Agents in region Number of agents (avatars) currently in region
    Wind            Wind vector, metres per second

The second record, "regenv", provides mostly static information about
the region.
    "Gm"            Identifier for Gridmark log items
    1/0             Success/failure status
    "info"          Test name
    Region name
    "regenv"        Identifier for regenv record
    Agent limit     Maximum agents (avatars) permitted in region
    Pathfinding     Is dynamic pathfinding "enabled" or "disabled"
    Estate ID       Numeric unique identification of the estate
    Estate name     This will be "mainland" or the name of a private estate
    Frame number    Frames executed since the region was last restarted
    Regions per CPU This will be 1 for a dedicated Region and 4 for a Homestead
    Region idle     Is region idle (1) or active (0)?
    Product name    Region product name, for example "Estate / Full Region"
    Region SKU      Internal product number for region type
    Start time      Date and time region last restarted as a Unix time() value
    Up time         Seconds since the region was last restarted
    Sim channel     Simulator channel: this will usually be "Second Life Server"
    Sim host name   Simulator host name: usually the same as in the "region" record
    Maximum prims   Maximum prims (land impact) permitted in region
    Bonus factor    Region "object bonus factor", allowing more prims in region
    Whisper range   Whisper range in metres
    Chat range      Chat range in metres
    Shout range     Shout range in metres

The third record, "regrate", provides only the region's maturity
setting.  It is placed in a separate record because a different
mechanism is used to retrieve it which can, in some circumstances,
fail, and we don't want such a failure to affect retrieval of other
information about the region.
    "Gm"            Identifier for Gridmark log items
    1/0             Success/failure status
    "info"          Test name
    Region name
    "regrate"       Identifier for regrate record
    Maturity rating "PG" (General), "MATURE" (Moderate), "ADULT", or "UNKNOWN".

Analysis Programs

Two analysis programs written in the Perl language are supplied with
the product as notecards whose content you may copy to your computer
and run locally, or which may be downloaded from the Git repository for
this project from the link at the end of this document.  These programs
read test logs from Gridmark, either copied and pasted from local chat
transcripts (material other than log items is ignored), extracted from
an HTTP server, or delivered via E-mail.  These programs are intended
to process a test suite run by the script “Script: Tour tests”,
included in the attachment's inventory.  These tests can be run
automatically in regions all across the Second Life grid with the
script “Script: Grand Test Auto”.  (Second Life is always in flux, and
some regions included in the test may have disappeared or changed
by the time you receive the object.  You may need to edit the script
accordingly to run the complete set of tests.)

Once you have run the tests and copied the log items they produced to a
file on your computer, you can analyse it with the two included
programs. The first, “tour_summary.pl”, produces an overall summary of
the tests and regions, with output like the following run.  (Due to the
proportionally-spaced font used by most viewers when displaying
notecards, the columns in the following tables won't line up.  When you
produce the reports on your own computer with a monospace terminal
font, they'll be easier to read.)  This report compares the performance
of different regions on each of the Gridmark tests, using the first
region tested (Fourmilab in this case) as the reference.  For each test
and region, a “figure of merit” is shown which compares the speed at
which the test ran compared to the reference region.  A region which
ran as fast as the reference gets a figure of merit of 100, one which
ran half as fast, 50, and a blank entry indicates a test was unable to
be run in the region due to permission settings.  Below the test table,
details on all of the regions tested from “test info” are presented.

                                    2020-12-24 13:59 UTC

 _________ C O M P U T E ________   ___ M E S S A G E ___   REZ
 float list  prim  string texture   link  region regionto  rezscr      Region
  100   100   100   100   100        100   100   100         100       Fourmilab
  136   134   138   123   131         99   100   100         103       Arowana
   50    46    55    45    53         51    54    55        57.3       Babbage Palisade
   53    50    54    42    49         35    36    35        59.9       Caledon Oxbridge
   96    99   102    91   100         99   100   100        97.5       Combat (sandbox) Rausch
   92    87    94    85   102        100   100   100        1.33       Debug1
   60    81    70    68    80         61    62    61        1.33       Devolin Mal
   43    38    45    33    45         36    36    36                   Esperia
  118   103   110    79   104         75    76    78        1.32       Langdale
   93    84    72    62    77         81    81    79        84.5       Lapara
  130   123   131   113   126        100   100   100         105       Limia
   44    34    48    36    51         51    53    42                   London City
  132   131   140   100   124         93    90    93        60.4       London City Brittany
   91    80    92    82    96         98   100   100        1.34       Maryport
   87    24    86    69    95         99    99    96        1.32       Mauve
  122   117   112    97   111        100   100   100         102       Orville
   97    92   109    96   102         99   100   100        92.2       Sandbox Amoena
   89    90    93    79   100        100   100   100        1.33       Sandbox Artifex
   94    86    96    76   105         99   100    96        1.33       Sandbox Bricker
  113   118   134   106   124        100   100   100        1.33       Sandbox Exemplar
   94    96   105    86   106        100   100   100         105       Sandbox Formonsa
  115   109   122    89   118        100   100   100         103       Sandbox Mirificatio
  123   122   116    99   122        100   100   100         105       Sandbox Pristina
   95    96    93    76   103        100   100   100        1.33       Sandbox Verenda
   91    51    57    57    79         68    71    72        1.33       Vallone
  146   132   143    98   129        100   100   100        61.1       Woodbine

  Region                   Agents  FPS  Dila CPU Prims Parcel Region DaysUp
Fourmilab                   1/44    45  0.99  1   10685/20000  20000  12.7  Estate / Full Region
Arowana                     1/25    45  1.00  4     436/4843    5000   9.1  Estate / Homestead
Babbage Palisade            1/77    45  1.00  1    1833/20000  20000  12.7  Estate / Full Region
Caledon Oxbridge            4/25    45  1.00  4    2940/5000    5000   2.3  Estate / Homestead
Combat (sandbox) Rausch     2/44    45  1.00  1       1/22313  22500   2.1  Mainland / Full Region
Debug1                      1/8     45  1.00  1     841/18813  20000  12.6  Estate / Full Region
Devolin Mal                 3/44    45  0.99  1    8731/10393  22500  13.8  Mainland / Full Region
Esperia                    18/70    45  0.98  1   26263/28527  30000   1.0  Estate / Full Region 30k
Langdale                    1/44    45  1.00  1    2324/4213   22500  12.7  Mainland / Full Region
Lapara                      2/44    44  0.95  1    2114/2158   22500  13.8  Mainland / Full Region
Limia                       1/25    45  1.00  4       2/139     5000   9.1  Estate / Homestead
London City                51/110   45  1.00  1    7806/12144  20000   2.2  Estate / Full Region
London City Brittany        4/10    45  1.00  4    3676/5000    5000   2.2  Estate / Homestead
Maryport                    1/44    45  1.00  1     342/351    22500  12.7  Mainland / Full Region
Mauve                      13/55    45  1.00  1     647/4866   22500  12.6  Mainland / Full Region
Orville                     1/44    45  1.00  1    5346/20000  20000  12.6  Estate / Full Region
Sandbox Amoena              2/44    45  1.00  1     296/18603  20000  13.8  Estate / Full Region
Sandbox Artifex             3/44    45  1.00  1     296/18603  20000  12.6  Estate / Full Region
Sandbox Bricker             7/44    45  1.00  1      98/18750  20000  12.7  Estate / Full Region
Sandbox Exemplar            2/44    45  1.00  1     296/18603  20000  13.8  Estate / Full Region
Sandbox Formonsa            3/44    45  1.00  1     296/18603  20000  12.7  Estate / Full Region
Sandbox Mirificatio         2/44    45  1.00  1     296/18603  20000   4.2  Estate / Full Region
Sandbox Pristina            2/44    45  1.00  1     296/18603  20000  12.6  Estate / Full Region
Sandbox Verenda             2/44    45  1.00  1     296/18603  20000  13.8  Estate / Full Region
Vallone                     1/44    45  1.00  1     286/351    22500  12.6  Mainland / Full Region
Woodbine                    1/25    45  1.00  4     929/679     5000   4.5  Mainland / Homestead

A second analysis program, “rez_script_time.pl”, concentrates upon the
rezscript test, running it five times in every region which permits
it, and computing the mean time between creation of an object and
its scripts beginning to run.

                         2020-12-24 13:59 UTC

  Region                           Delay    n   Std. dev  Uptime  Type
  ----------------------------    ------   ---  --------  ------  ----
  Fourmilab                       0.0296    5    0.0102    12.7    ER
  Sandbox Pristina                0.0263    5    0.0011    12.6    ER
  Sandbox Exemplar                2.0227    5    0.0006    13.8    ER   Slow
  Sandbox Verenda                 2.0228    5    0.0006    13.8    ER   Slow
  Sandbox Formonsa                0.0269    5    0.0010    12.7    ER
  Sandbox Amoena                  0.0283    5    0.0010    13.8    ER
  Sandbox Artifex                 2.0267    5    0.0104    12.6    ER   Slow
  Sandbox Mirificatio             0.0262    5    0.0003     4.2    ER
  London City Brittany            0.0358    5    0.0098     2.2    EH
  Debug1                          2.0222    5    0.0004    12.6    ER   Slow
  Mauve                           2.0325    5    0.0052    12.6    MR   Slow
  Devolin Mal                     2.0310    5    0.0056    13.8    MR   Slow
  Limia                           0.0299    5    0.0096     9.1    EH
  Arowana                         0.0250    5    0.0009     9.1    EH
  Orville                         0.0262    5    0.0009    12.6    ER
  Woodbine                        0.0440    5    0.0006     4.5    MH
  Lapara                          0.0366    5    0.0071    13.8    MR
  Caledon Oxbridge                0.0609    5    0.0090     2.3    EH
  Babbage Palisade                0.0374    5    0.0180    12.7    ER
  Maryport                        2.0224    5    0.0104    12.7    MR   Slow
  Combat (sandbox) Rausch         0.0266    5    0.0006     2.1    MR
  Langdale                        2.0309    5    0.0095    12.7    MR   Slow
  Sandbox Bricker                 2.0209    5    0.0013    12.7    ER   Slow
  Vallone                         2.0333    5    0.0130    12.6    MR   Slow

  Regions: 25, 15 fast, 10 slow.
  Mean uptime (days): Fast regions 8.9, Slow regions 13.0
  Total test time 66.1 minutes, 27 teleports.

A third program, “periodic_monitor.pl”, reads logs collected by a
Gridmark appliance installed in a fixed location, running tests at
regular intervals.  The following log reflects data collected hourly
over a one day period at the Fourmilab houseboat using the “Periodic
test” script supplied with Gridmark.

                                      2020-12-25 14:00 UTC

   _________ C O M P U T E ________   ___ M E S S A G E ___   REZ
   float list  prim  string texture   link  region regionto  rezscr           Time
    100   100   100   100   100        100   100   100         100       2020-12-25 14:00
    101   100    85    88    95        101   106    99        99.2       2020-12-25 15:00
     97    90    88    92    97        101   106   100         100       2020-12-25 16:00
    102    87    83    87    95        100   106   100         100       2020-12-25 17:00
     96    96    90    93    98        100   106   100        99.7       2020-12-25 18:00
     95    92    89    90    96        100   106   100         101       2020-12-25 19:00
    102    94    86    91    97        100   106   100         100       2020-12-25 20:00
     97    91    87    99   102        101   106   100        99.7       2020-12-25 21:00
     99    87    86    86    96        100   106   100         100       2020-12-25 22:00
     98    98    90    98   102        101   106   100         100       2020-12-25 23:00
     96    99    87    89    98        100   106   100        99.5       2020-12-26 00:00
     95    96    88    85    99        100   106   100        99.3       2020-12-26 01:00
     99    96    89    84   101        100   106   100         100       2020-12-26 02:00
     95    83    83    82    96        100   106    99         100       2020-12-26 03:00
    101   104    86    91    96        100   106   100        99.9       2020-12-26 04:00
    102    99    88    90    99        101   106   100         100       2020-12-26 05:00
     96    95    90    86    99        100   106   100        99.5       2020-12-26 06:00
     96   100    87    89    99        101   106   100        99.5       2020-12-26 07:00
     97    90    89    85   100        101   106   100         100       2020-12-26 08:00
     97    97    91    95    98        101   106   100         100       2020-12-26 09:00
     99   103    90    93    99        101   106   100        99.8       2020-12-26 10:00
     95    95    86    88    96        101   106   100         100       2020-12-26 11:00
    102    93    85    96    98        101   106   100         100       2020-12-26 12:30
     97    87    88    86    95        101   106    99         100       2020-12-26 13:00

    Region                   Agents  FPS  Dila CPU Prims Parcel Region DaysUp
  Backhill                    0/59    45  1.00  1     333/351    22500  14.6  Linden Homes / Full Region

A fourth program, “airborne_surveillance.pl”, processes data collected 
periodically in multiple regions by a script and compares performance 
over time for tests run in the regions.  Output can be either a table 
or chart created by the Gnuplot program.  The “Airborne Reconnaissance” 
script, included with Gridmark, demonstrates collection of data for 
analysis by this program.  Here is an extract from a run sampling 
performance at the busy London City region at half hour intervals 
between 16:00 and 22:00 Universal Time, showing performance on the 
compute:float and message:region tests, the number of agents (avatars) 
present, and the time of the test.  You can see how at the peak of 
avatars in the region between 19:00 and 20:30 the performance on both 
tests fell dramatically compared to when the simulation was more 
lightly loaded.
                  London City

    compute: message:
    float     region Agents     Time
     77         69     48  2020-12-27 16:00
     63         69     42  2020-12-27 16:30
     79         62     44  2020-12-27 17:00
     62         57     41  2020-12-27 17:30
     36         43     53  2020-12-27 18:00
     38         42     55  2020-12-27 18:30
     27         15     63  2020-12-27 19:00
     25         29     74  2020-12-27 19:30
     31         31     71  2020-12-27 20:00
     30         25     68  2020-12-27 20:30
     69         50     46  2020-12-27 21:00
     41         44     55  2020-12-27 21:30
     46         56     51  2020-12-27 22:00

Adding Your Own Tests

If you're experienced in writing Linden Scripting Language programs,
it's relatively easy to add your own tests to Gridmark, taking
advantage of its user interaction and scripting facilities.  In the
inventory of the attachment you will find a script called “Test:
template” which is the framework for a Gridmark test.  Make a copy of
this script, add it to the attachment's inventory, and rename it as you
wish, for example “Test: mytest” (the name must begin with “Test: ”).
Now edit your new script and add your test code to its runTest()
function.  The test may be parameterised by the arguments on the chat
command line which launched it, provided as a list of strings named
args[].  Your test should report its results by calling
testLogMessage() with the first argument TRUE or FALSE indicating
whether the test passed and the second string argument containing the
results of the test in Comma-Separated Value (CSV) format.  The
runTest() function should return LM_TE_PASS if the test passed and
LM_TE_FAIL if it failed.  Here is sample code which simply loops for
the number of times specified by the argument and reports the time
elapsed.
    integer runTest(string message, string lmessage, list args) {
        integer n = (integer) llList2String(args, 2);
        float start = llGetTime();
        while (n-- > 0) ;
        testLogMessage(TRUE, "time," + (string) (llGetTime() - start));
        return LM_TE_PASS;
    }
You will find this code in a script named “Test: example” in the
attachment.

The Gridmark HTTP Server

Users who run Gridmark benchmarks on a regular basis may find it
convenient to collect the results on an external World-Wide Web server
under their control.  If you have such a server and the ability to
install Common Gateway Interface (CGI) applications written in the Perl
programming language on it, the Gridmark.pl HTTP server, included with
the product in the Development Kit / Tools / Server folder, and
available for download from the GitHub repository cited at the end of
this document, may be useful.  Installed in the CGI directory of your
server, it may be used to store Gridmark test results by setting its
URL and the API key you create with the “Set log HTTP” command
documented above.  To install the server, read the source code and set
the configuration parameters appropriately for your site, then test
with Gridmark HTTP logging.  Let's assume you've installed the server
at a URL like:
    http://www.ratburger.net/cgi-bin/Gridmark
and you've set an API key of TopSecret.  You can then access the server
remotely from any Web browser with the following commands:
    http://www.ratburger.net/cgi-bin/Gridmark?dump&k=TopSecret
        Dump all stored log items.
    http://www.ratburger.net/cgi-bin/Gridmark?status&k=TopSecret
        Show server status, including the size of the stored log in
        both lines and bytes.
    http://www.ratburger.net/cgi-bin/Gridmark?extract&k=TopSecret&args...
        Extract items from the log as specified by args, which may be
        any of the following.  Multiple args are logically ANDed
        together to restrict the items returned.
            user=username               Second Life user name
            start=YYYY-MM-DDThh:mm:ss   Start date and time
            end=YYYY-MM-DDThh:mm:ss     End date and time
            test=testname               Name of test: compute, message, etc.
            status=1/0                  Test status: 1 = OK, 0 = Fail
            region=RegionName           Region in which test was run
        The args should be separated by ampersands, and any special
        characters in them must be escaped as in a URL.

The Gridmark server may be run as a command line application by users
on the server which hosts it who have appropriate permissions for its
log file.  Available commands are:
        status
            Print a summary of the log file, including total lines and
            bytes, and the number of log items broken down by Second
            Life user name, date, test, and Region.
        purge age [ really ]
            Purge entries from the log file based upon their age,
            specified as a decimal number followed by a letter
            indicating the unit: s=seconds, m=minutes, h=hours, d=days,
            w=weeks.  If “really” is specified, the items will actually
            be removed from the log file; otherwise, a message will be
            printed showing how many would be removed, but the log file
            will not be modified.

Land Impact and Permissions

As a wearable attachment, Fourmilab Gridmark has no land impact, and
you do not need land to use it: just Add it to your outfit from the
Inventory.  If you have your own land or access to land on which others
permit you to create objects (for example, a public sandbox or rez
zone), you can rez the object on the land and operate it from there via
chat commands just as if you were wearing it except, of course, the
“Beam” command to teleport your avatar won't bring the Gridmark object
along with you to the destination.  When rezzed onto land, Gridmark has
a land impact of 2.

The “rezscript” test can only be run on land where you are permitted to
create objects, and the objects it creates are temporary have a land
impact of 1.  Since only two objects are ever present at a time, there
is no cumulative land impact due to creating multiple objects in a test
run.

Acknowledgements

The anvil mesh is based upon a Blender model of an anvil:
    https://www.blendswap.com/blend/20662
developed by Alan Shukan:
    https://www.blendswap.com/profile/278192
and used under a Creative Commons CC-BY license.

The sound effect is a free clip available from:
    https://www.soundeffectsplus.com/
The sound when an the rezscript test object disintegrates is derived
from "Balloon Explode" (SFX 43561988):
    https://www.soundeffectsplus.com/product/balloon-explode-01/
This sound effect is © Copyright Finnolia Productions Inc. and
distributed under the Standard License:
    https://www.soundeffectsplus.com/content/license/
The sound clip was prepared for use in this object with the Audacity
sound editor on Linux.

License

This product (software, documents, and models) is licensed under a
Creative Commons Attribution-ShareAlike 4.0 International License.
    http://creativecommons.org/licenses/by-sa/4.0/
    https://creativecommons.org/licenses/by-sa/4.0/legalcode
You are free to copy and redistribute this material in any medium or
format, and to remix, transform, and build upon the material for any
purpose, including commercially.  You must give credit, provide a link
to the license, and indicate if changes were made.  If you remix,
transform, or build upon this material, you must distribute your
contributions under the same license as the original.

The anvil mesh and sound effect are licensed as described above in the
Acknowledgements section.

Source code for this project is maintained on and available from the
GitHub repository:
    https://github.com/Fourmilab/gridmark
