import os
import dotenv
from adk_robotic_arm_app import tools
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from google.adk.agents import LlmAgent
from google.adk.agents.remote_a2a_agent import RemoteA2aAgent
from a2a_types import AgentCard

dotenv.load_dotenv()
PROJECT_ID = os.getenv('GOOGLE_CLOUD_PROJECT', 'project_not_set')

# The internal GKE DNS URL for the next step in the pipeline
HMI_AGENT_URL = os.getenv("SMART_HMI_AGENT_URL", "http://adk-hmi-service:8082/process")

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# 1. Define the next agent's card
hmi_card = AgentCard(
    name="smart_hmi_agent",
    description="Formulates telemetry notifications and updates UI displays.",
    defaultInputModes=["application/json"],
    defaultOutputModes=["application/json"],
    skills=[{"id": "hmi_alert", "name": "hmi_alert", "description": "Formulates UI status text streams.", "tags": ["ui"]}],
    url=HMI_AGENT_URL,
    capabilities={},
    version="1.0.0"
)

# 2. Setup the Remote A2A instance
smart_hmi_agent = RemoteA2aAgent(
    name="smart_hmi_agent",
    description="Agent handling downstream dashboard updates and user messages.",
    agent_card=hmi_card
)

maps_toolset = tools.get_maps_mcp_toolset()
bigquery_toolset = tools.get_bigquery_mcp_toolset()

# 3. Define the Robot Agent itself
robot_agent = LlmAgent(
    model='gemini-2.5-flash-lite',
    name='robotic_arm_agent',
    description="Calculates conveyor sort locations and physics trajectory coordinates.",
    instruction="""
        Evaluate the material category and conveyor speed given. 
        Calculate the appropriate physical BIN assignment:
        For example:
        - PLASTIC -> BIN-01
        - FOAM -> BIN-00
        - GLASS -> BIN-01
        - PAPER -> BIN-12
        - METAL -> BIN-11
        - TEXTILE -> BIN-12
        Output JSON mapping and hand off the task to the smart_hmi_agent.
    """,
    sub_agents=[smart_hmi_agent]
)

# Expose its own Agent Card for discovery
@app.get("/.well-known/agent.json")
async def get_card():
    return {
        "name": "robotic_arm_agent",
        "description": "Calculates kinematics and assigns physical sort bin mappings.",
        "url": os.getenv("ROBOTIC_ARM_AGENT_URL", "http://adk-robotic-service:8081/process"),
        "version": "1.0.0"
    }

@app.post("/process")
async def process(request: Request):
    data = await request.json()
    
    # Process the kinematics (Deterministic or LLM-augmented helper)
    material = data.get("material_category", "UNKNOWN")
    speed = data.get("conveyor_speed_fps", 4.5)
    
    bin_map = {"FOAM": "BIN-01", "PLASTIC": "BIN-02", "PAPER": "BIN-03", "METAL": "BIN-04"}
    assigned_bin = bin_map.get(material, "BIN-MISC")
    
    # Enrich the payload state
    data["assigned_bin_id"] = assigned_bin
    data["robot_execution_matrix"] = f"ROTATION_Y: 45deg, SPEED_FACTOR: {speed}"
    
    # Collaborate: Cascade message forward via the sub-agent interface over GKE CoreDNS
    # Instead of manual requests, your A2A format allows root_agent structure execution
    import requests
    response = requests.post(HMI_AGENT_URL, json=data).json()
    return response