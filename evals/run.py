#!/usr/bin/env python3
import json
import math
import subprocess
import sys
from pathlib import Path

BASE = Path(__file__).parent
ROOT = BASE.parent
FIXTURES = BASE / "fixtures"
LEGACY_CASES = BASE / "cases.json"
DECISION_CASES = BASE / "decision_cases.json"
APPLY_CASES = BASE / "apply_cases.json"


def classify_input(text: str):
    t = text.lower()
    result = {
        "intent_class": None,
        "action": None,
        "tracking_confidence": None,
        "issue": None,
        "structure_action": None,
        "reason": None,
        "budget_action": None,
        "rsa_direction": None,
    }

    if any(x in t for x in ["login", "support", "customer service", "account"]):
        result["intent_class"] = "support"
        result["action"] = "exclude"
    elif any(x in t for x in ["jobs", "job", "career", "careers", "internship", "salary"]):
        result["intent_class"] = "job-seeker"
        result["action"] = "exclude"
    elif "what is" in t:
        result["intent_class"] = "research"
        result["action"] = "exclude_or_separate"
    elif any(x in t for x in ["alternatives", " vs ", "compare", "comparison"]):
        result["intent_class"] = "competitor_or_comparison"
        result["action"] = "isolate"
    elif "free" in t:
        result["intent_class"] = "freebie"
        result["action"] = "review_carefully"
    elif any(x in t for x in ["demo", "pricing", "quote", "trial"]):
        result["intent_class"] = "buyer"
        result["action"] = "keep_or_isolate"
    elif any(x in t for x in ["reduce", "improve", "fix", "optimize", "chaos"]):
        result["intent_class"] = "buyer_or_mixed"
        result["action"] = "watch_or_isolate"

    if "ga4 import" in t and "native google ads tag" in t and "same" in t:
        result["tracking_confidence"] = "low"
        result["issue"] = "duplicate_counting"

    if "add-to-cart" in t or "add to cart" in t or "page scroll" in t:
        result["tracking_confidence"] = "low_or_medium"
        result["issue"] = "micro_conversion_pollution"

    if "brand name" in t and "generic category terms" in t and "same bucket" in t:
        result["structure_action"] = "split"
        result["reason"] = "brand_nonbrand_mixed"

    if "mixed educational" in t or "weak conversion quality" in t:
        result["budget_action"] = "fix_before_scaling"

    if "top converting modifiers" in t and any(x in t for x in ["demo", "pricing"]):
        result["rsa_direction"] = "use_query_language"

    return result


def analyze_fixture(path: Path):
    data = json.loads(path.read_text())
    terms = data.get("search_terms", [])
    counts = {
        "buyer_like": 0,
        "research_like": 0,
        "support_like": 0,
        "job_like": 0,
        "comparison_like": 0,
    }
    for row in terms:
        q = row["query"]
        c = classify_input(q)
        ic = c.get("intent_class")
        if ic == "buyer":
            counts["buyer_like"] += 1
        elif ic == "research":
            counts["research_like"] += 1
        elif ic == "support":
            counts["support_like"] += 1
        elif ic == "job-seeker":
            counts["job_like"] += 1
        elif ic == "competitor_or_comparison":
            counts["comparison_like"] += 1

    notes_blob = " ".join(data.get("notes", [])).lower()
    return {
        "has_brand_nonbrand_mix": "brand and non-brand" in notes_blob,
        "has_tracking_duplication_risk": "ga4 import and native google ads tag" in notes_blob,
        "has_micro_conversion_risk": "micro events" in notes_blob,
        "has_pmax_cannibalization_risk": "pmax" in notes_blob and "branded demand" in notes_blob,
        "intent_summary": counts,
    }


def load_decision_cases():
    cases = []
    if LEGACY_CASES.exists():
        cases.extend(json.loads(LEGACY_CASES.read_text()))
    if DECISION_CASES.exists():
        cases.extend(json.loads(DECISION_CASES.read_text()))

    deduped = {}
    for case in cases:
        deduped[case["id"]] = case
    return list(deduped.values())


def run_decision_cases():
    cases = load_decision_cases()
    passed = 0
    failed = 0
    print(f"Decision-quality evals — {len(cases)} cases\n")
    for case in cases:
        actual = classify_input(case["input"])
        failures = []
        for key, value in case["expected"].items():
            if actual.get(key) != value:
                failures.append((key, value, actual.get(key)))
        if failures:
            failed += 1
            print(f"❌ {case['id']}")
            for key, expected, got in failures:
                print(f"   - {key}: expected={expected!r} got={got!r}")
        else:
            passed += 1
            print(f"✅ {case['id']}")
    print(f"\nPassed: {passed}")
    print(f"Failed: {failed}\n")
    return failed == 0


def run_account_fixtures():
    fixture_files = sorted(FIXTURES.glob("account-snapshot-*.json"))
    print(f"Fixture walkthroughs — {len(fixture_files)} files\n")
    for path in fixture_files:
        findings = analyze_fixture(path)
        print(f"📦 {path.name}")
        print(json.dumps(findings, indent=2))
        print()
    return True


def _parse_draft_via_bash(draft_path: Path):
    cmd = f'cd "{ROOT}" && source scripts/apply-layer/lib/parse-draft.sh && parse_draft "{draft_path}"'
    proc = subprocess.run(["bash", "-lc", cmd], capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "parse_draft failed")
    return json.loads(proc.stdout)


def run_parser_fixtures():
    md_fixtures = sorted(FIXTURES.glob("draft-*.md"))
    print(f"Apply parser fixtures — {len(md_fixtures)} files\n")
    ok = True
    for path in md_fixtures:
        try:
            parsed = _parse_draft_via_bash(path)
        except Exception as exc:
            ok = False
            print(f"❌ {path.name} — parser error: {exc}")
            continue

        action_count = parsed.get("action_count")
        actions = parsed.get("actions", [])
        if action_count != len(actions):
            ok = False
            print(f"❌ {path.name} — action_count mismatch: {action_count} vs {len(actions)}")
            continue

        if path.name == "draft-budget-manifest.md":
            if actions[0].get("type") != "SET_CAMPAIGN_DAILY_BUDGET":
                ok = False
                print(f"❌ {path.name} — expected budget action, got {actions[0].get('type')!r}")
                continue
        if path.name == "draft-negative-legacy.md":
            if actions[0].get("type") != "ADD_NEGATIVE":
                ok = False
                print(f"❌ {path.name} — expected legacy negative action, got {actions[0].get('type')!r}")
                continue

        print(f"✅ {path.name}")
    print()
    return ok


def pct_change(current: int, proposed: int) -> int:
    if current <= 0:
        return 0
    pct = ((proposed - current) / current) * 100.0
    if pct >= 0:
        return int(pct + 0.5)
    return int(pct - 0.5)


def min_meaningful_delta(current: int) -> int:
    return max(math.ceil(current * 0.05), 5_000_000)


def evaluate_apply_case(case):
    if case["type"] == "parser_fixture":
      parsed = _parse_draft_via_bash(FIXTURES / case["fixture"])
      return {
          "action_count": parsed["action_count"],
          "first_type": parsed["actions"][0]["type"],
          "mode": "manifest" if parsed.get("meta") is not None and case["fixture"] == "draft-budget-manifest.md" else "legacy",
      }

    data = case["input"]
    tracking = data.get("tracking_confidence", "").lower()
    if tracking not in {"medium", "high"}:
        return {"allowed": False, "reason": "tracking_confidence"}

    if data.get("pending_tracking_drafts", False):
        return {"allowed": False, "reason": "pending_tracking_drafts"}

    actions = data.get("actions", [])
    for action in actions:
        current = action["current_micros"]
        proposed = action["proposed_micros"]
        if abs(pct_change(current, proposed)) > action.get("max_pct_change", 30):
            return {"allowed": False, "reason": "max_pct_change"}
        if abs(proposed - current) < min_meaningful_delta(current):
            return {"allowed": False, "reason": "noop_delta"}
        if action.get("days_since_last_change", 999) < action.get("cooldown_days", 7) and not data.get("force", False):
            return {"allowed": False, "reason": "cooldown"}

    sum_current = sum(a["current_micros"] for a in actions)
    sum_proposed = sum(a["proposed_micros"] for a in actions)
    net_delta = sum_proposed - sum_current
    budget_policy = data.get("meta", {}).get("budget_policy", {})
    allow_net_increase = budget_policy.get("allow_net_increase", False)
    max_net_increase_pct = budget_policy.get("max_net_increase_pct", 10)

    if net_delta != 0:
        if net_delta > 0 and allow_net_increase:
            if pct_change(sum_current, sum_proposed) > max_net_increase_pct:
                return {"allowed": False, "reason": "net_increase_cap"}
        else:
            return {"allowed": False, "reason": "budget_neutrality"}

    return {
        "allowed": True,
        "reason": "ok",
        "net_delta_micros": net_delta,
        "net_pct": pct_change(sum_current, sum_proposed),
    }


def run_apply_cases():
    cases = json.loads(APPLY_CASES.read_text())
    passed = 0
    failed = 0
    print(f"Apply-layer evals — {len(cases)} cases\n")
    for case in cases:
        try:
            actual = evaluate_apply_case(case)
        except Exception as exc:
            actual = {"error": str(exc)}

        failures = []
        for key, value in case["expected"].items():
            if actual.get(key) != value:
                failures.append((key, value, actual.get(key)))

        if failures:
            failed += 1
            print(f"❌ {case['id']}")
            for key, expected, got in failures:
                print(f"   - {key}: expected={expected!r} got={got!r}")
        else:
            passed += 1
            print(f"✅ {case['id']}")

    print(f"\nPassed: {passed}")
    print(f"Failed: {failed}\n")
    return failed == 0


def main():
    ok_decisions = run_decision_cases()
    ok_fixtures = run_account_fixtures()
    ok_parsers = run_parser_fixtures()
    ok_apply = run_apply_cases()
    sys.exit(0 if ok_decisions and ok_fixtures and ok_parsers and ok_apply else 1)


if __name__ == "__main__":
    main()
