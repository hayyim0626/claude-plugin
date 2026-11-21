#!/usr/bin/env python3
# collect.sh 가 부른다: stdin 으로 세션 jsonl 경로 목록, env WL_CFG/WL_SINCE/WL_UNTIL/WL_LIMIT
import sys, json, os, re
cfg = json.load(open(os.environ["WL_CFG"]))
since, until, limit = os.environ["WL_SINCE"], os.environ["WL_UNTIL"], int(os.environ["WL_LIMIT"])
home = os.path.expanduser("~")

def enc(path):
    p = os.path.expanduser(path).rstrip("/")
    return re.sub(r"[/.]", "-", p)

pmap = {enc(r["path"]): r["project"] for r in cfg.get("repos", [])}
extra = cfg.get("sessions", {}).get("extra_projects", [])
SKIP = ("<", "[Request interrupted", "[Image", "# Claude in Chrome", "Caveat:", "This session is being continued", "Approach this as", "Base directory for this skill")

def project_of(dirname):
    if dirname in pmap: return pmap[dirname]
    for e in extra:
        if dirname.startswith(e["dir_prefix"]): return e["project"]
    for k, v in pmap.items():
        if dirname.startswith(k + "-"): return v
    return "?"

def local_date(ts):
    # ts is UTC ISO; convert to local date
    from datetime import datetime, timezone
    try:
        d = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
        return d.strftime("%Y-%m-%d")
    except Exception:
        return ts[:10]

for f in sys.stdin.read().split():
    dirname = os.path.basename(os.path.dirname(f))
    msgs = []
    try:
        with open(f, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                if '"type":"user"' not in line: continue
                try: d = json.loads(line)
                except Exception: continue
                if d.get("type") != "user": continue
                day = local_date(d.get("timestamp", ""))
                if not (since <= day <= until): continue
                m = d.get("message", {}).get("content")
                t = m if isinstance(m, str) else next((c.get("text", "") for c in (m or []) if isinstance(c, dict) and c.get("type") == "text"), "")
                t = (t or "").strip()
                if not t or t.startswith(SKIP): continue
                t = t.replace("\n", " ")[:200]
                # 같은 문장을 고쳐 다시 보낸 경우 마지막 것만 남긴다
                if msgs and (t.startswith(msgs[-1][1][:40]) or msgs[-1][1].startswith(t[:40])):
                    msgs[-1] = (day, t)
                else:
                    msgs.append((day, t))
    except Exception:
        continue
    if not msgs: continue
    total = len(msgs)
    if total > limit:
        step = total / limit
        msgs = [msgs[int(i * step)] for i in range(limit)]
    print(f"--- {project_of(dirname)} [{dirname}] {os.path.basename(f)[:8]} ({total} msgs, showing {len(msgs)})")
    for day, t in msgs:
        print(f"{day} - {t}")
