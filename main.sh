#!/bin/bash

# Load .env properly on Mac
if [ -f .env ]; then
    # We source it inside a subshell to avoid polluting your current terminal
    # but allowing the script to access the variables
    set -a
    source .env
    set +a
else
    echo "❌ Error: .env file not found."
    exit 1
fi

# Quick connectivity check
echo "Verifying GitHub Authentication..."
if ! gh api user -i > /dev/null 2>&1; then
    echo "❌ Error: Your GH_TOKEN is invalid or expired."
    echo "Please check SSO authorization or run 'gh auth login'."
    # gh auth login
    exit 1
fi
echo "✅ Authenticated."

# Validation
if [[ -z "$REPOS" ]]; then
    echo "❌ Error: 'REPOS' is empty or not declared in .env."
    exit 1
fi

# Date Logic
if [ -n "$FETCH_RANGE" ]; then
    RANGE=$FETCH_RANGE
else
    RANGE=$(date +%Y-%m-%d)
fi

# Dynamic Filename
SAFE_RANGE=$(echo "$RANGE" | sed 's/\.\./_to_/g')
OUTPUT_FILE="workflows_${SAFE_RANGE}.csv"

if [ -f "$OUTPUT_FILE" ]; then
    echo "🧹 Existing file found ($OUTPUT_FILE). Deleting to start fresh..."
    rm "$OUTPUT_FILE"
fi

echo "Using Range: $RANGE"
echo "--------------------------------------------------------"

# Initialize CSV
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "repo,workflow,status,headBranch,conclusion,started_at,updated_at" > "$OUTPUT_FILE"
fi

# Process Repos
# This version handles the multi-line string from .env correctly
while read -r REPO; do
    # Skip empty lines or lines that are just whitespace
    [[ -z "${REPO// }" ]] && continue

    # Clean repo name (removes any accidental quotes or trailing spaces)
    REPO=$(echo "$REPO" | tr -d '"' | tr -d "'" | tr -d ' ')

    echo "Checking $REPO..."

    # Run the command and capture output in a variable
    # We send stderr to a temporary file to inspect if it fails
    # Available fields:
    #     attempt
    #     conclusion
    #     createdAt
    #     databaseId
    #     displayTitle
    #     event
    #     headBranch
    #     headSha
    #     name
    #     number
    #     startedAt
    #     status
    #     updatedAt
    #     url
    #     workflowDatabaseId
    #     workflowName
    DATA=$(gh run list -R "$REPO" --created "$RANGE" --limit 300 \
        --json workflowName,status,headBranch,conclusion,startedAt,updatedAt \
        --jq ".[] | [ \"$REPO\", .workflowName, .status, .headBranch, .conclusion, .startedAt, .updatedAt ] | @csv" 2>error.log)

    # --- CHECK RETURN CODE ---
    if [ $? -eq 0 ]; then
        if [ -z "$DATA" ]; then
            echo "Done (No runs found)."
        else
            echo "$DATA" >> "$OUTPUT_FILE"
            echo "Done (Data added)."
        fi
    else
        # If gh failed, read the error message from the log
        ERR_MSG=$(cat error.log)
        echo "❌ FAILED"
        echo "   Reason: $ERR_MSG"

        # Optional: Exit if it's a credential error (401)
        if [[ "$ERR_MSG" == *"401"* ]]; then
            echo "Stopping script: Please run 'gh auth login' to refresh credentials."
            rm error.log
            exit 1
        fi
    fi

    sleep 0.2
done <<< "$REPOS"

echo "--------------------------------------------------------"
echo "✅ Done! Results saved to $OUTPUT_FILE"
