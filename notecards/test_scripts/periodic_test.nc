
#   Run the "Tour tests" suite every hour, report by E-mail

Set log email collect on

Script loop
    Script wait 60 minutes
    Script run Tour tests
    Set log email send
Script end
