#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "🚀 DevOps Automation - Full Deployment"
echo "============================================"
echo

echo "📋 Checking prerequisites..."
command -v vboxmanage >/dev/null 2>&1 || { echo -e "${RED}❌ VirtualBox is not installed${NC}"; exit 1; }
command -v vagrant    >/dev/null 2>&1 || { echo -e "${RED}❌ Vagrant is not installed${NC}"; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { echo -e "${RED}❌ Ansible is not installed${NC}"; exit 1; }
echo -e "${GREEN}✅ All prerequisites installed${NC}"
echo

echo "🧹 Step 1: Destroy existing VMs..."
vagrant destroy -f 2>/dev/null || true
echo -e "${GREEN}✅ Clean slate ready${NC}"
echo

echo "🖥️  Step 2: Creating VMs..."
vagrant up
echo -e "${GREEN}✅ All VMs created successfully${NC}"
echo

echo "🔑 Step 3: Generating Vagrant SSH config..."
vagrant ssh-config > .vagrant-ssh-config
echo -e "${GREEN}✅ .vagrant-ssh-config generated${NC}"
echo

echo "⏳ Step 4: Waiting for SSH to stabilize..."
sleep 15
echo -e "${GREEN}✅ Proceeding${NC}"
echo

# Helper: wait until ansible can ping all hosts
echo "🧪 Step 5: Waiting until Ansible can reach all hosts..."
for i in {1..20}; do
  if ansible -i ansible/inventory.ini all -m ping >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Ansible connectivity OK${NC}"
    break
  fi
  echo -e "${YELLOW}...not ready yet (${i}/20), retrying...${NC}"
  sleep 3
done
echo

echo "⚙️  Step 6: Configure infrastructure (main.yml)..."
ansible-playbook -i ansible/inventory.ini ansible/main.yml
echo -e "${GREEN}✅ Infrastructure configured${NC}"
echo

echo "🚀 Step 7: Deploy application (deploy-app.yml)..."
ansible-playbook -i ansible/inventory.ini ansible/deploy-app.yml
echo -e "${GREEN}✅ Application deployed${NC}"
echo

echo "🔍 Step 8: Quick verification..."
echo "Backend health (from app VM):"
vagrant ssh app -c "curl -m 3 -s -i http://127.0.0.1:3000/health | head -n 12" || true
echo

echo "Backend metrics (from app VM):"
vagrant ssh app -c "curl -m 3 -s -i http://127.0.0.1:3000/api/metrics | head -n 12" || true
echo

echo "LB /api/metrics (from host):"
curl -m 3 -s -i http://192.168.56.10/api/metrics | head -n 12 || true
echo

echo "LB / (from host):"
curl -m 3 -s -i http://192.168.56.10/ | head -n 12 || true
echo

echo "============================================"
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo "============================================"
echo "📊 Dashboard: http://192.168.56.10"
echo "🔧 Jenkins:   http://192.168.56.14:8080"
echo
