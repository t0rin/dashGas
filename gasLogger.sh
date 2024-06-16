#!/bin/zsh

# Script to check regular gasoline prices for a pre-defined list of Costco gas stations.
# Use with crontab -e to create a record of historical gas prices with the following daily cron job:
# 

# Get the script's filename without the extension
SCRIPT_NAME="${0:t:r}"

# Get the current timestamp in YYMMDD_HH:MM format
TIMESTAMP=$(date '+%Y%m%d,%H%M')

# Construct the output filename
OUTPUT_FILE="/Users/torin/scripts/gas/gasLog.csv"

# Debugging: Print the output file name
#echo "Output file will be: $OUTPUT_FILE"

# Check if the directory is writable
#if [ ! -w "$(pwd)" ]; then
#  echo "Error: Current directory is not writable."
#  exit 1
#fi

# Initialize the output file using a different approach
: >> "$OUTPUT_FILE" || { echo "Failed to initialize $OUTPUT_FILE"; exit 1; }

# Debugging: Confirm the file has been initialized
if [ -f "$OUTPUT_FILE" ]; then
  #echo "$OUTPUT_FILE initialized successfully."
else
  echo "Failed to create $OUTPUT_FILE."
  exit 1
fi

# Function to send request and extract gas prices
send_request() {
  local store_id=$1
  response=$(curl -s -G \
    --url "https://www.costco.com/AjaxWarehouseBrowseLookupView" \
    --data-urlencode "hasGas=true" \
    --data-urlencode "populateWarehouseDetails=true" \
    --data-urlencode "warehouseNumber=${store_id}" \
    -H "User-Agent: Gastrak/1.0" \
    -H "Accept-Language: en-US,en;q=0.5" \
    -H "Accept: */*")

  # Parse the JSON response
  json_body=$(echo "$response" | /opt/homebrew/bin/jq '.')
  
  # Check for errors in the response
  if [[ $? -ne 0 ]]; then
    echo "Failed to parse response as JSON for store ID ${store_id}"
    return
  fi

  # Extract the relevant data, skipping the first element
  gas_data=$(echo "$json_body" | /opt/homebrew/bin/jq '.[1:]')

  # Extract and display the gasPrices data
  gas_prices=$(echo "$gas_data" | /opt/homebrew/bin/jq '.[].gasPrices.regular | tonumber')
  gas_address=$(echo "$gas_data" | /opt/homebrew/bin/jq '.[].address1')
  gas_city=$(echo "$gas_data" | /opt/homebrew/bin/jq '.[].city')
  formatted_price=$(printf "%.2f" "$gas_prices")
  echo "$TIMESTAMP,$formatted_price,$gas_address,$gas_city" >> "$OUTPUT_FILE"
}

WAREHOUSE_LIST=('1660' '778' '1042' '423') # TODO: read from text file to make this more customizable
for WAREHOUSE in $WAREHOUSE_LIST; do
  #echo "Checking prices for warehouse $WAREHOUSE"
  send_request "$WAREHOUSE"
done

#echo "Output written to $OUTPUT_FILE"

