---
name: vouchsafe
description: Check any BNB Chain contract against Vouchsafe Shield, the one-vote-per-Agent-ID scam registry, before signing a transaction to it; and, after a wallet preview reveals a honeypot, rug, drainer or phishing contract, offer to file a report. Use alongside binance-agentic-wallet whenever a contract-call, swap, mint, claim or approval is about to be signed, or when the user asks "is this contract safe", "report this scam", "check this token", or "link my wallet".
---

# Vouchsafe Shield

Shield (Vouchsafe's scam registry) is an on-chain registry on BNB Chain. Each Agent ID holder has one vote per target address:
`SAFE`, `HONEYPOT`, `RUG`, `DRAINER` or `PHISHING`. Because an Agent ID cannot be transferred and each user
holds one, the counts reflect distinct real users rather than fresh addresses.

Config: `cli/vouchsafe.json` (deployed address, the user's agentic wallet). CLI: `python3 cli/vouchsafe.py`.

## Before signing anything (read-only, always allowed)

Before any `contract-call execute`, swap, mint, claim or approval to an address the user has not used before:

1. Run `vouchsafe.py check <to-address>` (a free eth_call).
2. Show the user the counts in one line. If harm reports outnumber SAFE, say so plainly before they decide.
3. Zero reports means nothing is known. Say "no reports", never "safe".

Checking never blocks or alters the user's transaction. The decision stays theirs.

## After a preview reveals harm (propose, never send unasked)

When a wallet preview or simulation shows a sell that reverts, a balance change larger than the call implies, an
unexpected approval or authority change, or a contract impersonating another project:

1. Tell the user what the preview showed.
2. Offer to report it: "Report <address> as HONEYPOT to Vouchsafe Shield? It costs about $0.01 of gas."
3. Only on an explicit yes, save the preview output to a file and run
   `vouchsafe.py report <address> <verdict> --evidence <file>`. The CLI previews the report itself and asks again
   before signing. That second confirmation is the user's, not yours.

## Hard rules

- One transaction per confirmation. Never batch reports, never schedule them, never report on a timer.
- Never answer the wallet's confirmation prompt on the user's behalf, and never pipe `y` into the CLI.
- Never ask for, store or forward a pairing code, QR code, seed phrase, private key or API secret. Never keep a
  wallet session on a server.
- Report contracts and scam addresses, never people. Do not use Shield, Sift, Agent Link or Agent ID to look up who
  owns a wallet or which wallet belongs to a name.
- A verdict is the user's own judgement backed by evidence. Never file a verdict the user did not choose, and never
  report a contract to harm a competitor.
- Shield holds no funds and has no token. Do not describe reporting as earning anything.

## Agent Link

The agentic wallet cannot connect to dApps. `vouchsafe.py link <wallet>` sends step 1 (`offerLink`) from the agentic
wallet; the user then sends step 2 (`acceptLink`) from the ordinary wallet themselves, for example on BscScan.
Either side can end it with `unlink()`. A linked wallet acts for the same identity and never adds a second vote.
