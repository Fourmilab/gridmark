
#   This script illustrates periodic monitoring of the state and
#   performance of a variety of regions.

#  DON'T FORGET TO START FLYING BEFORE YOU RUN THIS SCRIPT

#   It teleports "up in the air" to a variety of regions and runs
#   a brief suite of tests there.  Choosing a vacant altitude
#   avoids disrupting people who may be there.  In flying mode,
#   we'll simply "altitude hold" before teleporting on to the next
#   region.  After every test sequence, we teleport back to the
#   place from which we started to wait for the next test interval.

Set mark at Origin here://

#   Run tests at home region to get a baseline
Script run Reconnaissance tests

Script loop
    Script wait 30m

    Beam http://maps.secondlife.com/secondlife/Debug1/128/128/2200
    Script run Reconnaissance tests

    Beam http://maps.secondlife.com/secondlife/London%20City/85/223/3600
    Script run Reconnaissance tests

    Beam http://maps.secondlife.com/secondlife/Babbage%20Palisade/149/72/2200
    Script run Reconnaissance tests

    Beam http://maps.secondlife.com/secondlife/Esperia/236/159/2200
    Script run Reconnaissance tests

    Beam mark://Origin

Script end
