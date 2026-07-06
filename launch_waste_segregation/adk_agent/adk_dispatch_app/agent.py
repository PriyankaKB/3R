import os
import dotenv
from adk_dispatch_app import tools
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from google.adk.agents import LlmAgent
from google.cloud import bigquery

dotenv.load_dotenv()
bq_client = bigquery.Client()

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# Expose card for discovery handshake
@app.get("/.well-known/agent.json")
async def get_card():
    return {
        "name": "dispatch_agent",
        "description": "The terminating node. Receives state telemetry blocks and logs rows directly to BigQuery.",
        "url": os.getenv("DISPATCH_AGENT_URL", "http://adk-dispatch-service:8083/process"),
        "version": "1.0.0"
    }

@app.post("/process")
async def process(request: Request):
    data = await request.json()
    
    table_id = f"{bq_client.project}.mcp_waste_dataset.conveyor_dispatch_logs"
    
    row_to_insert = [{
        "batch_id": data.get("batch_id"),
        "image_gcs_uri": data.get("image_gcs_uri"),
        "material_category": data.get("material_category"),
        "assigned_bin_id": data.get("assigned_bin_id"),
        "robot_matrix": data.get("robot_execution_matrix"),
        "hmi_message": data.get("hmi_telemetry_payload")
    }]

    try:
        errors = bq_client.insert_rows_json(table_id, row_to_insert)
        data["bigquery_commit_success"] = (errors == [])
    except Exception as e:
        data["bigquery_commit_success"] = False
        data["bq_errors"] = str(e)

    # Return the entire pipeline execution log back up the call chain to the user
    return {
        "status": "CONVEYOR_PIPELINE_SUCCESS",
        "final_state_snapshot": data
    }