    /*

                    E-mail Log Delivery

    */

    integer MAX_EMAIL_BODY = 3500;  // Maximum E-mail body length per message

    key whoDat;                     // User (UUID) who requested command
    key owner;                      // Owner of the attachment

    //  Test script messages

    integer LM_TE_RESET = 80;       // Reset script
//  integer LM_TE_RUN = 81;         // Run test
//  integer LM_TE_PASS = 82;        // Test passed
//  integer LM_TE_FAIL = 83;        // Test failed
//  integer LM_TE_BEAM = 84;        // Notify tests we've teleported
    integer LM_TE_STAT = 85;        // Print status
    integer LM_TE_LOG = 86;         // Log results from test

    //  Command processor messages

    integer LM_CP_COMMAND = 223;    // Process command

    integer collecting = FALSE;     // Are we collecting log items for E-mail ?
    list logQueue = [ ];            // Log messages queued for E-mail
    integer mailSent = 0;           // Mail messages sent

    /*  tawk  --  Send a message to the interacting user in chat.
                  The recipient of the message is defined as
                  follows.  If an agent has provoked the message,
                  that avatar receives the message.  Otherwise,
                  the message goes to the owner of the object.
                  In either case, if the message is being sent to
                  the owner, it is sent with llOwnerSay(), which isn't
                  subject to the region rate gag, rather than
                  llRegionSayTo().  */

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

    /*  processAuxCommand  --  Process a command.  This code
                               handles commans delegated to us
                               by the main script.  */

    integer processAuxCommand(key id, list args) {

        whoDat = id;            // Direct chat output to sender of command

        string message = llList2String(args, 0);
        string lmessage = llList2String(args, 1);
        args = llDeleteSubList(args, 0, 1);
        integer argn = llGetListLength(args);       // Number of arguments
        string command = llList2String(args, 0);    // The command

        //  Set                         Set log Email clear/collect/send

        if (abbrP(command, "se") && (argn >= 3) &&
            abbrP(llList2String(args, 1), "lo") &&
            abbrP(llList2String(args, 2), "em")) {
            string tparam = llList2String(args, 3);

            //  Set log Email clear

            if (abbrP(tparam, "cl")) {
                logQueue = [ ];

            //  Set log Email collect on/off

            } else if (abbrP(tparam, "co")) {
                collecting = onOff(llList2String(args, 4));

            //  Set log Email send

            } else if (abbrP(tparam, "se")) {
                string body = "";
                integer len = 0;
                integer i;
                integer n = llGetListLength(logQueue);

                for (i = 0; i < n; i++) {
                    string s = llList2String(logQueue, i);
                    integer l = llStringLength(s);

                    if ((len + l) > MAX_EMAIL_BODY) {
                        logQueue = llDeleteSubList(logQueue, 0, i - 1);
                        llTargetedEmail(TARGETED_EMAIL_OBJECT_OWNER,
                            "Gridmark log items", body);
                        /*  Note that we now snooze for twenty long seconds.
                            In all likelihood, if additional messages
                            arrive, they'll just pile up in our input
                            queue while we're dozing, but just in case
                            we restart assembly of the balance of the
                            message from the queue from first principles.  */
                        i = 0;
                        n = llGetListLength(logQueue);
                        body = "";
                        len = 0;
                        s = llList2String(logQueue, i);
                        l = llStringLength(s);
                    }
                    body += s + "\n";
                    len += l + 1;
                }
                logQueue = [ ];
                llTargetedEmail(TARGETED_EMAIL_OBJECT_OWNER,
                    "Gridmark log items", body);
            } else {
                tawk("Invalid Set log Email command.  Valid: clear/collect/send.");
            }
        }
        return TRUE;
    }

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
            owner = whoDat = llGetOwner();
            logQueue = [ ];
            mailSent = 0;
        }

        /*  The link_message() event receives commands from the client
            script and passes them on to the script processing functions
            within this script.  */

        link_message(integer sender, integer num, string str, key id) {
//ttawk(llGetScriptName() + " link message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);
            whoDat = id;

            //  LM_TE_RESET (80): Reset test

            if (num == LM_TE_RESET) {
                llResetScript();

            //  LM_TE_STAT (85): Print status

            } else if (num == LM_TE_STAT) {
                string stat = llGetScriptName() + " status:\n";
                stat += "    Collecting: " + (string) collecting + "\n";
                if (logQueue != [ ]) {
                    integer i;
                    integer n = llGetListLength(logQueue);
                    integer l = 0;

                    for (i = 0; i < n; i++) {
                        l += llStringLength(llList2String(logQueue, i)) + 1;
                    }
                    stat += "    Log items queued: " + (string) llGetListLength(logQueue) +
                        "  Length: " + (string) l + "\n";
                }
                if (mailSent > 0) {
                    stat += "    E-mail messages sent: " + (string) mailSent + "\n";
                }
                integer mFree = llGetFreeMemory();
                integer mUsed = llGetUsedMemory();
                stat += "    Script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)";
                tawk(stat);

            //  LM_TE_LOG (86): Log result from test

            } else if (num == LM_TE_LOG) {
                if (collecting) {
                    logQueue += str;
                }

            //  LM_CP_COMMAND (223): Process auxiliary command

            } else if (num == LM_CP_COMMAND) {
                processAuxCommand(id, llJson2List(str));
            }
        }
    }
