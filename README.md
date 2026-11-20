# Vouchsafe

**Trust tools for BNB Chain where one Agent ID is one voice.**

Site: **https://blocknbull.github.io/vouchsafe/**

A Binance Agent ID (`name.ai`) is one per Binance user and cannot be transferred. That makes it the first identity on
BNB Chain that a person cannot multiply. Vouchsafe builds three products on that single fact:

| | What it does | Status |
|---|---|---|
| **Shield** | Scam registry. Every Agent ID holds one vote per address: SAFE, HONEYPOT, RUG, DRAINER or PHISHING. Free reads before signing. | Live, [`0x81f1…1F5B`](https://bscscan.com/address/0x81f1a94ad7e4d6f9a8c349f21e4749d694751f5b#code) (verified) |
| **Sift** | Airdrop filter. Paste a claim list; each address comes back *backed by a real Agent ID* or *not*, and two addresses of the same holder are flagged. Yes or no, never who. | Live, in the browser |
| **Errands** | Agent job board. A poster's agent locks a reward in escrow, another Agent ID holder's agent does the task, release builds reputation tied to Agent IDs. | In build, live before 2026-12-09 |

## Shield

| | |
|---|---|
| `report(target, verdict, evidence)` | Agent ID holder records a verdict. One vote per identity per target; a new report replaces the old one. `evidence` is the sha256 of the evidence document (wallet preview, tx hashes, notes). |
| `retract(target)` | Withdraws the vote. |
| `riskOf(target)` | Free read: vote counts per verdict and the total. |
| `respond(target, evidence)` | The target's `owner()` publishes counter-evidence. Renounced contracts cannot respond, which is itself visible. |
| `offerLink(wallet)` / `acceptLink(identity)` / `unlink()` | **Agent Link.** The agentic wallet cannot connect to dApps; this lets it name one ordinary wallet that acts for the same identity. Two signatures, either side can end it, never a second vote. |
| `isAgentBacked(addr)` / `identityOf(addr)` | Other contracts (and Sift) can check Agent ID through a linked wallet too. Returns an address or a boolean, never a name. |

The Shield contract was deployed under the project's first name, so its verified source is `src/Antibody.sol`.

Counts on-chain are unweighted. The reporter score on the site (+1 for each settled address called the same way as the
majority, −1 the other way) is computed off-chain from events and is advisory only.

## Sift

Runs entirely in the visitor's browser: it batches `identityOf(address)` calls (200 per JSON-RPC request) against
Shield on a public BSC RPC. For each address: *backed* when `identityOf` is non-zero; *same holder* when two addresses
on the list return the same identity (a holder and their linked wallet). The output CSV has
`address,agent_backed,same_holder_as` and no identity or name column. Nothing is uploaded anywhere. Free.

## Errands (in build)

Planned contract, one escrow per errand, BNB only:

1. **Post**: the poster's identity posts a task hash, a deadline and the reward as `msg.value`. Cancel for a full refund until taken.
2. **Take**: one Agent ID holder (or their linked wallet) accepts. Never the poster's own identity.
3. **Deliver**: the worker submits a result hash before the deadline.
4. **Release**: the poster releases to the worker. If the poster is silent for a review window after delivery, the worker can claim. No delivery by the deadline: the poster reclaims.

No owner, admin, fee or token; funds can only go to the worker or back to the poster. Completions are counted per
Agent ID identity, so reputation can't be farmed with fresh wallets.

## Permissions (required disclosure)

**Shield: none.** No owner, admin, pauser, upgrade proxy, fee, token, mint, tax, freeze or withdrawal. The contract
holds no funds and cannot move anyone's assets. The deployer has no privileges.

## Hackathon safety rules: how this complies

- No web QR or pairing-code login, no server-side sessions: the CLI drives the user's own local `baw` session.
- No bypassing confirmation: every write is previewed and sent only after the user types `y`; one tx per yes.
- No transfers, approvals or value in Shield; the CLI refuses any preview with balance, allowance or authority changes.
- Open source, verified, permissions documented.
- No name-to-wallet lookups: Shield is about contracts, Sift answers yes/no, Agent Link answers "is this backed".
- No promised returns, no token. Not named after Binance or BNB.

## Layout

```
src/Antibody.sol            Shield contract (deployed name)
test/Antibody.t.sol         16 unit tests (mock Agent ID), offline, zero dependencies
test/fork/                  tests against the live Agent ID contract on BNB Chain
script/Deploy.s.sol         deployment
script/dev/SeedLocal.s.sol  demo data on a local anvil node, for developing the site
cli/vouchsafe.py            check / whoami / report / retract / link (stdlib + cast + baw)
skill/vouchsafe/SKILL.md    agent skill: check before signing, offer to report after a bad preview
indexer/index.py            reads Shield events into docs/data.json (stdlib; a GitHub Action runs it every 15 min)
docs/index.html             the site: Shield lookup, Sift, Errands
PRODUCT.md                  product record
```

## Run

```bash
forge test                              # offline unit tests
FOUNDRY_PROFILE=fork forge test         # against BNB Chain mainnet state
python3 cli/vouchsafe.py check <address>
```

To use the CLI with your own agentic wallet, create `cli/vouchsafe.local.json` (git-ignored):

```json
{"from": "0xYourAgenticWallet"}
```

Agent ID contract: `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (from the Agent ID Hackathon announcement).
Not affiliated with Binance.
