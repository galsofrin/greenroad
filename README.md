# GreenRoad - Complete Setup Guide

## Project Info
- **ECR:** 809809881598.dkr.ecr.eu-north-1.amazonaws.com/greenroad-app
- **GitHub:** https://github.com/galsofrin/greenroad
- **Region:** eu-north-1

---

## STEP 1: Install Prerequisites (WSL)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install basic tools
sudo apt install -y curl wget git jq unzip

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install Docker
sudo apt install -y docker.io
sudo usermod -aG docker $USER
newgrp docker

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Verify
node --version
docker --version
aws --version
terraform --version
kubectl version --client
```

---

## STEP 2: Configure AWS

```bash
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region: eu-north-1
# Default output: json

# Verify
aws sts get-caller-identity
```

---

## STEP 3: Clone and Setup Project

```bash
cd ~
git clone https://github.com/galsofrin/greenroad.git
cd greenroad
```

Or if starting fresh, create the directory and copy files:
```bash
mkdir -p ~/greenroad
cd ~/greenroad
# Copy all project files here
```

---

## STEP 4: Deploy AWS Infrastructure with Terraform

```bash
cd ~/greenroad/terraform

# Initialize
terraform init

# Preview
terraform plan

# Deploy (type 'yes')
terraform apply

# Save the outputs - YOU WILL NEED THESE!
terraform output
```

**Save these values:**
- `ec2_public_ip` - Your server IP
- `ssh_command` - How to connect

---

## STEP 5: Wait for EC2 Setup (~5-10 minutes)

```bash
# SSH into EC2
ssh -i greenroad-key.pem ubuntu@<EC2_IP>

# Check setup progress
tail -f /var/log/user-data.log

# When done, verify Minikube
minikube status
kubectl get nodes
```

---

## STEP 6: Build and Push Docker Image to ECR

```bash
# On your local machine (WSL)
cd ~/greenroad/app

# Login to ECR
aws ecr get-login-password --region eu-north-1 | docker login --username AWS --password-stdin 809809881598.dkr.ecr.eu-north-1.amazonaws.com

# Build
docker build -t 809809881598.dkr.ecr.eu-north-1.amazonaws.com/greenroad-app:latest .

# Push
docker push 809809881598.dkr.ecr.eu-north-1.amazonaws.com/greenroad-app:latest
```

---

## STEP 7: Deploy to Minikube

```bash
# SSH into EC2
ssh -i ~/greenroad/terraform/greenroad-key.pem ubuntu@<EC2_IP>

# Copy k8s manifest (run from local)
scp -i ~/greenroad/terraform/greenroad-key.pem ~/greenroad/k8s/deployment.yaml ubuntu@<EC2_IP>:/home/ubuntu/k8s/

# On EC2: Deploy
./deploy.sh latest

# Or manually:
aws ecr get-login-password --region eu-north-1 | docker login --username AWS --password-stdin 809809881598.dkr.ecr.eu-north-1.amazonaws.com/greenroad-app
docker pull 809809881598.dkr.ecr.eu-north-1.amazonaws.com/greenroad-app:latest
minikube image load 809809881598.dkr.ecr.eu-north-1.amazonaws.com/greenroad-app:latest
kubectl apply -f /home/ubuntu/k8s/deployment.yaml
kubectl rollout status deployment/greenroad
```

---

## STEP 8: Configure GitHub Actions Secrets

Go to: https://github.com/galsofrin/greenroad/settings/secrets/actions

Add these secrets:

| Secret Name | Value |
|------------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `EC2_HOST` | EC2 public IP from terraform output |
| `EC2_SSH_KEY` | Contents of `greenroad-key.pem` file |

To get the SSH key content:
```bash
cat ~/greenroad/terraform/greenroad-key.pem
```

---

## STEP 9: Push to GitHub (Triggers CI/CD)

```bash
cd ~/greenroad
git add .
git commit -m "Initial setup"
git push origin main
```

Watch the pipeline at: https://github.com/galsofrin/greenroad/actions

---

## STEP 10: Access Your Application

| Service | URL |
|---------|-----|
| **App** | http://<EC2_IP>:30080 |
| **Grafana** | http://<EC2_IP>:30300 (admin/admin123) |
| **Prometheus** | Run: `kubectl port-forward -n monitoring svc/prometheus-server 9090:80` |

---

## Useful Commands

```bash
# SSH to EC2
ssh -i ~/greenroad/terraform/greenroad-key.pem ubuntu@<EC2_IP>

# Check pods
kubectl get pods

# Check logs
kubectl logs -l app=greenroad

# Restart deployment
kubectl rollout restart deployment/greenroad

# Check services
kubectl get svc

# Minikube status
minikube status

# Access Minikube dashboard
minikube dashboard --url
```

---

## Monitoring

### Grafana Setup
1. Open http://<EC2_IP>:30300
2. Login: admin / admin123
3. Add Data Source → Prometheus
4. URL: http://prometheus-server.monitoring.svc.cluster.local
5. Import Dashboard ID: 11159 (Node.js Application)

### View Prometheus Metrics
```bash
# On EC2
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 --address 0.0.0.0 &
# Access: http://<EC2_IP>:9090
```

---

## Cleanup

```bash
cd ~/greenroad/terraform
terraform destroy
```

---

## Troubleshooting

### Minikube not starting
```bash
minikube delete
minikube start --driver=docker --cpus=2 --memory=3g
```

### Can't pull from ECR
```bash
aws ecr get-login-password --region eu-north-1 | docker login --username AWS --password-stdin 809809881598.dkr.ecr.eu-north-1.amazonaws.com
```

### Pods not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### SSH permission denied
```bash
chmod 400 greenroad-key.pem
```
