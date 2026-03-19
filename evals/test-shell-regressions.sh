#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES_DIR="$ROOT/evals/fixtures/retrieval-regressions"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat > "$TMP_DIR/mcporter" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${RETRIEVAL_FIXTURES_DIR:?}"
TEST_CASE="${TEST_CASE:?}"

if [[ "${1:-}" != "call" ]]; then
  echo "expected 'call'" >&2
  exit 1
fi
shift

query="${1:-}"

fixture_path() {
  printf '%s/%s/%s\n' "$FIXTURES_DIR" "$TEST_CASE" "$1"
}

emit() {
  cat "$(fixture_path "$1")"
}

is_account_wide_search_term_view() {
  [[ "$query" == *'resource:"search_term_view"'* ]] &&
  [[ "$query" != *"campaign.advertising_channel_type = 'SEARCH'"* ]] &&
  [[ "$query" != *"campaign.resource_name ="* ]]
}

is_search_only_search_term_view() {
  [[ "$query" == *'resource:"search_term_view"'* ]] &&
  [[ "$query" == *"campaign.advertising_channel_type = 'SEARCH'"* ]]
}

is_campaign_report() {
  [[ "$query" == *'resource:"campaign"'* ]]
}

is_pmax_view() {
  [[ "$query" == *'resource:"campaign_search_term_view"'* ]]
}

is_pmax_insight() {
  [[ "$query" == *'resource:"campaign_search_term_insight"'* ]]
}

case "$TEST_CASE" in
  retrieval_low_spend_then_between_success)
    if is_account_wide_search_term_view && [[ "$query" == *"segments.date DURING LAST_30_DAYS"* ]]; then
      emit step1_last30.json
    elif is_search_only_search_term_view && [[ "$query" == *"segments.date DURING LAST_30_DAYS"* ]]; then
      emit empty.json
    elif is_campaign_report && [[ "$query" == *"segments.date DURING LAST_30_DAYS"* ]]; then
      emit empty.json
    elif is_account_wide_search_term_view && [[ "$query" == *"segments.date DURING LAST_14_DAYS"* ]]; then
      emit empty.json
    elif is_search_only_search_term_view && [[ "$query" == *"segments.date DURING LAST_14_DAYS"* ]]; then
      emit empty.json
    elif is_campaign_report && [[ "$query" == *"segments.date DURING LAST_14_DAYS"* ]]; then
      emit empty.json
    elif is_account_wide_search_term_view && [[ "$query" == *"segments.date BETWEEN"* ]]; then
      emit step1_between.json
    else
      emit empty.json
    fi
    ;;
  retrieval_state_reset)
    if is_account_wide_search_term_view && [[ "$query" == *"segments.date DURING LAST_30_DAYS"* ]]; then
      emit empty.json
    elif is_search_only_search_term_view && [[ "$query" == *"segments.date DURING LAST_30_DAYS"* ]]; then
      emit empty.json
    elif is_campaign_report && [[ "$query" == *"segments.date DURING LAST_30_DAYS"* ]]; then
      emit campaigns_last30.json
    elif is_pmax_view && [[ "$query" == *"customers/1234567890/campaigns/777"* ]]; then
      emit empty.json
    elif is_pmax_insight && [[ "$query" == *"campaign_search_term_insight.campaign_id = 777"* ]]; then
      emit empty.json
    elif is_account_wide_search_term_view && [[ "$query" == *"segments.date DURING LAST_14_DAYS"* ]]; then
      emit empty.json
    elif is_search_only_search_term_view && [[ "$query" == *"segments.date DURING LAST_14_DAYS"* ]]; then
      emit empty.json
    elif is_campaign_report && [[ "$query" == *"segments.date DURING LAST_14_DAYS"* ]]; then
      emit empty.json
    elif is_account_wide_search_term_view && [[ "$query" == *"segments.date BETWEEN"* ]]; then
      emit step1_between.json
    else
      emit empty.json
    fi
    ;;
  negative_non_negative_shared_sets)
    case "$query" in
      *'resource:"campaign_criterion"'*) emit empty.json ;;
      *'resource:"ad_group_criterion"'*) emit empty.json ;;
      *'resource:"shared_set"'*'fields:["shared_set.id","shared_set.name"]'*) emit shared_set_min.json ;;
      *'resource:"shared_set"'*'fields:["shared_set.resource_name","shared_set.name","shared_set.type"]'*) emit shared_set_typed.json ;;
      *) emit empty.json ;;
    esac
    ;;
  negative_verified_filtering)
    case "$query" in
      *'resource:"campaign_criterion"'*) emit empty.json ;;
      *'resource:"ad_group_criterion"'*) emit empty.json ;;
      *'resource:"shared_set"'*'fields:["shared_set.id","shared_set.name"]'*) emit shared_set_min.json ;;
      *'resource:"shared_set"'*'fields:["shared_set.resource_name","shared_set.name","shared_set.type"]'*) emit shared_set_typed.json ;;
      *'resource:"campaign_shared_set"'*"campaign_shared_set.shared_set = 'customers/1234567890/sharedSets/neg-1'"*) emit campaign_shared_neg.json ;;
      *'resource:"shared_criterion"'*"shared_criterion.shared_set = 'customers/1234567890/sharedSets/neg-1'"*"shared_criterion.type = 'KEYWORD'"*) emit shared_criterion_neg.json ;;
      *'resource:"shared_criterion"'*"shared_criterion.shared_set = 'customers/1234567890/sharedSets/neg-1'"*) emit shared_criterion_neg.json ;;
      *) emit empty.json ;;
    esac
    ;;
  *)
    echo "unknown test case: $TEST_CASE" >&2
    exit 1
    ;;
esac
EOF

chmod +x "$TMP_DIR/mcporter"

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "Missing expected text: $expected" >&2
    echo "--- output ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

run_with_stub() {
  local test_case="$1"
  shift
  PATH="$TMP_DIR:$PATH" RETRIEVAL_FIXTURES_DIR="$FIXTURES_DIR" TEST_CASE="$test_case" "$@"
}

bash -n "$ROOT/scripts/search-terms-retrieval.sh"
bash -n "$ROOT/scripts/negative-inventory.sh"

OUT1="$TMP_DIR/retrieval-low-spend.out"
run_with_stub retrieval_low_spend_then_between_success "$ROOT/scripts/search-terms-retrieval.sh" 1234567890 > "$OUT1"
assert_contains "$OUT1" 'rows found, but spend is below the $5.00 threshold'
assert_contains "$OUT1" 'Date range: segments.date BETWEEN'
assert_contains "$OUT1" 'Retrieval mode: classic'

OUT2="$TMP_DIR/retrieval-state-reset.out"
run_with_stub retrieval_state_reset "$ROOT/scripts/search-terms-retrieval.sh" 1234567890 > "$OUT2"
assert_contains "$OUT2" 'Retrieval mode: classic'
assert_contains "$OUT2" 'Campaigns probed: 0 total, 0 Search, 0 PMax, 0 other'
assert_contains "$OUT2" 'PMax campaigns without rows: none'

OUT3="$TMP_DIR/negative-non-negative-shared-sets.out"
run_with_stub negative_non_negative_shared_sets "$ROOT/scripts/negative-inventory.sh" 1234567890 > "$OUT3"
assert_contains "$OUT3" 'Verified negative keyword shared sets: 0'
assert_contains "$OUT3" 'Shared negative lists: 0'
assert_contains "$OUT3" 'Shared negative-list attachments: 0'
assert_contains "$OUT3" 'Verification result: No negatives found anywhere'

OUT4="$TMP_DIR/negative-verified-filtering.out"
run_with_stub negative_verified_filtering "$ROOT/scripts/negative-inventory.sh" 1234567890 > "$OUT4"
assert_contains "$OUT4" 'Verified negative keyword shared sets: 1'
assert_contains "$OUT4" 'Shared negative lists: 1'
assert_contains "$OUT4" 'Shared negative-list attachments: 1'
assert_contains "$OUT4" 'Shared negative-list keyword members: 1'
assert_contains "$OUT4" 'Verification result: Negatives are active in the account'

echo "Shell regression checks passed."
