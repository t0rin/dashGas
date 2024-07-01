#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 [-a latitude,longitude] [-s store_ids] [-o output_file]"
  echo "  -a latitude,longitude   Find all Costcos at the specified latitude and longitude"
  echo "  -s store_ids            Comma-separated list of store IDs to show information for (default: 1660,778,1042,423)"
  echo "  -o output_file          Specify the output file for the results"
  exit 1
}

# Parse command-line arguments
all_flag=false
store_ids="1660,778,1042,423"
latitude=""
longitude=""
output_file=""

while getopts "a:s:o:" opt; do
  case ${opt} in
    a)
      all_flag=true
      IFS=',' read -r latitude longitude <<< "${OPTARG}"
      ;;
    s)
      store_ids="${OPTARG}"
      ;;
    o)
      output_file="${OPTARG}"
      ;;
    *)
      usage
      ;;
  esac
done

shift $((OPTIND - 1))

# Check if necessary arguments are provided
if [ "$all_flag" = true ] && ([ -z "$latitude" ] || [ -z "$longitude" ]); then
  echo "Latitude and longitude are required with the -a option"
  usage
fi

if [ -z "$output_file" ]; then
  echo "Output file is required with the -o option"
  usage
fi

# Get the current timestamp in YYMMDD_HH:MM format
TIMESTAMP=$(date '+%Y%m%d,%H%M')

# Function to send request and extract gas prices
send_request() {
  local store_id=$1
  local retries=5

  while [ $retries -gt 0 ]; do
    response=$(curl -s -G \
      --url "https://www.costco.com/AjaxWarehouseBrowseLookupView" \
      --data-urlencode "hasGas=true" \
      --data-urlencode "populateWarehouseDetails=true" \
      --data-urlencode "warehouseNumber=${store_id}" \
      -H "User-Agent: Gastrak/1.0" \
      -H "Accept-Language: en-US,en;q=0.5" \
      -H "Accept: */*")

    # Parse the JSON response
    json_body=$(echo "$response" | jq '.')

    # Check for errors in the response
    if [[ $? -ne 0 ]]; then
      echo "Failed to parse response as JSON for store ID ${store_id}"
      return
    fi

    # Extract the relevant data, skipping the first element
    gas_data=$(echo "$json_body" | jq '.[1:]')

    # Extract and display the gasPrices data
    gas_prices=$(echo "$gas_data" | jq '.[].gasPrices.regular | tonumber')

    # Check if the gas price is null or zero
    if [ -n "$gas_prices" ] && [ "$gas_prices" != "0" ]; then
      gas_address=$(echo "$gas_data" | jq '.[].address1')
      gas_city=$(echo "$gas_data" | jq '.[].city')
      formatted_price=$(printf "%.2f" "$gas_prices")
      echo "$TIMESTAMP,$formatted_price,$gas_address,$gas_city" >> "$output_file"
      break
    else
      echo "Received null or zero gas price for store ID ${store_id}. Retrying..."
      retries=$((retries - 1))
      sleep 1
    fi
  done

  if [ $retries -le 0 ]; then
    echo "Failed to get a valid gas price for store ID ${store_id} after multiple attempts."
  fi
}

# Process all store IDs if provided
if [ -n "$store_ids" ]; then
  IFS=',' read -r -a ids <<< "$store_ids"
  for store_id in "${ids[@]}"; do
    send_request "$store_id"
  done
fi

# Process all flag if provided
if [ "$all_flag" = true ]; then
  response=$(curl -s -G \
    --url "https://www.costco.com/AjaxWarehouseBrowseLookupView" \
    --data-urlencode "numOfWarehouses=50" \
    --data-urlencode "hasGas=true" \
    --data-urlencode "populateWarehouseDetails=true" \
    --data-urlencode "latitude=${latitude}" \
    --data-urlencode "longitude=${longitude}" \
    --data-urlencode "countryCode=US" \
    -H "User-Agent: Gastrak/1.0" \
    -H "Accept-Language: en-US,en;q=0.5" \
    -H "Accept: */*")

  # Parse the JSON response
  json_body=$(echo "$response" | jq '.')

  # Check for errors in the response
  if [[ $? -ne 0 ]]; then
    echo "Failed to parse response as JSON" >> "$output_file"
    exit 1
  fi

  # Extract the relevant data, skipping the first element
  gas_data=$(echo "$json_body" | jq '.[1:]')

  # Extract and display the gasPrices data with formatted regular price
  gas_prices=$(echo "$gas_data" | jq -r '.[].gasPrices.regular | tonumber')

  # Retry if gas prices are null or zero
  retries=5
  while [ -n "$gas_prices" ] && ([ "$gas_prices" = "null" ] || [ "$gas_prices" = "0" ]) && [ $retries -gt 0 ]; do
    echo "Received null or zero gas prices. Retrying..."
    sleep 1
    gas_prices=$(echo "$gas_data" | jq -r '.[].gasPrices.regular | tonumber')
    retries=$((retries - 1))
  done

  if [ -n "$gas_prices" ] && [ "$gas_prices" != "0" ]; then
    formatted_price=$(printf "%.2f" "$gas_prices")
    echo "$formatted_price" >> "$output_file"
  else
    echo "Failed to get a valid gas price after multiple attempts."
  fi
fi