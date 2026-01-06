#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Starting Setup ==="

# Update system
apt-get update && apt-get upgrade -y

# Install dependencies
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release conntrack socat jq unzip

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker && systemctl start docker
usermod -aG docker ubuntu

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Setup Docker config (no credential helper)
mkdir -p /home/ubuntu/.docker
echo '{}' > /home/ubuntu/.docker/config.json
chown -R ubuntu:ubuntu /home/ubuntu/.docker

# Start Minikube as ubuntu user
sudo -u ubuntu bash <<'MINIKUBE'
cd /home/ubuntu
minikube start --driver=docker --cpus=2 --memory=1800m --disk-size=15g
minikube addons enable metrics-server
minikube addons enable ingress
kubectl cluster-info
MINIKUBE

# Create k8s directory
mkdir -p /home/ubuntu/k8s
chown ubuntu:ubuntu /home/ubuntu/k8s

# Create deployment.yaml
cat > /home/ubuntu/k8s/deployment.yaml << 'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: greenroad
  labels:
    app: greenroad
spec:
  replicas: 2
  selector:
    matchLabels:
      app: greenroad
  template:
    metadata:
      labels:
        app: greenroad
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: greenroad
          image: 809809881598.dkr.ecr.eu-north-1.amazonaws.com/greenroad-app:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 3000
          env:
            - name: NODE_ENV
              value: "production"
            - name: PORT
              value: "3000"
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 15
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: greenroad
  labels:
    app: greenroad
spec:
  type: NodePort
  selector:
    app: greenroad
  ports:
    - port: 80
      targetPort: 3000
      nodePort: 30080
K8SEOF
chown ubuntu:ubuntu /home/ubuntu/k8s/deployment.yaml

# Create deploy script
cat > /home/ubuntu/deploy.sh << 'DEPLOYSCRIPT'
#!/bin/bash
set -e
ECR_REPO="809809881598.dkr.ecr.eu-north-1.amazonaws.com/greenroad-app"
TAG=${1:-latest}
AWS_REGION="eu-north-1"

echo "=== Deploying $ECR_REPO:$TAG ==="

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin 809809881598.dkr.ecr.eu-north-1.amazonaws.com

# Pull image
docker pull $ECR_REPO:$TAG

# Load into Minikube
minikube image load $ECR_REPO:$TAG

# Apply k8s manifests
kubectl apply -f /home/ubuntu/k8s/

# Wait for rollout
kubectl rollout status deployment/greenroad --timeout=120s

# Restart port forwards
sudo systemctl restart greenroad-portforward

echo "=== Done ==="
kubectl get pods
echo ""
echo "URLs:"
PUBLIC_IP=$(curl -s ifconfig.me)
echo "  App:        http://$PUBLIC_IP:3000"
echo "  Grafana:    http://$PUBLIC_IP:3001 (admin/admin123)"
echo "  Prometheus: http://$PUBLIC_IP:9090"
DEPLOYSCRIPT
chmod +x /home/ubuntu/deploy.sh
chown ubuntu:ubuntu /home/ubuntu/deploy.sh

# Install Prometheus & Grafana
sudo -u ubuntu bash <<'MONITORING'
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/prometheus \
  --namespace monitoring --create-namespace \
  --set server.persistentVolume.enabled=false \
  --set alertmanager.persistentVolume.enabled=false

helm install grafana grafana/grafana \
  --namespace monitoring \
  --set persistence.enabled=false \
  --set adminPassword=admin123 \
  --set service.type=NodePort \
  --set service.nodePort=30300
MONITORING

# Create port forward script
cat > /home/ubuntu/start-portforward.sh << 'PFEOF'
#!/bin/bash
cd /home/ubuntu

# Wait for services to be ready
sleep 10

while true; do
    # Kill any existing port forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Start port forwards
    kubectl port-forward svc/greenroad 3000:80 --address 0.0.0.0 &
    kubectl port-forward svc/grafana -n monitoring 3001:80 --address 0.0.0.0 &
    kubectl port-forward svc/prometheus-server -n monitoring 9090:80 --address 0.0.0.0 &
    
    # Wait and restart if any fails
    sleep 60
done
PFEOF
chmod +x /home/ubuntu/start-portforward.sh
chown ubuntu:ubuntu /home/ubuntu/start-portforward.sh

# Create systemd service for port forwarding
cat > /etc/systemd/system/greenroad-portforward.service << 'SERVICEEOF'
[Unit]
Description=GreenRoad Port Forwarding
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=ubuntu
Environment=HOME=/home/ubuntu
Environment=KUBECONFIG=/home/ubuntu/.kube/config
ExecStart=/home/ubuntu/start-portforward.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Enable and start port forward service
systemctl daemon-reload
systemctl enable greenroad-portforward.service
systemctl start greenroad-portforward.service

echo "=== Setup Complete ==="
echo ""
echo "URLs (after deploying app):"
PUBLIC_IP=$(curl -s ifconfig.me)
echo "  App:        http://$PUBLIC_IP:3000"
echo "  Grafana:    http://$PUBLIC_IP:3001 (admin/admin123)"
echo "  Prometheus: http://$PUBLIC_IP:9090"
