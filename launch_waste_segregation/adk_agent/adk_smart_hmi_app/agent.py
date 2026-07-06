import os
import dotenv
import requests
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from google.adk.agents import LlmAgent
from google.adk.agents.remote_a2a_agent import RemoteA2aAgent
from a2a_types import AgentCard

dotenv.load_dotenv()

DISPATCH_AGENT_URL = os.getenv("DISPATCH_AGENT_URL", "http://adk-dispatch-service:8083/process")

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# 1. Define the final agent's card
dispatch_card = AgentCard(
    name="dispatch_agent",
    description="Commits analytical streaming log events to BigQuery storage.",
    defaultInputModes=["application/json"],
    defaultOutputModes=["application/json"],
    skills=[{"id": "bq_commit", "name": "bq_commit", "description": "BigQuery ingestion gateway", "tags": ["database"]}],
    url=DISPATCH_AGENT_URL,
    capabilities={},
    version="1.0.0"
)

dispatch_agent = RemoteA2aAgent(
    name="dispatch_agent",
    description="Agent handling final historical persistence operations.",
    agent_card=dispatch_card
)

hmi_agent = LlmAgent(
    model='gemini-2.5-flash-lite',
    name='smart_hmi_agent',
    description="Formats user telemetry alerts and passes information to the database.",
    instruction="Generate string status payloads and trigger dispatch routing logs.",
    sub_agents=[dispatch_agent]
)

@app.get("/.well-known/agent.json")
async def get_card():
    return {
        "name": "smart_hmi_agent",
        "description": "Formulates real-time notification streams and diagnostic telemetry lines.",
        "url": os.getenv("SMART_HMI_AGENT_URL", "http://adk-hmi-service:8082/process"),
        "version": "1.0.0"
    }

@app.post("/process")
async def process(request: Request):
    data = await request.json()
    
    # Format dashboard messages
    hmi_msg = f"[ALERT] Batch {data.get('batch_id')} flagged as {data.get('material_category')}. Sending to {data.get('assigned_bin_id')}."
    data["hmi_telemetry_payload"] = hmi_msg
    
    # Route data down to the final database gateway
    response = requests.post(DISPATCH_AGENT_URL, json=data).json()
    return response