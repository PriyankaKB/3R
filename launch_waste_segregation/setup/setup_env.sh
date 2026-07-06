#!/bin/bash

# Get Google Cloud Project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo "Error: Could not determine Google Cloud Project ID."
    echo "Please run 'gcloud config set project <PROJECT_ID>' first."
    exit 1
fi

echo "Found Project ID: $PROJECT_ID"

# Configuration variables
VERTEX_LOCATION="us-central1"
SA_NAME="project-3r-gke-sa"
KSA_NAME="project-3r-ksa"
NAMESPACE="default"

# -------------------------------------------------------------------------
# Step 1: Enable necessary APIs
# -------------------------------------------------------------------------
echo "Enabling Google Cloud APIs..."
gcloud services enable aiplatform.googleapis.com --project=$PROJECT_ID
gcloud services enable apikeys.googleapis.com --project=$PROJECT_ID
gcloud services enable mapstools.googleapis.com --project=$PROJECT_ID
gcloud services enable bigquery.googleapis.com --project=$PROJECT_ID
gcloud services enable iam.googleapis.com --project=$PROJECT_ID

# Enable Model Context Protocol (MCP) services if not already active
ENABLED_SERVICES=$(gcloud beta services mcp list --enabled --format="value(name.basename())" --project=$PROJECT_ID 2>/dev/null)
if [[ ! "$ENABLED_SERVICES" == *"mapstools.googleapis.com"* ]]; then
    echo "Enabling MCP for Maps Tools..."
    gcloud --quiet beta services mcp enable mapstools.googleapis.com --project=$PROJECT_ID
fi
if [[ ! "$ENABLED_SERVICES" == *"bigquery.googleapis.com"* ]]; then
    echo "Enabling MCP for BigQuery..."
    gcloud --quiet beta services mcp enable bigquery.googleapis.com --project=$PROJECT_ID
fi

# -------------------------------------------------------------------------
# Step 2: Provision IAM Service Account & Workload Identity Bindings
# -------------------------------------------------------------------------
echo "Checking/Creating IAM Service Account ($SA_NAME)..."
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# Create the IAM Service Account if it doesn't already exist
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
    gcloud iam service-accounts create "$SA_NAME" \
        --description="IAM Service Account for Project-3R GKE microservices" \
        --display-name="$SA_NAME" \
        --project="$PROJECT_ID"
    echo "Created IAM Service Account: $SA_EMAIL"
else
    echo "IAM Service Account already exists: $SA_EMAIL"
fi

echo "Applying Workload Identity policy bindings..."
# Allow GKE KSA to impersonate IAM Service Account
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]" \
    --project="$PROJECT_ID" \
    --quiet

# Assign Vertex AI User permissions to the IAM Service Account
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/aiplatform.user" \
    --quiet

# Assign Cloud Storage Object Viewer permissions (for processing images from buckets)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.objectViewer" \
    --quiet

# -------------------------------------------------------------------------
# Step 3: Create API Key for Maps Platform
# -------------------------------------------------------------------------
echo "Creating Google Maps Platform API Key..."
API_KEY_NAME="project-3r-demo-key-$(date +%s)"
API_KEY_JSON=$(gcloud alpha services api-keys create --display-name="$API_KEY_NAME" \
    --api-target=service=mapstools.googleapis.com \
    --format=json 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$API_KEY_JSON" ]; then
    API_KEY=$(echo "$API_KEY_JSON" | grep -oP '"keyString": "\K[^"]+' 2>/dev/null || echo "$API_KEY_JSON" | grep '"keyString":' | cut -d '"' -f 4)
    if [ -z "$API_KEY" ]; then
        echo "Could not parse API Key automatically from JSON response."
    else
        echo "Successfully created API Key automatically."
    fi
fi

# Fallback if automated API key generation fails
if [ -z "$API_KEY" ]; then
    echo "Could not automate API key creation."
    read -p "Please enter your Google Maps Platform API Key manually: " API_KEY
fi

if [ -z "$API_KEY" ]; then
    echo "Error: API Key cannot be empty."
    exit 1
fi

# -------------------------------------------------------------------------
# Step 4: Determine Directory Structure & Generate Local .env Configurations
# -------------------------------------------------------------------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# List of all Project-3R microservices + orchestrator
AGENTS=("adk_segregation_app" "adk_robotic_arm_app" "adk_smart_hmi_app" "adk_dispatch_app" "orchestrator")

# Starting port number for local testing orchestration
BASE_PORT=8080

echo "Generating container/local configuration files..."
for i in "${!AGENTS[@]}"; do
  AGENT_NAME=${AGENTS[$i]}
  PORT=$((BASE_PORT + i))   # auto-increment port per agent

  ENV_FILE="$SCRIPT_DIR/../adk_agent/$AGENT_NAME/.env"
  mkdir -p $(dirname "$ENV_FILE")

  cat <<EOF > "$ENV_FILE"
# Environment variables for $AGENT_NAME
PORT=$PORT
LOG_LEVEL=info
DATASET_PATH=/data/$AGENT_NAME
GOOGLE_GENAI_USE_VERTEXAI=1
GOOGLE_CLOUD_PROJECT=$PROJECT_ID
GOOGLE_CLOUD_LOCATION=$VERTEX_LOCATION
MAPS_API_KEY=$API_KEY
EOF

  echo " -> Successfully created .env for $AGENT_NAME at $ENV_FILE (PORT=$PORT)"
done

echo "------------------------------------------------------------"
echo "Setup complete! Both cloud roles and local environment configs are built."
echo "Your GKE manifest will now map successfully using SA Name: $SA_NAME"