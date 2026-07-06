# shared/a2a_types.py
from pydantic import BaseModel
from typing import List, Dict, Any

class AgentCard(BaseModel):
    name: str
    description: str
    defaultInputModes: List[str]
    defaultOutputModes: List[str]
    skills: List[Dict[str, Any]]
    url: str
    capabilities: Dict[str, Any]
    version: str