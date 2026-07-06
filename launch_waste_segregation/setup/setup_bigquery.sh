#!/bin/bash

PROJECT_ID=$(gcloud config get-value project)
DATASET_NAME="waste_segregation_3r"
LOCATION="US"

# Generate bucket name if not provided
if [ -z "$1" ]; then
    BUCKET_NAME="gs://3r-autonoumous-waste-segregation-$PROJECT_ID"
    echo "No bucket provided. Using default: $BUCKET_NAME"
else
    BUCKET_NAME=$1
fi

echo "----------------------------------------------------------------"
echo "Project-3R Demo Setup"
echo "Project: $PROJECT_ID"
echo "Dataset: $DATASET_NAME"
echo "Bucket:  $BUCKET_NAME"
echo "----------------------------------------------------------------"

# 1. Create Bucket if it doesn't exist
echo "[1/8] Checking bucket $BUCKET_NAME..."
if gcloud storage buckets describe $BUCKET_NAME >/dev/null 2>&1; then
    echo "      Bucket already exists."
else
    echo "      Creating bucket $BUCKET_NAME..."
    gcloud storage buckets create $BUCKET_NAME --location=$LOCATION
fi

# 2. Upload Data
echo "[2/8] Uploading data to $BUCKET_NAME..."
gcloud storage cp data/*.csv $BUCKET_NAME

# 3. Create Dataset
echo "[3/8] Creating Dataset '$DATASET_NAME'..."
if bq show "$PROJECT_ID:$DATASET_NAME" >/dev/null 2>&1; then
    echo "      Dataset already exists. Skipping creation."
else    
    bq mk --location=$LOCATION --dataset \
        --description "$DATASET_DESCRIPTION" \
        "$PROJECT_ID:$DATASET_NAME"
    echo "      Dataset created."
fi

# =====================================================================
# 2. Create waste_categories_data Table
# =====================================================================
echo "[4/13] Setting up Table: waste_categories_data..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.waste_segregation_3r.waste_categories_data\` (
    sr_no INT64 OPTIONS (description='Serial number or identifier of the record'),
    waste_category STRING OPTIONS (description='The mapped segregation waste category block'),
    bin_color STRING OPTIONS (description='Assigned color code for physical sorting bins'),
    symbol STRING OPTIONS (description='Emoji or icon representing the waste type on the bin labels'),
    materials STRING OPTIONS (description='Comma-separated specific list of items belonging to this category'),
    global_reference STRING OPTIONS (description='Standard regulatory framework reference such as SWM 2016 or EU Directive'),
    description STRING OPTIONS (description='Physical details and disposal constraints of the material category'),
    remark STRING OPTIONS (description='Processing note or processing routing destinations')
)
OPTIONS(
    description='Master taxonomy data defining the physical 2x3 grid mapping configurations for the automated waste segregation sorting pipeline.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.waste_categories_data" "$BUCKET_NAME/waste_categories_data.csv"

# =====================================================================
# 2. Create recyclable_materials_data Table
# =====================================================================
echo "[5/13] Setting up Table: recyclable_materials_data..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.recyclable_materials_data\` (
    sr_no INT64 OPTIONS (description='Serial identifier'),
    waste_category STRING OPTIONS (description='High-level category matching the grid layout'),
    bin_id STRING OPTIONS (description='Physical bin target matrix ID mapping'),
    bin_color STRING OPTIONS (description='Assigned bin color code'),
    symbol STRING OPTIONS (description='Emoji or character label'),
    materials STRING OPTIONS (description='Description of specific materials under this category')
)
OPTIONS(
    description='Taxonomy structure for clean recyclable material targets.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.recyclable_materials_data" "$BUCKET_NAME/recyclable_materials_data.csv"

# =====================================================================
# 3. Create recycle_bin_id_matrix Table
# =====================================================================
echo "[6/13] Setting up Table: recycle_bin_id_matrix..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.recycle_bin_id_matrix\` (
    row_column STRING OPTIONS (description='Row axis key identifier'),
    col_0 STRING OPTIONS (description='Column Index 0 Bin Mapping Target'),
    col_1 STRING OPTIONS (description='Column Index 1 Bin Mapping Target'),
    col_2 STRING OPTIONS (description='Column Index 2 Bin Mapping Target')
)
OPTIONS(
    description='Structural physical grid system coordinate routing array mapping.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.recycle_bin_id_matrix" "$BUCKET_NAME/recycle_bin_id_matrix.csv"

# =====================================================================
# 4. Create plastic_segregation_data Table
# =====================================================================
echo "[7/13] Setting up Table: plastic_segregation_data..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.plastic_segregation_data\` (
    category STRING OPTIONS (description='Resin Identification Code (RIC) and polymer type classification'),
    examples STRING OPTIONS (description='Common item instances matching this resin density profile'),
    recyclable STRING OPTIONS (description='Boolean validation symbol representation'),
    notes STRING OPTIONS (description='Material specific clean constraints or downstream processing limitations')
)
OPTIONS(
    description='Granular polymer resin lookup table for target execution branches.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.plastic_segregation_data" "$BUCKET_NAME/plastic_segregation_data.csv"

# =====================================================================
# 5. Create foam_segregation_data Table
# =====================================================================
echo "[8/13] Setting up Table: foam_segregation_data..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.foam_segregation_data\` (
    category STRING OPTIONS (description='Foam and polymer compound sub-profile identification'),
    examples STRING OPTIONS (description='Physical instances matching this foam composition model'),
    recyclable_or_compostable STRING OPTIONS (description='Processing indicator status representation'),
    notes STRING OPTIONS (description='Conversion options like densifiers or specialized pyrolysis notes')
)
OPTIONS(
    description='Granular Expanded Polystyrene and foam categorization structures.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.foam_segregation_data" "$BUCKET_NAME/foam_segregation_data.csv"

# =====================================================================
# 6. Create dustbin_color_codes Table
# =====================================================================
echo "[9/13] Setting up Table: dustbin_color_codes..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.dustbin_color_codes\` (
    sr_no INT64 OPTIONS (description='Serial record identifier'),
    waste_category STRING OPTIONS (description='Organic or specialized wet waste categories'),
    bin_color STRING OPTIONS (description='Plain text description name of the target container'),
    color_code STRING OPTIONS (description='Hexadecimal web standard color notation representation'),
    symbol STRING OPTIONS (description='Associated character icon or emoji marker label')
)
OPTIONS(
    description='Visual palette metadata mapping configurations for front-end HMIs or smart-bin graphics.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.dustbin_color_codes" "$BUCKET_NAME/dustbin_color_codes.csv"

# =====================================================================
# 7. Create gke_dispatch_logs Table
# =====================================================================
echo "[10/13] Setting up Table: gke_dispatch_logs..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.gke_dispatch_logs\` (
    batch_id STRING OPTIONS (description='Unique sequence execution payload block identifier'),
    image_gcs_uri STRING OPTIONS (description='Cloud Storage object identifier path used for vision inference'),
    material_category STRING OPTIONS (description='Resolved target label category returned from Gemini execution models'),
    assigned_bin_id STRING OPTIONS (description='Downstream physical coordinate routing destination mapped'),
    robot_matrix STRING OPTIONS (description='Structural kinematics variables payload passed to the execution arm'),
    hmi_message STRING OPTIONS (description='Raw string context parsed to the local physical UI console'),
    bigquery_commit_success BOOLEAN OPTIONS (description='Transactional logging pipeline health confirmation flag')
)
OPTIONS(
    description='Auditable ledger logs storing active routing events evaluated across the cluster services.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.gke_dispatch_logs" "$BUCKET_NAME/gke-dispatch-logs.csv"

# =====================================================================
# 8. Create gke_hmi_metrics Table
# =====================================================================
echo "[11/13] Setting up Table: gke_hmi_metrics..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.gke_hmi_metrics\` (
    log_id STRING OPTIONS (description='Unique monitoring event identifier token'),
    timestamp TIMESTAMP OPTIONS (description='Standard ISO UTC timeline transaction mark'),
    conveyor_queue_depth INT64 OPTIONS (description='Active object item counts pending kinematics routing analysis'),
    active_operator_id STRING OPTIONS (description='Worker session profile currently monitoring the node stream'),
    override_triggered BOOLEAN OPTIONS (description='Indicates if human intervention bypassed automated path calculations'),
    system_health_score FLOAT64 OPTIONS (description='Aggregated availability score parameter factor')
)
OPTIONS(
    description='Telemetry log data tracking operational metrics for physical control dashboards.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.gke_hmi_metrics" "$BUCKET_NAME/gke-hmi-metrics.csv"

# =====================================================================
# 9. Create gke_robotic_kinematics Table
# =====================================================================
echo "[12/13] Setting up Table: gke_robotic_kinematics..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.gke_robotic_kinematics\` (
    item_profile_id STRING OPTIONS (description='Structural density profile signature token'),
    weight_class STRING OPTIONS (description='Calculated inertial load profile categorization bracket'),
    target_bin_id STRING OPTIONS (description='Active destination bin assignment index coordinate'),
    max_extension_cm INT64 OPTIONS (description='Physical safe operating reach radius parameters'),
    arm_velocity_deg_sec FLOAT64 OPTIONS (description='Actuator sweep speed limits enforced during sort execution'),
    expected_cycle_time_ms INT64 OPTIONS (description='Target execution performance baseline window')
)
OPTIONS(
    description='Actuator profile limits queried by downstream services to map sorted motor configurations.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.gke_robotic_kinematics" "$BUCKET_NAME/gke-robotic-kinematics.csv"

# =====================================================================
# 10. Create gke_segregation_telemetry Table
# =====================================================================
echo "[13/13] Setting up Table: gke_segregation_telemetry..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.gke_segregation_telemetry\` (
    batch_id STRING OPTIONS (description='Active pipeline sequence transaction index marker'),
    timestamp TIMESTAMP OPTIONS (description='ISO entry event tracking time reference'),
    conveyor_speed_fps FLOAT64 OPTIONS (description='Realtime speed metric parsed by local accelerated RAPIDS loops'),
    weight_grams FLOAT64 OPTIONS (description='Conveyor scale payload reading index parameter'),
    ambient_light_lux INT64 OPTIONS (description='Optical sensor visibility values monitoring ingestion quality'),
    camera_temperature_c FLOAT64 OPTIONS (description='Thermal tracking index data protecting hardware from overheating')
)
OPTIONS(
    description='IoT sensor metric logs streaming from edge conveyor systems into the data lake layer.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.gke_segregation_telemetry" "$BUCKET_NAME/gke-segregation-telemetry.csv"

echo "[Success] Schema initialization and data backfills completed successfully across all 10 datasets."

echo "----------------------------------------------------------------"
echo "Setup Complete!"
echo "----------------------------------------------------------------"