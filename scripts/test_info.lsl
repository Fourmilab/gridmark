    /*

                        Fourmilab Gridmark

            test info region/parcel

        This test queries information about the environment in which
        the test is being run and displays it as log items.

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

    key simdata = NULL_KEY;         // Query key for region simulator data
    key pownerName = NULL_KEY;      // Query key for parcel owner name
    key pokey;                      // Parcel owner key we're querying
    float ownerNameTimeout = 5;     // Timeout for querying parcel owner name
    key pgroupName = NULL_KEY;      // Query key for group name

    list parcelOwnerCache = [ ];    // Cache of parcel owner key => name
    float poCacheTimer = 60;        // Parcel owner cache expiry, seconds

    //  runTest  --  Run this test

    integer runTest(string message, string lmessage, list args) {
        string query = llList2String(args, 2);

        //  parcel

        if (query == "parcel") {
            list pownerl = llGetParcelDetails(llGetPos(),
                [ PARCEL_DETAILS_OWNER, PARCEL_DETAILS_GROUP ]);
            pokey = llList2Key(pownerl, 0);
            string powner = llKey2Name(pokey);
            if (powner == "") {
                /*  Parcel owner not in this region.  See if it's in
                    the owner cache and, if not, query the data server
                    to look it up.  */
                integer cx = llListFindList(parcelOwnerCache, [ pokey ]);
                if (cx >= 0) {
                    parcelInformation(pokey,
                        llList2String(parcelOwnerCache, cx + 1),
                        llList2String(parcelOwnerCache, cx + 2));
                    //  Restart cache expiry timer after cache hit
                    llSetTimerEvent(poCacheTimer);
                } else {
                    /*  Request owner name from parcel owner key.  The
                        owner key may be the key of an avatar for
                        individually owned land or the key of a group
                        for land owned by a group.  In the latter case,
                        the key for the owner and group will be the
                        same.  In that case, we must request the group
                        name with a gnarly HTTP server query.  */

                    key pgkey =  llList2Key(pownerl, 1);
                    if (pokey == pgkey) {
                        pgroupName = llHTTPRequest("http://world.secondlife.com/group/" +
                            (string) pgkey, [ ], "");
                    } else {
                        pownerName = llRequestAgentData((string) pokey, DATA_NAME);
                    }
                    /*  These requests can fail and not return any
                        response at all or none in a tolerable time.
                        We set a timer to detect this case and give up.  */
                    llSetTimerEvent(ownerNameTimeout);
                }
            } else {
                /*  This land is owned by an avatar currently present
                    on it.  We can immediately respond to the query.  */
                parcelInformation(pokey, powner, "A");
            }
            return FALSE;               // parcelInformation() responds

        //  region

        } else if (query == "region") {
            vector gridloc = llGetRegionCorner() / 256;
            integer startTime = (integer) env("region_start_time");
            integer upTime = llGetUnixTime() - startTime;


            simdata = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);

            testLogMessage(TRUE, [ "region",
                llGetRegionName(),                      // Name
                "<" + (string) llRound(gridloc.x) +     // Grid location
                "," + (string) llRound(gridloc.y) + ",0>",
                llGetSimulatorHostname(),               // Simulator host name
                llGetRegionFPS(),                       // Frames per second
                llGetRegionTimeDilation(),              // Time dilation
                llGetRegionFlags(),                     // Flag bits
                llGetRegionAgentCount(),                // Agents in region
                llWind(ZERO_VECTOR) ]);                 // Wind

            testLogMessage(TRUE, [ "regenv",
                env("agent_limit"),                     // Agent limit
                env("dynamic_pathfinding"),             // Dynamic pathfinding
                env("estate_id"),                       // Estate ID
                env("estate_name"),                     // Estate name
                env("frame_number"),                    // Frame number
                env("region_cpu_ratio"),                // Regions per CPU
                env("region_idle"),                     // Region idle ?
                env("region_product_name"),             // Region type
                env("region_product_sku"),              // Region SKU
                startTime,                              // Start time (Unix time)
                upTime,                                 // Up time (seconds)
                env("sim_channel"),                     // Sim channel
                env("sim_version"),                     // Sim version
                env("simulator_hostname"),              // Sim host name
                env("region_max_prims"),                // Max prims
                env("region_object_bonus"),             // Bonus factor
                env("whisper_range"),                   // Whisper range
                env("chat_range"),                      // Chat range
                env("shout_range") ]);                  // Shout range

                return FALSE;           // Defer completion until simulator responds
        } else {
            testStatus =  "Unknown Test info query";
            testLogMessage(FALSE, [ testStatus ]);
        }
        return LM_TE_FAIL;
    }

    /*  parcelInformation  --  Display parcel information.  We may
                               have to defer displaying this information
                               until we receive the parcel owner's name
                               from llRequestAgentData().  */

    parcelInformation(key ownerKey, string ownerName, string ownerType) {
        vector p = llGetPos();
        list pd = llGetParcelDetails(p,
            [ PARCEL_DETAILS_NAME, PARCEL_DETAILS_DESC,
              PARCEL_DETAILS_AREA ]);

        testLogMessage(TRUE, [ "parcel",
            llList2String(pd, 0),                   // Name
            llList2String(pd, 1),                   // Description
            ownerKey,                               // Owner key
            ownerType,                              // Owner type: A = avatar, G = group
            ownerName,                              // Owner name
            llList2Integer(pd, 2),                  // Area
            llGetParcelPrimCount(p,                 // Prims used
                PARCEL_COUNT_TOTAL, FALSE),
            llGetParcelMaxPrims(p,                  // Prims max
                FALSE),
            llGetParcelFlags(p) ]);                 // Flags
        llMessageLinked(LINK_THIS, LM_TE_PASS, testStatus, whoDat);
    }

    //  env  --  Get environment variable

    string env(string var) {
        return llGetEnv(var);
    }

    //  testLogMessage  --  Standard test log message

    testLogMessage(integer passed, list results) {
        llMessageLinked(LINK_THIS, LM_TE_LOG,
            flList2CSVSane([ "Gm", passed, testName,
                              llGetRegionName() ] + results),
            whoDat);
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

    //                      Fourmilab CSV

    integer escape = TRUE;              // Escape line end characters and \ ?

    //  ef  --  Edit floats in string to parsimonious representation

    string efv(vector v) {      // Edit vector
        return "<" + float2Sci(v.x) + "," + float2Sci(v.y) +
               "," + float2Sci(v.z) + ">";
    }

    string eff(float f) {       // Edit float
        return float2Sci(f);
    }

    string efr(rotation r) {    // Edit rotation
        return "<" + float2Sci(r.x) + "," + float2Sci(r.y) +
               "," + float2Sci(r.z) + "," + float2Sci(r.s) + ">";
    }

    //  qm  --  Quote metacharacter in string

    string qm(string s, string mchar, string rep) {
        list l = llParseString2List("|" + s + "|", [ mchar ], [ ]);
        if (llGetListLength(l) > 1) {
            return llGetSubString(llDumpList2String(l, rep), 1, -2);
        }
        return s;
    }

    //  flList2CSVSane  --  Correctly encode a list as CSV

    string Ucr;

    string flList2CSVSane(list l) {
        integer n = llGetListLength(l);
        if (n == 0) {
            return "";
        }
        string s = "";
        integer i;

        for (i = 0; i < n; i++) {
            for (i = 0; i < n; i++) {
                integer t = llGetListEntryType(l, i);

                if ((t == TYPE_INTEGER) || (t == TYPE_KEY)) {
                    //  No encoding required
                    s += (string) llList2String(l, i);
                } else if (t == TYPE_FLOAT) {
                    s += eff(llList2Float(l, i));
                } else if (t == TYPE_STRING) {
                    string v = llList2String(l, i);

                    /*  What the heck is this, you ask?  Well, in LSL, API calls and
                        anything affecting a string which may get the garbage collector
                        into the act can be terribly costly in time, so you try to do
                        as much as possible with a few calls, of which this is an extreme
                        example.  What we're trying to determine is whether we need to
                        quote a string field in the CSV file because it contains a
                        metacharacter or a character which we need to escape.  In a
                        reasonable language, this can be accomplished by a regular
                        expression or fast string search functions, but not here.  So,
                        we use a sledgehammer on the mosquito, deploying the parse
                        string function to split the string at any of the troublemaking
                        characters (which, the ever-helpful LSL limits to 8, maximum).
                        If this results in a list with more than one element, we know the
                        string needs to be quoted and/or escaped, and we do it all with
                        just two API calls.  But what are those vertical bar concatenates
                        about, you ask?  Well, you see, llParseStringKeepNulls(), in its
                        wisdom and *despite its own name*, does not split a string when
                        one of its separator characters appears at the start or end of
                        the string.  In any reasonable implementation, this should result
                        in a null string at the start and/or end, but it doesn't do that.
                        So, we tack on dummy non-meta characters to guarantee that case
                        doesn't occur.  Isn't this fun?  */
                    if (llGetListLength(llParseStringKeepNulls("|" + v + "|",
                            [ ], [ " ", ",", "\\", "\"", "\n", "" + Ucr + "" ])) != 1) {

                        /*  Escape any meta- or special characters in the
                            string.  Note that these are exquisitely
                            sensitive to the order in which they are done.  */
                        v = qm(v, "\"", "\"\"");
                        if (escape) {
                            v = qm(v, "\\", "\\\\");
                            v = qm(v, "\n", "\\n");
                            v = qm(v, Ucr, "\\r");
                        }
                        //  Wrap quotes around the escaped string
                        v = "\"" + v + "\"";
                    }
                    s += v;
                } else if (t == TYPE_VECTOR) {
                    s += "\"" + efv(llList2Vector(l, i)) + "\"";
                } else if (t == TYPE_ROTATION) {
                    s += "\"" + efr(llList2Rot(l, i)) + "\"";
                }
else { s += "!BLOOIE!"; }
                s += ",";
            }
        }
        return llGetSubString(s, 0, -2);
    }

    /*  float2Sci  --  Edit floating point number to accurate
                       scientific notation.

        The following function is:
            Copyright © 2016 Linden Research, Inc.
            Licensed under Creative Commons Attribution-Share Alike 3.0
            Source: http://wiki.secondlife.com/wiki/Float2Sci

        It has been modified for use within Fourmilab CSV and,
        conveniently, is distributed under the same license.  */

    string float2Sci(float input) {
        if (input == 0) {           // Handle negative zero
            //  Remove trailing zeroes
            return llDeleteSubString((string) input, -5, -1);
        }

        float frac = llFabs(input); // Put the negative back at the end
        string mantissa = (string) frac;    // May be as long as 47 characters
        if (!~llSubStringIndex(mantissa, ".")) {
            return (string) input;  // Handle NaN and Infinities
        }

        integer exponent = -6;      // Default exponent for optical method
        if (frac == (float) mantissa) {
            mantissa = llDeleteSubString(mantissa, -7, -7); // Elide decimal point
            jump optical;
        }

        /*  Optical method failed:

            Ugly Math version; ugly in the sense that it is slow and
            not as elegant as working with it as a string.
                A) Calculate the exponent via approximation of C log2().
                B) Use kludge to avert fatal error in approximation of
                   log2 result (only a problem with values >= 0x1.FFFFF8p127).
                   (The exponent is sometimes reported as 128, which
                   will break float math, so we subtract the test for
                   128. max_float is 0x1.FFFFFEp127, so we are only
                   talking a very small fraction of numbers.)
                C) Normalise floats with questionable exponents.
                D) Calculate rounding error left from log2
                   approximation and add to normalization value. (The '|'
                   acts like a '+' in this instance but saves us one
                   byte.)  */

        integer position = (24 | (3 <= frac)) -                 // D
                     (integer) (frac /= llPow(2.0,              // C
                        exponent = (exponent -                  // B
                            ((exponent = llFloor(llLog(frac) /
                            0.69314718055994530941723212145818))// A
                                == 128))));

        /*  This pushes the float into the integer buffer exactly.
            since the shift is within integer range, we don't need to
            make a float.  */

        integer int = (integer) (frac * (1 << position));
        //  Since the float is in the integer buffer, we need to clear the float buffer.
        integer target = (integer) (frac = 0.0);

        /*  We don't use a traditional while loop, and instead opt for
            a do-while, because it's faster since we may have to do about
            128 iterations, this savings is important.  The exponent needs
            one final adjustment because of the shift, so we do it here to
            save memory and it's faster.

            The two loops try to make exponent == position by shifting
            and multiplying. when they are equal, then this should be
            true: ((int * llPow(10, exponent)) == llFabs(input)) That
            is of course assuming that the llPow(10, exponent) result
            has enough precision.

            We recycle position for these loops as a temporary buffer.
            This is so we can save a few operations.  If we didn't, then
            we could actually optimize the variable out of the code;
            though it would be slower.  */

        if (target > (exponent -= position)) {
            //  Apply the rest of the bit shift if |input| < 1
            do {
                if (int < 0x19999999) {     // (0x80000000 / 5)
                    //  Won't overflow, multiply in 5
                    int = int * 5 + (position = (integer) (frac *= 5.0));
                    frac -= (float) position;
                    target = ~-target;
                } else {
                    //  Overflow predicted, divide by 2
                    frac = (frac + (int & 1)) / 2;
                    int = int >> 1;
                    exponent = -~exponent;
                }
            } while (target ^ exponent);
        } else if (target ^ exponent) {     // Target < exponent
            //  Apply the rest of the bit shift if |input| > 1
            do {
                if  (int < 0x40000000) {    // (0x80000000 / 2)
                    //  Won't overflow, multiply in 2
                    int = (int << 1) + (position = (integer) (frac *= 2.0));
                    frac -= (float) position;
                    exponent = ~-exponent;
                }
                else {                      //  Overflow predicted, divide by 5
                    frac = (frac + (int % 5)) / 5.0;
                    int /= 5;
                    target = -~target;
                }
            } while (target ^ exponent);
        }

        /*  int is now properly calculated.  It holds enough data to
            accurately describe the input in conjunction with exponent.
            we feed this through optical to clean up the answer.  */

        mantissa = (string) int;

        @optical;

        /*  It's not an issue that we may be jumping over the
            initialization of some of the variables, we initialise
            everything we use here.

            To accurately describe a float you only need 9 decimal
            places; so we throw the extras away. */

        if (9 < (target = position = llStringLength(mantissa))) {
            position = 9;
        }

        //  Chop off the tailing zeroes; we don't need them.

        do;                 //  Faster then a while loop
        while ((llGetSubString(mantissa, position, position) == "0") &&
               (position = ~-position));

        /*  We do a bad thing: we recycle 'target' here, position is
            one less then target, "target + ~position" is the same as
            "target - (position + 1)" saves 6 bytes. This block of code
            actually does the cutting.  */

        if (target + ~position) {
            mantissa = llGetSubString(mantissa, 0, position);
        }

        /*  Insert the decimal point (not strictly needed).  We add the
            extra zero for aesthetics. by adding in the decimal point,
            which simplifies some of the code.  */

        mantissa = llInsertString(mantissa, 1, llGetSubString(".0", 0, !position));

        //  Adjust exponent from having added the decimal place
        if ((exponent += ~-target) != 0) {
            mantissa += "e" + (string) exponent;
        }

        //  Negate if input was negative
        if (input < 0) {
            return "-" + mantissa;
        }
        return mantissa;
    }
    //  End Linden Lab float2Sci() function
    //                      End Fourmilab CSV

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
                    if (result > 0) {
                        llMessageLinked(LINK_THIS, result, testStatus, whoDat);
                    }
                }

            //  LM_TE_STAT (85): Print status

            } else if (num == LM_TE_STAT) {
                string stat = llGetScriptName() + " status:\n";
                integer mFree = llGetFreeMemory();
                integer mUsed = llGetUsedMemory();
                stat += "  Script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)";
                if (parcelOwnerCache != [ ]) {
                    stat += "\n  Parcel owner cache: " +
                        llList2CSV(parcelOwnerCache);
                }
                tawk(stat);
            }
        }

        //  Receive simulator data for region and avatar name look-ups

        dataserver(key query, string result) {
            if (query == simdata) {
                testLogMessage(TRUE, [ "regrate", result ]);
                llMessageLinked(LINK_THIS, LM_TE_PASS, testStatus, whoDat);
                simdata = NULL_KEY;
            } else if (query == pownerName) {
                parcelInformation(pokey, result, "A");
                parcelOwnerCache += [ pokey, result, "A" ];
                llSetTimerEvent(poCacheTimer);
                pownerName = NULL_KEY;
            }
        }

        /*  We receive group name look-ups via HTTP queries.  We
            have to dig the name out of the resulting XHTML page.  */

        http_response(key query, integer status, list data, string body) {
            if (query == pgroupName) {
                string groupname = "";
                string nametype = "?";

                if (status == 200) {
                    list pbod = llParseString2List(body, [ "<title>", "</title>"], [ ]);
                    groupname = llList2String(pbod, 1);

                    /*  The group name may include various Unicode characters
                        which Second Life returns in the reply as XHTML text
                        entities.  Convert some of the most common back to
                        Unicode.  */
                    list parsedname = llParseString2List(groupname, [ ],
                        [ "&lt;", "&rt;", "&quote;", "&amp;", "&cent;", "&pound;",
                          "&yen;", "&euro;", "&copy;", "&reg;" ]);
                    integer i;
                    integer n = llGetListLength(parsedname);
                    list replace = [ "&lt;", "<", "&rt;", ">", "&quote;" ,"\"", "&amp;", "&",
                                     "&cent;", "¢", "&pound;", "£", "&yen;", "¥","&euro;", "€",
                                     "&copy;", "©", "&reg;", "®" ];
                    for (i = 0; i < n; i++) {
                        string substring = llList2String(parsedname, i);
                        integer idx = llListFindList(replace, [ substring ]);
                        if ((idx >= 0) && (!(idx % 2))) {
                            parsedname = llListReplaceList(parsedname,
                                llList2List(replace, idx + 1, idx + 1), i, i);
                        }
                    }
                    groupname = llDumpList2String(parsedname, "");
                    nametype = "G";
                }
                pgroupName = NULL_KEY;

                parcelInformation(pokey, groupname, nametype);
                //  Succeed or fail, save the results in the cache
                parcelOwnerCache += [ pokey, groupname, nametype ];
                llSetTimerEvent(poCacheTimer);
            }
        }

        /*  We use the timer to expire the parcel owner cache
            and to detect failures to retrieve the parcel owner
            or group name.  */

        timer() {
            if ((pownerName != NULL_KEY) || (pgroupName != NULL_KEY)) {
                pownerName = pgroupName = NULL_KEY;
                parcelInformation(pokey, "", "?");
                parcelOwnerCache += [ pokey, "", "?" ];
                //  Add failed query to the cache to avoid subsequent attempts
                llSetTimerEvent(poCacheTimer);
            } else {
                parcelOwnerCache = [ ];
                llSetTimerEvent(0);
            }
        }
    }
