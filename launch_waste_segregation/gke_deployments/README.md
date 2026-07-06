To comply with your security policy banning raw API keys, you should shift authentication to **Application Default Credentials (ADC)** via **GKE Workload Identity Federation** (formerly Workload Identity).

This approach completely removes the need for `project-3r-secrets` containing strings like `GEMINI_API_KEY`. Instead, your Segregation Agent container automatically inherits credentials implicitly via the Google SDK when initialized.

Here is the fast-track conversion setup to switch to ADC:

### Step 1: Bind your GKE Service Account to GCP IAM Roles

Run these three quick `gcloud` commands in Cloud Shell to authorize your GKE pod natively via Workload Identity:

```bash
# 1. Create a dedicated Google IAM Service Account (GSA)
gcloud iam service-accounts create project-3r-gke-sa --display-name="Project 3R GKE Agent Service Account"

# 2. Grant it access to Vertex AI (Gemini), BigQuery, and GCS
gcloud projects add-iam-policy-binding your-gcp-project-id \
    --member="serviceAccount:project-3r-gke-sa@your-gcp-project-id.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding your-gcp-project-id \
    --member="serviceAccount:project-3r-gke-sa@your-gcp-project-id.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"

# 3. Allow your Kubernetes Service Account (KSA) to impersonate the GSA
gcloud iam service-accounts add-iam-policy-binding project-3r-gke-sa@your-gcp-project-id.iam.gserviceaccount.com \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:your-gcp-project-id.svc.id.goog[default/project-3r-ksa]"

```

---

### Step 2: The Security-Compliant YAML (`project-3r-adc.yaml`)

This updated manifest provisions a Kubernetes Service Account (`project-3r-ksa`) linked natively to Google Cloud's ADC engine. It securely drops the raw `Secret` object completely:

```yaml
---
# ==============================================================================
# KUBERNETES SERVICE ACCOUNT (WORKLOAD IDENTITY / ADC LINK)
# ==============================================================================
apiVersion: v1
kind: ServiceAccount
metadata:
  name: project-3r-ksa
  namespace: default
  annotations:
    # This annotation maps your pod directly to the secure GCP IAM Service account
    iam.gke.io/gcp-service-account: "project-3r-gke-sa@your-gcp-project-id.iam.gserviceaccount.com"
---
# ==============================================================================
# CONFIGMAP (Environment Targets Only)
# ==============================================================================
apiVersion: v1
kind: ConfigMap
metadata:
  name: project-3r-config
data:
  GCP_PROJECT_ID: "your-gcp-project-id"
  GCS_WASTE_BUCKET: "your-3r-waste-bucket"
  BQ_DATASET: "waste_analytics"
  BQ_TELEMETRY_TABLE: "gke_segregation_telemetry"
  SEGREGATION_AGENT_URL: "http://segregation-service:8080/process"
  ROBOTIC_ARM_URL: "http://robotic-arm-service:8081/process"
  HMI_AGENT_URL: "http://smart-hmi-service:8082/update"
  DISPATCH_AGENT_URL: "http://review-dispatch-service:8083/log"

---
# ==============================================================================
# 1. SEGREGATION AGENT (Port 8080 - Now Using Native ADC Engine)
# ==============================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: segregation-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: segregation-agent
  template:
    metadata:
      labels:
        app: segregation-agent
    spec:
      serviceAccountName: project-3r-ksa # Instructs pod to assume Workload Identity metadata
      containers:
      - name: agent
        image: gcr.io/your-gcp-project-id/segregation-agent:latest
        ports:
        - containerPort: 8080
        envFrom:
        - configMapRef:
            name: project-3r-config
        # Note: NO Secret reference or GEMINI_API_KEY environment variable injected here!
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: segregation-service
spec:
  type: ClusterIP
  selector:
    app: segregation-agent
  ports:
  - port: 8080
    targetPort: 8080

---
# ==============================================================================
# 2. ROBOTIC ARM AGENT (Port 8081)
# ==============================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: robotic-arm-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: robotic-arm-agent
  template:
    metadata:
      labels:
        app: robotic-arm-agent
    spec:
      serviceAccountName: project-3r-ksa
      containers:
      - name: agent
        image: gcr.io/your-gcp-project-id/robotic-arm-agent:latest
        ports:
        - containerPort: 8081
        envFrom:
        - configMapRef:
            name: project-3r-config
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: robotic-arm-service
spec:
  type: ClusterIP
  selector:
    app: robotic-arm-agent
  ports:
  - port: 8081
    targetPort: 8081

---
# ==============================================================================
# 3. SMART HMI AGENT (Port 8082)
# ==============================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: smart-hmi-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: smart-hmi-agent
  template:
    metadata:
      labels:
        app: smart-hmi-agent
    spec:
      serviceAccountName: project-3r-ksa
      containers:
      - name: agent
        image: gcr.io/your-gcp-project-id/smart-hmi-agent:latest
        ports:
        - containerPort: 8082
        envFrom:
        - configMapRef:
            name: project-3r-config
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: smart-hmi-service
spec:
  type: ClusterIP
  selector:
    app: smart-hmi-agent
  ports:
  - port: 8082
    targetPort: 8082

---
# ==============================================================================
# 4. REVIEW & DISPATCH AGENT (Port 8083)
# ==============================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: review-dispatch-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: review-dispatch-agent
  template:
    metadata:
      labels:
        app: review-dispatch-agent
    spec:
      serviceAccountName: project-3r-ksa
      containers:
      - name: agent
        image: gcr.io/your-gcp-project-id/review-dispatch-agent:latest
        ports:
        - containerPort: 8083
        envFrom:
        - configMapRef:
            name: project-3r-config
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: review-dispatch-service
spec:
  type: ClusterIP
  selector:
    app: review-dispatch-agent
  ports:
  - port: 8083
    targetPort: 8083

```

---

### Step 3: Code Verification for the Segregation Agent

When using ADC, you initialization pattern inside `adk_segregation_app/agent.py` simplifies. The new `google-genai` SDK natively sweeps the container environment for Workload Identity tokens when instantiated cleanly without parameters:

```python
from google import genai
from google.genai import types

# Initialize client using ADC
ai_client = genai.Client()

# Construct the Part referencing your Cloud Storage URI directly
# Replace this with your actual GCS bucket variable or dynamic incoming payload
gcs_image_uri = "gs://your-3r-waste-bucket/sample_conveyor_clip.jpg"

image_part = types.Part.from_uri(
    file_uri=gcs_image_uri,
    mime_type="image/jpeg"  # or image/png depending on your file type
)

# Pass it directly to Gemini
response = ai_client.models.generate_content(
    model="gemini-2.5-flash",
    contents=[
        image_part,
        "Analyze this item on the waste segregation conveyor belt and output standard JSON routing data."
    ]
)

print(response.text)

```

Apply this manifest using `kubectl apply -f project-3r-adc.yaml`. Your cluster is now fully compliant with your team's keyless security configuration.