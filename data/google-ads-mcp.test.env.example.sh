#!/usr/bin/env bash
# Copy to a local untracked file before use, for example:
#   cp data/google-ads-mcp.test.env.example.sh data/google-ads-mcp.test.env.sh
# Then replace the placeholder values below.

export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/data/google-ads-adc-authorized-user.json"
export GOOGLE_CLOUD_PROJECT="your-google-cloud-project-id"
export GOOGLE_ADS_DEVELOPER_TOKEN="your-google-ads-developer-token"

# Optional: manager account ID for MCC access
# export GOOGLE_ADS_LOGIN_CUSTOMER_ID="1234567890"
