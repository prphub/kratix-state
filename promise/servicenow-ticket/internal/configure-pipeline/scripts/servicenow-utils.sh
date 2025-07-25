#!/usr/bin/env sh

# ServiceNow utility functions (sh-compatible)

validate_environment() {
    echo "Validating ServiceNow environment variables..."
    
    if [ -z "${SERVICENOW_INSTANCE:-}" ]; then
        echo "SERVICENOW_INSTANCE environment variable is required"
        exit 1
    fi
    
    if [ -z "${SERVICENOW_USERNAME:-}" ]; then
        echo "SERVICENOW_USERNAME environment variable is required"
        exit 1
    fi
    
    if [ -z "${SERVICENOW_PASSWORD:-}" ]; then
        echo "SERVICENOW_PASSWORD environment variable is required"
        exit 1
    fi
    
    if [ -z "${SERVICENOW_TABLE:-}" ]; then
        echo "SERVICENOW_TABLE environment variable is required"
        exit 1
    fi
    
    echo "Environment validation passed"
}

get_ticket_status() {
    ticket_id=$1
    
    if [ -z "${ticket_id}" ]; then
        echo "error"
        return 1
    fi
    
    response=$(curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        -H "Accept: application/json" \
        "https://${SERVICENOW_INSTANCE}.service-now.com/api/now/table/${SERVICENOW_TABLE}/${ticket_id}")
    
    echo "${response}" | jq -r '.result.u_status // "unknown"'
}

update_ticket_status() {
    ticket_id=$1
    new_status=$2
    notes=${3:-""}
    
    if [ -n "${notes}" ]; then
        update_payload=$(cat <<EOF
{
    "u_status": "${new_status}",
    "work_notes": "${notes}"
}
EOF
)
    else
        update_payload=$(cat <<EOF
{
    "u_status": "${new_status}"
}
EOF
)
    fi
    
    curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -X PUT \
        -d "${update_payload}" \
        "https://${SERVICENOW_INSTANCE}.service-now.com/api/now/table/${SERVICENOW_TABLE}/${ticket_id}"
}
