K3s Kubernetes Cluster on AWS with Terraform
This guide provides step-by-step instructions to deploy a lightweight Kubernetes cluster using k3s on AWS EC2 instances, managed by Terraform. A bastion host is included for secure access to the private cluster nodes.

Table of Contents
Prerequisites

Terraform Setup

Deploy AWS Infrastructure

Deploy K3s Cluster

Accessing the Bastion Host

Installing K3s on Master Node

Joining Worker Nodes

Verify the Cluster

Deploy a Simple Workload

Accessing the Cluster from Local Machine

Method 1: SSH Tunneling (Recommended)

Method 2: Transferring Kubeconfig

Cleanup

1. Prerequisites
Before you begin, ensure you have the following installed and configured:

AWS Account: An active AWS account with access to the AWS Free Tier (to avoid charges).

AWS CLI: Configured with credentials that have permissions to create EC2 instances, VPCs, security groups, etc.

aws configure

Terraform: Version 1.0.0 or higher.

terraform -v

SSH Client: For connecting to EC2 instances (e.g., OpenSSH on Linux/macOS, PuTTY on Windows).

2. Terraform Setup
Create a Project Directory:

mkdir k3s-aws-cluster
cd k3s-aws-cluster

Save Terraform Code:
Save the provided Terraform code (from the previous response) into a file named main.tf inside the k3s-aws-cluster directory.

Initialize Terraform:
This command downloads the necessary providers (AWS, TLS, Local).

terraform init

3. Deploy AWS Infrastructure
Review the Plan:
This command shows you what Terraform will create, modify, or destroy. Review it carefully.

terraform plan

Apply the Configuration:
This command will provision the AWS resources as defined in main.tf. Type yes when prompted.

terraform apply

Upon successful completion, Terraform will output the public IP of your bastion host and the private IPs of your K3s master and worker nodes, along with the path to your generated SSH private key (k3s_id_rsa).

Important: A file named k3s_id_rsa will be created in your current directory. This is your SSH private key. Ensure its permissions are set correctly:

chmod 600 k3s_id_rsa

4. Deploy K3s Cluster
Now that your AWS infrastructure is ready, you'll connect to the bastion host and then to the K3s nodes to install k3s.

Accessing the Bastion Host
Use the public IP address of the bastion host from the Terraform output.

ssh -i k3s_id_rsa ubuntu@<BASTION_PUBLIC_IP>

Replace <BASTION_PUBLIC_IP> with the actual IP. You will be logged in as the ubuntu user.

Installing K3s on Master Node
From the bastion host, SSH into the K3s master node using its private IP address (also from Terraform output).

# From bastion host, connect to master
ssh -i k3s_id_rsa ubuntu@<K3S_MASTER_PRIVATE_IP>

Once connected to the master node, run the following command to install k3s as the server (master):

# On K3s Master Node
curl -sfL https://get.k3s.io | sh -

This command installs k3s and starts the server. It also configures kubectl to use the k3s cluster.

Get K3s Node Token:
After the master is installed, you need to retrieve the node token. This token is used by worker nodes to join the cluster.

# On K3s Master Node
sudo cat /var/lib/rancher/k3s/server/node-token

Copy this token. You will need it for the worker nodes.

Joining Worker Nodes
From the bastion host, SSH into the K3s worker node using its private IP address.

# From bastion host, connect to worker
ssh -i k3s_id_rsa ubuntu@<K3S_WORKER_PRIVATE_IP>

Once connected to the worker node, run the following command, replacing <K3S_MASTER_PRIVATE_IP> and <K3S_NODE_TOKEN> with your actual values:

# On K3s Worker Node
curl -sfL https://get.k3s.io | K3S_URL=https://<K3S_MASTER_PRIVATE_IP>:6443 K3S_TOKEN=<K3S_NODE_TOKEN> sh -

This command installs k3s as an agent and connects it to the master node.

5. Verify the Cluster
After installing k3s on both master and worker nodes, you can verify the cluster status from the K3s master node.

SSH back into the K3s Master Node (if you're not already there):

# From bastion host
ssh -i k3s_id_rsa ubuntu@<K3S_MASTER_PRIVATE_IP>

Run kubectl get nodes:

# On K3s Master Node
kubectl get nodes

You should see output similar to this, showing both your master and worker nodes in a Ready state:

NAME          STATUS   ROLES                  AGE     VERSION
k3s-master    Ready    control-plane,master   2m30s   v1.28.6+k3s1
k3s-worker    Ready    <none>                 1m15s   v1.28.6+k3s1

(Note: I cannot provide a live screenshot, but the above output is what you should expect.)

6. Deploy a Simple Workload
To ensure your cluster is fully functional, deploy a simple Nginx pod.

On the K3s Master Node, run the following command:

# On K3s Master Node
kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml

You should see output like:

pod/nginx-pod created

Verify the Pod Status:

# On K3s Master Node
kubectl get pods

Wait a few moments, and you should see the nginx-pod in a Running state:

NAME        READY   STATUS    RESTARTS   AGE
nginx-pod   1/1     Running   0          20s

You can also get more details about the pod:

kubectl describe pod nginx-pod

7. Accessing the Cluster from Local Machine
You can access your Kubernetes cluster from your local machine using kubectl. There are two common methods:

Method 1: SSH Tunneling (Recommended for development/testing)
This method allows you to securely tunnel your local kubectl traffic through the bastion host to the K3s master's API server.

On your Local Machine, open a new terminal and set up the SSH tunnel:

ssh -i k3s_id_rsa -N -L 6443:<K3S_MASTER_PRIVATE_IP>:6443 ubuntu@<BASTION_PUBLIC_IP>

-i k3s_id_rsa: Specifies your private key.

-N: Do not execute a remote command (just forward ports).

-L 6443:<K3S_MASTER_PRIVATE_IP>:6443: Forwards local port 6443 to the master's API server on port 6443, via the bastion.

ubuntu@<BASTION_PUBLIC_IP>: Connects to the bastion host.

Keep this terminal window open as long as you want to access the cluster.

Get Kubeconfig from Master Node:
On the K3s Master Node (via your SSH session to it), copy the Kubeconfig content:

sudo cat /etc/rancher/k3s/k3s.yaml

Copy the entire output.

Modify Kubeconfig Locally:
On your Local Machine, create a file (e.g., k3s-config.yaml) and paste the copied content. Then, edit the server line to point to localhost:6443:

apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: <YOUR_CA_DATA>
    server: https://127.0.0.1:6443 # CHANGE THIS LINE from the master's private IP
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    client-certificate-data: <YOUR_CLIENT_CERT_DATA>
    client-key-data: <YOUR_CLIENT_KEY_DATA>

Save the file.

Set KUBECONFIG Environment Variable:
In a new local terminal (where you want to run kubectl commands), set the KUBECONFIG environment variable:

export KUBECONFIG=/path/to/your/k3s-config.yaml

Replace /path/to/your/k3s-config.yaml with the actual path.

Test Local kubectl:

kubectl get nodes
kubectl get pods

You should now be able to interact with your cluster from your local machine!

Method 2: Transferring Kubeconfig (Less secure for production, but simpler for quick tests)
This method involves directly transferring the k3s.yaml file to your local machine and modifying it.

On the K3s Master Node, copy the k3s.yaml to the ubuntu user's home directory:

sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/k3s.yaml
sudo chown ubuntu:ubuntu /home/ubuntu/k3s.yaml

Exit the Master Node SSH session and return to the bastion host.

Transfer the file from Master to Bastion:

# On Bastion Host
scp -i k3s_id_rsa ubuntu@<K3S_MASTER_PRIVATE_IP>:/home/ubuntu/k3s.yaml .

Transfer the file from Bastion to Local Machine:

# On Local Machine
scp -i k3s_id_rsa ubuntu@<BASTION_PUBLIC_IP>:/home/ubuntu/k3s-aws-cluster/k3s.yaml .

(Assuming you are in the k3s-aws-cluster directory locally)

Modify Kubeconfig Locally:
Open the k3s.yaml file on your local machine. You need to change the server address from the master's private IP to the bastion's public IP.

apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: <YOUR_CA_DATA>
    server: https://<BASTION_PUBLIC_IP>:6443 # CHANGE THIS LINE from the master's private IP
  name: default
# ... rest of the file ...

Note: This method exposes port 6443 on your bastion host to the internet. While the K3s API requires certificates, it's generally safer to use SSH tunneling for direct access from your local machine. If you choose this, ensure your bastion_sg allows 6443 from your specific IP only.

Set KUBECONFIG Environment Variable:

export KUBECONFIG=/path/to/your/k3s.yaml

Test Local kubectl:

kubectl get nodes

8. Cleanup
To avoid incurring AWS costs, remember to destroy the resources when you are finished.

Navigate to your Terraform directory:

cd k3s-aws-cluster

Destroy the resources:

terraform destroy

Type yes when prompted. This will remove all AWS resources created by Terraform.
You can also manually delete the k3s_id_rsa file.

rm k3s_id_rsa




---

## Explanation of Changes and Improvements:

1.  **Centralized `main.tf`:** The provided `main.tf` was fragmented. I've consolidated all resource definitions into a single, logical `main.tf` file.
2.  **Explicit Variable Usage:** All network CIDRs, availability zones, instance types, and key names are now properly defined as variables in `variables.tf` and referenced in `main.tf`. This makes the configuration more flexible and reusable.
3.  **Dedicated Subnets:**
    * **Public Subnet:** For the bastion host, which requires a public IP.
    * **Private Master Subnet:** For the K3s master node, ensuring it's not directly exposed to the internet.
    * **Private Worker Subnet:** For the K3s worker node, also in a private subnet.
    * **NAT Gateway:** Added a NAT Gateway to the public subnet to allow instances in private subnets to access the internet (e.g., for `apt update`, `curl` commands for K3s installation).
4.  **Refined Security Groups:**
    * `aws_security_group.bastion_sg`: Allows SSH from anywhere (`0.0.0.0/0`) for your local machine to connect. **Important: In a production environment, restrict `cidr_blocks` to your specific IP address.**
    * `aws_security_group.k3s_node_sg`: Allows SSH *only* from the bastion host, and K3s API traffic (port 6443) from within the VPC, and all traffic between K3s nodes.
5.  **Automated SSH Key Pair Management:**
    * Uses `tls_private_key` to generate a new SSH key pair locally.
    * `local_file` saves the private key (`k3s-cluster-key.pem` by default) to your local machine with correct permissions (`chmod 0600`).
    * `aws_key_pair` uploads the public key to AWS.
    * This simplifies the SSH access and ensures you have the correct key for all instances.
6.  **K3s Installation via `user_data`:**
    * **Master:** The `user_data` script on the master node directly installs K3s with `--write-kubeconfig-mode 644` to ensure the `kubeconfig` file has correct permissions. It also stores the `node-token` in a temporary file for easy retrieval by workers.
    * **Worker:** The `user_data` for the worker node uses a `templatefile` (`join_worker.sh.tpl`). This template fetches the K3s token from the master (via `ssh` to the master's private IP) and then joins the cluster using the master's private IP and the retrieved token. The `depends_on` ensures the master is ready before the worker attempts to join.
7.  **Clear Outputs:** The `outputs` provide the public IP of the bastion and the private IPs of the K3s master and worker, along with the path to your generated private key.
8.  **README File:** A comprehensive `README.md` is provided, detailing the setup, access methods (including local access with SSH tunneling), cluster verification, workload deployment, and cleanup. It explicitly addresses the steps for accessing the cluster from your local computer, which was an "additional task."

This setup provides a robust and secure way to deploy a K3s cluster on AWS Free Tier resources. Remember to review and adjust security group `cidr_blocks` for production environments.
