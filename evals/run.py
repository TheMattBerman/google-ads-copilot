#!/usr/bin/env python3
import json
import sys
from pathlib import Path

BASE = Path(__file__).parent
CASES = BASE / 'cases.json'
FIXTURES = BASE / 'fixtures'


def classify_input(text: str):
    t = text.lower()
    result = {
        'intent_class': None,
        'action': None,
        'tracking_confidence': None,
        'issue': None,
        'structure_action': None,
        'reason': None,
        'budget_action': None,
        'rsa_direction': None,
    }

    if any(x in t for x in ['login', 'support', 'customer service', 'account']):
        result['intent_class'] = 'support'
        result['action'] = 'exclude'
    elif any(x in t for x in ['jobs', 'job', 'career', 'careers', 'internship', 'salary']):
        result['intent_class'] = 'job-seeker'
        result['action'] = 'exclude'
    elif 'what is' in t:
        result['intent_class'] = 'research'
        result['action'] = 'exclude_or_separate'
    elif any(x in t for x in ['alternatives', ' vs ', 'compare', 'comparison']):
        result['intent_class'] = 'competitor_or_comparison'
        result['action'] = 'isolate'
    elif 'free' in t:
        result['intent_class'] = 'freebie'
        result['action'] = 'review_carefully'
    elif any(x in t for x in ['demo', 'pricing', 'quote', 'trial']):
        result['intent_class'] = 'buyer'
        result['action'] = 'keep_or_isolate'
    elif any(x in t for x in ['reduce', 'improve', 'fix', 'optimize', 'chaos']):
        result['intent_class'] = 'buyer_or_mixed'
        result['action'] = 'watch_or_isolate'

    if 'ga4 import' in t and 'native google ads tag' in t and 'same' in t:
        result['tracking_confidence'] = 'low'
        result['issue'] = 'duplicate_counting'

    if 'add-to-cart' in t or 'add to cart' in t or 'page scroll' in t:
        result['tracking_confidence'] = 'low_or_medium'
        result['issue'] = 'micro_conversion_pollution'

    if 'brand name' in t and 'generic category terms' in t and 'same bucket' in t:
        result['structure_action'] = 'split'
        result['reason'] = 'brand_nonbrand_mixed'

    if 'mixed educational' in t or 'weak conversion quality' in t:
        result['budget_action'] = 'fix_before_scaling'

    if 'top converting modifiers' in t and any(x in t for x in ['demo', 'pricing']):
        result['rsa_direction'] = 'use_query_language'

    return result


def check_case(case):
    actual = classify_input(case['input'])
    expected = case['expected']
    failures = []
    for key, value in expected.items():
        if actual.get(key) != value:
            failures.append((key, value, actual.get(key)))
    return actual, failures


def analyze_fixture(path: Path):
    data = json.loads(path.read_text())
    terms = data.get('search_terms', [])
    counts = {
        'buyer_like': 0,
        'research_like': 0,
        'support_like': 0,
        'job_like': 0,
        'comparison_like': 0,
    }
    for row in terms:
        q = row['query']
        c = classify_input(q)
        ic = c.get('intent_class')
        if ic == 'buyer':
            counts['buyer_like'] += 1
        elif ic == 'research':
            counts['research_like'] += 1
        elif ic == 'support':
            counts['support_like'] += 1
        elif ic == 'job-seeker':
            counts['job_like'] += 1
        elif ic == 'competitor_or_comparison':
            counts['comparison_like'] += 1

    notes_blob = ' '.join(data.get('notes', [])).lower()
    findings = {
        'has_brand_nonbrand_mix': 'brand and non-brand' in notes_blob,
        'has_tracking_duplication_risk': 'ga4 import and native google ads tag' in notes_blob,
        'has_micro_conversion_risk': 'micro events' in notes_blob,
        'has_pmax_cannibalization_risk': 'pmax' in notes_blob and 'branded demand' in notes_blob,
        'intent_summary': counts,
    }
    return findings


def run_cases():
    cases = json.loads(CASES.read_text())
    passed = 0
    failed = 0
    print(f"Google Ads Copilot evals — {len(cases)} direct cases\n")
    for case in cases:
        actual, failures = check_case(case)
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


def run_fixtures():
    fixture_files = sorted(FIXTURES.glob('*.json'))
    print(f"Fixture walkthroughs — {len(fixture_files)} files\n")
    for path in fixture_files:
        findings = analyze_fixture(path)
        print(f"📦 {path.name}")
        print(json.dumps(findings, indent=2))
        print()
    return True


def main():
    ok_cases = run_cases()
    ok_fixtures = run_fixtures()
    sys.exit(0 if ok_cases and ok_fixtures else 1)


if __name__ == '__main__':
    main()
