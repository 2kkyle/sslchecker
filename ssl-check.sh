#!/bin/bash

# ----------------- Configuration -----------------
CSV="hosts.csv"
MAILTO="you@example.com"
MAILFROM="me@example.com"
MAILHOST="smtp.example.com"
MAILPORT="25"
MAILSUBJECT="SSL Certificate Expiration"
LOGFILE="sslchecker.log"
# -------------------------------------------------

# Start Log File
NOW=`date`
echo $NOW > $LOGFILE

# Check if required commands exist
for cmd in openssl date msmtp; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is not installed." >> $LOGFILE
        exit 1
    fi
done

# Read CSV file
tail -n +2 "$CSV" | while IFS=',' read -r HOST PORT DAYS COMMENT; do
    echo "Checking $HOST on port $PORT..." >> $LOGFILE

    # Get the expiration date using OpenSSL
    EXPIRES=$(echo | openssl s_client -servername "$HOST" -connect "$HOST:$PORT" 2>/dev/null \
        | openssl x509 -noout -enddate \
        | cut -d= -f2)

    # Failboat
    if [[ -z "$EXPIRES" ]]; then
        echo "FAILED: to retrieve certificate for $HOST:$PORT $COMMENT." >> $LOGFILE
        echo -e "To: $MAILTO\nSubject: $MAILSUBJECT for $HOST\n\nFAILED: to retrieve certificate for $HOST:$PORT $COMMENT." | msmtp --tls=on --tls-starttls=on --tls-certcheck=off --host=$MAILHOST --port=$MAILPORT --from=$MAILFROM $MAILTO
        echo "" >> $LOGFILE
        continue
    fi

    # Convert date to epoch
    EXPIRESEPOCH=$(date -d "$EXPIRES" +%s)
    NOWEPOCH=$(date -d "$NOW" +%s)
    DAYSREMAIN=$(( (EXPIRESEPOCH - NOWEPOCH) / 86400 ))

    if (( DAYSREMAIN <= DAYS )); then
        echo -e "To: $MAILTO\nSubject: $MAILSUBJECT for $HOST\n\nALERT: $HOST:$PORT $COMMENT expires on $EXPIRES ($DAYSREMAIN days left)." | msmtp --tls=on --tls-starttls=on --tls-certcheck=off --host=$MAILHOST --port=$MAILPORT --from=$MAILFROM $MAILTO
        echo "ALERT: $HOST:$PORT $COMMENT expires on $EXPIRES ($DAYSREMAIN days left)" >> $LOGFILE
    else
        echo "$HOST:$PORT $COMMENT expires on $EXPIRES ($DAYSREMAIN days left)" >> $LOGFILE
    fi

    echo "" >> $LOGFILE
done
