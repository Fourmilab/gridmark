    /*

                        Fourmilab Gridmark

                          Rezscript Test

            test rezscript <object_count>

        This test measures the time elapsed between instantiating an
        object from the inventory with llRezObject() and when a
        script within the object gets control and can send a
        message back to its creator.  The rez to script delay is
        particularly significant in cases such as scripted
        projectiles launched by other objects.

    */

    key owner;                      // Owner/wearer of attachment
    key whoDat = NULL_KEY;          // Avatar who sent command
    string testName;                // Name of this test (from script)

    //  Test script messages

    integer LM_TE_RESET = 80;       // Reset script
    integer LM_TE_RUN = 81;         // Run test
    integer LM_TE_PASS = 82;        // Test passed
    integer LM_TE_FAIL = 83;        // Test failed
//  integer LM_TE_BEAM = 84;        // Notify tests we've teleported
    integer LM_TE_STAT = 85;        // Print status
    integer LM_TE_LOG = 86;         // Log results from test

    string testStatus = "";         // Extended status (if any) from test

    //  runTest  --  Run this test

    integer gridmarkChan = -982449808;  // Channel for reporting script running
    integer gmHandle = 0;           // Handle for gridmarkChan listener
    string rezStart;                // Time we rezzed the projectile
    string projectileName = "rezscript Bullet";
    float rezFailTimeout = 10;      // Seconds after which we declare rez failed if no response

    integer projI;                  // Projectile index
    integer projN;                  // Number of projectiles to create
    rotation projRot;               // Projectile rotation
    vector projVel;                 // Projectile velocity vector
    vector projPos;                 // Projectile position
    vector projPosB;                // Projectile position base
    integer projAbort;              // Have we aborted the test ?

    integer runTest(string message, string lmessage, list args) {
        if (rezPermitted(llGetPos())) {
            gmHandle = llListen(gridmarkChan, "", "", ""); // Listen for rez confirmations
            projN = (integer) llList2String(args, 2);
            if (projN < 1) {
                projN = 1;
            }

            projRot = llGetRot();
            projVel = llRot2Fwd(projRot);
            projPos = llGetPos();
            projPos = projPos + projVel;
            projPos.z += 0.75;
            projPosB = projPos;

            projI = 0;
            projAbort = FALSE;
            return runNext();
        }
        testStatus = "You are not permitted to create objects on this parcel";
        testLogMessage(FALSE, "\"" + testStatus + "\"");
        llMessageLinked(LINK_THIS, LM_TE_FAIL, testStatus, whoDat);
        return FALSE;
    }

    /*  runNext  --  Run next of a series of tests.  Returns LM_TE_PASS
                     when we've performed the last iteration.  Note that
                     each successive iteration is triggered by receipt of
                     the RES message indicating completion of the
                     previous.  */

    integer runNext() {
        if (projI < projN) {
            if (projI > 0) {
                llSleep(1);
            }
            llSetTimerEvent(rezFailTimeout);    // Start no response timer running
            rezStart = llGetTimestamp();
            llRezObject(projectileName, projPos, ZERO_VECTOR, projRot, (projI * 100) + 1);
            projI++;
            projPos = projPosB + (<0, 0, 0.2> * (projI % 10));
            return FALSE;
        }
        return LM_TE_PASS;
    }

    /*  rezPermitted  --  Test whether we're allowed to create
                          objects here.  Returns FALSE (0) if we
                          can't use llRezObject() on this parcel
                          and a positive value if we are permitted
                          for the following reasons:
                            1   Anybody can create objects here
                            2   User is owner of this parcel
                            4   User is in the same group as this
                                parcel and the parcel permits
                                group members to create objects
                          The status codes are returned in the order
                          listed, but are defined to permit them to
                          be bit-coded (at the cost of a little speed)
                          should that be desired in the future.  */

    integer rezPermitted(vector here) {
        integer pflags = llGetParcelFlags(here);
        if (pflags & PARCEL_FLAG_ALLOW_CREATE_OBJECTS) {
            return 1;       // Anybody can create objects here
        }
        list pdet = llGetParcelDetails(here,
            [ PARCEL_DETAILS_OWNER, PARCEL_DETAILS_GROUP ]);
        if (llList2Key(pdet, 0) == whoDat) {
            return 2;       // User is owner of the parcel
        }
        if (llSameGroup(llList2Key(pdet, 1))) {
            if (pflags && PARCEL_FLAG_ALLOW_CREATE_GROUP_OBJECTS) {
                return 4;   // User is in group, parcel allows create
            }
        }
        return FALSE;
    }

    //  testLogMessage  --  Standard test log message

    testLogMessage(integer passed, string results) {
        llMessageLinked(LINK_THIS, LM_TE_LOG,
             "Gm," + (string) passed + "," + testName +
             ",\"" + llGetRegionName() +
              "\"," + results, whoDat);
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

        //  The listen event handles REZ reports from objects we've instantiated

        listen(integer channel, string name, key id, string message) {
            if (channel == gridmarkChan) {
                list msg = llJson2List(message);
                string ccmd = llList2String(msg, 0);
                if ((ccmd == "REZ") && (!projAbort)) {
                    llSetTimerEvent(0);         // Cancel rez fail timeout
                    string rezComplete = llList2String(msg, 1);
                    float secStart = (float) llGetSubString(rezStart, 17, -2);
                    float secEnd = (float) llGetSubString(rezComplete, 17, -2);
                    if (secEnd < secStart) {
                        secEnd += 60;           //  Crossed minute boundary
                    }
                    testLogMessage(TRUE,
                        "test," + (string) projI + "," +
                        "ntests," + (string) projN + "," +
                        "delay," + (string) (secEnd - secStart));
                    integer result;
                    if ((result = runNext()) != 0) {
                        llListenRemove(gmHandle);
                        gmHandle = 0;
                        testStatus = "";
                        llMessageLinked(LINK_THIS, result, testStatus, whoDat);
                    }
                }
            }
        }

        //  The timer is used to detect failure to respond after rezFailTimeout

        timer() {
            llSetTimerEvent(0);
            llListenRemove(gmHandle);
            projAbort = TRUE;
            gmHandle = 0;
            testLogMessage(FALSE,
                "test," + (string) projI + "," +
                "ntests," + (string) projN + "," +
                "timeout");
            llMessageLinked(LINK_THIS, LM_TE_FAIL, testStatus, whoDat);
        }
    }
