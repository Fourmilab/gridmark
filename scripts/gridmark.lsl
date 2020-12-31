    /*

                        Fourmilab Gridmark

                    by John Walker (Fourmilab)


    */

    string version = "1.0";         // Version number
    key owner;                      // Owner / wearer key
    string userName;                // Username of owner
    integer commandChannel = 76;    // Command channel in chat
    integer commandH = 0;           // Handle for command channel
    key whoDat = NULL_KEY;          // Avatar who sent command
    integer echo = TRUE;            // Echo chat and script commands ?
    integer trace = FALSE;          // Trace operation
    float glow = 0.25;              // Glow while running tests ?
    vector moveTarget = <-1, -1, -1>;   // Target of current Moveto
    float moveDistL;                // Move progress tracker
    integer moveStuck;              // Move stuck counter
    integer moveLookAt;             // Counter to stop look at
    string helpFileName = "Fourmilab Gridmark User Guide";  // Help file

    //  Log destination settings

    integer logChannel = PUBLIC_CHANNEL;    // Channel on which to report results
    integer imessage = FALSE;       // Report tests via instant messages ?
    string httpURL = "";            // HTTP request URL
    string httpAPI = "";            // HTTP request API key, if any
    key httpKey;                    // HTTP key for pending request

    //  Script processing

    integer scriptActive = FALSE;   // Are we reading from a script ?
    integer scriptSuspend = FALSE;  // Suspend script execution for asynchronous event

    //  Grid destination specifications

    list destMark = [ ];        // Marked destinations
    string destRegion = "";     // Region name of destination
    vector destGrid;            // Grid co-ordinates of destination
    vector destRegc;            // Destination co-ordinates within region

    //  Teleport source identification

    string srcRegion;           // Region we're leaving
    vector srcGrid;             // Its grid co-ordinates
    vector srcRegc;             // Its co-ordinates within region
    integer beamActive = FALSE; // Is a commanded Beam in progress ?

    //  Region queries

    integer REGION_SIZE = 256;  // Size of region in metres
    string rnameQ;              // Region name being queried
    key regionQ = NULL_KEY;     // Query region handle
    integer stateQ = 0;         /* Query state:
                                        0   Idle
                                        1   Requesting status
                                        2   Requesting grid position  */
    list regionCache;           // Region look-up cache

    //  Script Processor messages

    integer LM_SP_INIT = 50;        // Initialise
    integer LM_SP_RESET = 51;       // Reset script
    integer LM_SP_STAT = 52;        // Print status
//  integer LM_SP_RUN = 53;         // Enqueue script as input source
    integer LM_SP_GET = 54;         // Request next line from script
    integer LM_SP_INPUT = 55;       // Input line from script
    integer LM_SP_EOF = 56;         // Script input at end of file
    integer LM_SP_READY = 57;       // Script ready to read
    integer LM_SP_ERROR = 58;       // Requested operation failed

    //  Test script messages

    integer LM_TE_RESET = 80;       // Reset script
    integer LM_TE_RUN = 81;         // Run test
    integer LM_TE_PASS = 82;        // Test passed
    integer LM_TE_FAIL = 83;        // Test failed
    integer LM_TE_BEAM = 84;        // Notify tests we've teleported
    integer LM_TE_STAT = 85;        // Print status
    integer LM_TE_LOG = 86;         // Log results from test

    //  Command processor messages

    integer LM_CP_COMMAND = 223;    // Process command

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

    //  logMessage  --  Send a message to the designated logging facilities

    logMessage(string msg) {
        if (logChannel == PUBLIC_CHANNEL) {
            tawk(msg);
        } else if (logChannel != -1) {
            llRegionSay(logChannel, msg);
        }
        if (imessage) {
            llInstantMessage(owner, msg);
        }
        if (httpURL != "") {
            /*  Prefix the record from the test with:
                    User name
                    Version  */
            string req = httpURL + "?l=" +
                llEscapeURL("\"" + userName + "\"," + version + "," + msg);
            if (httpAPI != "") {
                req += "&k=" + llEscapeURL(httpAPI);
            }
            httpKey = llHTTPRequest(req, [ ], "");
        }
    }

    /*  parseDestination  --  Parse destination from location or SLUrl.
                              Returns a list containing the region name
                              and co-ordinates within the region.  The
                              format for destinations are as follows:

                    "Fourmilab Island, Fourmilab (120, 122, 27) - Moderate"
                    "http://maps.secondlife.com/secondlife/Fourmilab/120/122/28"
                    "secondlife://Fourmilab/128/128/50"
    */

    list parseDestination(string dest) {
        if (llSubStringIndex(dest, "http://") >= 0) {
            /*  SLUrl like:
                "http://maps.secondlife.com/secondlife/Fourmilab/120/122/28" */
            list url = llParseString2List(dest, [ "/" ], []);
            return [ llUnescapeURL(llList2String(url, 3)),
                     < llList2Float(url, 4), llList2Float(url, 5), llList2Float(url, 6) > ];

        } else if (llSubStringIndex(dest, "secondlife://") >= 0) {
            /*  SLUrl like:
                "secondlife"//Fourmilab/120/122/28"

                SLUrls for the Aditi Beta Grid look like:
                "secondlife://Aditi/secondlife/Astutula/207/247/22"
                but such URLs, if parsed like one for the main grid, will
                try to look up a region of Aditi and fail.  We first
                transform Aditi URLs so they can be parsed as if on the
                main grid.  */
            integer p = llSubStringIndex(dest, "://Aditi/secondlife/");
            if (p >= 0) {
                dest = llDeleteSubString(dest, p + 3, p + 19);
            }
            list url = llParseString2List(dest, [ "/" ], []);
            return [ llUnescapeURL(llList2String(url, 1)),
                     < llList2Float(url, 2), llList2Float(url, 3), llList2Float(url, 4) > ];

        } else if (llSubStringIndex(dest, "here://") >= 0) {
            /*  Here specification:
                "here://"  */
            return [ llGetRegionName(), llGetPos() ];

        } else if (llSubStringIndex(dest, "mark://") >= 0) {
            /*  Mark specified by its name:
                "mark://name"  */
            list url = llParseString2List(dest, [ "/" ], []);
            string mname = llList2String(url, 1);
            integer i;
            integer ll = llGetListLength(destMark);

            for (i = 0; i < ll; i += 3) {
                if (mname == llList2String(destMark, i)) {
                    return [ llList2String(destMark, i + 1),
                             llList2Vector(destMark, i + 2) ];
                }
            }
            tawk("Mark \"" + mname + "\" not found.");
            return [ ] ;

        } else {
            /*  Primate-readable destination like:
                "Fourmilab Island, Fourmilab (120, 122, 27) - Moderate" */
            list result = [ ];
            integer regstart = llSubStringIndex(dest, ", ");
            if (regstart >= 0) {
                list comps = llParseString2List(llGetSubString(dest, regstart + 2, -1), [ " " ], []);
                result = [ llList2String(comps, 0),
                           < (float) llGetSubString(llList2String(comps, 1), 1, -2),
                             (float) llGetSubString(llList2String(comps, 2), 0, -2),
                             (float) llGetSubString(llList2String(comps, 3), 0, -2) > ];
            }
            return result;
        }
    }

    //  beamMe()  --  Teleport to selected destination

    beamMe() {
        //  Save position we're departing
        srcRegion = llGetRegionName();
        srcGrid = llGetRegionCorner() / REGION_SIZE;
        srcRegc = llGetPos();
        beamActive = TRUE;          // Indicate we're beaming
        if (srcRegion == destRegion) {
            //  Teleport within current region
            llTeleportAgent(whoDat, "", destRegc, llRot2Fwd(llGetRot()));
        } else {
            //  Teleport to a different region
            llTeleportAgentGlobalCoords(whoDat, destGrid * REGION_SIZE,
                destRegc,  llRot2Fwd(llGetRot()));
        }
    }

    //  abbrP  --  Test if string matches abbreviation

    integer abbrP(string str, string abbr) {
        return abbr == llGetSubString(str, 0, llStringLength(abbr) - 1);
    }

    //  onOff  --  Parse an on/off parameter

    integer onOff(string param) {
        if (abbrP(param, "on")) {
            return TRUE;
        } else if (abbrP(param, "of")) {
            return FALSE;
        } else {
            tawk("Error: please specify on or off.");
            return -1;
        }
    }

    /*  inventoryName  --   Extract inventory item name from Set subcmd.
                            This is a horrific kludge which allows
                            names to be upper and lower case.  It finds the
                            subcommand in the lower case command then
                            extracts the text that follows, trimming leading
                            and trailing blanks, from the upper and lower
                            case original command.   */

    string inventoryName(string subcmd, string lmessage, string message) {
        //  Find subcommand in Set subcmd ...
        integer dindex = llSubStringIndex(lmessage, subcmd);
        //  Advance past space after subcmd
        integer di = llSubStringIndex(llGetSubString(lmessage, dindex, -1), " ");
        if (di < 0) {
            return "";
        }
        dindex += di + 1;
        //  Note that STRING_TRIM elides any leading and trailing spaces
        return llStringTrim(llGetSubString(message, dindex, -1), STRING_TRIM);
    }

    /*  scriptResume  --  Resume script execution when asynchronous
                          command completes.  */

    scriptResume() {
        if (scriptActive) {
            if (scriptSuspend) {
                scriptSuspend = FALSE;
                llMessageLinked(LINK_THIS, LM_SP_GET, "", NULL_KEY);
                if (trace) {
                    tawk("Script resumed.");
                }
            }
        }
    }

    //  processCommand  --  Process a command

    integer processCommand(key id, string message, integer fromScript) {
        whoDat = id;            // Direct chat output to sender of command

        /*  If echo is enabled, echo command to sender unless
            prefixed with "@".  The command is prefixed with ">>"
            if entered from chat or "++" if from a script.  */

        integer echoCmd = TRUE;
        if (llGetSubString(llStringTrim(message, STRING_TRIM_HEAD), 0, 0) == "@") {
            echoCmd = FALSE;
            message = llGetSubString(llStringTrim(message, STRING_TRIM_HEAD), 1, -1);
        }
        if (echo && echoCmd) {
            string prefix = ">> ";
            if (fromScript) {
                prefix = "++ ";
            }
            tawk(prefix + message);                 // Echo command to sender
        }

        string lmessage = llToLower(llStringTrim(message, STRING_TRIM));
        list args = llParseString2List(lmessage, [" "], []);    // Command and arguments
        integer argn = llGetListLength(args);       // Number of arguments
        string command = llList2String(args, 0);    // The command
        string sparam = llList2String(args, 1);     // First argument, for convenience

        //  Beam slurl              Teleport to destination

        if (abbrP(command, "be")) {
            string des = inventoryName("be", lmessage, message);
            list dl = parseDestination(des);
            if (dl == []) {
                tawk("Invalid destination " + des);
                return FALSE;
            } else {
                rnameQ = llList2String(dl, 0);      // Destination region name
                destRegion = "";                    // Mark destination unknown
                destRegc = llList2Vector(dl, 1);    // Save location within region
                if (fromScript) {
                    scriptSuspend = TRUE;           // Suspend script until we arrive
                }
                integer rcachep;
                if ((rcachep = llListFindList(regionCache, [ rnameQ ])) != -1) {
                    //  Region name in cache: no need to query simulator data
                    destRegion = rnameQ;
                    rnameQ = "";
                    destGrid = llList2Vector(regionCache, rcachep + 1);
                    if (trace) {
                        tawk("Region found in cache: " + destRegion + " " + (string) destGrid);
                    }
                    if ((llGetPermissions() & PERMISSION_TELEPORT) == 0) {
                        llRequestPermissions(owner, PERMISSION_TELEPORT);
                    } else {
                        beamMe();                   // Already have permission to teleport
                    }
                } else {
                    stateQ = 1;
                    regionQ = llRequestSimulatorData(rnameQ, DATA_SIM_STATUS);
                }
            }

        //  Boot                    Restart script

        } else if (abbrP(command, "bo")) {
            //  Reset all test scripts in inventory
            llMessageLinked(LINK_THIS, LM_TE_RESET, "", whoDat);
            //  Reset the script processor
            llMessageLinked(LINK_THIS, LM_SP_RESET, "", whoDat);
            llResetScript();

        //  Clear                   Clear chat for debugging

        } else if (abbrP(command, "cl")) {
            tawk("\n\n\n\n\n\n\n\n\n\n\n\n\n");

        //  Echo message                Display message

        } else if (abbrP(command, "ec")) {
            string msg = inventoryName("ec", lmessage, message);
            if (msg == "") {
                msg = " ";
            }
            tawk(msg);

        //  Help                    Print command summary

        } else if (abbrP(command, "he")) {
            llGiveInventory(id, helpFileName);  // Give requester the User Guide notecard

        //  Moveto                  Move to location in region

        } else if (abbrP(command, "mo")) {
            if (argn > 1) {
                vector moveBase = ZERO_VECTOR;
                if (llGetSubString(sparam, 0, 0) == "+") {
                    moveBase = llGetPos();
                    sparam = llGetSubString(sparam, 1, -1);
                }
                moveTarget = ((vector) sparam) + moveBase;
                if (llVecDist(moveTarget, llGetPos()) >= 65) {
                    tawk("Cannot move more than 65 metres at once.");
                    return FALSE;
                }
                float speed = 1;
                if (argn > 2) {
                    speed = (float) llList2String(args, 2);
                }
                if (moveTarget.x >= 0) {
                    if (moveLookAt > 0) {
                        moveLookAt = 0;
                        llStopLookAt();
                    }
                    llStopMoveToTarget();
                }
                moveDistL = REGION_SIZE;
                moveStuck = 0;
                llLookAt(moveTarget / llGetRootRotation(), 3, 1);
                moveLookAt = 3;
                llMoveToTarget(moveTarget, speed);
                llSetTimerEvent(0.25);
                if (fromScript) {
                    scriptSuspend = TRUE;           // Suspend script until we arrive
                }
            } else {
                if (moveTarget.x >= 0) {
                    if (moveLookAt > 0) {
                        moveLookAt = 0;
                        llStopLookAt();
                    }
                    llStopMoveToTarget();
                    llSetTimerEvent(0);
                    moveTarget = <-1, -1, -1>;
                }
            }

        //  Script                      Script commands (handled by Script Processor)

        } else if (abbrP(command, "sc")) {
            llMessageLinked(LINK_THIS, LM_CP_COMMAND,
                llList2Json(JSON_ARRAY, [ message, lmessage ] + args), whoDat);

        //  Set                         Set parameter

        } else if (abbrP(command, "se")) {
            string param = llList2String(args, 1);
            string svalue = llList2String(args, 2);
            argn = llGetListLength(args);

            /*  Set Channel n                   Change command channel.  Note that
                                                the channel change is lost on a
                                                script reset.  */

            if (abbrP(param, "ch")) {
                integer newch = (integer) svalue;
                if ((newch < 2)) {
                    tawk("Invalid channel number.  Must be 2 or greater.");
                } else {
                    llListenRemove(commandH);
                    commandChannel = newch;
                    commandH = llListen(commandChannel, "", NULL_KEY, "");
                    tawk("Listening on chat /" + (string) commandChannel + ".");
                }

            //  Set Echo on/off             Control echo of commands to sender

            } else if (abbrP(param, "ec")) {
                echo = onOff(svalue);

            //  Set Glow intensity          Set glow while running tests

            } else if (abbrP(param, "gl")) {
                glow = (float) svalue;

            //  Set Log                     Set log messages options

            } else if (abbrP(param, "lo")) {
                string tparam = llList2String(args, 3);

                //  Set log channel n       Set local chat channel for log messages

                if (abbrP(svalue, "ch")) {
                    logChannel = (integer) tparam;

                //  Set log Email collect/send/clear    Control E-mail delivery of logs

                } else if (abbrP(svalue, "em")) {
                    llMessageLinked(LINK_THIS, LM_CP_COMMAND,
                        llList2Json(JSON_ARRAY, [ message, lmessage ] + args), whoDat);

                //  Set log IM on/off       Control logging via instant messages to owner

                } else if (abbrP(svalue, "im")) {
                    imessage = onOff(tparam);

                //  Set log HTTP [ URL [ API_key ] ]

                } else if (abbrP(svalue, "ht")) {
                    if (argn > 3) {
                        httpURL = inventoryName("ht", lmessage, message);
                        httpAPI = "";
                        integer ls = 0;
                        integer es = -1;
                        integer is;

                        while ((is = llSubStringIndex(llGetSubString(httpURL, ls, -1), " ")) >= 0) {
                            es = ls + is;
                            ls += is + 1;
                        }
                        if (es >= 0) {
                            httpAPI = llGetSubString(httpURL, es + 1, -1);
                            httpURL = llGetSubString(httpURL, 0, es - 1);
                        }
                    } else {
                        httpURL = "";
                        httpAPI = "";
                    }
                }

            //  Mark at <name> <destination>
            //       clear [<name>]  (default all)
            //       list
            } else if (abbrP(param, "ma")) {
                string ulmessage = llStringTrim(message, STRING_TRIM);
                list ulargs = llParseString2List(ulmessage, [" "], []);

                if (abbrP(svalue, "at")) {          // at
                    string mname = llList2String(ulargs, 3);
                    integer dindex = llSubStringIndex(ulmessage, " " + mname + " ");
                    dindex += llStringLength(mname) + 2;
                    list dl = [ ];
                    if (dindex > 0) {
                        dl = parseDestination(llGetSubString(ulmessage, dindex, -1));
                    }
                    if (dl == []) {
                        tawk("Invalid destination " + llGetSubString(ulmessage, dindex, -1));
                        return FALSE;
                    } else {
                        destMark += mname;
                        destMark += dl;
                    }
                } else if (abbrP(svalue, "cl")) {      // clear
                    if (argn < 4) {
                        destMark = [ ];
                    } else {
                        string mname = llList2String(ulargs, 3);
                        integer i;
                        integer ll = llGetListLength(destMark);
                        integer found = FALSE;

                        for (i = 0; i < ll; i += 3) {
                            if (mname == llList2String(destMark, i)) {
                                destMark = llDeleteSubList(destMark, i, i + 2);
                                i = ll * 3;
                                found = TRUE;
                            }
                        }
                        if (!found) {
                            tawk("Mark \"" + mname + "\" not found.");
                        }
                    }
                } else if (abbrP(svalue, "li")) {       // list
                    integer ll = llGetListLength(destMark);
                    integer i;

                    for (i = 0; i < ll; i += 3) {
                        tawk("  " + llList2String(destMark, i) + ": " +
                            llList2String(destMark, i + 1) + " " +
                            (string) llList2Vector(destMark, i + 2));
                    }
                } else {
                    tawk("Invalid.  Set mark at/clear/list");
                }

                //  Set trace on/off

                } else if (abbrP(sparam, "tr")) {
                        trace = onOff(svalue);

                }

        //  Status                  Print status

        } else if (abbrP(command, "st")) {
            integer mFree = llGetFreeMemory();
            integer mUsed = llGetUsedMemory();
            string http = "off";
            if (httpURL != "") {
                http = "URL " + httpURL;
                if (httpAPI != "") {
                    http += " API key set";
                }
            }
            tawk(llGetScriptName() + " version " + version + " status:\n" +
                 "    Echo: " + (string) echo + " Trace: " + (string) trace + "\n" +
                 "    Log:  Channel " + (string) logChannel + " IM: " + (string) imessage +
                    " HTTP: " + http + "\n" +
                 "    Region cache: " + llList2CSV(regionCache) + "\n" +
                 "    Script memory.  Free: " + (string) mFree +
                 "    Used: " + (string) mUsed + " (" +
                    (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)"
                );
            llMessageLinked(LINK_THIS, LM_SP_STAT, "", whoDat);
            llMessageLinked(LINK_THIS, LM_TE_STAT, "", whoDat);

        //  Test                    Run test from script in inventory

        } else if (abbrP(command, "te")) {
            if (argn > 1) {
                string testName = "Test: " + sparam;
                if (llGetInventoryType(testName) == INVENTORY_SCRIPT) {
                    if (glow > 0) {
                        llSetLinkPrimitiveParamsFast(LINK_THIS,
                            [ PRIM_GLOW, ALL_SIDES, glow ]);
                    }
                    llMessageLinked(LINK_THIS, LM_TE_RUN,
                        llList2Json(JSON_ARRAY, [ message, lmessage ] + args), whoDat);
                    //  Suspend script until test complete
                    scriptSuspend = TRUE;
                } else {
                    tawk("No test script named \"Test: " + sparam + "\".");
                }
            } else {
                //  No argument: list tests in inventory
                integer n = llGetInventoryNumber(INVENTORY_SCRIPT);
                integer i;
                integer j = 0;
                for (i = 0; i < n; i++) {
                    string s = llGetInventoryName(INVENTORY_SCRIPT, i);
                    if ((s != "") && (llGetSubString(s, 0, 5) == "Test: ")) {
                        tawk("  " + (string) (++j) + ". " + llGetSubString(s, 6, -1));
                    }
                }
            }

        //  Time                    Log current time (UTC)

        } else if (abbrP(command, "ti")) {
            /*  Obtain the time to as to minimise time parallax
                between the two API calls.  If we're right on the
                boundary of second, the second in the timestamp may
                be before that in the Unix time, but it's unlikely.
                If data processing reduction programs care about
                this, they can re-generate the Unix time from the
                timestamp.  */
            string ts = llGetTimestamp();
            integer ut = llGetUnixTime();
            /*  Write the output in the form of a log item from a
                built-in test called "time".  */
            llMessageLinked(LINK_THIS, LM_TE_LOG, "Gm,1,time,\"" +
                llGetRegionName() + "\"," + ts + "," + (string) ut, whoDat);

        } else {
            tawk("Unknown command.  Use /" + (string) commandChannel +
                 " help for documentation.");
        }
        return TRUE;
    }

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
            whoDat = owner = llGetOwner();
            /*  Get the username while we're guaranteed the
                owner is in the region.  */
            userName = llGetUsername(owner);
            if (commandH == 0) {
                commandH = llListen(commandChannel, "", whoDat, "");
                tawk("Listening on /" + (string) commandChannel);
            }
            //  Initialise the region cache with the region we're in
            regionCache = [ llGetRegionName(), llGetRegionCorner() / REGION_SIZE ];
        }

        //  Attachment to or detachment from an avatar

        attach(key attachedAgent) {
            if (attachedAgent != NULL_KEY) {
                whoDat = attachedAgent;
                if (commandH == 0) {
                    //  Listen only for messages from wearer
                    commandH = llListen(commandChannel, "", whoDat, "");
                    tawk("Listening on /" + (string) commandChannel);
                }
            } else {
                llListenRemove(commandH);
                commandH = 0;
            }
        }

        /*  The run_time_permissions() event is received when granted
            permissions for various operations. We then make the
            request we're now permitted to submit.  */

        run_time_permissions(integer perm) {

            //  Teleport to destination

            if (perm & PERMISSION_TELEPORT) {
                beamMe();
            }
        }

        /*  The listen event handler processes messages from
            our chat control channel.  */

        listen(integer channel, string name, key id, string message) {
            if (channel == commandChannel) {
                processCommand(id, message, FALSE);
            }
        }

        //  The changed event notifies us when we've teleported

        changed(integer what) {
            if (what & CHANGED_TELEPORT) {
                if (!beamActive) {
                    /*  If beamActive is not set, this was a user-commanded
                        teleport, not one we initiated.  */
                    srcRegion = "";
                    srcGrid = srcRegc = ZERO_VECTOR;
                    destRegion = llGetRegionName();
                    destGrid = llGetRegionCorner() / REGION_SIZE;
                    destRegc = llGetPos();
                } else {
                    beamActive = FALSE;
                }
                llMessageLinked(LINK_THIS, LM_TE_BEAM,
                    llList2Json(JSON_ARRAY,
                        [ destRegion, destGrid, destRegc,
                          srcRegion, srcGrid, srcRegc ]), whoDat);
                if (trace) {
                    tawk("Teleported from " + srcRegion + " " + (string) srcRegc +
                         " to " + destRegion + " " + (string) destRegc);
                }
                llMessageLinked(LINK_THIS, LM_TE_LOG, "Gm,1,teleport,\"" +
                    destRegion + "\"," + "\"" + (string) destRegc +
                    "\",\"" + srcRegion + "\",\"" +
                    (string) srcRegc + "\"", whoDat);
                scriptResume();
            }
        }

        //  Process messages from other scripts

        link_message(integer sender, integer num, string str, key id) {

            //  Script Processor Messages

            //  LM_SP_READY (57): Script ready to read

            if (num == LM_SP_READY) {
                scriptActive = TRUE;
                llMessageLinked(LINK_THIS, LM_SP_GET, "", id);  // Get the first line

            //  LM_SP_INPUT (55): Next executable line from script

            } else if (num == LM_SP_INPUT) {
                if (str != "") {                // Process only if not hard EOF
                    scriptSuspend = FALSE;
                    integer stat = processCommand(id, str, TRUE);
                    // Some commands may set scriptSuspend
                    if (stat) {
                        if (!scriptSuspend) {
                            llMessageLinked(LINK_THIS, LM_SP_GET, "", id);
                        }
                    } else {
                        //  Error in script command.  Abort script input.
                        scriptActive = scriptSuspend = FALSE;
                        llMessageLinked(LINK_THIS, LM_SP_INIT, "", id);
                        tawk("Script terminated.");
                    }
                }

            //  LM_SP_EOF (56): End of file reading from script

            } else if (num == LM_SP_EOF) {
                scriptActive = FALSE;           // Mark script input complete
                if (echo || trace) {
                    tawk("End script.");
                }

            //  LM_SP_ERROR (58): Error processing script request

            } else if (num == LM_SP_ERROR) {
                llRegionSayTo(id, PUBLIC_CHANNEL, "Script error: " + str);
                scriptActive = scriptSuspend = FALSE;
                llMessageLinked(LINK_THIS, LM_SP_INIT, "", id);

            //  Test messages

            //  LM_TE_PASS (82): Test passed
            //  LM_TE_FAIL (83): Test failed

            } else if ((num == LM_TE_PASS) ||
                       (num == LM_TE_FAIL)) {
                if (trace) {
                    if (num == LM_TE_PASS) {
                        tawk("Test passed.");
                    } else {
                        tawk("Test failed.");
                    }
                }
                if (glow > 0) {
                    llSetLinkPrimitiveParamsFast(LINK_THIS,
                        [ PRIM_GLOW, ALL_SIDES, 0 ]);
                }
                scriptResume();

            //  LM_TE_LOG (86): Log result from test

            } else if (num == LM_TE_LOG) {
                logMessage(str);

            }
        }

        //  Dataserver: receive region look-up query information

        dataserver(key id, string reply) {
            if (id == regionQ) {
                if (stateQ == 1) {
                    //  Query for region valid and up/down status
                    if (reply == "up") {
                        stateQ++;
                        regionQ = llRequestSimulatorData(rnameQ, DATA_SIM_POS);
                    } else {
                        stateQ = 0;
                        tawk("Destination region " + rnameQ + " is " + reply + ".");
                        destRegion = rnameQ = "";
                        scriptResume();
                    }
                } else if (stateQ == 2) {
                    //  Query for region grid co-ordinates
                    vector gridc = ((vector) reply) / REGION_SIZE;
                    destRegion = rnameQ;
                    destGrid = gridc;
                    tawk("Destination: " + destRegion + " (" +
                        (string) ((integer) llRound(destRegc.x)) + ", " +
                        (string) ((integer) llRound(destRegc.y)) + ", " +
                        (string) ((integer) llRound(destRegc.z)) + ")");
                    stateQ = 0;
                    rnameQ = "";

                    //  Add the region to the cache of known regions
                    regionCache += [ destRegion, destGrid ];

                    if ((llGetPermissions() & PERMISSION_TELEPORT) == 0) {
                        llRequestPermissions(owner, PERMISSION_TELEPORT);
                    } else {
                        beamMe();           // Already have permission to teleport
                    }
                }
            }
        }

        //  Handle HTTP response from log update transmission

        http_response(key query, integer status, list data, string body) {
            if (query == httpKey) {
                if (status == 200) {
                    list st = llCSV2List(body);
                    if (llList2Integer(st, 0) != 200) {
                        tawk("HTTP log update rejected: status " +
                            llGetSubString(body, 0, 80) + ".");
                    }
                } else {
                    tawk("HTTP log update failed: status " + (string) status + ".");
                }
            }
        }

        //  The timer is used to monitor the move toward a target

        timer() {
            if (moveTarget.x >= 0) {
                if (moveLookAt > 0) {
                    moveLookAt--;
                    if (moveLookAt <= 0) {
                        llStopLookAt();
                    }
                }
                vector mtxy = moveTarget;
                vector cpxy = llGetPos();
                mtxy.z = cpxy.z = 0;
                float dist = llVecDist(mtxy, cpxy);
                integer stuck = FALSE;
                if (moveDistL <= dist) {
                    moveStuck++;
                    if (moveStuck > 5) {
                        stuck = TRUE;
                    }
                }
                moveDistL = dist;
                if ((dist < 0.25) || stuck) {
                    if (trace) {
                        if (stuck) {
                            tawk("Stuck.  Distance: " + (string) dist);
                        } else {
                            tawk("Arrived at target.  Distance: " + (string) dist);
                        }
                    }
                    if (moveLookAt > 0) {
                        moveLookAt = 0;
                        llStopLookAt();
                    }
                    llStopMoveToTarget();
                    llSetTimerEvent(0);
                    moveTarget = <-1, -1, -1>;
                    scriptResume();
                }
            }
        }
    }
