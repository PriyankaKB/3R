import logo from './logo.svg';
import './App.css';
import React, { useState } from "react";
import AgentCard from "./components/AgentCard";

function App() {
  const agents = [
    "adk_segregation_app",
    "adk_robotic_arm_app",
    "adk_smart_hmi_app",
    "adk_dispatch_app",
  ];

// Operational Real-time State Tracking
  const [activeTab, setActiveTab] = useState('hmi_control');
  const [systemStatus, setSystemStatus] = useState('OPERATIONAL');
  const [conveyorSpeed, setConveyorSpeed] = useState(4.5);
  const [latestDispatch, setLatestDispatch] = useState({
    batch_id: "B-104",
    category: "PLASTIC",
    bin_id: "BIN-00",
    cycle_time: "600ms"
  });

  // Simulation loop mimicking GKE edge state updates
  useEffect(() => {
    const interval = setInterval(() => {
      setConveyorSpeed(+(4.2 + Math.random() * 0.6).toFixed(2));
    }, 3000);
    return () => clearInterval(interval);
  }, []);
  

  return (
    <div style={{ padding: "2rem" }}>
      <h1>Agent Dashboard</h1>
      <p>Interact with your FastAPI agents via the orchestrator.</p>
      {agents.map(agent => (
        <AgentCard key={agent} agent={agent} />
      ))}
    </div>
  );

return (
    <div className="min-h-screen bg-slate-900 text-slate-100 font-sans flex flex-col">
      {/* Top Navigation Control Bar */}
      <header className="bg-slate-950 border-b border-slate-800 p-4 flex justify-between items-center shadow-lg">
        <div className="flex items-center space-x-3">
          <span className="text-2xl">♻️</span>
          <h1 className="text-xl font-bold tracking-wider text-emerald-400">PROJECT 3R // SMART HMI</h1>
                {agents.map(agent => (
        <AgentCard key={agent} agent={agent} />
      ))}
        </div>
        <div className="flex space-x-2 bg-slate-900 p-1 rounded-lg border border-slate-800">
          <button 
            onClick={() => setActiveTab('hmi_control')}
            className={`px-4 py-2 rounded-md font-medium text-sm transition-all ${activeTab === 'hmi_control' ? 'bg-emerald-500 text-slate-950 shadow' : 'text-slate-400 hover:text-white'}`}>
            🎛️ Telemetry Control
          </button>
          <button 
            onClick={() => setActiveTab('looker_analytics')}
            className={`px-4 py-2 rounded-md font-medium text-sm transition-all ${activeTab === 'looker_analytics' ? 'bg-emerald-500 text-slate-950 shadow' : 'text-slate-400 hover:text-white'}`}>
            📊 Looker Analytics
          </button>
          <button 
            onClick={() => setActiveTab('manuals')}
            className={`px-4 py-2 rounded-md font-medium text-sm transition-all ${activeTab === 'manuals' ? 'bg-emerald-500 text-slate-950 shadow' : 'text-slate-400 hover:text-white'}`}>
            📖 Manuals & Docs
          </button>
        </div>
      </header>

      {/* Main Container Layout */}
      <main className="flex-1 p-6 max-w-7xl w-full mx-auto grid grid-cols-1 gap-6">
        
        {/* Tab 1: Telemetry Control Interface */}
        {activeTab === 'hmi_control' && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* System Status Metrics Card */}
            <div className="bg-slate-950 p-6 rounded-xl border border-slate-800 shadow-md flex flex-col justify-between">
              <div>
                <h3 className="text-slate-400 text-sm font-semibold uppercase tracking-wider mb-2">Conveyor Node Metrics</h3>
                <div className="text-4xl font-extrabold text-white mb-2">{conveyorSpeed} <span className="text-lg text-slate-500">FPS</span></div>
                <p className="text-xs text-slate-400">Monitored using NVIDIA RAPIDS Zero-Code Drop-in acceleration framework</p>
              </div>
              <div className="mt-4 pt-4 border-t border-slate-900 flex justify-between items-center">
                <span className="text-sm text-slate-400">System Loop Health</span>
                <span className="px-2 py-1 text-xs font-bold bg-emerald-500/10 text-emerald-400 rounded border border-emerald-500/20">ONLINE</span>
              </div>
            </div>

            {/* Robotic Kinematics Real-time Card */}
            <div className="bg-slate-950 p-6 rounded-xl border border-slate-800 shadow-md flex flex-col justify-between">
              <div>
                <h3 className="text-slate-400 text-sm font-semibold uppercase tracking-wider mb-2">Robotic Arm State</h3>
                <div className="text-xl font-bold text-white mb-1">Target Coordinates Mapped</div>
                <div className="text-sm font-mono text-amber-400 bg-slate-900 p-2 rounded border border-slate-800 mt-2">
                  ROTATION_Y: 45deg | FACTOR: {conveyorSpeed}
                </div>
              </div>
              <div className="mt-4 pt-4 border-t border-slate-900 flex justify-between items-center">
                <span className="text-sm text-slate-400">Active Routing Matrix</span>
                <span className="text-sm font-bold text-white font-mono">{latestDispatch.bin_id}</span>
              </div>
            </div>

            {/* Last Handled Batch Item Card */}
            <div className="bg-slate-950 p-6 rounded-xl border border-slate-800 shadow-md flex flex-col justify-between">
              <div>
                <h3 className="text-slate-400 text-sm font-semibold uppercase tracking-wider mb-2">Gemini Vision Result</h3>
                <div className="text-3xl font-black text-emerald-400 mb-1">{latestDispatch.category}</div>
                <p className="text-xs text-slate-400">Validated via Gemini 2.5 Flash context schema mapping</p>
              </div>
              <div className="mt-4 pt-4 border-t border-slate-900 flex justify-between items-center">
                <span className="text-sm text-slate-400">Batch ID</span>
                <span className="text-sm font-mono text-slate-300">{latestDispatch.batch_id}</span>
              </div>
            </div>

            {/* BigQuery Source Dataset Overview Grid */}
            <div className="col-span-1 md:col-span-3 bg-slate-950 p-6 rounded-xl border border-slate-800 shadow-md">
              <h3 className="text-lg font-bold mb-4 text-slate-200 flex items-center">
                <span className="mr-2">🗄️</span> BigQuery Pipeline Core Taxonomy Datasets
              </h3>
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-300">
                  <thead className="bg-slate-900 text-slate-400 text-xs uppercase font-mono border-b border-slate-800">
                    <tr>
                      <th className="p-3">Dataset / Table Name</th>
                      <th className="p-3">Data Role Context</th>
                      <th className="p-3">GKE Edge Consumer Node Access</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-900">
                    <tr>
                      <td className="p-3 font-mono font-bold text-emerald-400">waste_categories_data</td>
                      <td className="p-3">Master taxonomy mapping for the 2x3 physical sort layout matrix</td>
                      <td className="p-3 font-mono text-xs">segregation_agent (LlmAgent)</td>
                    </tr>
                    <tr>
                      <td className="p-3 font-mono font-bold text-emerald-400">gke_segregation_telemetry</td>
                      <td className="p-3">IoT conveyor belt speed, lux index readings, and payload weights</td>
                      <td className="p-3 font-mono text-xs">cudf.pandas processing thread</td>
                    </tr>
                    <tr>
                      <td className="p-3 font-mono font-bold text-emerald-400">gke_dispatch_logs</td>
                      <td className="p-3">Auditable transactional ledger tracking Gemini classifications</td>
                      <td className="p-3 font-mono text-xs">FastAPI /process routing endpoint</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* Tab 2: Embedded Looker Dashboard Section */}
        {activeTab === 'looker_analytics' && (
          <div className="bg-slate-950 p-6 rounded-xl border border-slate-800 shadow-md flex flex-col h-[700px]">
            <div className="flex justify-between items-center mb-4">
              <div>
                <h2 className="text-lg font-bold text-white">Looker Smart Business Intelligence Stream</h2>
                <p className="text-xs text-slate-400">Live analytical visualization dashboard tracking GKE cluster actions and BigQuery telemetry metrics</p>
              </div>
              <button 
                onClick={() => alert("Simulating Refresh of BigQuery Cache Layers...")}
                className="px-3 py-1 bg-slate-900 border border-slate-800 rounded text-xs hover:text-emerald-400 font-mono transition-colors">
                🔄 FORCE SYNC
              </button>
            </div>
            {/* Embedded Iframe Container */}
            <div className="flex-1 bg-slate-900 rounded-lg border border-slate-800 overflow-hidden relative flex items-center justify-center">
              {/* Replace the src line with your production Looker SSO / embed link parameters */}
              <iframe
                title="Looker Pipeline Analytics"
                className="w-full h-full absolute inset-0 z-10 bg-slate-900"
                src="https://lookerstudio.google.com/embed/reporting/your-dashboard-id"
                frameBorder="0"
                allowFullScreen
              />
            </div>
          </div>
        )}

        {/* Tab 3: System Operation Manual Documentation */}
        {activeTab === 'manuals' && (
          <div className="bg-slate-950 p-6 rounded-xl border border-slate-800 shadow-md prose prose-invert max-w-none">
            <h2 className="text-xl font-bold text-slate-200 mb-4 border-b border-slate-800 pb-2">📖 GKE Pipeline Runbook & Standard Manuals</h2>
            <div className="space-y-4 text-sm text-slate-400">
              <div className="bg-slate-900 p-4 rounded-lg border border-slate-800">
                <h4 className="font-bold text-slate-200 mb-1">Heterogeneous Cluster Architecture Standard</h4>
                <p>The system routes workloads across 4 dedicated GKE nodes. System operations require 3 CPU nodes for routing proxies, agent orchestration APIs, and database commit triggers. Image analytics run on a single dedicated GPU node configuration.</p>
              </div>
              <div className="bg-slate-900 p-4 rounded-lg border border-slate-800">
                <h4 className="font-bold text-slate-200 mb-1">NVIDIA RAPIDS cuDF Acceleration Protocol</h4>
                <p>Telemetry file reads utilize `cudf.pandas`. When processing inside the GPU node pool, file parsing operations execute directly inside the CUDA hardware layer. If tasks land on a fallback CPU node, processing switches back automatically without triggering execution fault exceptions.</p>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

export default App;