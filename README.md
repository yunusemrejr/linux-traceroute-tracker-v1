# Traceroute Route Investigator with VPN Comparison

## Overview

**Traceroute Route Investigator** is a Bash script that performs a traceroute to a target domain **with and without a VPN connection**, providing:

- **Hop-by-hop** route details (hostname, IP).
- **Geolocation** (country) and **network owner/ASN** for each hop.
- **Latency spike detection** — flags possible congestion, long-haul links, or traffic shaping.
- **Country changes** — detects when traffic crosses national borders.
- **ISP changes** — highlights when your traffic is handed to a different provider.
- **Narrative summaries** for each path in plain English.
- **Comparison mode** to detect differences between ISP routing and VPN routing — great for identifying censorship, throttling, or peering manipulation.

***

## Features

- **Narrated Journey**: Tells the story of where your packets went and through whom.
- **GeoIP \& ASN Lookups**: Fetches country info and the ISP/network for each hop.
- **Anomaly Detection**:
    - Latency jumps (>50 ms) 🔴
    - Country transitions ✈️
    - ISP handoffs 🔄
- **VPN Comparison**:

1. Runs traceroute without VPN
2. Prompts you to connect VPN
3. Runs traceroute again
4. Lets you compare paths
- Works on **Ubuntu/Debian-based systems** with standard packages.

***

## Installation

### 1. Install required packages

```bash
sudo apt update
sudo apt install traceroute geoip-bin whois gawk coreutils bc
```


### 2. Download the script

Save it as `trace_investigator_vpn_compare.sh`.

### 3. Make it executable

```bash
chmod +x trace_investigator_vpn_compare.sh
```


***

## Usage

```bash
./trace_investigator_vpn_compare.sh
```


### Steps:

1. Enter your target domain or IP (e.g., `google.com`).
2. Script runs traceroute **without VPN** and narrates the route.
3. Script tells you to connect to your VPN.
4. Once connected, press Enter to continue.
5. Script runs traceroute **with VPN** and narrates that route.
6. Compare the two summaries to see routing differences.

***

## Example Output (Summarized)

**Without VPN:**

```
- First hop: Your local router
- Then into TR (Türk Telekom AS9121)
- International hop to US
- Destination reached: google.com
✅ Connection succeeded
```

**With VPN:**

```
- First hop: VPN gateway
- Into CZ (AS212238 - VPN provider)
- Handed to CDN77 (AS60068)
- Hop to US
- Destination reached: google.com
✅ Connection succeeded
```


***

## Interpreting Results

- **Different countries** in the two paths suggest geolocation masking via VPN.
- **Different ISPs or ASNs** highlight who handled your traffic in each mode.
- **Latency jumps** may indicate long-distance connections or congestion.
- If a site is reachable over VPN but **not** without VPN → possible ISP filtering/censorship.
- If certain hops only appear without VPN, they are likely ISP-internal devices.

***

## Limitations

- GeoIP \& ASN data depend on public databases — some private or internal IPs will show as "Unknown".
- Some routers don’t respond to traceroute (timeouts are normal).
- Latency detection is per single traceroute — use multiple runs for consistent evidence.
- This script does **not** decrypt or inspect packet content.

***

## License

MIT License — free to modify \& share.

