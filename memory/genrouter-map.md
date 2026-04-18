# Genrouter Memory

## Core workflow
- For this device fleet, prefer the source/config and actual controller mapping over ad-hoc guesses.
- Normal work is usually done by accessing each phone/device via its XXTouch web endpoint (`http://IP:46952/`).
- SSH is only for deeper repair/recovery when needed.

## Cluster mapping rules
### Tiktok 04
- Gateway/local: `192.16.0.1`
- Machines 1 -> 250 => `192.16.4.1` -> `192.16.4.250`
- Machines 251 -> 450 => `192.16.5.1` -> `192.16.5.200`

Formula:
- If machine N is between 1 and 250: `192.16.4.N`
- If machine N is between 251 and 450: `192.16.5.(N-250)`

Examples:
- Machine 38 => `192.16.4.38`
- Machine 184 => `192.16.4.184`
- Machine 251 => `192.16.5.1`

## Special / frequently referenced machines
### Tiktok 04
- Machine 38
  - Expected IP by cluster mapping: `192.16.4.38`
  - Recent context: this machine was discussed for data-loss recovery, jailbreak/Sileo/OpenSSH recovery, and XXTouch web access checks.
- Machine 184
  - Expected IP by cluster mapping: `192.16.4.184`
  - Recent context: target machine mentioned for replacing/overlaying the localized `web/` files.

### Tiktok 03
- Gateway/local: `192.14.0.1`
- Machines 1 -> 250 => `192.14.5.1` -> `192.14.5.250`
- Machines 251 -> 312 => `192.14.4.1` -> `192.14.4.62`

Formula:
- If machine N is between 1 and 250: `192.14.5.N`
- If machine N is between 251 and 312: `192.14.4.(N-250)`

### Tiktok 05
- Gateway/local: `192.15.0.1`
- Machines 1 -> 250 => `192.15.4.1` -> `192.15.4.250`
- Machines 251 -> 312 => `192.15.5.1` -> `192.15.5.62`

Formula:
- If machine N is between 1 and 250: `192.15.4.N`
- If machine N is between 251 and 312: `192.15.5.(N-250)`

## Important reminder
- Do not confuse one-off example endpoints with the general cluster mapping unless the user explicitly says source/config overrides the formula.
- When asked for a machine IP by cluster number, use the cluster formulas above first.
