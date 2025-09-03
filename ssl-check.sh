#!/bin/bash

# ----------------- Configuration -----------------
CSV="hosts.csv"
MAILTO="you@example.com"
MAILFROM="me@example.com"
MAILHOST="smtp.example.com"
MAILPORT="25"
MAILSUBJECT="SSL Certificate Expiration"
LOGFILE="sslchecker.log"
MSMTPOPTS="--tls=on --tls-starttls=on --tls-certcheck=off --host=$MAILHOST --port=$MAILPORT --from=$MAILFROM $MAILTO"
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
tail -n +2 "$CSV" | grep -v ^\# | while IFS=',' read -r HOST PORT DAYS COMMENT; do
    echo "Checking $HOST on port $PORT..." >> $LOGFILE

    # Get the expiration date using OpenSSL
    EXPIRES=$(echo | openssl s_client -servername "$HOST" -connect "$HOST:$PORT" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null \
        | cut -d= -f2)

    # Failboat
    if [[ -z "$EXPIRES" ]]; then
	FMESSAGE="FAILED: to retrieve certificate for $HOST:$PORT $COMMENT."
        echo $FMESSAGE >> $LOGFILE
        echo -e "To: $MAILTO\nSubject: $MAILSUBJECT for $HOST\n\n$FMESSAGE" | msmtp $MSMTPOPTS
        echo "" >> $LOGFILE
        continue
    fi

    # Convert date to epoch
    EXPIRESEPOCH=$(date -d "$EXPIRES" +%s)
    NOWEPOCH=$(date -d "$NOW" +%s)

    DAYSREMAIN=$(( (EXPIRESEPOCH - NOWEPOCH) / 86400 ))
    MESSAGE="$HOST:$PORT $COMMENT expires on $EXPIRES ($DAYSREMAIN days left)."

    if (( DAYSREMAIN <= DAYS )); then
	AMESSAGE="ALERT: $MESSAGE $HOST:$PORT $COMMENT expires on $EXPIRES ($DAYSREMAIN days left)."
        echo -e "To: $MAILTO\nSubject: $MAILSUBJECT for $HOST\n\n$AMESSAGE" | msmtp $MSMTPOPTS
        echo $AMESSAGE >> $LOGFILE
    else
        echo $MESSAGE >> $LOGFILE
    fi

    echo "" >> $LOGFILE
done
