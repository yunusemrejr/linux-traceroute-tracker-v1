#!/bin/bash
#
# Traceroute Route Investigator + VPN Comparison
# Shows detailed packet route; compares ISP routing vs VPN routing
# Yunus Emre Vurgun Custom Shell Scripts Collection 2025
# Developed by Yunus Emre Vurgun, for Ubuntu-based GNU/Linux Operating Systems.

# Requirements: traceroute, geoip-bin, whois, gawk, coreutils, bc
# Usage: Run the script, enter your domain. Script auto-detects connection (you should first connect to VPN and keep it running when prompted).

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
RESET=$(tput sgr0)

compare_results () {
    local label="$1"
    local dest="$2"
    local p_route="$3"

    echo -e "${CYAN}=== Traceroute: $label ===${RESET}"
    echo -e "${GREEN}Tracing route to $dest ...${RESET}"
    echo

    declare -a STORY
    declare -a HOP_COUNTRIES
    declare -a HOP_ISPS
    declare -a HOP_HOSTNAMES
    declare -a HOP_IPS

    SUCCESS=false
    HOP_COUNT=0
    PREV_RTT=0
    PREV_COUNTRY=""
    PREV_ISP=""
    LOCAL_ISP=""

    DEST_IP=$(getent ahosts "$dest" | awk '/STREAM/ {print $1; exit}')
    if [[ -z "$DEST_IP" ]]; then
        echo -e "${RED}Could not resolve${RESET} $dest"
        return
    fi

    while read -r line; do
        HOP=$(echo "$line" | awk '{print $1}')
        ((HOP_COUNT++))

        if [[ "$line" =~ \*{1,} ]]; then
            STORY+=("Hop $HOP: No response — likely filtered or timed out.")
            HOP_COUNTRIES+=("Unknown")
            HOP_ISPS+=("Unknown")
            HOP_HOSTNAMES+=("No response")
            HOP_IPS+=("N/A")
            continue
        fi

        HOSTNAME=$(echo "$line" | awk '{print $2}')
        IPs=$(echo "$line" | grep -oE '\([0-9\.]+\)' | tr -d '()')
        RTTs=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+ ms' | tr '\n' ' ')
        MAIN_IP=$(echo "$IPs" | head -n1)

        GEO_INFO=""
        COUNTRY="Unknown"
        if command -v geoiplookup &>/dev/null && [[ -n "$MAIN_IP" ]]; then
            GEO_INFO=$(geoiplookup "$MAIN_IP" 2>/dev/null | head -n 1 | cut -d: -f2- | sed 's/^ //')
            COUNTRY=$(echo "$GEO_INFO" | awk -F, '{print $1}')
        fi

        ASN_INFO="Unknown"
        if command -v whois &>/dev/null && [[ -n "$MAIN_IP" ]]; then
            ASN_INFO=$(whois "$MAIN_IP" 2>/dev/null | awk -F: '/origin/ {print $2; exit}' | sed 's/^ //')
            if [[ -z "$ASN_INFO" ]]; then
                ASN_INFO=$(whois "$MAIN_IP" 2>/dev/null | awk -F: '/descr/ {print $2; exit}' | sed 's/^ //')
            fi
        fi

        if [[ -z "$LOCAL_ISP" && "$ASN_INFO" != "Unknown" ]]; then
            LOCAL_ISP="$ASN_INFO"
        fi

        AVG_RTT=$(echo "$RTTs" | awk '{sum=0; for(i=1;i<=NF;i++) {gsub(/ ms/,"",$i); sum+=$i} print sum/NF}')
        LAT_CHANGE=$(awk -v prev="$PREV_RTT" -v curr="$AVG_RTT" 'BEGIN {print curr - prev}')
        ANOMALY=""
        if (( $(echo "$LAT_CHANGE > 50" | bc -l) )); then
            ANOMALY="${RED}⚠ Latency jump of ${LAT_CHANGE} ms — possible long-distance link, congestion, or traffic shaping${RESET}"
        fi

        if [[ "$COUNTRY" != "Unknown" && "$PREV_COUNTRY" != "" && "$COUNTRY" != "$PREV_COUNTRY" ]]; then
            ANOMALY="$ANOMALY ${MAGENTA}✈ Country change: $PREV_COUNTRY → $COUNTRY${RESET}"
        fi

        if [[ "$ASN_INFO" != "Unknown" && "$PREV_ISP" != "" && "$ASN_INFO" != "$PREV_ISP" ]]; then
            ANOMALY="$ANOMALY ${CYAN}🔄 ISP change: $PREV_ISP → $ASN_INFO${RESET}"
        fi

        PREV_RTT=$AVG_RTT
        [[ "$COUNTRY" != "Unknown" ]] && PREV_COUNTRY="$COUNTRY"
        [[ "$ASN_INFO" != "Unknown" ]] && PREV_ISP="$ASN_INFO"

        NARRATIVE="Our packets reached ${HOSTNAME} ($IPs)"
        [[ -n "$GEO_INFO" ]] && NARRATIVE="$NARRATIVE in $GEO_INFO"
        [[ "$ASN_INFO" != "Unknown" ]] && NARRATIVE="$NARRATIVE — network: $ASN_INFO"
        [[ -n "$ANOMALY" ]] && NARRATIVE="$NARRATIVE — $ANOMALY"

        STORY+=("Hop $HOP: $NARRATIVE with RTTs $RTTs")
        HOP_COUNTRIES+=("$COUNTRY")
        HOP_ISPS+=("$ASN_INFO")
        HOP_HOSTNAMES+=("$HOSTNAME")
        HOP_IPS+=("$MAIN_IP")

        for ip in $IPs; do
            if [[ "$ip" == "$DEST_IP" ]] || [[ "$HOSTNAME" =~ $dest ]]; then
                SUCCESS=true
                break 2
            fi
        done
    done < <(traceroute "$dest" | tail -n +2)

    echo
    echo -e "${MAGENTA}=== Journey Summary ($label) ===${RESET}"
    if $SUCCESS; then
        echo "Your packets departed from your device and first reached your local gateway, then:"
    else
        echo "Your packets departed from your device and started the journey, but did not fully reach the destination."
    fi

    PREV_COUNTRY="${HOP_COUNTRIES[0]}"
    PREV_ISP="${HOP_ISPS[0]}"
    for ((i=0; i<${#HOP_COUNTRIES[@]}; i++)); do
        COUNTRY="${HOP_COUNTRIES[$i]}"
        ISP="${HOP_ISPS[$i]}"
        HOST="${HOP_HOSTNAMES[$i]}"
        IP="${HOP_IPS[$i]}"

        if [[ $i -eq 0 ]]; then
            echo -e "  - First, your packets went to your local ISP server named [${YELLOW}$HOST${RESET}] at IP [${CYAN}$IP${RESET}] located in [${GREEN}$COUNTRY${RESET}] (Network: $ISP)."
        else
            if [[ "$COUNTRY" != "$PREV_COUNTRY" ]]; then
                echo -e "  - Then, they crossed into [${MAGENTA}$COUNTRY${RESET}] and began using infrastructure operated by [${CYAN}$ISP${RESET}]."
                PREV_COUNTRY="$COUNTRY"
                PREV_ISP="$ISP"
            elif [[ "$ISP" != "$PREV_ISP" && -n "$ISP" ]]; then
                echo -e "  - Afterwards, your packets were handed over to a new ISP: [${CYAN}$ISP${RESET}], via server [${YELLOW}$HOST${RESET}] at IP [${CYAN}$IP${RESET}]."
                PREV_ISP="$ISP"
            fi
        fi
    done

    if $SUCCESS; then
        echo -e "  - Finally, your packets reached [${GREEN}$dest${RESET}] ($DEST_IP) successfully."
        echo -e "${GREEN}✅ Connection succeeded.${RESET}"
    else
        echo -e "  - However, somewhere along this journey the packets were dropped or filtered, so the target was not reached."
        echo -e "${RED}❌ Connection incomplete. Review hops above for anomaly notes.${RESET}"
    fi

    echo -e "${CYAN}Traceroute investigation complete.${RESET}"
}

# --------- MAIN FIELD---------
echo -e "${YELLOW}Enter domain or IP to trace:${RESET}"
read -r DEST

echo -e "${MAGENTA}Performing traceroute WITHOUT VPN connection...${RESET}"
compare_results "Without VPN" "$DEST" "route_novpn.txt"

echo
echo -e "${YELLOW}Now disconnect from your regular network and connect to your VPN.${RESET}"
read -p "Press Enter when your VPN is connected..."

echo -e "${MAGENTA}Performing traceroute WITH VPN connection...${RESET}"
compare_results "With VPN" "$DEST" "route_vpn.txt"

echo -e "${CYAN}=== ROUTE COMPARISON ===${RESET}"

# I cut it off here, (too tired lmao) but you could, literally add diff logic here as you wish, if you want to automatically show the differences or some more advanced concepts.
echo -e "${YELLOW}Compare the journey summaries above to see if your ISP and VPN manipulated routing, country path, or latency differently.${RESET}"

