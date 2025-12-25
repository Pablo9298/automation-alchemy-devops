# Verification & Review Checklist

This document contains practical commands to demonstrate that the infrastructure meets the review requirements.

> Assumptions:
> - You are in the project root.
> - Vagrant VMs are up and reachable.
> - Your SSH config/hosts are already configured (example: `.ssh/config` in project root).
> - User: `devops`

---

## 1) Hostnames are correct and resolvable

### Show hostname on each VM

```bash
for host in lb web1 web2 app jenkins; do
  echo "===== $host ====="
  ssh -F .ssh/config devops@$host "hostname"
done
```

### Ping hostnames from another VM

```bash
ssh -F .ssh/config devops@web1 "
  ping -c 1 loadbalancer &&
  ping -c 1 appserver &&
  ping -c 1 jenkinsserver
"
```

### Full mesh check (ping all from each)

```bash
for src in lb web1 web2 app jenkins; do
  echo "===== from $src ====="
  ssh -F .ssh/config devops@$src "
    ping -c 1 loadbalancer    >/dev/null && echo loadbalancer OK
    ping -c 1 webserver1     >/dev/null && echo webserver1 OK
    ping -c 1 webserver2     >/dev/null && echo webserver2 OK
    ping -c 1 appserver      >/dev/null && echo appserver OK
    ping -c 1 jenkinsserver  >/dev/null && echo jenkinsserver OK
  "
done
```

---

## 2) Static IP addresses persist after reboot

### Show IPv4 addresses

```bash
for host in lb web1 web2 app jenkins; do
  echo "===== $host ====="
  ssh -F .ssh/config devops@$host "ip -4 a | grep inet"
done
```

### Reboot one VM and verify IP is the same

```bash
ssh -t -F .ssh/config devops@web1 "sudo reboot"
# wait until SSH is back, then:
ssh -F .ssh/config devops@web1 "ip a | grep 192.168.56"
```

---

## 3) Only the Load Balancer is accessible externally

### Load Balancer (should respond)

```bash
curl -I http://192.168.56.10
```

### Web servers (should NOT be exposed externally — depends on your Vagrant networking/firewall rules)

```bash
curl -I http://192.168.56.11
curl -I http://192.168.56.12
```

### App server (should not be directly reachable externally)

```bash
curl -I http://192.168.56.13:3000
```

### Backend reachable only through LB (example endpoint)

```bash
curl http://192.168.56.10/api/metrics
```

> If your current setup allows access to web/app VMs from the host, explain that the *intended* design is:
> external access → LB only; internal traffic → between VMs.

---

## 4) VMs are up-to-date with security patches

```bash
for host in lb web1 web2 app jenkins; do
  echo "===== $host ====="
  ssh -t -F .ssh/config devops@$host 'bash -lc "
    sudo apt update -qq
    echo "Upgradable packages:"
    sudo apt list --upgradable
  "'
done
```

---

## 5) `devops` user exists on each VM

```bash
for host in lb web1 web2 app jenkins; do
  echo "===== $host ====="
  ssh -F .ssh/config       -o BatchMode=yes       devops@$host "grep '^devops:' /etc/passwd"
done
```

Or by IP:

```bash
for ip in 192.168.56.10 192.168.56.11 192.168.56.12 192.168.56.13 192.168.56.14; do
  echo "===== $ip ====="
  ssh -o UserKnownHostsFile=./.ssh/known_hosts       -o StrictHostKeyChecking=yes       -o BatchMode=yes       devops@$ip "grep '^devops:' /etc/passwd"
done
```

---

## 6) SSH keys only (password login disabled)

### Key login should work

```bash
ssh -F .ssh/config devops@jenkins
```

### Password auth attempt should fail

```bash
ssh -F .ssh/config   -o PreferredAuthentications=password   -o PubkeyAuthentication=no   devops@jenkins
```

---

## 7) `devops` is in sudo group

```bash
for host in lb web1 web2 app jenkins; do
  echo "===== $host ====="
  ssh -F .ssh/config -o BatchMode=yes devops@$host "groups devops"
done
```

Expected output includes: `devops sudo`

---

## 8) Sudo requires password (not passwordless)

```bash
ssh -F .ssh/config devops@jenkins
sudo visudo
```

You should be prompted for a password.

---

## 9) Root login disabled

```bash
for host in lb web1 web2 app jenkins; do
  echo "===== $host ====="
  ssh -F .ssh/config -o BatchMode=yes root@$host true     && echo "❌ FAIL: root login allowed"     || echo "✅ OK: root login denied"
done
```

---

## 10) Only `devops` can login

Example (should fail):

```bash
ssh linus_torvalds@192.168.56.10
```

Example (should succeed):

```bash
ssh -F .ssh/config devops@jenkins
```

---

## 11) Secure umask is set

```bash
for ip in 192.168.56.10 192.168.56.11 192.168.56.12 192.168.56.13 192.168.56.14; do
  echo "===== $ip ====="
  ssh -o UserKnownHostsFile=./.ssh/known_hosts       -o StrictHostKeyChecking=yes       devops@$ip "bash -lc umask"
done
```

---

## 12) Container tools installed where required

```bash
for host in lb web1 web2 app jenkins; do
  echo "===== $host ====="
  ssh -F .ssh/config devops@$host "docker --version || echo 'Docker not installed'"
done
```

```bash
for host in web1 web2 app jenkins; do
  echo "===== $host ====="
  ssh -F .ssh/config devops@$host "docker compose version"
done
```

```bash
ssh -F .ssh/config devops@app "systemctl status docker --no-pager | head -n 5"
```

---

## 13) Firewall rules (no unused ports open)

```bash
for host in lb web1 web2 app jenkins; do
  echo "===== $host ====="
  ssh -t -F .ssh/config devops@$host "sudo ufw status verbose"
done
```

---

## 14) Backend container runs on app server

```bash
ssh -F .ssh/config devops@app
docker ps
docker logs backend
curl http://localhost:3000/health
```

---

## 15) Frontend on both web servers (container demo)

> If system nginx conflicts with port 80, temporarily stop/disable it.

### 0) Preparation (optional)

```bash
for host in web1 web2; do
  echo "===== disable system nginx on $host ====="
  ssh -t -F .ssh/config devops@$host "sudo systemctl stop nginx && sudo systemctl disable nginx"
done
```

### 1) Run frontend container on both web servers

```bash
for host in web1 web2; do
  echo "===== start frontend on $host ====="
  ssh -t -F .ssh/config devops@$host "
    docker rm -f frontend 2>/dev/null || true
    docker run -d --name frontend -p 80:80 -v /var/www/html:/usr/share/nginx/html:ro nginx:alpine
  "
done
```

### 2) Confirm containers are running

```bash
for host in web1 web2; do
  echo "===== $host: docker ps ====="
  ssh -F .ssh/config devops@$host "docker ps"
done
```

### 3) Exec into container (review requirement)

```bash
ssh -F .ssh/config devops@web1
docker exec -it frontend /bin/sh
ls /usr/share/nginx/html
exit
```

### Restore original state after demo

A) Remove containers:

```bash
for host in web1 web2; do
  echo "===== remove frontend container on $host ====="
  ssh -t -F .ssh/config devops@$host "docker rm -f frontend || true"
done
```

B) Re-enable system nginx:

```bash
for host in web1 web2; do
  echo "===== enable system nginx on $host ====="
  ssh -t -F .ssh/config devops@$host "sudo systemctl enable nginx && sudo systemctl start nginx"
done
```

C) Quick status check:

```bash
for host in web1 web2; do
  echo "===== $host: nginx status ====="
  ssh -F .ssh/config devops@$host "systemctl is-active nginx"
done
```

---

## 16) Load balancing works (round-robin)

### Show LB config and service status

```bash
ssh -t -F .ssh/config devops@lb "sudo cat /etc/nginx/sites-available/loadbalancer"
ssh -t -F .ssh/config devops@lb "sudo systemctl status nginx"
```

Explain during review:

- NGINX uses an `upstream` block with two backends.
- Default algorithm is **round-robin**, so requests are distributed evenly.

### Put markers (Ansible copy) and curl multiple times

```bash
ansible -i ansible/inventory.ini web1 -b -m copy   -a "dest=/var/www/html/index.html content='WEB1
' mode=0644"

ansible -i ansible/inventory.ini web2 -b -m copy   -a "dest=/var/www/html/index.html content='WEB2
' mode=0644"
```

```bash
for i in {1..10}; do
  curl -s http://192.168.56.10
done
```

Expected: output alternates between `WEB1` and `WEB2`.

### Restore original frontend file

```bash
ansible -i ansible/inventory.ini webservers -b -m copy   -a "src=app/frontend/index.html dest=/var/www/html/index.html mode=0644"
```
