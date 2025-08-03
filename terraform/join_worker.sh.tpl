#!/bin/bash
# Wait for the master node to be ready and get its token
until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${path.module}/${var.private_key_path} ubuntu@${master_ip} "sudo cat /var/lib/rancher/k3s/server/node-token" > /tmp/k3s_node_token 2>/dev/null; do
  echo "Waiting for master node to generate K3s token..."
  sleep 10
done

K3S_TOKEN=$(cat /tmp/k3s_node_token)
K3S_URL="https://${master_ip}:6443"

curl -sfL https://get.k3s.io | K3S_URL="${K3S_URL}" K3S_TOKEN="${K3S_TOKEN}" sh -