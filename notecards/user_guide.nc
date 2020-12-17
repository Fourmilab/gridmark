
                            Fourmilab Gridmark

                                 User Guide

Fourmilab Gridmark is a wearable accessory which provides a variety of
performance benchmark tests for the Second Life virtual world.  By
wearing the accessory and launching tests via commands in local chat,
developers may run tests which measure the speed of scripts written in
the Linden Scripting Language (LSL).  Since Gridmark is an attachment
which may be worn by an avatar, its users are able to visit various
Second Life regions to measure and compare the performance of scripts,
discovering how load on the simulator running the region affects
scripts within them.  A scripting facility permits automating the
process of running a series of tests, including automatically
teleporting the wearer to different locations in Second Life to run
tests in multiple regions.

Fourmilab Gridmark is supplied with three built-in tests measuring
different aspects of performance.  Developers may add their own custom
tests which can be run under Fourmilab Gridmark and take advantage of
its scripting facilities.

Running Tests

Tests are launched from local chat using the “Test” command.  The
default chat channel is 76.

    compute             Script execution performance
        This test includes four sub-tests which perform different
        compute-bound operations.
            float   Floating point (Leibniz's series for Pi)
            list    List shuffling
            prim    Manipulation of prim properties
            string  String concatenation (and garbage collection)
            texture Changing texture on the attached object
        Each test is scaled so one iteration runs around one second in
        an idle simulation.  Results are reported in local chat in CSV
        format.  Here is an example of running the four tasks in a
        near-idle sandbox region.
            /76 test compute float 10
            1,"compute","Magnum Sandbox A","task float ips 127634 iter 1180000 time 9.245169"
            /76 test compute list 10
            1,"compute","Magnum Sandbox A","task list ips 5013 iter 42230 time 8.423551
            /76 test compute prim 10
            1,"compute","Magnum Sandbox A","task prim ips 383 iter 3600 time 9.400740"
            /76 test compute string 10
            1,"compute","Magnum Sandbox A","task string ips 8073 iter 82000 time 10.157300"
            /76 test compute texture 10
            1,"compute","Magnum Sandbox A","task texture ips 348 iter 3150 time 9.045113"
        When comparing performance from region to region, run the same
        test in the two regions and then compare the iterations per
        second (“ips”) between the two regions.  Now, let's go to a
        busy region, London City, which had 67 avatars present when I
        ran the tests, receiving the following results:
            1,"compute","London City","task float ips 51379 iter 1180000 time 22.966510"
            1,"compute","London City","task list ips 2023 iter 42230 time 20.875720"
            1,"compute","London City","task prim ips 152 iter 3600 time 23.672140"
            1,"compute","London City","task string ips 2974 iter 82000 time 27.571750"
            1,"compute","London City","task texture ips 148 iter 3150 time 21.243800"

    message             Message exchange
        Tests scripted message sending and receiving with three
        different mechanisms: llMessageLinked(), llRegionSay(), and
        llRegionSayTo() via tasks invoked as in the following examples.
        The number specifies how many messages are sent to the built-in
        transponder object (which appears as a golden disc on top of
        the anvil while active).  Since each message is sent to the
        transponder then echoed back to the sender, the actual message
        traffic is twice the number of iterations specified. Here are
        examples of the three tests run at Fourmilab.
            /76 test message link 500
            1,"message","Fourmilab","type link messages 1000 length 128 bytes 128000 time 11.111640 msg/sec 89.995700 bytes/sec 11519.450000"
            /76 test message region 500
            1,"message","Fourmilab","type region messages 1000 length 128 bytes 128000 time 11.114840 msg/sec 89.969770 bytes/sec 11516.130000"
            /76 test message regionto 500
            1,"message","Fourmilab","type regionto messages 1000 length 128 bytes 128000 time 11.117690 msg/sec 89.946700 bytes/sec 11513.180000"
        Here, the interesting numbers are the number of messages per
        second and the bytes per second transferred.  These tests used
        the default message length of 128 bytes.  Let's try increasing
        the message length to 1024 [the maximum for llRegionSay() and
        llRegionSayTo()] and see how that affects performance.
            /76 test message region 500 1024
            1,"message","Fourmilab","type region messages 1000 length 1024 bytes 1024000 time 11.135280 msg/sec 89.804640 bytes/sec 91959.950000"
        We can see that the rate at which messages were sent and
        received was almost unchanged, while the data transfer rate
        increased by a factor of almost 8, the packet size increase.
        Thus, given a choice, for best performance you should send
        fewer large messages rather than many small ones.

    rezscript               Rez to script delay measurement
        When a script uses llRezObject() to instantiate an object from
        its inventory into the world, there is a delay between the time
        the call to create the object is made and when scripts within
        the object begin to run.  This can cause a variety of problems
        with scripts that create objects (for example, projectile
        launchers which need to communicate with objects they launch).
        If a script sends a message to the newly-created object
        immediately with llRegionSayTo(), for example, the message may
        be lost because the object's script has not yet received
        control and started to listen for such messages.  A physical
        object may fall to the ground before its script gets a chance
        to launch it toward its destination.  Starting in early 2020,
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
            1,"rezscript","Fourmilab","1 of 5: delay 0.028215 sec"
            1,"rezscript","Fourmilab","2 of 5: delay 0.031453 sec"
            1,"rezscript","Fourmilab","3 of 5: delay 0.023618 sec"
            1,"rezscript","Fourmilab","4 of 5: delay 0.035944 sec"
            1,"rezscript","Fourmilab","5 of 5: delay 0.026910 sec"
        Next, we'll repeat the test at the public sandbox in the Mauve
        region (note that you'll have to walk a bit from the region's
        landing zone to get to the sandbox).
            1,"rezscript","Mauve","1 of 5: delay 2.129353 sec"
            1,"rezscript","Mauve","2 of 5: delay 2.033085 sec"
            1,"rezscript","Mauve","3 of 5: delay 2.609699 sec"
            1,"rezscript","Mauve","4 of 5: delay 2.038265 sec"
            1,"rezscript","Mauve","5 of 5: delay 2.026997 sec"
        This region was “slow” when I ran the test, having been up for
        almost five days since its last restart.

        A Perl program named “rez_script_time.pl” is included as a
        notecard (or may be downloaded from the project's GitHub
        repository) which reads a chat transcript containing runs of
        the rezscript test in multiple regions and reports statistics
        for them, for example:
              Region                           Delay    n   Std. dev
              ----------------------------    ------   ---  --------
              Sandbox Pristina                0.0256    5    0.0009
              Sandbox Astutula                0.0316    5    0.0099
              Sandbox Exemplar                2.0221    5    0.0008  Slow
              Sandbox Verenda                 2.0239    5    0.0007  Slow
              Limia                           0.0253    5    0.0010
              Arowana                         0.0284    5    0.0087
              Orville                         0.0252    5    0.0009
              Sandbox Artifex                 0.0266    5    0.0004
              Sandbox Mirificatio             0.0253    5    0.0004
              London City Brittany            2.0399    5    0.0183  Slow
              Mauve                           2.0533    5    0.0686  Slow
              Vallone                         2.0392    5    0.0193  Slow
              Maryport                        0.0242    5    0.0009
              Lapara                          0.0291    5    0.0076
              Combat (sandbox) Rausch         0.0254    5    0.0004
            Regions: 17, 12 fast, 5 slow.

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
            1,"teleport","London City",<85.00000, 223.00000, 24.00000>,"Fourmilab",<230.65210, 131.31360, 24.82259>
        Teleports initiated directly by the user of another object are
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
            Scripts may be nested, so the “Script run” command can
            appear within a script.  Entering “Script run” with no
            script name terminates any running script(s).

            The following commands may be used only within scripts.

            Script loop [ n ]
                Begin a loop within the script which will be executed n
                times, or forever if n is omitted.  Loops may be
                nested, and scripts may run other scripts within loops.
                An infinite loop can be terminated by “Script run” with
                no script name or the “Boot” command.

            Script end
                Marks the end of a "Script loop".  If the number of
                iterations has been reached, proceeds to the next
                command. Otherwise, resumes at the statement at the
                start of the loop.

            Script pause n
                Pauses execution of the script for n seconds.

        Set
            Sets a variety of parameters.

            Set channel n
                Sets the channel on which the attachment listens for
                commands in local chat.  The default is 76.  Note that
                the channel number will return to the default if you
                reset the script with the edit menu or Boot command.

            Set echo on/off
                Controls whether commands from local chat and scripts
                are echoed to local chat.

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
            Prints status of the main Gridmark script and all test
            scripts, including their memory usage.

        Test testname arguments...
            Runs a test defined by a script in the inventory.  The
            arguments which follow are passed to the test script and
            interpreted as it defines them.  You can list all of the
            available tests by entering “Test” with no arguments.

Scripting Tests

You can automate tests by creating scripts of Gridmark commands (not to
be confused with Linden Scripting Language programs) in notecards
placed in the attachment's inventory.  These scripts contain commands
in exactly the same form as entered in local chat (except for the
channel number, which doesn't apply to a script).  Names of all scripts
must begin with “Script: ” to distinguish them from other notecards.
To run a script, enter the “Script run” command with the name of the
script (excluding the “Script: ” prefix). You can list all scripts in
the attachment with the “Script list” command.  Special commands can be
used within a script to repeat a sequence of commands multiple times
and insert pauses of a specified length—see the documentation of the
Script command for details.  You can stop a running script by entering
“Script run” with no script name.

Scripts may be nested: one script can run another.  This is
particularly handy when you want to run a sequence of tests in a series
of different regions.

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
whether the test passed and the second string argument containing any
message you wish to include in the log entry.  The runTest() function
should return LM_TE_PASS if the test passed and LM_TE_FAIL if it
failed.  Here is sample code which simply loops for the number of times
specified by the argument and reports the time elapsed.
    integer runTest(string message, string lmessage, list args) {
        integer n = (integer) llList2String(args, 2);
        float start = llGetTime();
        while (n-- > 0) ;
        testLogMessage(TRUE, "Time " + (string) (llGetTime() - start));
        return LM_TE_PASS;
    }
You will find this code in a script named “Test: example” in the
attachment.

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
create objects, and the objects it creates have a land impact of 1.
Since only one object is present at a time, there is no cumulative land
impact due to creating multiple objects in a test run.

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

