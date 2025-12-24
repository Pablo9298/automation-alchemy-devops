#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWN_HOSTS_DIR="${PROJECT_ROOT}/.ssh"
KNOWN_HOSTS_FILE="${KNOWN_HOSTS_DIR}/known_hosts"

# IPs for safety
VM_IPS=(192.168.56.10 192.168.56.11 192.168.56.12 192.168.56.13 192.168.56.14)

echo "============================================"
echo "🚀 DevOps Automation - Full Deployment"
echo "============================================"
echo

echo "📋 Checking prerequisites..."
command -v vboxmanage >/dev/null 2>&1 || { echo -e "${RED}❌ VirtualBox is not installed${NC}"; exit 1; }
command -v vagrant    >/dev/null 2>&1 || { echo -e "${RED}❌ Vagrant is not installed${NC}"; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { echo -e "${RED}❌ Ansible is not installed${NC}"; exit 1; }
command -v ssh-keyscan >/dev/null 2>&1 || { echo -e "${RED}❌ ssh-keyscan is not installed (openssh-client)${NC}"; exit 1; }
echo -e "${GREEN}✅ All prerequisites installed${NC}"
echo

echo "🧹 Step 1: Destroy existing VMs (if any)..."
cd "${PROJECT_ROOT}"
vagrant destroy -f 2>/dev/null || true
echo -e "${GREEN}✅ Clean slate ready${NC}"
echo

echo "🖥️  Step 2: Creating VMs..."
vagrant up
echo -e "${GREEN}✅ All VMs created successfully${NC}"
echo

echo "🔑 Step 3: Generating Vagrant SSH config..."
vagrant ssh-config > "${PROJECT_ROOT}/.vagrant-ssh-config"
echo -e "${GREEN}✅ .vagrant-ssh-config generated${NC}"
echo

echo "🧽 Step 4: Reset project SSH known_hosts..."
mkdir -p "${KNOWN_HOSTS_DIR}"
rm -f "${KNOWN_HOSTS_FILE}"
touch "${KNOWN_HOSTS_FILE}"
chmod 600 "${KNOWN_HOSTS_FILE}"
echo -e "${GREEN}✅ Project known_hosts prepared: ${KNOWN_HOSTS_FILE}${NC}"
echo

echo "⏳ Step 5: Waiting for SSH to stabilize..."
sleep 10
echo -e "${GREEN}✅ Proceeding${NC}"
echo

echo "🔍 Step 6: Warm up SSH host keys (aliases + IPs) into project known_hosts..."

# build scan targets: aliases + IPs from inventory + fixed IP list
SCAN_TARGETS=()

# add fixed IPs
for ip in "${VM_IPS[@]}"; do SCAN_TARGETS+=("$ip"); done

# add aliases from inventory
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^\[.*\]$ ]] && continue

  alias_name="$(echo "$line" | awk '{print $1}')"
  [[ -n "$alias_name" ]] && SCAN_TARGETS+=("$alias_name")

  inv_ip="$(echo "$line" | sed -n 's/.*vm_ip=\([0-9.]\+\).*/\1/p')"
  [[ -n "$inv_ip" ]] && SCAN_TARGETS+=("$inv_ip")
done < "${PROJECT_ROOT}/ansible/inventory.ini"

# unique
SCAN_TARGETS=($(printf "%s\n" "${SCAN_TARGETS[@]}" | awk '!seen[$0]++'))

for round in {1..25}; do
  all_ok=1

  for target in "${SCAN_TARGETS[@]}"; do
    if ssh-keygen -F "${target}" -f "${KNOWN_HOSTS_FILE}" >/dev/null 2>&1; then
      continue
    fi

    # IMPORTANT: no -H (no hashing)
    ssh-keyscan -T 3 -t ed25519,ecdsa,rsa "${target}" >> "${KNOWN_HOSTS_FILE}" 2>/dev/null || true

    if ! ssh-keygen -F "${target}" -f "${KNOWN_HOSTS_FILE}" >/dev/null 2>&1; then
      all_ok=0
    fi
  done

  if [[ "${all_ok}" -eq 1 ]]; then
    echo -e "${GREEN}✅ Host keys collected${NC}"
    break
  fi

  echo -e "${YELLOW}...host keys not complete yet (${round}/25), retrying...${NC}"
  sleep 3
done
echo

echo "🧪 Step 7: Waiting until Ansible can reach all hosts..."
for i in {1..40}; do
  if ANSIBLE_CONFIG="${PROJECT_ROOT}/ansible/ansible.cfg" \
     ansible -i "${PROJECT_ROOT}/ansible/inventory.ini" all -m ping; then
    echo -e "${GREEN}✅ Ansible connectivity OK${NC}"
    break
  fi
  echo -e "${YELLOW}...not ready yet (${i}/40), retrying...${NC}"
  sleep 3
done
echo

echo "⚙️  Step 8: Configure infrastructure (ansible/main.yml)..."
ANSIBLE_CONFIG="${PROJECT_ROOT}/ansible/ansible.cfg" \
ansible-playbook -i "${PROJECT_ROOT}/ansible/inventory.ini" "${PROJECT_ROOT}/ansible/main.yml"
echo -e "${GREEN}✅ Infrastructure configured${NC}"
echo

echo "🚀 Step 9: Deploy application (ansible/deploy-app.yml)..."
ANSIBLE_CONFIG="${PROJECT_ROOT}/ansible/ansible.cfg" \
ansible-playbook -i "${PROJECT_ROOT}/ansible/inventory.ini" "${PROJECT_ROOT}/ansible/deploy-app.yml"
echo -e "${GREEN}✅ Application deployed${NC}"
echo

echo "🔍 Step 10: Quick verification..."
echo "Backend health (from app VM):"
vagrant ssh app -c "curl -m 3 -s -i http://127.0.0.1:3000/health | head -n 12" || true
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
