#!/usr/bin/env python3
"""Vouchsafe Shield indexer. Standard library only, no key, signs nothing: it only reads public events.

Reads every Shield event since the last run, replays them into current votes, and writes docs/data.json,
which the public page loads. Safe to run repeatedly; each run continues from the last indexed block.

  python3 indexer/index.py                 # BNB Chain mainnet, the deployed contract
  VOUCHSAFE_RPC=http://127.0.0.1:8545 VOUCHSAFE_SHIELD=0x... VOUCHSAFE_FROM_BLOCK=0 python3 indexer/index.py --out /tmp/x.json

Reputation here is v1 and advisory: a target is "settled" once at least 3 identities have voted and at least
two thirds of them agree on SAFE vs harmful. A reporter gains a point for each settled target they called the
same way, and loses one for each they called the other way. Outcome checks (did the liquidity really go, did the
sell really revert) are planned and are not part of this score yet.
"""
from __future__ import annotations
import argparse, json, os, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = json.load(open(os.path.join(ROOT, "cli", "vouchsafe.json")))
RPC = os.environ.get("VOUCHSAFE_RPC", CFG["rpc"])
ADDR = os.environ.get("VOUCHSAFE_SHIELD", CFG["shield"]).lower()
FROM_BLOCK = int(os.environ.get("VOUCHSAFE_FROM_BLOCK", CFG.get("deployedBlock", 0)))
if not ADDR.startswith("0x") or len(ADDR) != 42:
    sys.exit(f"bad Shield address {ADDR!r}")
SPAN = 50_000            # publicnode's maximum block range per eth_getLogs
CONFIRMATIONS = 3        # stay a few blocks behind the head so reorgs do not leave ghosts

VERDICTS = ["NONE", "SAFE", "HONEYPOT", "RUG", "DRAINER", "PHISHING"]
# keccak256 of each event signature (enums are uint8 in the ABI)
T_REPORTED = "0x8220a4ede788c7fe86843bae980fca67b06a8209c4b1987153da643b2d1a7bee"   # Reported(address,address,uint8,uint8,bytes32)
T_RESPONDED = "0x8e82bed75391582864a87043fa1ad14d3cfbfe3182dd3bb34f2d05680a46585b"  # Responded(address,address,bytes32)
T_OFFERED = "0x98b1cb69d282a8b071b735521345a5ce14fab51880986bc5087cf930807d883e"    # LinkOffered(address,address)
T_LINKED = "0x5febe1b9e375a634d9d565149e636879057714c557b8c78aab7cccae8cf48e48"     # Linked(address,address)
T_UNLINKED = "0x2907c66279ef6379e65c015c50c76fa0554a6bd8cd1c5614353d64517e279e14"   # Unlinked(address,address)
SEL_NAME, SEL_SYMBOL = "0x06fdde03", "0x95d89b41"


def rpc(method: str, params: list, tries: int = 4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(tries):
        try:
            req = urllib.request.Request(RPC, body, {"content-type": "application/json", "user-agent": "vouchsafe-indexer"})
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.load(r)
            if "error" in d:
                raise RuntimeError(d["error"].get("message", str(d["error"])))
            return d["result"]
        except Exception as e:
            if i == tries - 1:
                raise
            time.sleep(2 * (i + 1))


def addr(word: str) -> str:
    return "0x" + word[-40:].lower()


def decode_string(ret: str) -> str | None:
    """ABI string or bytes32 return value -> short printable text. Token names are untrusted display data."""
    try:
        b = bytes.fromhex(ret[2:])
        if len(b) >= 64:
            off = int.from_bytes(b[:32], "big")
            n = int.from_bytes(b[off:off + 32], "big")
            s = b[off + 32:off + 32 + n].decode("utf-8", "replace")
        elif len(b) == 32:
            s = b.rstrip(b"\0").decode("utf-8", "replace")
        else:
            return None
    except Exception:
        return None
    s = "".join(ch for ch in s if ch.isprintable()).strip()
    return s[:40] or None


def label(target: str) -> dict:
    code = rpc("eth_getCode", [target, "latest"])
    info = {"isContract": code not in ("0x", "0x0", None)}
    if info["isContract"]:
        for key, sel in (("name", SEL_NAME), ("symbol", SEL_SYMBOL)):
            try:
                info[key] = decode_string(rpc("eth_call", [{"to": target, "data": sel}, "latest"], tries=1))
            except Exception:
                info[key] = None
    return info


def fetch(lo: int, hi: int) -> list:
    out = []
    while lo <= hi:
        top = min(lo + SPAN - 1, hi)
        out += rpc("eth_getLogs", [{"address": ADDR, "fromBlock": hex(lo), "toBlock": hex(top)}])
        lo = top + 1
    return out


def parse(log: dict) -> dict | None:
    t, data = log["topics"], log["data"][2:]
    words = [data[i:i + 64] for i in range(0, len(data), 64)]
    base = {"block": int(log["blockNumber"], 16), "tx": log["transactionHash"], "logIndex": int(log["logIndex"], 16)}
    k = t[0].lower()
    if k == T_REPORTED:
        return {**base, "type": "report", "target": addr(t[1]), "identity": addr(t[2]),
                "verdict": VERDICTS[int(words[0], 16)], "previous": VERDICTS[int(words[1], 16)], "evidence": "0x" + words[2]}
    if k == T_RESPONDED:
        return {**base, "type": "response", "target": addr(t[1]), "responder": addr(t[2]), "evidence": "0x" + words[0]}
    if k in (T_OFFERED, T_LINKED, T_UNLINKED):
        return {**base, "type": {T_OFFERED: "linkOffered", T_LINKED: "linked", T_UNLINKED: "unlinked"}[k],
                "identity": addr(t[1]), "wallet": addr(t[2])}
    return None


def harmful(v: str) -> bool:
    return v not in ("NONE", "SAFE")


def build(events: list, labels: dict) -> dict:
    votes: dict[str, dict[str, str]] = {}    # target -> identity -> verdict
    last: dict[str, int] = {}
    responses: dict[str, list] = {}
    links = {}
    for e in events:
        if e["type"] == "report":
            tv = votes.setdefault(e["target"], {})
            if e["verdict"] == "NONE":
                tv.pop(e["identity"], None)
            else:
                tv[e["identity"]] = e["verdict"]
            last[e["target"]] = e["block"]
        elif e["type"] == "response":
            responses.setdefault(e["target"], []).append({"evidence": e["evidence"], "block": e["block"], "tx": e["tx"]})
        elif e["type"] == "linked":
            links[e["identity"]] = e["wallet"]
        elif e["type"] == "unlinked":
            links.pop(e["identity"], None)

    targets, reporters = {}, {}
    for tgt, tv in votes.items():
        counts = [0] * len(VERDICTS)
        for v in tv.values():
            counts[VERDICTS.index(v)] += 1
        total = sum(counts)
        bad = total - counts[1]
        consensus = None
        if total >= 3:
            if bad * 3 >= total * 2:
                consensus = "HARMFUL"
            elif counts[1] * 3 >= total * 2:
                consensus = "SAFE"
        targets[tgt] = {"counts": counts, "total": total, "harmful": bad, "consensus": consensus,
                        "lastBlock": last.get(tgt), "responses": responses.get(tgt, []), **labels.get(tgt, {})}
        for ident, v in tv.items():
            r = reporters.setdefault(ident, {"votes": 0, "agree": 0, "disagree": 0})
            r["votes"] += 1
            if consensus:
                r["agree" if harmful(v) == (consensus == "HARMFUL") else "disagree"] += 1
    for tgt, rs in responses.items():   # a target can respond before anyone has voted on it
        targets.setdefault(tgt, {"counts": [0] * len(VERDICTS), "total": 0, "harmful": 0, "consensus": None,
                                 "lastBlock": None, "responses": rs, **labels.get(tgt, {})})
    for r in reporters.values():
        r["score"] = r["agree"] - r["disagree"]
    return {"targets": targets, "reporters": reporters, "linkedWallets": len(links)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "data.json"))
    ap.add_argument("--full", action="store_true", help="ignore the previous snapshot and re-read from the deploy block")
    a = ap.parse_args()

    prev = {}
    if not a.full and os.path.exists(a.out):
        prev = json.load(open(a.out))
        if (prev.get("contract") or "").lower() != ADDR:
            prev = {}
    events = prev.get("events", [])
    labels = prev.get("labels", {})
    times = prev.get("blockTimes", {})
    start = prev.get("lastBlock", FROM_BLOCK - 1) + 1

    head = int(rpc("eth_blockNumber", []), 16) - CONFIRMATIONS
    new = []
    if start <= head:
        new = [p for p in map(parse, fetch(start, head)) if p]
        new.sort(key=lambda e: (e["block"], e["logIndex"]))
    for e in new:
        if str(e["block"]) not in times:
            times[str(e["block"])] = int(rpc("eth_getBlockByNumber", [hex(e["block"]), False])["timestamp"], 16)
        e["time"] = times[str(e["block"])]
        if e.get("target") and e["target"] not in labels:
            labels[e["target"]] = label(e["target"])
    events += new

    snap = {"contract": ADDR, "chainId": CFG["chainId"], "deployedBlock": FROM_BLOCK,
            "lastBlock": max(head, start - 1), "updatedAt": int(time.time()), "verdicts": VERDICTS,
            "events": events, "labels": labels, "blockTimes": times, **build(events, labels)}
    snap["stats"] = {"reports": sum(1 for e in events if e["type"] == "report" and e["verdict"] != "NONE"),
                     "identities": len(snap["reporters"]), "targets": len(snap["targets"]),
                     "linkedWallets": snap["linkedWallets"]}
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    tmp = a.out + ".tmp"
    with open(tmp, "w") as f:
        json.dump(snap, f, separators=(",", ":"))
    os.replace(tmp, a.out)
    print(f"indexed to block {snap['lastBlock']}: +{len(new)} event(s), {snap['stats']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
