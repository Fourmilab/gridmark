    /*

                        Fourmilab Gridmark

            test template <args>...

        This is a working template for a Gridmark test script.
        It simply logs its arguments and reports success.

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

    integer runTest(string message, string lmessage, list args) {
        testLogMessage(TRUE, llList2CSV(args));
        return LM_TE_PASS;
    }

    //  testLogMessage  --  Standard test log message

    testLogMessage(integer passed, string remarks) {
        tawk((string) passed + ",\"" + testName  +
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
                integer result;
                testStatus = "";
                if (testid == testName) {
                    result = runTest(message, lmessage, args);
                    llMessageLinked(LINK_THIS, result, testStatus, whoDat);
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
    }
