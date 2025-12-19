const express = require('express');
const os = require('os');
const { execSync } = require('child_process');
const cors = require('cors');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// Helper function to execute commands
function executeCommand(command) {
  try {
    return execSync(command).toString().trim();
  } catch (error) {
    return 'N/A';
  }
}

// Get CPU usage
function getCPUUsage() {
  const cpus = os.cpus();
  let totalIdle = 0;
  let totalTick = 0;

  cpus.forEach(cpu => {
    for (let type in cpu.times) {
      totalTick += cpu.times[type];
    }
    totalIdle += cpu.times.idle;
  });

  const idle = totalIdle / cpus.length;
  const total = totalTick / cpus.length;
  const usage = 100 - ~~(100 * idle / total);
  
  return {
    usage: usage,
    cores: cpus.length,
    model: cpus[0].model
  };
}

// Get memory usage
function getMemoryUsage() {
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = totalMem - freeMem;
  
  return {
    total: (totalMem / 1024 / 1024 / 1024).toFixed(2) + ' GB',
    used: (usedMem / 1024 / 1024 / 1024).toFixed(2) + ' GB',
    free: (freeMem / 1024 / 1024 / 1024).toFixed(2) + ' GB',
    percentage: ((usedMem / totalMem) * 100).toFixed(2)
  };
}

// Get disk usage
function getDiskUsage() {
  try {
    const df = executeCommand("df -h / | tail -1 | awk '{print $2,$3,$4,$5}'").split(' ');
    return {
      total: df[0],
      used: df[1],
      available: df[2],
      percentage: df[3]
    };
  } catch (error) {
    return {
      total: 'N/A',
      used: 'N/A',
      available: 'N/A',
      percentage: 'N/A'
    };
  }
}

// Get network stats
function getNetworkStats() {
  try {
    const interfaces = os.networkInterfaces();
    const stats = [];
    
    for (let name in interfaces) {
      const iface = interfaces[name];
      const ipv4 = iface.find(i => i.family === 'IPv4');
      if (ipv4 && !ipv4.internal) {
        stats.push({
          interface: name,
          ip: ipv4.address,
          mac: ipv4.mac
        });
      }
    }
    
    return stats;
  } catch (error) {
    return [];
  }
}

// Get uptime
function getUptime() {
  const uptime = os.uptime();
  const days = Math.floor(uptime / 86400);
  const hours = Math.floor((uptime % 86400) / 3600);
  const minutes = Math.floor((uptime % 3600) / 60);
  
  return `${days}d ${hours}h ${minutes}m`;
}

// API endpoint for metrics
app.get('/api/metrics', (req, res) => {
  const metrics = {
    hostname: os.hostname(),
    platform: os.platform(),
    uptime: getUptime(),
    cpu: getCPUUsage(),
    memory: getMemoryUsage(),
    disk: getDiskUsage(),
    network: getNetworkStats(),
    timestamp: new Date().toISOString(),
    serverName: process.env.SERVER_NAME || 'appserver'
  };
  
  res.json(metrics);
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'Infrastructure Metrics API', 
    version: '1.0.0',
    endpoints: {
      metrics: '/api/metrics',
      health: '/health'
    }
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend server running on port ${PORT}`);
  console.log(`Server: ${os.hostname()}`);
});
