# Antibody

**A scam registry for BNB Chain where every Agent ID holds exactly one vote.**

Live on BNB Chain: [`0x81f1A94Ad7E4d6f9a8c349f21E4749d694751F5B`](https://bscscan.com/address/0x81f1a94ad7e4d6f9a8c349f21e4749d694751f5b) (source verified)

Every Binance Agentic Wallet already simulates each transaction before it is signed. When that simulation shows a
honeypot, a drainer or a rug, the knowledge dies with the preview. Antibody lets the holder turn it into a public,
signed report, and lets any wallet, dApp, bot or AI agent read the result with a free view call before signing.

Crowd-sourced scam lists normally fail because one person can create a thousand addresses. Agent ID changes that:
one per Binance user, non-transferable. A thousand reports on Antibody means a thousand distinct users.

## How it works

| | |
|---|---|
| `report(target, verdict, evidence)` | Agent ID holder records SAFE / HONEYPOT / RUG / DRAINER / PHISHING. One vote per identity per target; a new report replaces the old one. `evidence` is the sha256 of the evidence document (wallet preview, tx hashes, notes). |
| `retract(target)` | Withdraws the vote. |
| `riskOf(target)` | Free read: vote counts per verdict and the total. |
| `respond(target, evidence)` | The target's `owner()` publishes counter-evidence. Renounced contracts cannot respond, which is itself visible. |
| `offerLink(wallet)` / `acceptLink(identity)` / `unlink()` | **Agent Link.** The agentic wallet cannot connect to dApps; this lets it name one ordinary wallet that acts for the same identity. Two signatures, either side can end it, never a second vote. |
| `isAgentBacked(addr)` / `identityOf(addr)` | Other contracts can gate on Agent ID through a linked wallet too. Returns an address or a boolean, never a name. |

Counts on-chain are unweighted. A reputation score (reporters whose verdicts were later confirmed on-chain, e.g. the
liquidity really was pulled, the sell really reverted) is computed off-chain from the events and is advisory only.

## Permissions (required disclosure)

**None.** No owner, admin, pauser, upgrade proxy, fee, token, mint, tax, freeze or withdrawal. The contract holds no
funds and cannot move anyone's assets. Every state change is made by an address for itself. The deployer gets no
privileges.

## Hackathon safety rules: how this complies

- No web QR or pairing-code login, no server-side sessions: the CLI drives the user's own local `baw` session.
- No bypassing confirmation: every write is previewed and sent only after the user types `y`; one tx per yes; the
  skill forbids answering prompts on the user's behalf.
- No transfers, approvals or value: every call is `value 0`; the CLI refuses a preview with any balance, allowance or
  authority change.
- Open source, verified, permissions documented (above).
- No name-to-wallet lookups: the registry is about contracts; Agent Link answers "is this address backed", not "whose".
- No promised returns, no token.
- Not named after Binance or BNB.

## Layout

```
src/Antibody.sol            the contract
test/Antibody.t.sol         16 unit tests (mock Agent ID), offline, zero dependencies
test/fork/                  tests against the live Agent ID contract on BNB Chain
script/Deploy.s.sol         deployment
cli/antibody.py             check / whoami / report / retract / link (stdlib + cast + baw)
skill/antibody/SKILL.md     agent skill: check before signing, offer to report after a bad preview
```

## Run

```bash
forge test                              # offline unit tests
FOUNDRY_PROFILE=fork forge test         # against BNB Chain mainnet state
python3 cli/antibody.py check <address>
```

Deploy with an encrypted keystore (never a key in an environment variable):

```bash
FOUNDRY_PROFILE=fork forge script script/Deploy.s.sol --rpc-url bsc --account <keystore-name> --broadcast
```

Then set `"antibody"` in `cli/antibody.json` and verify the source on BscScan.

To use the CLI with your own agentic wallet, create `cli/antibody.local.json` (git-ignored):

```json
{"from": "0xYourAgenticWallet"}
```

Agent ID contract: `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (from the Agent ID Hackathon announcement).
