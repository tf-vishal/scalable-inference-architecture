# 🚀 Scalable Inference Architecture on AWS

A production-grade infrastructure prototype that deploys a distributed language model inference system across multiple EC2 instances using Terraform. A Python worker hosts Google's Gemma-3 model and exposes inference as an RPC function; a TypeScript worker fans incoming HTTP requests into that RPC and returns the result as JSON — all orchestrated by the [iii RPC engine](https://iii.dev/docs/).

This project provisions a **two-tier distributed inference architecture** on AWS where:

1. **API Tier (Worker VM)** — A public-facing EC2 instance runs the iii RPC engine with a TypeScript caller-worker that exposes an OpenAI-compatible HTTP API endpoint (`POST /v1/chat/completions`).
2. **Inference Tier (Inference VM)** — A private EC2 instance runs a Python inference-worker that loads Google's `gemma-3-270m` model and performs text generation via the `transformers` library.

The two workers communicate over WebSocket (port 49134) through the iii RPC engine, enabling **language-agnostic, cross-VM function calls**. This means you can scale the inference tier independently of the API tier.

> **📌 Project Status:** The AWS infrastructure has been **successfully provisioned and validated** (17 resources, all healthy). The iii RPC engine starts correctly and binds to the expected ports. However, the end-to-end inference pipeline is **not yet fully operational** due to application-level worker connectivity issues between the caller and inference workers. See [Known Issues](#-known-issues--debugging-log) for full details.

---

## 🏗 Architecture

### Architecture Diagram

![Architecture Diagram](docs/images/architecture-diagram.png)

### Instance Roles

**Worker VM** (Public Subnet) — This is your API gateway. It runs the iii engine which hosts both the HTTP API on port 3111 and the WebSocket RPC bus on port 49134. The TypeScript caller-worker lives here, receiving HTTP requests and forwarding them as RPC calls to the inference tier.

**Inference VM** (Private Subnet) — This is your model host. It runs the Python inference-worker which loads the Gemma-3 language model and registers `inference::run_inference` as a callable RPC function. It never connects to the engine directly — it connects to the Worker VM's engine via WebSocket.

**Bastion Host** (Public Subnet) — A lightweight SSH jump box for securely accessing the private Inference VM. It's only accessible from your operator IP.

---

## 🔧 Infrastructure Deep Dive

### 1. The Network (VPC + Subnets)

We provision an isolated network (VPC with CIDR `10.0.0.0/16`) that no one outside AWS can accidentally wander into.

- **Public Subnet (`10.0.1.0/24`)** — Has an Internet Gateway attached. This is where the Worker VM lives so it can accept public HTTP requests. Instances here get public IPs automatically.
- **Private Subnet (`10.0.2.0/24`)** — Has NO inbound internet access, only a NAT Gateway for outbound. This is where the Inference VM lives. It can reach out to the internet to download the Python model and dependencies, but nobody on the internet can reach in. This is standard network hygiene for sensitive workloads.

### 2. Security Groups (Firewalls)

Each instance gets its own security group with the minimum required permissions — nothing more.

- **Worker Security Group** — Opens TCP port 3111 to the world (`0.0.0.0/0`) for the HTTP API, TCP 22 strictly to your operator IP for SSH, and TCP port 49134 only from the private subnet (`10.0.2.0/24`) so the inference-worker can connect back to the shared iii engine.
- **Inference Security Group** — Completely blocked from inbound internet traffic. SSH is only accessible via the Bastion host. Outbound connections flow through the NAT Gateway so the VM can download the model.
- **Bastion Security Group** — SSH from your operator IP only. Nothing else in or out that isn't initiated from the bastion itself.

### 3. The EC2 Instances

- **Worker VM (`t2.micro`)** — Extremely lightweight because it only runs a Node.js web server and forwards requests. No model lives here.
- **Inference VM (`t3.large`)** — Needs more RAM because loading PyTorch and the 8-bit quantized Gemma model (~270MB) takes significant memory overhead.
- **Bastion (`t2.micro`)** — The smallest possible instance. It just forwards SSH connections.

### 4. Scripts (User Data)

When Terraform launches the VMs, it automatically runs bash scripts via cloud-init on first boot. These scripts:

- Install Node.js 20 LTS or Python 3 depending on the instance
- Install the `iii` CLI v0.12.0 (the RPC engine binary)
- Clone this repository and run `npm install` / `pip install` for dependencies
- Write the `config.yaml` for the iii engine
- Register and start `systemd` services so the workers start automatically on boot and restart on failure
  Terraform uses `templatefile()` to inject live values (like the Worker VM's private IP and port numbers) directly into these scripts before they run.

> **Key Design Decision:** The Inference VM does **not** run its own iii engine. Instead, it connects directly to the Worker VM's engine via `III_URL=ws://<worker_private_ip>:49134`. This is required by iii v0.12.0's single-engine architecture — both workers must register with the same engine to see each other's functions.

---

## 🚀 How to Deploy from Scratch

Before you start, make sure you have [Terraform ≥ 1.5](https://terraform.io/downloads) and [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) installed, and your AWS credentials configured via `aws configure`.

**1. Find your public IP** — Go to [https://checkip.amazonaws.com](https://checkip.amazonaws.com). You'll need this to whitelist your machine for SSH access. Note it down.

**2. Clone the repository:**

```bash
git clone https://github.com/tf-vishal/scalable-inference-architecture.git
cd scalable-inference-architecture/terraform
```

**3. Generate an SSH key pair** — This key is used to SSH into all three instances. Skip this step if you already have `worker-key` and `worker-key.pub` in the `terraform/` directory.

```bash
ssh-keygen -t ed25519 -f worker-key -N ""
```

**4. Configure your variables** — Create a `terraform.tfvars` file (it's already in `.gitignore`) and fill in your public IP:

```hcl
home_ip = "YOUR_PUBLIC_IP/32"  # e.g., "49.47.135.128/32"

# Optional overrides — defaults are shown below
aws_region              = "us-east-1"
worker_instance_type    = "t2.micro"
instance_type_inference = "t3.large"
http_port               = 3111
ws_port                 = 49134
```

**5. Deploy the infrastructure:**

```bash
terraform init
terraform plan   # Expected: Plan: 17 to add, 0 to change, 0 to destroy.
terraform apply  # Type 'yes' when prompted
```

**6. Wait for bootstrap** — After `terraform apply` finishes, wait ~3–5 minutes for cloud-init to complete on both VMs. This is when the instances install dependencies, clone the repo, and start the systemd services.

**7. Grab your outputs** and test the endpoint:

```bash
terraform output
# Gives you the worker_public_ip, api_endpoint, and inference_private_ip

curl -s http://<worker_public_ip>:3111/v1/chat/completions
```

### Tearing Down

```bash
terraform destroy
# Type 'yes' when prompted
# Expected: Destroy complete! Resources: 17 destroyed.
```

---

## 🌐 API Usage

```bash
curl -X POST http://<worker_public_ip>:3111/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "What is 2+2?"}
    ]
  }'
```

**Expected response (when fully operational):**

```json
{
  "response": "2 + 2 = 4"
}
```

> ⚠️ The endpoint is currently reachable (port open, engine running) but does not return inference results due to the inference worker not being fully connected. See [Known Issues](#-known-issues--debugging-log) below. No authentication is implemented yet — the API is open on port 3111.

---

## 🐛 Known Issues

The infrastructure provisioning is fully successful — all 17 AWS resources are created, healthy, and correctly networked. The issue is at the application level: the inference worker does not successfully register its RPC functions with the remote iii engine, so the HTTP endpoint returns empty responses.

**Current Blocker**

The iii engine starts and binds to both ports (3111 HTTP, 49134 WebSocket). The caller-worker registers with the engine successfully. However, the inference worker on the private subnet has not yet been confirmed to connect and register `inference::run_inference`. This is an application-level SDK communication issue, not an infrastructure issue.

---

## 📸 Deployment Evidence

### Terraform Apply Output

The infrastructure was provisioned successfully with all 17 resources:

```
Apply complete! Resources: 17 added, 0 changed, 0 destroyed.

Outputs:

api_endpoint         = "http://18.207.183.230:3111/v1/chat/completions"
inference_private_ip = "10.0.2.219"
vpc_id               = "vpc-092b1f667ec88d7c8"
worker_public_ip     = "18.207.183.230"
```

![Terraform apply showing 17 resources created successfully with all outputs](docs/images/ooutput.png)

---

### EC2 Instances — All Running

![Three EC2 instances running: inference (t3.large), worker (t2.micro), bastion (t2.micro)](docs/images/instances.png)
_All three EC2 instances in "Running" state: `alchemyst-assignment-inference` (t3.large, private), `alchemyst-assignment-worker` (t2.micro, public IP: 18.207.183.230), and `alchemyst-assignment-bastion` (t2.micro, public IP: 98.84.114.252)._

---

### VPC — Available

![VPC console showing alchemyst-assignment-vpc with CIDR 10.0.0.0/16](docs/images/vpc.png)
_Custom VPC `alchemyst-assignment-vpc` with CIDR block `10.0.0.0/16` in "Available" state._

---

## 🔗 References

- [iii Engine Documentation](https://iii.dev/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
