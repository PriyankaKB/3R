// api.js
const BASE_URL = process.env.REACT_APP_ORCHESTRATOR_URL || "http://localhost:8005";

export async function callAgent(agent, endpoint, payload = {}) {
  const res = await fetch(`${BASE_URL}/${agent}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return res.json();
}
