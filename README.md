# Infra Automation – DevOps Infrastructure Project

## Overview

This project demonstrates a DevOps automation setup using **Vagrant, Ansible, Docker, Jenkins, and Nginx**.

The focus of the project is:
- infrastructure provisioning with Vagrant
- configuration management with Ansible
- CI/CD automation with Jenkins
- containerized application deployment with Docker
- load balancing using Nginx

The project reflects the **actual implementation** and is intended for learning, review, and portfolio demonstration.

---

## Architecture

The infrastructure consists of several virtual machines managed by **Vagrant** and configured using **Ansible**.

| VM | Purpose |
|----|--------|
| loadbalancer | Nginx load balancer |
| web servers | Serve frontend via Nginx |
| app server | Runs backend (Node.js) in Docker |
| jenkins | CI/CD automation |

Traffic flow:

Client → Load Balancer → Web Servers → Application

---

## Technology Stack

- **Virtualization**: Vagrant, VirtualBox
- **Configuration Management**: Ansible
- **CI/CD**: Jenkins (JCasC, seed jobs)
- **Containers**: Docker, Docker Compose
- **Load Balancer**: Nginx
- **Backend**: Node.js
- **OS**: Linux (Ubuntu-based VMs)

---

## Project Structure (Actual)

```
infra-automation/
├── Vagrantfile
├── Jenkinsfile
├── deploy.sh
├── README.md
├── ansible/
│   ├── ansible.cfg
│   ├── inventory.ini
│   ├── main.yml
│   ├── playbook.yml
│   ├── deploy-app.yml
│   ├── group_vars/
│   │   └── all.yml
│   └── roles/
│       └── loadbalancer/
│           ├── tasks/
│           │   └── main.yml
│           ├── handlers/
│           │   └── main.yml
│           └── templates/
│               └── loadbalancer.conf.j2
├── app/
│   ├── docker-compose.yml
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── server.js
│   └── frontend/
│       ├── index.html
│       └── nginx.conf
├── jenkins/
│   ├── jcasc.yml
│   ├── jobs.groovy
│   ├── plugins.txt
│   └── seed-job.xml
└── vagrant/
```

---

## Prerequisites

- VirtualBox
- Vagrant
- Ansible
- Docker
- Git

Verify installations:

```bash
vagrant --version
ansible --version
docker --version
git --version
```

---

## Deployment

### One-Click Deployment

```bash
chmod +x deploy.sh
./deploy.sh
```

This will:
- start VMs
- apply Ansible configuration
- configure load balancer
- deploy application containers
- prepare Jenkins environment

---

### Manual Deployment

```bash
vagrant up
ansible-playbook -i ansible/inventory.ini ansible/main.yml
```

---

## CI/CD (Jenkins)

Jenkins is configured using **Jenkins Configuration as Code (JCasC)**.

- `jcasc.yml` – Jenkins system configuration
- `jobs.groovy` – seed job DSL
- `plugins.txt` – Jenkins plugins list
- `Jenkinsfile` – pipeline definition

---

## Load Balancer Verification (Review)

On the load balancer VM:

```bash
cat /etc/nginx/nginx.conf
sudo systemctl status nginx
```

Refresh the application multiple times to confirm traffic is distributed correctly.

---

## Idempotency

Re-run Ansible playbook:

```bash
ansible-playbook -i ansible/inventory.ini ansible/main.yml
```

The second run should produce no changes.

---

## Cleanup

```bash
vagrant destroy -f
```

---

## Purpose

This project was created to demonstrate:
- Infrastructure as Code
- Automation and repeatability
- CI/CD pipelines
- Load balancing fundamentals

---

## Author

**Pavlo (Pablo9298)**  
DevOps / Full-Stack Developer


---

## Verification (Review)

For a step-by-step set of commands to demonstrate hostnames, networking, security hardening, firewall rules, containers, and load balancing, see:

- `VERIFICATION.md`
