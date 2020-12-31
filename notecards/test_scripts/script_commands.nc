
#   Test of internal Script Processor commands

Set echo on

@Echo Loop 3 times
Script loop 3
@Echo In loop of 3
Script end

@Echo
@Echo Two nested loops of 2 iterations
Script loop 2
@Echo Starting outer loop
Script loop 2
@Echo   Inner loop
Script end
@Echo Ending outer loop
Script end

@Echo
@Echo Pause of default 1 second
Script pause
@Echo End 1 second pause

@Echo
@Echo Pause of 5 seconds
Script pause 5
@Echo End 5 second pause

@Echo
@Echo Pause until touched
@Echo Please touch to resume script...
Script pause touch
@Echo ...script resumed

@Echo Cancelling pause touch with Script resume
@Echo Please enter "Script resume" to cancel pause...
Script pause touch
@Echo ...script resumed

@Echo Cancelling very long pause with Script resume
@Echo Please enter "Script resume" to cancel pause...
Script pause 600
@Echo ...script resumed
