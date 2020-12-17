    /*

                        rezscript Bullet

        This is the object which is rezzed from the Gridmark prim's
        inventory to measure the interval between its being rezzed
        and this script's receiving control.

    */

    integer dynamic = FALSE;                // Were we rezzed by the launcher ?
    string Collision = "Balloon Pop";       // Explosion sound clip

    //  These are usually overridden by the start_param in on_rez()
    integer time_to_live = 15;              // Lifetime of object (seconds)
    integer colour;                         // Colour index of object

    key myself;                             // Our own key
    key owner;                              // Key of our owner
    vector launchPos;                       // Location at launch
    integer gridmarkChan = -982449808;      // Channel for reporting script running

    /*  Standard colour names and RGB values.  This is
        based upon the resistor colour code.  */

    list colours = [
        "black",   <0, 0, 0>,                   // 0
        "brown",   <0.3176, 0.149, 0.1529>,     // 1
        "red",     <0.8, 0, 0>,                 // 2
        "orange",  <0.847, 0.451, 0.2784>,      // 3
        "yellow",  <0.902, 0.788, 0.3176>,      // 4
        "green",   <0.3216, 0.5608, 0.3961>,    // 5
        "blue",    <0.00588, 0.3176, 0.5647>,   // 6
        "violet",  <0.4118, 0.4039, 0.8078>,    // 7
        "grey",    <0.4902, 0.4902, 0.4902>,    // 8
        "white",   <1, 1, 1>                    // 9

//      "silver",  <0.749, 0.745, 0.749>,       // 10%
//      "gold",    <0.7529, 0.5137, 0.1529>     // 5%
    ];

    //  Create particle system for explosion effect

    splodey() {
        vector pcol = llGetColor(ALL_SIDES);

        llParticleSystem([
            PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,

            PSYS_SRC_BURST_RADIUS, 0.05,

            PSYS_PART_START_COLOR, pcol,
            PSYS_PART_END_COLOR, pcol,

            PSYS_PART_START_ALPHA, 0.9,
            PSYS_PART_END_ALPHA, 0.0,

            PSYS_PART_START_SCALE, <0.3, 0.3, 0>,
            PSYS_PART_END_SCALE, <0.1, 0.1, 0>,

            PSYS_PART_START_GLOW, 1,
            PSYS_PART_END_GLOW, 0,

            PSYS_SRC_MAX_AGE, 0.1,
            PSYS_PART_MAX_AGE, 0.5,

            PSYS_SRC_BURST_RATE, 20,
            PSYS_SRC_BURST_PART_COUNT, 1000,

            PSYS_SRC_ACCEL, <0, 0, 0>,

            PSYS_SRC_BURST_SPEED_MIN, 2,
            PSYS_SRC_BURST_SPEED_MAX, 2,

            PSYS_PART_FLAGS, 0
                | PSYS_PART_EMISSIVE_MASK
                | PSYS_PART_INTERP_COLOR_MASK
                | PSYS_PART_INTERP_SCALE_MASK
                | PSYS_PART_FOLLOW_VELOCITY_MASK
        ]);
    }

    default {

        on_rez(integer CMM) {
            if (gridmarkChan != 0) {
                //  Report time script received control to rezzer
                llRegionSayTo(llList2Key(llGetObjectDetails(llGetKey(),
                                         [ OBJECT_REZZER_KEY ]), 0),
                    gridmarkChan,
                    llList2Json(JSON_ARRAY, [ "REZ", llGetTimestamp() ]));
            }
            myself = llGetKey();
            owner = llGetOwner();

            dynamic = CMM != 0;                     // Mark if we were rezzed by the launcher

            if (dynamic) {
                launchPos = llGetPos();             // Save position at launch

                /*  Encoding of CMM:
                        CTT

                        TT = Time to live, 0 - 99 seconds (0 = immortal)
                        C  = Colour index, (resistor colour code + 1) % 10
                */

                time_to_live = CMM % 100;
                colour = (CMM / 100) % 10;
                integer cx = ((colour + 1) % 10) * 2;
                llSetColor(llList2Vector(colours, cx + 1), ALL_SIDES);

                llSetTimerEvent(time_to_live);      // Set timed delete
            }
        }

        /*  The timer is used to delete objects after they've served
            their purpose.  We could make them temporary, but that
            might influence the results of the benchmark and make them
            unrepresentative of the usual case of rezzing regular objects.  */

        timer() {
            llPlaySound(Collision, 1);
            splodey();
            llSleep(1);     // Need to wait to allow particles and sound to play
            llDie();
        }
    }
