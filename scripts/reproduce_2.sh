DAEMON=${1:-"exampled"}

if [ -n "$BASH_SOURCE" ]; then
    # Bash
    SCRIPT_FILE="${BASH_SOURCE[0]}"
elif [ -n "$ZSH_VERSION" ]; then
    # Zsh
    SCRIPT_FILE="${(%):-%N}"
else
    # fallback
    SCRIPT_FILE="$0"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_FILE")" && pwd)"

# initialize
jq '.members[0].weight = "1e-50000"
    | .members[1].weight = "1e50000"' \
    json_template/members.json > tmp.json \
&& mv tmp.json members.json

# modify the JSON files
source $SCRIPT_DIR/setup_json.sh $DAEMON
source addresses.env

# submit proposal
$DAEMON tx group submit-proposal proposal.json --from alice --gas auto --yes
sleep 2s # wait for block generation but less than the voting period

# vote
$DAEMON tx group vote 1 $ALICE VOTE_OPTION_YES "" --gas auto --yes

# END OF THE VOTING PERIOD WILL SUMMON THE CHAIN HAULT