#!/usr/bin/env python3
"""Antibody CLI for a Binance Agentic Wallet. Standard library only; uses `cast` (Foundry) and `baw`.

Reads cost nothing and sign nothing:
  antibody.py check  <target>                 vote counts for a contract or address
  antibody.py whoami [address]                is this address Agent-ID-backed, and as which identity

Writes are previewed by the wallet, shown to you, and sent only after you type y. One tx per confirmation:
  antibody.py report <target> <verdict> [--evidence FILE] [--note TEXT]
  antibody.py retract <target>
  antibody.py link <wallet>                   step 1 of Agent Link, from the agentic wallet
                                              (step 2, acceptLink, is sent from <wallet> itself; this prints it)

Verdicts: safe honeypot rug drainer phishing

This tool never stores a session, never asks for a pairing code, a seed phrase or a key, and never batches.
"""
from __future__ import annotations
import argparse, hashlib, json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = json.load(open(os.path.join(HERE, "antibody.json")))
# Your own agentic wallet address goes in antibody.local.json (not committed): {"from": "0x..."}
_LOCAL = os.path.join(HERE, "antibody.local.json")
if os.path.exists(_LOCAL):
    CFG.update(json.load(open(_LOCAL)))
# Overrides for testing against a local fork (anvil); never needed in normal use.
CFG["rpc"] = os.environ.get("ANTIBODY_RPC", CFG["rpc"])
CFG["antibody"] = os.environ.get("ANTIBODY_ADDR", CFG.get("antibody"))
CHAIN_ID = str(CFG["chainId"])
RPC = CFG["rpc"]
BAW = next((p for p in map(os.path.expanduser, ["~/.hermes/node/bin/baw", "~/.local/bin/baw"]) if os.path.exists(p)), "baw")
CAST = next((p for p in map(os.path.expanduser, ["~/.foundry/bin/cast"]) if os.path.exists(p)), "cast")
VERDICTS = ["none", "safe", "honeypot", "rug", "drainer", "phishing"]
EVIDENCE_DIR = os.path.join(HERE, "evidence")


def die(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(1)


def antibody() -> str:
    a = CFG.get("antibody")
    if not a:
        die("Antibody is not deployed yet: set \"antibody\" in cli/antibody.json to the deployed address.")
    return a


def cast(*args: str) -> str:
    r = subprocess.run([CAST, *args], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        die(f"cast {args[0]} failed: {(r.stderr or r.stdout).strip()[:200]}")
    return r.stdout.strip()


def call(sig: str, *args: str) -> str:
    return cast("call", antibody(), sig, *args, "--rpc-url", RPC)


def baw(*args: str) -> dict:
    r = subprocess.run([BAW, *args, "--json"], capture_output=True, text=True, timeout=180)
    try:
        return json.loads(r.stdout)
    except Exception:
        return {"success": False, "error": {"message": (r.stdout or r.stderr)[:200]}}


def agent_wallet() -> str:
    w = CFG.get("from")
    if not w:
        die("put your agentic wallet address in cli/antibody.local.json as {\"from\": \"0x...\"}")
    return w


# ------------------------------------------------------------------ reads

def cmd_check(a) -> None:
    out = call("riskOf(address)(uint32[6],uint32)", a.target).splitlines()
    counts = [int(x) for x in out[0].strip("[]").split(",")]
    total = int(out[1])
    print(f"{a.target}   {total} Agent ID vote(s)")
    for i, n in enumerate(counts[1:], 1):
        if n:
            print(f"  {VERDICTS[i]:9} {n}")
    bad = sum(counts[2:])
    if total == 0:
        print("  no reports. Absence of reports is not evidence of safety.")
    elif bad > counts[1]:
        print("  WARNING: more identities report harm than report it safe")


def cmd_whoami(a) -> None:
    who = a.address or agent_wallet()
    ident = call("identityOf(address)(address)", who)
    if int(ident, 16) == 0:
        print(f"{who}  not Agent-ID-backed")
    elif ident.lower() == who.lower():
        print(f"{who}  holds an Agent ID")
    else:
        print(f"{who}  linked wallet, acts for identity {ident}")


# ------------------------------------------------------------------ writes

def send(data: str, what: str) -> None:
    """Preview with the wallet, refuse anything that is not a plain zero-value call to Antibody, ask, execute."""
    me, to = agent_wallet(), antibody()
    d = baw("contract-call", "preview", "--binanceChainId", CHAIN_ID, "--from", me, "--to", to,
            "--value", "0", "--inputData", data)
    if not d.get("success"):
        die(f"preview refused: {(d.get('error') or {}).get('message', '')}")
    x = d["data"]
    sim, rk = x.get("simulationResult") or {}, x.get("risks") or {}
    problems = [k for k in ("riskDetails", "riskBehaviors") if rk.get(k)]
    problems += [k for k in ("authorityChanges", "allowanceChanges", "simulationErrorDetail") if sim.get(k)]
    if sim.get("balanceChanges"):
        problems.append("balance changes (an Antibody call moves no assets)")
    if problems:
        die(f"preview carries {', '.join(problems)}; not sending")
    fee = x.get("networkFee") or x.get("gasFee") or "see wallet"
    print(f"\n  {what}\n  from {me}\n  to   {to} (Antibody)\n  value 0   fee {fee}\n  preview clean")
    if input("  sign and send this one transaction? [y/N] ").strip().lower() != "y":
        print("  not sent")
        return
    e = baw("contract-call", "execute", "--requestId", x["requestId"])
    if not e.get("success"):
        die(f"execute failed: {(e.get('error') or {}).get('message', '')}. Not retried.")
    ed = e.get("data") or {}
    print(f"  sent: {ed.get('txHash') or ed.get('hash') or ('order ' + str(ed.get('orderId')) + ' ' + str(ed.get('status', '')))}")


def evidence_hash(a) -> str:
    doc = {"target": a.target.lower(), "verdict": a.verdict, "note": a.note or "", "created": int(time.time())}
    if a.evidence:
        with open(a.evidence, "rb") as f:
            raw = f.read()
        try:
            doc["evidence"] = json.loads(raw)
        except ValueError:
            doc["evidence"] = raw.decode("utf-8", "replace")
    blob = json.dumps(doc, sort_keys=True, separators=(",", ":")).encode()
    h = hashlib.sha256(blob).hexdigest()
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    with open(os.path.join(EVIDENCE_DIR, f"{h}.json"), "wb") as f:
        f.write(blob)
    print(f"  evidence {h[:16]}…  saved to cli/evidence/{h}.json (publish it so others can check)")
    return "0x" + h


def cmd_report(a) -> None:
    v = a.verdict.lower()
    if v not in VERDICTS[1:]:
        die(f"verdict must be one of: {' '.join(VERDICTS[1:])}")
    a.verdict = v
    ev = evidence_hash(a)
    data = cast("calldata", "report(address,uint8,bytes32)", a.target, str(VERDICTS.index(v)), ev)
    send(data, f"report {a.target} as {v.upper()}")


def cmd_retract(a) -> None:
    send(cast("calldata", "retract(address)", a.target), f"retract your vote on {a.target}")


def cmd_link(a) -> None:
    send(cast("calldata", "offerLink(address)", a.wallet), f"offer Agent Link to {a.wallet}")
    accept = cast("calldata", "acceptLink(address)", agent_wallet())
    print(f"\n  Step 2, from {a.wallet} itself (not from here): call Antibody {antibody()}\n"
          f"  acceptLink({agent_wallet()})   calldata {accept}\n"
          "  e.g. BscScan > Contract > Write Contract > acceptLink, connected with that wallet.")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    p = sp.add_parser("check"); p.add_argument("target"); p.set_defaults(f=cmd_check)
    p = sp.add_parser("whoami"); p.add_argument("address", nargs="?"); p.set_defaults(f=cmd_whoami)
    p = sp.add_parser("report"); p.add_argument("target"); p.add_argument("verdict")
    p.add_argument("--evidence"); p.add_argument("--note"); p.set_defaults(f=cmd_report)
    p = sp.add_parser("retract"); p.add_argument("target"); p.set_defaults(f=cmd_retract)
    p = sp.add_parser("link"); p.add_argument("wallet"); p.set_defaults(f=cmd_link)
    a = ap.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
