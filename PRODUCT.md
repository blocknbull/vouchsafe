# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Static HTML/CSS/JS in `docs/`, served by GitHub Pages; no build step and no framework. Solidity contracts built and tested with Foundry. Python standard library for the indexer and CLI.

## Users

Primary: everyday BNB Chain users who hold a Binance Agent ID (a `name.ai`, one per Binance user, non-transferable, held in their Agentic Wallet). They are about to sign something — a mint, a claim, a swap, an approval — and want to know whether other real people have flagged the contract. Their agents (Binance Agentic Wallet skills) act for them and must always ask before signing.

Secondary: BSC project teams running airdrops (Sift), and people or agents who want to hire or be hired for small on-chain tasks (Errands). Hackathon judges read the same site.

## Product Purpose

Vouchsafe turns Agent ID into trust tools for BNB Chain. Because each Binance user holds exactly one Agent ID and cannot transfer it, an Agent ID is a scarce, sybil-resistant identity. Vouchsafe builds three products on that one fact:

- **Shield** (live): a scam registry where every Agent ID holds one vote per address — SAFE, HONEYPOT, RUG, DRAINER or PHISHING — with evidence hashes, owner responses and free reads before signing.
- **Sift** (live): an airdrop filter. A team pastes a list of claim addresses and learns, per address, a plain yes or no: is it backed by a real Agent ID, and do two addresses belong to the same identity (holder plus linked wallet). It never reveals names.
- **Errands** (live since 2026-11-21 at 0x8e2B9dc9347F0210C6D9c3f786eC7Ab0730d9203, verified): an agent job board. A poster's agent posts a task with payment held in escrow; another Agent ID holder's agent completes it; release builds reputation tied to Agent IDs.

Success: Agent ID holders interact with the contracts (the hackathon's Pioneer track ranks by distinct interacting holders; the Innovation track needs at least 30), and readers trust the tools enough to check before signing.

## Positioning

Crowd-sourced scam lists, airdrop sybil filters and job boards all exist, and all fail the same way: one person can make a thousand wallets. Vouchsafe's mechanism is that every vote, every eligibility check and every reputation point is anchored to an Agent ID, which a person cannot multiply. A neighbouring product without Agent ID cannot truthfully claim "one real user, one voice".

## Operating Context

- Users arrive from X posts, the hackathon listing, or a shared result link (`?a=0x…`).
- Checking is free (eth_call from the browser against a public BSC RPC). Writing (report, link, post or accept an errand) happens through the user's own Binance Agentic Wallet, previewed and confirmed per transaction, via the `cli/` tool or the agent skill in `skill/`.
- Agentic wallets cannot connect to dApps; Agent Link lets one ordinary wallet act for the identity.
- Data: on-chain events indexed every 15 minutes into `docs/data.json`; the page reads newer events live.

## Capabilities and Constraints

- Shield contract live at `0x81f1A94Ad7E4d6f9a8c349f21E4749d694751F5B` (BSC, verified, deployed source named `Antibody.sol` — the product's earlier name). No owner, admin, upgrade, fee, token or withdrawal.
- Agent ID contract: `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`; check with `balanceOf > 0`.
- Hackathon red lines (binding): no web QR or pairing-code login; no server-side wallet sessions; nothing that bypasses per-transaction user confirmation; no automatic transfers or unlimited approvals; open-source verified contracts with documented permissions; no "Binance" or "BNB" in product, token or domain names; Agent ID must not become a tool for looking up other people's wallets by name; no promised returns; trading products show risk warnings.
- Sift is free, runs in the browser, and shows no pricing.
- Errands holds user funds in escrow; it shipped after 27 unit tests, a 5,000-run conservation fuzz, live fork tests and an independent adversarial review (no critical/high). Rewards are capped at 1 BNB per errand, a constant.

## Brand Commitments

- Name: Vouchsafe (archaic verb: to grant as a guarantee). Products: Shield, Sift, Errands. Chosen 2026-11-20 after "Antibody", "Tessera" and "Sigil" were ruled out (rename requested; the latter two collide with other crypto projects).
- Voice: plain, direct, honest about limits ("no reports is not evidence of safety"). Never hype, never promise earnings.
- Must not use Binance or BNB in the brand; refer to "BNB Chain" and "Binance Agent ID" only descriptively.
- The user asked for a premium hero: premium fonts, distinct sections, transitions.

## Evidence on Hand

- Live, verified Shield contract and public repo `github.com/blocknbull/vouchsafe`.
- 16 unit tests plus fork tests against the live Agent ID contract.
- No real reports yet (all live counts are 0). No users, testimonials, partners, audits or press exist — never fabricate them. Demo data exists only on local anvil (`script/dev/SeedLocal.s.sol`).

## Product Principles

1. One real person, one voice: every count and score is anchored to an Agent ID.
2. The user signs every write; Vouchsafe never signs, batches or stores sessions.
3. Say what a signal does not prove as clearly as what it does.
4. Addresses, never names: no feature reveals who owns a wallet.
5. Free to read, cheap to contribute.

## Accessibility & Inclusion

Readable on phones (most traffic from X), respects reduced-motion, WCAG AA contrast in both light and dark themes.
