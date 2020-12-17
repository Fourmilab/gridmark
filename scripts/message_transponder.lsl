    /*

                           Message Transponder

        This object is part of the Gridmark attachment.  When the
        message benchmarks are run, it responds to probes
        from the test script allowing measurement of message
        bandwidth.

    */

    key owner;                      // Owner/wearer of attachment
    key parent;                     // Root prim of link set
    key attachedTo;                 // Avatar to which we're attached, if any

    integer transChannel = -982449810;  // Transponder channel
    integer trHandle;               // Transponder listener handle
    integer trActive = FALSE;       // Is transponder active ?

    integer sayTo = FALSE;          // Use llRegionSayTo(), not llRegionSay()

    //  Test script messages

    integer LM_TE_RESET = 80;       // Reset script

    //  Transponder messages

    integer LM_TR_ACTIVE = 340;     // Activate/deactivate transponder
    integer LM_TR_PING = 341;       // Ping over link channel

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
            owner = llGetOwner();
            parent = llGetLinkKey(LINK_ROOT);
            trActive = FALSE;
            trHandle = 0;
        }

        //  Process messages from other scripts

        link_message(integer sender, integer num, string str, key id) {

            //  LM_TE_RESET (80): Reset test

            if (num == LM_TE_RESET) {
                llResetScript();

            //  LM_TR_ACTIVE (340): Activate/deactivate transponder

            } else if (num == LM_TR_ACTIVE) {
                integer what = (integer) str;

                /*  What bits:
                        1   Activate / deactivate
                        2   Use llRegionSayTo() to respond
                        4   Testing link messages, not llRegionSay...  */

                if (what & 1) {
                    //  Activate transponder
                    if (!trActive) {
                        if (!(what & 4)) {
                            trHandle = llListen(transChannel, "", parent, "");
                        }
                        //  Determine whether we're attached and if so, to whom
                        if (llGetAttached() != 0) {
                            attachedTo = owner;
                        } else {
                            attachedTo = NULL_KEY;
                        }
                        sayTo = (what & 2) != 0;
                        trActive = TRUE;
                        llSetAlpha(1, ALL_SIDES);
                    }
                } else {
                    if (trActive) {
                        if (trHandle != 0) {
                            llListenRemove(trHandle);
                        }
                        trHandle = 0;
                        trActive = FALSE;
                        llSetAlpha(0, ALL_SIDES);
                    }
                }
                //  Confirm transponder activated/deactivated
                llMessageLinked(sender, num, str, id);

            //  LM_TR_PING (341): Respond to ping on link message channel

            } else if (num == LM_TR_PING) {
                llMessageLinked(sender, num, str, id);
            }
        }

        //  The listen event echoes transponder pings from the test script

        listen(integer channel, string name, key id, string message) {
            if (channel == transChannel) {
                if (sayTo) {
                    /*  When attached to an avatar, llRegionSayTo() directed
                        to another prim in the attachment's link set does
                        nothing.  When we're attached, we have to send the
                        message to the avatar to which we're attched, which
                        will cause the listener in the link running the test
                        to receive it.  */
                    if (attachedTo != NULL_KEY) {
                        llRegionSayTo(attachedTo, transChannel, message);
                    } else {
                        /*  When we're not attached, we can just send the
                            reply back to the sender in the root prim.  */
                        llRegionSayTo(id, transChannel, message);
                    }
                } else {
                    //  llRegionSay() works whether we're attached or not.
                    llRegionSay(transChannel, message);
                }
            }
        }
    }
