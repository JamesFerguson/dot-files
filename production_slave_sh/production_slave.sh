#!/bin/zsh

echo "Setting up slave tunnel..."
ssh re-db-slave-tunnel -N &

echo "\nRun reports with: \nRAILS_ENV=reports ./script/rails runner report.rb > report.csv\n"
echo "Start console with:\nRAILS_ENV=reports console"

echo "Currently this doesn't seem to work."
