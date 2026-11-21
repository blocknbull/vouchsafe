#!/usr/bin/env python3
"""Vouchsafe CLI (Shield) for a Binance Agentic Wallet. Standard library only; uses `cast` (Foundry) and `baw`.

Reads cost nothing and sign nothing:
  vouchsafe.py check  <target>                 vote counts for a contract or address
  vouchsafe.py whoami [address]                is this address Agent-ID-backed, and as which identity

Writes are previewed by the wallet, shown to you, and sent only after you type y. One tx per confirmation:
  vouchsafe.py report <target> <verdict> [--evidence FILE] [--note TEXT]
  vouchsafe.py retract <target>
  vouchsafe.py link <wallet>                   step 1 of Agent Link, from the agentic wallet
                                              (step 2, acceptLink, is sent from <wallet> itself; this prints it)

Verdicts: safe honeypot rug drainer phishing

Errands (the escrow job board). Reads are free:
  vouchsafe.py errand list [--last N]          recent errands
  vouchsafe.py errand show <id>                one errand in full
  vouchsafe.py errand record [address]         an identity's public record
Writes, one confirmed transaction each:
  vouchsafe.py errand post --reward 0.01 --deadline 3d --review 1d --task "text" | --task-file FILE [--assignee 0x..]
  vouchsafe.py errand take <id>
  vouchsafe.py errand deliver <id> --result "text" | --result-file FILE
  vouchsafe.py errand release|reject|claim|reclaim|cancel <id>
  vouchsafe.py errand withdraw [--to 0x..]

This tool never stores a session, never asks for a pairing code, a seed phrase or a key, and never batches.
"""
from __future__ import annotations
import argparse, hashlib, json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = json.load(open(os.path.join(HERE, "vouchsafe.json")))
# Your own agentic wallet address goes in vouchsafe.local.json (not committed): {"from": "0x..."}
_LOCAL = os.path.join(HERE, "vouchsafe.local.json")
if os.path.exists(_LOCAL):
    CFG.update(json.load(open(_LOCAL)))
# Overrides for testing against a local fork (anvil); never needed in normal use.
CFG["rpc"] = os.environ.get("VOUCHSAFE_RPC", CFG["rpc"])
CFG["shield"] = os.environ.get("VOUCHSAFE_SHIELD", CFG.get("shield"))
CFG["errands"] = os.environ.get("VOUCHSAFE_ERRANDS", CFG.get("errands"))
CHAIN_ID = str(CFG["chainId"])
RPC = CFG["rpc"]
BAW = next((p for p in map(os.path.expanduser, ["~/.hermes/node/bin/baw", "~/.local/bin/baw"]) if os.path.exists(p)), "baw")
# Testing only: a stand-in wallet tool and sender for a local chain. Never set these in normal use.
BAW = os.environ.get("VOUCHSAFE_BAW", BAW)
if os.environ.get("VOUCHSAFE_FROM"):
    CFG["from"] = os.environ["VOUCHSAFE_FROM"]
CAST = next((p for p in map(os.path.expanduser, ["~/.foundry/bin/cast"]) if os.path.exists(p)), "cast")
VERDICTS = ["none", "safe", "honeypot", "rug", "drainer", "phishing"]
EVIDENCE_DIR = os.path.join(HERE, "evidence")
ERRAND_DIR = os.path.join(HERE, "errands")
NATIVE = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
STATUS = ["none", "open", "taken", "delivered", "paid", "rejected", "refunded", "cancelled"]
ERRAND_T = "(address,address,address,address,address,uint96,uint40,uint40,uint32,uint8,bytes32,bytes32)"


def die(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(1)


def shield() -> str:
    a = CFG.get("shield")
    if not a:
        die("Shield is not deployed yet: set \"shield\" in cli/vouchsafe.json to the deployed address.")
    return a


def cast(*args: str) -> str:
    r = subprocess.run([CAST, *args], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        die(f"cast {args[0]} failed: {(r.stderr or r.stdout).strip()[:200]}")
    return r.stdout.strip()


def call(sig: str, *args: str) -> str:
    return cast("call", shield(), sig, *args, "--rpc-url", RPC)


def baw(*args: str) -> dict:
    r = subprocess.run([BAW, *args, "--json"], capture_output=True, text=True, timeout=180)
    try:
        return json.loads(r.stdout)
    except Exception:
        return {"success": False, "error": {"message": (r.stdout or r.stderr)[:200]}}


def agent_wallet() -> str:
    w = CFG.get("from")
    if not w:
        die("put your agentic wallet address in cli/vouchsafe.local.json as {\"from\": \"0x...\"}")
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

def _native(change: dict) -> bool:
    fields = [str(v).lower() for v in change.values() if isinstance(v, str)]
    return NATIVE in fields or any("native" in f for f in fields) or str(change.get("symbol", "")).upper() == "BNB"


def _sign(change: dict) -> int:
    for k in ("change", "amount", "delta", "value"):
        if k in change and change[k] not in (None, ""):
            v = str(change[k]).strip()
            return -1 if v.startswith("-") else (0 if v in ("0", "0.0") else 1)
    return 0


def send(data: str, what: str, to: str | None = None, label: str = "Shield", value_wei: int = 0, expect: str = "none") -> None:
    """Preview with the wallet, refuse anything outside what this call should do, show it, ask, then execute.

    expect: "none" = no balance may change; "out" = only BNB may leave (the escrowed reward);
            "in" = only BNB may arrive (a refund or payment). Allowance or authority changes are always refused.
    """
    me, to = agent_wallet(), (to or shield())
    d = baw("contract-call", "preview", "--binanceChainId", CHAIN_ID, "--from", me, "--to", to,
            "--value", str(value_wei), "--inputData", data)
    if not d.get("success"):
        die(f"preview refused: {(d.get('error') or {}).get('message', '')}")
    x = d["data"]
    sim, rk = x.get("simulationResult") or {}, x.get("risks") or {}
    problems = [k for k in ("riskDetails", "riskBehaviors") if rk.get(k)]
    problems += [k for k in ("authorityChanges", "allowanceChanges", "simulationErrorDetail") if sim.get(k)]
    changes = sim.get("balanceChanges") or []
    for c in changes:
        if not _native(c):
            problems.append(f"a non-BNB balance change ({json.dumps(c)[:80]})")
        elif expect == "none":
            problems.append("a BNB balance change on a call that should move none")
        elif expect == "out" and _sign(c) > 0:
            problems.append("BNB arriving on a call that should only send the reward")
        elif expect == "in" and _sign(c) < 0:
            problems.append("BNB leaving on a call that should only pay you")
    if problems:
        die(f"preview carries {'; '.join(problems)}; not sending")
    fee = x.get("networkFee") or x.get("gasFee") or "see wallet"
    bnb = f"{value_wei / 1e18:.6g} BNB" if value_wei else "0"
    print(f"\n  {what}\n  from {me}\n  to   {to} ({label})\n  value {bnb}   fee {fee}")
    for c in changes:
        print(f"  wallet preview: {json.dumps(c)[:140]}")
    print("  preview clean")
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
    print(f"\n  Step 2, from {a.wallet} itself (not from here): call Shield {shield()}\n"
          f"  acceptLink({agent_wallet()})   calldata {accept}\n"
          "  e.g. BscScan > Contract > Write Contract > acceptLink, connected with that wallet.")


# ------------------------------------------------------------------ errands

def errands() -> str:
    a = CFG.get("errands")
    if not a:
        die("Errands address missing: set \"errands\" in cli/vouchsafe.json.")
    return a


def ecall(sig: str, *args: str) -> str:
    return cast("call", errands(), sig, *args, "--rpc-url", RPC)


def _split_top(s: str) -> list[str]:
    s = s.strip()
    if s.startswith("(") and s.endswith(")"):
        s = s[1:-1]
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur.strip()); cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())
    return [p.split(" [")[0] for p in parts]


def get_errand(i: int) -> dict:
    f = _split_top(ecall(f"errand(uint256)({ERRAND_T})", str(i)))
    if len(f) != 12:
        die(f"could not read errand #{i} (got {len(f)} fields)")
    keys = ["poster", "funder", "worker", "payee", "assignee", "reward", "deadline", "deliveredAt", "reviewWindow", "status", "task", "result"]
    e = dict(zip(keys, f))
    for k in ("reward", "deadline", "deliveredAt", "reviewWindow", "status"):
        e[k] = int(e[k])
    e["id"] = i
    return e


def _when(ts: int) -> str:
    return time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(ts)) if ts else "-"


def _zero(a: str) -> bool:
    return int(a, 16) == 0


def print_errand(e: dict) -> None:
    st = STATUS[e["status"]]
    print(f"errand #{e['id']}   {st.upper()}   reward {e['reward'] / 1e18:.6g} BNB")
    print(f"  poster    {e['poster']}   (funded by {e['funder']})")
    if not _zero(e["assignee"]):
        print(f"  assignee  {e['assignee']}")
    if not _zero(e["worker"]):
        print(f"  worker    {e['worker']}   (paid to {e['payee']})")
    print(f"  deadline  {_when(e['deadline'])}   review window {e['reviewWindow'] // 3600} h")
    if e["deliveredAt"]:
        print(f"  delivered {_when(e['deliveredAt'])}   claimable after {_when(e['deliveredAt'] + e['reviewWindow'])}")
    print(f"  task      {e['task']}")
    if int(e["result"], 16):
        print(f"  result    {e['result']}")


def cmd_errand_list(a) -> None:
    n = int(ecall("count()(uint256)").split()[0])
    if n == 0:
        print("no errands posted yet"); return
    for i in range(n - 1, max(-1, n - 1 - a.last), -1):
        e = get_errand(i)
        print(f"#{i:<4} {STATUS[e['status']]:9} {e['reward'] / 1e18:>10.6g} BNB   deadline {_when(e['deadline'])}   poster {e['poster'][:10]}…")


def cmd_errand_show(a) -> None:
    print_errand(get_errand(a.id))


RECORD_KEYS = ["posted", "completed as worker", "paid as poster", "rejections received", "rejections issued", "expired as worker"]


def record_of(who: str) -> list[int]:
    return [int(x.split()[0]) for x in ecall("records(address)(uint32,uint32,uint32,uint32,uint32,uint32)", who).splitlines()]


def cmd_errand_record(a) -> None:
    who = a.address or agent_wallet()
    ident = call("identityOf(address)(address)", who)
    if _zero(ident):
        print(f"{who} is not Agent-ID-backed; no record"); return
    print(f"identity {ident}" + ("" if ident.lower() == who.lower() else f"  (via linked wallet {who})"))
    for k, v in zip(RECORD_KEYS, record_of(ident)):
        print(f"  {k:22} {v}")


def _dur(s: str) -> int:
    m = {"m": 60, "h": 3600, "d": 86400}
    if not s or s[-1] not in m or not s[:-1].isdigit():
        die(f"duration {s!r}: use a number with m, h or d, like 90m, 12h, 3d")
    return int(s[:-1]) * m[s[-1]]


def _doc_hash(kind: str, text: str | None, path: str | None) -> str:
    if not text and not path:
        die(f"give --{kind} \"text\" or --{kind}-file FILE")
    body = open(path, "rb").read().decode("utf-8", "replace") if path else text
    blob = json.dumps({"kind": kind, "body": body, "created": int(time.time())}, sort_keys=True, separators=(",", ":")).encode()
    h = hashlib.sha256(blob).hexdigest()
    os.makedirs(ERRAND_DIR, exist_ok=True)
    with open(os.path.join(ERRAND_DIR, f"{h}.json"), "wb") as f:
        f.write(blob)
    print(f"  {kind} {h[:16]}…  saved to cli/errands/{h}.json (share it with the other side; only the hash goes on-chain)")
    return "0x" + h


def cmd_errand_post(a) -> None:
    from decimal import Decimal
    wei = int(Decimal(a.reward) * 10**18)
    if wei <= 0 or wei > 10**18:
        die("reward must be more than 0 and at most 1 BNB")
    review = _dur(a.review)
    if not (86400 <= review <= 14 * 86400):
        die("review window must be between 1d and 14d")
    deadline = int(time.time()) + _dur(a.deadline)
    task = _doc_hash("task", a.task, a.task_file)
    assignee = a.assignee or "0x0000000000000000000000000000000000000000"
    data = cast("calldata", "post(bytes32,uint40,uint32,address)", task, str(deadline), str(review), assignee)
    who = f", only {assignee} may take it" if a.assignee else ", open to any Agent ID holder"
    send(data, f"post an errand: {a.reward} BNB into escrow, deadline {_when(deadline)}{who}",
         to=errands(), label="Errands", value_wei=wei, expect="out")


def cmd_errand_take(a) -> None:
    e = get_errand(a.id)
    print_errand(e)
    r = record_of(e["poster"])
    print(f"  poster's record: {r[2]} paid out, {r[4]} rejections issued")
    if r[4] and r[4] >= r[2]:
        print("  CAUTION: this poster has rejected as many deliveries as they have paid for")
    send(cast("calldata", "take(uint256)", str(a.id)), f"take errand #{a.id} (payment would come to this wallet)",
         to=errands(), label="Errands", expect="none")


def cmd_errand_deliver(a) -> None:
    res = _doc_hash("result", a.result, a.result_file)
    send(cast("calldata", "deliver(uint256,bytes32)", str(a.id), res), f"deliver errand #{a.id}",
         to=errands(), label="Errands", expect="none")


def _simple(fn: str, expect: str, what: str):
    def run(a) -> None:
        e = get_errand(a.id)
        print_errand(e)
        send(cast("calldata", f"{fn}(uint256)", str(a.id)), what.format(id=a.id, reward=e["reward"] / 1e18),
             to=errands(), label="Errands", expect=expect)
    return run


def cmd_errand_withdraw(a) -> None:
    me = agent_wallet()
    owed = int(ecall("owed(address)(uint256)", me).split()[0])
    if owed == 0:
        print("nothing owed to this wallet"); return
    if a.to:
        send(cast("calldata", "withdrawTo(address)", a.to), f"withdraw {owed / 1e18:.6g} BNB owed, to {a.to}",
             to=errands(), label="Errands", expect="none")
    else:
        send(cast("calldata", "withdraw()"), f"withdraw {owed / 1e18:.6g} BNB owed to this wallet",
             to=errands(), label="Errands", expect="in")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    p = sp.add_parser("check"); p.add_argument("target"); p.set_defaults(f=cmd_check)
    p = sp.add_parser("whoami"); p.add_argument("address", nargs="?"); p.set_defaults(f=cmd_whoami)
    p = sp.add_parser("report"); p.add_argument("target"); p.add_argument("verdict")
    p.add_argument("--evidence"); p.add_argument("--note"); p.set_defaults(f=cmd_report)
    p = sp.add_parser("retract"); p.add_argument("target"); p.set_defaults(f=cmd_retract)
    p = sp.add_parser("link"); p.add_argument("wallet"); p.set_defaults(f=cmd_link)
    er = sp.add_parser("errand", help="the Errands escrow job board").add_subparsers(dest="ecmd", required=True)
    p = er.add_parser("list"); p.add_argument("--last", type=int, default=10); p.set_defaults(f=cmd_errand_list)
    p = er.add_parser("show"); p.add_argument("id", type=int); p.set_defaults(f=cmd_errand_show)
    p = er.add_parser("record"); p.add_argument("address", nargs="?"); p.set_defaults(f=cmd_errand_record)
    p = er.add_parser("post"); p.add_argument("--reward", required=True); p.add_argument("--deadline", required=True)
    p.add_argument("--review", default="1d"); p.add_argument("--task"); p.add_argument("--task-file"); p.add_argument("--assignee")
    p.set_defaults(f=cmd_errand_post)
    p = er.add_parser("take"); p.add_argument("id", type=int); p.set_defaults(f=cmd_errand_take)
    p = er.add_parser("deliver"); p.add_argument("id", type=int); p.add_argument("--result"); p.add_argument("--result-file")
    p.set_defaults(f=cmd_errand_deliver)
    for name, exp, what in [("release", "none", "release {reward:.6g} BNB to the worker of errand #{id}"),
                            ("reject", "in", "reject the delivery on errand #{id} and refund {reward:.6g} BNB (recorded publicly)"),
                            ("claim", "in", "claim {reward:.6g} BNB for errand #{id}"),
                            ("reclaim", "in", "reclaim {reward:.6g} BNB from errand #{id} (deadline passed, nothing delivered)"),
                            ("cancel", "in", "cancel errand #{id} and refund {reward:.6g} BNB")]:
        p = er.add_parser(name); p.add_argument("id", type=int); p.set_defaults(f=_simple(name, exp, what))
    p = er.add_parser("withdraw"); p.add_argument("--to"); p.set_defaults(f=cmd_errand_withdraw)
    a = ap.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
