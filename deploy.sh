#!/bin/bash

# DevOps Project - One-Click Deployment Script
# This script automates the entire infrastructure setup and application deployment

set -e  # Exit on error

echo "============================================"
echo "🚀 DevOps Automation - Full Deployment"
echo "============================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

command -v vboxmanage >/dev/null 2>&1 || { echo -e "${RED}❌ VirtualBox is not installed${NC}"; exit 1; }
command -v vagrant >/dev/null 2>&1 || { echo -e "${RED}❌ Vagrant is not installed${NC}"; exit 1; }
command -v ansible >/dev/null 2>&1 || { echo -e "${RED}❌ Ansible is not installed${NC}"; exit 1; }

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
echo "   - Web Server 1 (192.168.56.11)"
echo "   - Web Server 2 (192.168.56.12)"
echo "   - App Server (192.168.56.13)"
echo "   - Jenkins Server (192.168.56.14)"
echo ""

vagrant up

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All VMs created successfully${NC}"
else
    echo -e "${RED}❌ Failed to create VMs${NC}"
    exit 1
fi
echo ""

# Step 3: Wait for VMs to be ready
echo "⏳ Step 3: Waiting for VMs to be ready..."
sleep 30
echo -e "${GREEN}✅ VMs are ready${NC}"
echo ""

# Step 4: Configure VMs with Ansible
echo "⚙️  Step 4: Configuring VMs (security, users, networking)..."
cd ansible
ansible-playbook -i inventory.ini playbook.yml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All VMs configured successfully${NC}"
else
    echo -e "${RED}❌ Failed to configure VMs${NC}"
    exit 1
fi
cd ..
echo ""

# Step 5: Build Docker images
echo "🐳 Step 5: Building Docker images..."

# Build backend
echo "   Building backend..."
cd app/backend
docker build -t infrastructure-backend:latest .
cd ../..

# Build frontend
echo "   Building frontend..."
cd app/frontend
docker build -t infrastructure-frontend:latest .
cd ../..

echo -e "${GREEN}✅ Docker images built${NC}"
echo ""

# Step 6: Deploy application
echo "🚀 Step 6: Deploying application..."
cd ansible
ansible-playbook -i inventory.ini deploy-app.yml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Application deployed successfully${NC}"
else
    echo -e "${RED}❌ Failed to deploy application${NC}"
    exit 1
fi
cd ..
echo ""

# Step 7: Verify deployment
echo "🔍 Step 7: Verifying deployment..."
echo ""

# Check VM status
echo "VM Status:"
vagrant status

echo ""
echo "Waiting for services to start..."
sleep 10

# Test backend
echo "Testing backend API..."
curl -s http://192.168.56.13:3000/health > /dev/null && echo -e "${GREEN}✅ Backend is healthy${NC}" || echo -e "${YELLOW}⚠️  Backend not responding yet${NC}"

# Test load balancer
echo "Testing load balancer..."
curl -s http://192.168.56.10 > /dev/null && echo -e "${GREEN}✅ Load balancer is working${NC}" || echo -e "${YELLOW}⚠️  Load balancer not responding yet${NC}"

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
echo "   vagrant ssh lb      # Load Balancer"
echo "   vagrant ssh web1    # Web Server 1"
echo "   vagrant ssh web2    # Web Server 2"
echo "   vagrant ssh app     # App Server"
echo "   vagrant ssh jenkins # Jenkins Server"
echo ""
echo "🔐 Default user: devops (password: devops123)"
echo ""
echo "📝 Next steps:"
echo "   1. Open http://192.168.56.10 in your browser"
echo "   2. Configure Jenkins at http://192.168.56.14:8080"
echo "   3. Set up CI/CD pipeline with Jenkinsfile"
echo ""
echo -e "${GREEN}✨ All done! Enjoy your automated infrastructure! ✨${NC}"
echo ""
