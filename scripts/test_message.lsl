    /*

                        Fourmilab Gridmark

                    Region and Link Message Test

            test message region/regionto/link iterations [ msg_length ]

        Tests message passing rate and data bandwidth on region and
        link messages.

    */

    key owner;                      // Owner/wearer of attachment
    key attachedTo;                 // Avatar to which we're attached, if any
    key whoDat = NULL_KEY;          // Avatar who sent command
    string testName;                // Name of this test (from script)

    integer transChannel = -982449810;  // Transponder channel
    integer trHandle;               // Transponder listener handle
    integer transponder;            // Transponder link number
    key transkey;                   // Transponder prim key

    integer compare = FALSE;        // Compare message contents ?

    //  Test script messages

    integer LM_TE_RESET = 80;       // Reset script
    integer LM_TE_RUN = 81;         // Run test
    integer LM_TE_PASS = 82;        // Test passed
    integer LM_TE_FAIL = 83;        // Test failed
    integer LM_TE_BEAM = 84;        // Notify tests we've teleported
    integer LM_TE_STAT = 85;        // Print status

    //  Transponder messages

    integer LM_TR_ACTIVE = 340;     // Activate/deactivate transponder
    integer LM_TR_PING = 341;       // Ping over link channel

    string testStatus = "";         // Extended status (if any) from test

    string content;                 // Message to send
    integer msglen;
    string tmsg;                    // Test message, adjusted to specified length
    integer tmsgl;

    //  runTest  --  Run this test

    string taskName;                // Task name
    integer taskID;                 // Integer task ID
    float starting;
    integer itero;
    integer nitero;

    integer runTest(string message, string lmessage, list args) {
        llResetTime();

        /*  Determine if we're attached and, if so, to whom.  Note
            that we can't rely upon the attach() event, since if
            the script is reset while we're attached, we'll never
            see it.  */
        if (llGetAttached() != 0) {
            attachedTo = whoDat;
        } else {
            attachedTo = NULL_KEY;
        }
        integer argn = llGetListLength(args);
        taskName = llList2String(args, 2);
        if (taskName == "region") {
            taskID = 1;
        } else if (taskName == "regionto") {
            taskID = 3;
        } else if (taskName == "link") {
            taskID = 5;
        } else {
            testLogMessage(FALSE, "Unknown message type: " + taskName);
            return LM_TE_FAIL;
        }

        itero = 0;
        nitero = (integer) llList2String(args, 3);

        //  Prepare the test message of the specified length

        tmsg = content;
        tmsgl = msglen;
        if (argn > 4) {
            tmsgl = (integer) llList2String(args, 4);
            if (tmsgl <= 0) {
                tawk("Invalid message length: zero or negative.");
                return LM_TE_FAIL;
            } else if (tmsgl > msglen) {
                tmsg = "";
                if (taskID & 4) {
                    //  Link message limited to script free memory - safety
                    integer mFree = (llGetFreeMemory() / 2) - 1024;
                    if (tmsgl > mFree) {
                        tawk("Link message size limited to free memory of " +
                            (string) mFree + " bytes.");
                        return LM_TE_FAIL;
                    }
                } else {
                    if (tmsgl > 1024) {
                        tawk("Region message cannot exceed 1024 characters.");
                        return LM_TE_FAIL;
                    }
                }
                while (llStringLength(tmsg) < tmsgl) {
                    integer more = tmsgl - llStringLength(tmsg);
                    if (more >= msglen) {
                        tmsg += content;
                    } else {
                        tmsg += llGetSubString(content, 0, more - 1);
                    }
                }
            } else if (tmsgl < msglen) {
                tmsg = llGetSubString(content, 0, tmsgl - 1);
            }
        }

        if (!(taskID & 4)) {
            //  Start listening for transponder ping backs
            trHandle = llListen(transChannel, "", transkey, "");
        }

        //  Activate the transponder
        llMessageLinked(transponder, LM_TR_ACTIVE, (string) taskID, NULL_KEY);

        return LM_TE_PASS;
    }

    /*  runNext  --  Run next of a series of tests.  Returns LM_TE_PASS
                     when we've performed the last iteration.  */

    integer runNext() {
        if (itero < nitero) {
            if (taskID & 4) {
                llMessageLinked(transponder, LM_TR_PING, tmsg, NULL_KEY);
            } else {
                if (taskID & 2) {
                    /*  When we're attached to an avatar, llRegionSayTo()
                        will not send a message to another prim in the
                        same link set as the attachment.  This works just
                        fine when the object is not attached to an avatar.
                        In order to exercise both cases, we direct the
                        message to the avatar when attached, and to the
                        linked prim when not.  */
                    if (attachedTo != NULL_KEY) {
                        llRegionSayTo(attachedTo, transChannel, tmsg);
                    } else {
                        llRegionSayTo(transkey, transChannel, tmsg);
                    }
                } else {
                    llRegionSay(transChannel, tmsg);
                }
            }
            itero++;
            return FALSE;
        }

        float elapsed = llGetTime() - starting;

        //  Deactivate the transponder
        llMessageLinked(transponder, LM_TR_ACTIVE, "0", NULL_KEY);

        if (trHandle != 0) {
            llListenRemove(trHandle);
        }

        tmsg = "";

        integer nmessages = nitero * 2;         // Because 2 messages per ping
        testLogMessage(TRUE, "type " + taskName +
            " messages " + (string) nmessages +
            " length " + (string) tmsgl +
            " bytes " + (string) (tmsgl * nmessages) +
            " time " + (string) elapsed +
            " msg/sec " + (string) (nmessages / elapsed) +
            " bytes/sec " + (string) ((tmsgl * nmessages) / elapsed));

        testStatus = "";
        llMessageLinked(LINK_THIS, LM_TE_PASS, testStatus, whoDat);
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

    /*  Find a linked prim from its name.  Avoids having to slavishly
        link prims in order in complex builds to reference them later
        by link number.  You should only call this once, in state_entry(),
        and then save the link numbers in global variables.  Returns the
        prim number or -1 if no such prim was found.  Caution: if there
        are more than one prim with the given name, the first will be
        returned without warning of the duplication.  */

    integer findLinkNumber(string pname) {
        integer i = llGetLinkNumber() != 0;
        integer n = llGetNumberOfPrims() + i;

        for (; i < n; i++) {
            if (llGetLinkName(i) == pname) {
                return i;
            }
        }
        return -1;
    }

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
            whoDat = owner = llGetOwner();
            testName = llGetSubString(llGetScriptName(), 6, -1);
            transponder = findLinkNumber("Message transponder");
            if (transponder < 0) {
                tawk(llGetScriptName() + ": Cannot find Message transponder in this link set.");
            }
            transkey = llGetLinkKey(transponder);
            content =
                    "What hath God wrought? " +
                    "The quick brown fox jumped over the lazy dog's back. " +
                    "The quick brown fox jumped over the lazy dog's back.";
            msglen = llStringLength(content);
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

            //  LM_TR_ACTIVE (340): Transponder activation confirmed

            } else if (num == LM_TR_ACTIVE) {
                if (((integer) str) != 0) {
                    starting = llGetTime();
                    runNext();                  // Run first iteration
                }

            //  LM_TR_PING (341): Ping back from transponder

            } else if (num == LM_TR_PING) {
                if (compare) {
                    if (str != tmsg) {
                        tawk("Compare failure on message " + (string) itero);
                    }
                }
                runNext();
            }
        }

        //  The listen event handles transponder ping backs

        listen(integer channel, string name, key id, string message) {
            if (channel == transChannel) {
                if (compare) {
                    if (message != tmsg) {
                        tawk("Compare failure on message " + (string) itero);
                    }
                }
                runNext();
            }
        }
    }
