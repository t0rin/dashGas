#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 -f <csv_file> -n <ntfy_address> -c <city_name>"
  exit 1
}

# Parse command-line arguments
while getopts "f:n:c:" opt; do
  case ${opt} in
    f)
      csv_file=${OPTARG}
      ;;
    n)
      ntfy_address=${OPTARG}
      ;;
    c)
      city_name=$(echo ${OPTARG} | tr '[:lower:]' '[:upper:]')
      ;;
    *)
      usage
      ;;
  esac
done

# Check if the necessary arguments are provided
if [ -z "$csv_file" ] || [ -z "$ntfy_address" ] || [ -z "$city_name" ]; then
  usage
fi

# Extract the most recent entry for the specified city
latest_entry=$(grep "$city_name" "$csv_file" | tail -n 1)

if [ -z "$latest_entry" ]; then
  echo "No entries found for $city_name"
  exit 1
fi

# Extract the city name and gas price
gas_price=$(echo "$latest_entry" | awk -F',' '{print $2}')

# Send the notification
curl -d "${city_name} gas price is ${gas_price}" "$ntfy_address"