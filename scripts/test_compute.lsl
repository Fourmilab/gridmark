    /*

                        Fourmilab Gridmark

                           Compute Test

            test compute <task> <iterations>

                Tasks:
                    float   Floating point (Leibniz's series for Pi)
                    list    List shuffling
                    prim    Manipulation of prim properties
                    string  String concatenation (and garbage collection)
                    texture Changing texture of prim

        Performs a variety of compute-bound tasks, run in segments
        of around one second per burst from the timer (to avoid
        non-responsiveness to events), logging iterations per second.

    */

    key owner;                      // Owner/wearer of attachment
    key whoDat = NULL_KEY;          // Avatar who sent command
    string testName;                // Name of this test (from script)

    //  Test script messages

    integer LM_TE_RESET = 80;       // Reset script
    integer LM_TE_RUN = 81;         // Run test
    integer LM_TE_PASS = 82;        // Test passed
    integer LM_TE_FAIL = 83;        // Test failed
    integer LM_TE_BEAM = 84;        // Notify tests we've teleported
    integer LM_TE_STAT = 85;        // Print status

    string testStatus = "";         // Extended status (if any) from test

    //  runTest  --  Run this test

    string taskName;                // Task name
    integer taskID;                 // Numerical identification of selected task
    float ipause = 0.01;            // Pause between outer loop iterations
    integer iter;
    integer niter = 1;              // Set to run around a second at Fourmilab Island
    integer itero;
    integer nitero;
    integer titer;
    float starting;
    list iTex;
    list aTex;

    integer runTest(string message, string lmessage, list args) {
        llResetTime();

        taskName = llList2String(args, 2);
        if (taskName == "float") {
            taskID = 1;
        } else if (taskName == "string") {
            taskID = 2;
        } else if (taskName == "list") {
            taskID = 3;
        } else if (taskName == "prim") {
            taskID = 4;
        } else if (taskName == "texture") {
            taskID = 5;
        } else {
            testLogMessage(FALSE, "Unknown task: " + taskName);
            return LM_TE_FAIL;
        }
        itero = 0;
        nitero = (integer) llList2String(args, 3);
        titer = 0;

        llSetTimerEvent(ipause);
        return LM_TE_PASS;
    }

    //  testLogMessage  --  Standard test log message

    testLogMessage(integer passed, string remarks) {
        tawk((string) passed + ",\"" + testName +
             "\",\"" + llGetRegionName() +
             "\",\"" + remarks + "\"");
    }

    //  tawk  --  Send a message to the interacting user in chat

    tawk(string msg) {
        if (whoDat == NULL_KEY) {
            //  No known sender.  Say in nearby chat.
            llSay(PUBLIC_CHANNEL, msg);
        } else {
            /*  While debugging, when speaking to the owner, use llOwnerSay()
                rather than llRegionSayTo() to avoid the risk of a runaway
                blithering loop triggering the gag which can only be removed
                by a region restart.  */
            if (owner == whoDat) {
                llOwnerSay(msg);
            } else {
                llRegionSayTo(whoDat, PUBLIC_CHANNEL, msg);
            }
        }
    }

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
            whoDat = owner = llGetOwner();
            testName = llGetSubString(llGetScriptName(), 6, -1);
        }

        //  Process messages from other scripts

        link_message(integer sender, integer num, string str, key id) {

            //  LM_TE_RESET (80): Reset test

            if (num == LM_TE_RESET) {
                llResetScript();

            //  LM_TE_RUN (81): Run test

            } else if (num == LM_TE_RUN) {
                whoDat = id;            // Direct chat output to sender of command

                list margs = llJson2List(str);
                string message = llList2String(margs, 0);
                string lmessage = llToLower(llStringTrim(message, STRING_TRIM));
                list args = llList2List(margs, 2, -1);
                string testid = llList2String(args, 1); // Requested test
                if (testid == testName) {
                    runTest(message, lmessage, args);
                }

            //  LM_TE_STAT (85): Print status

            } else if (num == LM_TE_STAT) {
                string stat = llGetScriptName() + " status:\n";
                integer mFree = llGetFreeMemory();
                integer mUsed = llGetUsedMemory();
                stat += "    Script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)";
                tawk(stat);
            }
        }

        /*  We run the inner loop off timer interrupts so the script
            remains responsive to events during the compute-bound
            test.  */

        timer() {
            if (titer == 0) {
                if (taskID == 5) {
                    iTex = [ PRIM_TEXTURE, ALL_SIDES ] +
                                llGetLinkPrimitiveParams(LINK_THIS,
                                    [ PRIM_TEXTURE, ALL_SIDES ]);
                    aTex = llListReplaceList(iTex, [ "89556747-24cb-43ed-920b-47caed15465f" ], 2, 2);
                }
                starting = llGetTime();
            }

            if (taskID == 1) {
                //  Task "float": Leibniz's series for Pi
                niter = 118000;
                float ssum = 1;
                float numerator = -1;
                float denominator = 3;

                //  Run the inner loop
                for (iter = 0; iter < niter; iter++) {
                    ssum += numerator / denominator;
                    numerator *= -1;
                    denominator += 2;
                    titer++;
                }
            } else if (taskID == 2) {
                //  Task "string": string concatenation and garbage collection
                niter = 10;
                integer ki = 820;

                for (iter = 0; iter < niter; iter++) {
                    string s = "";
                    integer j;
                    for (j = 0; j < ki; j++) {
                        s += "x";
                    }
                }
                titer += ki * niter;
            } else if (taskID == 3) {
                //  Task "list": list shuffling
                niter = 4223;
                list l = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
                for (iter = 0; iter < niter; iter++) {
                    l = llListReplaceList(l, llList2List(l, 7, 8), 2, 3);
                }
                titer += niter;
            } else if (taskID == 4) {
                //  Task "prim": manipulate prim
                integer niter = 3;
                integer n = 120;
                rotation rio = llList2Rot(llGetLinkPrimitiveParams(LINK_THIS, [ PRIM_ROT_LOCAL ]), 0);
                rotation ri = rio;
                rotation rinc = llEuler2Rot(<0, 0, (2 * PI) / n>);
                for (iter = 0; iter < niter; iter++) {
                    integer i;

                    for (i = 0; i < n; i++) {
                        ri = rinc * ri;
                        llSetLinkPrimitiveParamsFast(LINK_THIS, [ PRIM_ROT_LOCAL, ri ]);
                    }
                }
                llSetLinkPrimitiveParamsFast(LINK_THIS, [ PRIM_ROT_LOCAL, rio ]);
                titer += niter * n;
            } else if (taskID = 5) {
                //  Task "texture": change texture
                integer niter = 315;
                for (iter = 0; iter < niter; iter++) {
                    llSetLinkPrimitiveParamsFast(LINK_THIS, aTex);
                    llSetLinkPrimitiveParamsFast(LINK_THIS, iTex);
                }
                titer += niter;
            }
            itero++;
            if (itero < nitero) {
                llSetTimerEvent(ipause);
            } else {
                llSetTimerEvent(0);
                float finish = llGetTime();
                float elapsed = finish - starting;
                integer ips = llRound(titer / elapsed);
                testLogMessage(TRUE, "task " + taskName +
                    " ips " + (string) ips + " iter " +
                    (string) titer + " time " + (string) elapsed);
                testStatus = "";
                llMessageLinked(LINK_THIS, LM_TE_PASS, testStatus, whoDat);
            }
        }
    }
