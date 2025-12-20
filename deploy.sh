#!/bin/bash

# DevOps Project - One-Click Deployment Script
# Automates: clean slate -> VMs -> Ansible config -> build images -> deploy -> verify

set -euo pipefail

echo "============================================"
echo "🚀 DevOps Automation - Full Deployment"
echo "============================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v vboxmanage >/dev/null 2>&1 || { echo -e "${RED}❌ VirtualBox is not installed${NC}"; exit 1; }
command -v vagrant    >/dev/null 2>&1 || { echo -e "${RED}❌ Vagrant is not installed${NC}"; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { echo -e "${RED}❌ Ansible is not installed${NC}"; exit 1; }
echo -e "${GREEN}✅ All prerequisites installed${NC}"
echo ""

# Step 1: Destroy existing VMs (clean slate)
echo "🧹 Step 1: Cleaning up existing VMs..."
vagrant destroy -f 2>/dev/null || true
echo -e "${GREEN}✅ Clean slate ready${NC}"
echo ""

# Step 2: Create VMs
echo "🖥️  Step 2: Creating 5 VMs..."
echo "   - Load Balancer (192.168.56.10)"
echo "   - Web Server 1  (192.168.56.11)"
echo "   - Web Server 2  (192.168.56.12)"
echo "   - App Server    (192.168.56.13)"
echo "   - Jenkins       (192.168.56.14)"
echo ""

vagrant up
echo -e "${GREEN}✅ All VMs created successfully${NC}"
echo ""

# Step 3: Generate Vagrant SSH config (required for Ansible)
echo "🔑 Step 3: Generating Vagrant SSH config..."
vagrant ssh-config > .vagrant-ssh-config
echo -e "${GREEN}✅ .vagrant-ssh-config generated${NC}"
echo ""

# Step 4: Wait for VMs to be ready
echo "⏳ Step 4: Waiting for VMs to be ready..."
sleep 20
echo -e "${GREEN}✅ VMs should be reachable${NC}"
echo ""

# Step 5: Configure VMs with Ansible (RUN FROM PROJECT ROOT!)
echo "⚙️  Step 5: Configuring VMs with Ansible (security, users, networking, docker, nginx, jenkins)..."
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
echo -e "${GREEN}✅ All VMs configured successfully${NC}"
echo ""

echo "🐳 Step 6: Building Docker images on Jenkins VM..."
vagrant ssh jenkins -c "
  set -e
  rm -rf ~/automation-alchemy-devops
  git clone https://github.com/Pablo9298/automation-alchemy-devops.git ~/automation-alchemy-devops
  cd ~/automation-alchemy-devops/app/backend
  sudo docker build -t infrastructure-backend:latest .
  cd ~/automation-alchemy-devops/app/frontend
  sudo docker build -t infrastructure-frontend:latest .
"
echo -e "${GREEN}✅ Docker images built on Jenkins VM${NC}"
echo ""

# Step 7: Deploy application
echo "🚀 Step 7: Deploying application..."
ansible-playbook -i ansible/inventory.ini ansible/deploy-app.yml
echo -e "${GREEN}✅ Application deployed successfully${NC}"
echo ""

# Step 8: Verify deployment
echo "🔍 Step 8: Verifying deployment..."
echo ""

echo "VM Status:"
vagrant status
echo ""

echo "Waiting for services to start..."
sleep 10

echo "Testing backend API..."
curl -s http://192.168.56.13:3000/health >/dev/null \
  && echo -e "${GREEN}✅ Backend is healthy${NC}" \
  || echo -e "${YELLOW}⚠️  Backend not responding yet${NC}"

echo "Testing load balancer..."
curl -s http://192.168.56.10 >/dev/null \
  && echo -e "${GREEN}✅ Load balancer is working${NC}" \
  || echo -e "${YELLOW}⚠️  Load balancer not responding yet${NC}"

echo ""
echo "============================================"
echo "🎉 Deployment Complete!"
echo "============================================"
echo ""
echo "📊 Access Points:"
echo "   • Application:  http://192.168.56.10"
echo "   • Backend API:  http://192.168.56.13:3000/api/metrics"
echo "   • Jenkins:      http://192.168.56.14:8080"
echo ""
echo "🔑 SSH Access:"
echo "   vagrant ssh lb"
echo "   vagrant ssh web1"
echo "   vagrant ssh web2"
echo "   vagrant ssh app"
echo "   vagrant ssh jenkins"
echo ""
echo "🔐 Default user: devops (password: devops123)"
echo ""
echo -e "${GREEN}✨ All done! Enjoy your automated infrastructure! ✨${NC}"
echo ""
