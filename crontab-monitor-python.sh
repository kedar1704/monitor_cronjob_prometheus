#!/bin/bash

# Example how to call this script:
# bash crontab-monitor.sh test /path/to/python_script.py

start=$(date +%s)
# probably unused
textfile_dir=$(dirname "$0")
# name of the job
job="$1"
# path to script
script="$2"

PROMETHEUS_FILE="/var/monitoring/cron_${job}.prom"

if [[ -z "$job" || -z "$script" ]]; then
  msg="ERROR: Missing arguments."
  exit_code=1
else
  # Run the script.
  if [[ ! -f "$script" || ! -x "$(command -v python)" ]]; then
    msg="ERROR: Can't find or execute the Python script for '$job'. Aborting."
    exit_code=2
  else
    msg=$(python "$script" 2>&1)
    # Get results and clean up.
    exit_code=$?
  fi
fi
finish=$(date +%s)
duration=$(( finish - start ))

output="
# HELP cron_exitcode Exit code of runner.
# TYPE cron_exitcode gauge
cron_exitcode{script=\"$job\"} $exit_code
# HELP cron_finish Time latest run finished.
# TYPE cron_finish gauge
cron_finish{script=\"$job\"} $finish
# HELP cron_duration Duration of latest run.
# TYPE cron_duration gauge
cron_duration{script=\"$job\"} $duration
"
if [[ "$exit_code" -ne "0" ]]; then
  output+="
# HELP cron_message Always = exit_code, but provides a message as data if exit_code!=0
# TYPE cron_message gauge
cron_message{script=\"$job\", msg=\"$msg\"} $exit_code
"
fi

# Save output to a temporary file
tmp_file=$(mktemp)
echo "$output" > "$tmp_file"

# Overwrite the Prometheus file with the temporary file
cat "$tmp_file" > "$PROMETHEUS_FILE"

# Remove the temporary file
rm "$tmp_file"

