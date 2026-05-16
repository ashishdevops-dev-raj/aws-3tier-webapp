# AWS 3-Tier Web Application

A complete, production-style 3-tier web application deployed on AWS using Terraform.

**Stack**: React • Node.js + Express • MySQL on AWS RDS • Docker • NGINX • Terraform • Ubuntu • AWS EC2 / VPC / ALB

---

## Table of Contents

1. [Architecture](#1-architecture)
2. [Folder Structure](#2-folder-structure)
3. [Prerequisites](#3-prerequisites)
4. [Local Development (Docker Compose)](#4-local-development)
5. [Manual Local Run (no Docker)](#5-manual-local-run)
6. [Dockerization Details](#6-dockerization-details)
7. [Push Images to Docker Hub](#7-push-images-to-docker-hub)
8. [AWS Deployment with Terraform](#8-aws-deployment-with-terraform)
9. [Post-Deployment: Initialize the Database](#9-post-deployment-initialize-the-database)
10. [API Testing](#10-api-testing)
11. [Architecture Diagram](#11-architecture-diagram)
12. [Free Tier Cost Notes](#12-free-tier-cost-notes)
13. [Troubleshooting](#13-troubleshooting)
14. [Tear Down](#14-tear-down)
15. [GitHub Push Commands](#15-github-push-commands)
16. [Resume Description](#16-resume-description)

---

## 1. Architecture

```
                Internet
                   |
                   v
        +-----------------------+
        | Application Load      |   Public Subnets (AZ-a, AZ-b)
        | Balancer (ALB :80)    |
        +-----------+-----------+
                    |
                    v
        +-----------------------+
        | TIER 1 — Frontend     |   Public Subnet
        | EC2 Ubuntu + Docker   |
        | NGINX :80 -> React    |   Reverse proxies /api -> Backend
        +-----------+-----------+
                    | /api -> backend private IP :5000
                    v
        +-----------------------+
        | TIER 2 — Backend      |   Public or Private Subnet
        | EC2 Ubuntu + Docker   |   (depends on enable_nat_gateway)
        | Node.js + Express :5000|
        +-----------+-----------+
                    | mysql :3306
                    v
        +-----------------------+
        | TIER 3 — Database     |   Private Subnets
        | AWS RDS MySQL 8.0     |
        | db.t3.micro (Free)    |
        +-----------------------+
```

**Security model** (chain of trust via Security Groups):
- ALB SG ← `0.0.0.0/0:80`
- Frontend SG ← `ALB SG` on `:80` + `your_ip:22`
- Backend SG  ← `Frontend SG` on `:5000` + `your_ip:22`
- RDS SG      ← `Backend SG` on `:3306`

---

## 2. Folder Structure

```
.
├── frontend/              React app + multi-stage Dockerfile (built into NGINX image)
├── backend/               Node.js/Express API + Dockerfile
├── nginx/                 Host-level reverse proxy config (for frontend EC2)
├── database/schema.sql    MySQL schema + seed data
├── terraform/             Full AWS infrastructure as code
├── .github/workflows/     Optional CI/CD (Docker build + push)
├── docker-compose.yml     Local dev: spins up DB + backend + frontend
├── .gitignore
└── README.md
```

---

## 3. Prerequisites

Install on your local machine:

| Tool | Why | Verify |
|------|-----|--------|
| Git | version control | `git --version` |
| Docker Desktop | run containers locally | `docker --version` |
| Node.js 18+ | (optional) run without Docker | `node -v` |
| Terraform 1.5+ | provisions AWS | `terraform -v` |
| AWS CLI | configures credentials | `aws --version` |

**Configure AWS credentials once:**
```bash
aws configure
# AWS Access Key ID:     <from AWS Console -> IAM -> Users -> Security credentials>
# AWS Secret Access Key: <...>
# Default region:        ap-south-1
# Default output format: json
```

**Create an EC2 Key Pair** (AWS Console → EC2 → Key Pairs → Create) named e.g. `my-keypair`. Save the downloaded `.pem` file safely. On Linux/macOS run `chmod 400 my-keypair.pem`.

---

## 4. Local Development

The fastest way to see everything working. Spins up MySQL + backend + frontend with one command.

```bash
# 1. Clone (or open) the project
cd "AWS 3-tier project"

# 2. Start the whole stack
docker compose up --build

# 3. Open in browser
#    Frontend:   http://localhost:3000
#    Backend:    http://localhost:5000
#    Health:     http://localhost:5000/api/health
```

The MySQL schema is auto-loaded from `database/schema.sql` on first start. Pre-seeded users will appear in the UI.

**Stop everything:**
```bash
docker compose down            # keep DB volume
docker compose down -v         # also wipe DB
```

---

## 5. Manual Local Run

Useful for hot-reload development without Docker.

**Backend:**
```bash
cd backend
cp .env.example .env
# Edit .env: set DB_HOST=localhost (or use docker mysql), credentials...
npm install
npm run dev
# -> http://localhost:5000
```

**Frontend:**
```bash
cd frontend
cp .env.example .env
# REACT_APP_API_URL=http://localhost:5000/api
npm install
npm start
# -> http://localhost:3000
```

You'll need a MySQL instance running locally; the easiest option is to start *just* the DB container:
```bash
docker compose up -d mysql
```

---

## 6. Dockerization Details

### Backend image
- Base: `node:18-alpine` (~50 MB)
- Multi-stage: install prod deps in stage 1, copy them into a clean runtime image
- Runs as non-root user `nodeuser`
- HEALTHCHECK on `/api/health`

```bash
# Build manually
docker build -t threetier-backend ./backend

# Run manually
docker run -d -p 5000:5000 \
  -e DB_HOST=host.docker.internal -e DB_PORT=3306 \
  -e DB_NAME=appdb -e DB_USER=appuser -e DB_PASSWORD=apppassword \
  --name backend threetier-backend
```

### Frontend image
- Stage 1: builds the React app (`node:18-alpine`)
- Stage 2: serves it via `nginx:1.27-alpine` (~25 MB total)
- `REACT_APP_API_URL` is a build-arg, baked into the bundle

```bash
docker build --build-arg REACT_APP_API_URL=/api -t threetier-frontend ./frontend
docker run -d -p 3000:80 --name frontend threetier-frontend
```

---

## 7. Push Images to Docker Hub

Once the images are pushed, the Terraform user_data scripts can pull them onto EC2.

```bash
# Log in once
docker login

# Tag & push backend
docker tag threetier-backend  YOURNAME/threetier-backend:latest
docker push YOURNAME/threetier-backend:latest

# Tag & push frontend
docker tag threetier-frontend YOURNAME/threetier-frontend:latest
docker push YOURNAME/threetier-frontend:latest
```

Then edit `terraform/ec2.tf` and replace the `local.backend_image` / `local.frontend_image` placeholders:

```hcl
locals {
  backend_image  = "YOURNAME/threetier-backend:latest"
  frontend_image = "YOURNAME/threetier-frontend:latest"
  # ...
}
```

> **Tip:** Use GitHub Actions (`.github/workflows/deploy.yml`) to automate this on every `git push`.

---

## 8. AWS Deployment with Terraform

### Step 1 — Prepare variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- `key_pair_name` — name of your EC2 Key Pair (no `.pem`)
- `ssh_allowed_cidr` — your public IP `/32` (find it: `curl ifconfig.me`)
- `db_password` — strong password, no `/`, `"`, or `@`
- `enable_nat_gateway` — keep `false` for Free Tier

### Step 2 — Initialize and apply

```bash
terraform init
terraform validate
terraform plan      # review what will be created
terraform apply     # type 'yes' to confirm
```

Provisioning takes **~10 minutes** (RDS is the slowest piece).

### Step 3 — Get outputs

```bash
terraform output
```

Important outputs:
- `alb_dns_name` — open this in browser
- `frontend_public_ip` — for SSH
- `rds_endpoint` — for schema initialization

---

## 9. Post-Deployment: Initialize the Database

The Terraform resource creates an empty MySQL instance. You still need to load the schema.

```bash
# From your local machine, OR SSH into backend EC2 first
mysql -h <RDS_ENDPOINT> -u admin -p < database/schema.sql
# Enter the db_password you set in terraform.tfvars
```

If MySQL CLI isn't installed locally, do it from the backend EC2:

```bash
# SSH into backend EC2 (it's in public subnet by default)
ssh -i my-keypair.pem ubuntu@<BACKEND_PUBLIC_IP>

# Install client
sudo apt-get install -y mysql-client

# Copy schema (from your laptop)
scp -i my-keypair.pem database/schema.sql ubuntu@<BACKEND_PUBLIC_IP>:~

# Load it
mysql -h <RDS_ENDPOINT> -u admin -p < schema.sql
```

---

## 10. API Testing

### Open the app
```
http://<alb_dns_name>
```

### Direct API checks (from any machine)
```bash
ALB=<alb_dns_name>

curl http://$ALB/api/health
curl http://$ALB/api/users
curl -X POST http://$ALB/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Dana","email":"dana@example.com"}'
curl -X DELETE http://$ALB/api/users/1
```

### From inside frontend EC2 (verify the proxy chain)
```bash
ssh -i my-keypair.pem ubuntu@<FRONTEND_PUBLIC_IP>
curl http://localhost/api/health         # via host NGINX
curl http://<BACKEND_PRIVATE_IP>:5000/api/health   # direct to backend
```

---

## 11. Architecture Diagram

```
       ┌──────────────┐
       │   Browser    │
       └──────┬───────┘
              │ HTTP :80
              ▼
   ┌──────────────────────┐
   │   ALB (public)       │  health check: /healthz
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐   public subnet
   │ Frontend EC2         │   Ubuntu 22.04
   │ ├ host NGINX :80     │   reverse proxy
   │ │   / -> :3000       │
   │ │   /api -> backend  │
   │ └ Docker: React+NGINX│
   └──────────┬───────────┘
              │ /api -> <backend_priv_ip>:5000
              ▼
   ┌──────────────────────┐   public or private subnet
   │ Backend EC2          │   Ubuntu 22.04
   │ └ Docker: Node :5000 │
   └──────────┬───────────┘
              │ mysql :3306
              ▼
   ┌──────────────────────┐   private subnets (multi-AZ)
   │ AWS RDS MySQL 8.0    │   db.t3.micro
   └──────────────────────┘
```

---

## 12. Free Tier Cost Notes

| Service | Free Tier (12 months) | This project |
|---------|----------------------|--------------|
| EC2     | 750 hrs/mo of `t2.micro` or `t3.micro` | 2 instances → uses ~1440 hrs/mo (~$8/mo above free) |
| RDS     | 750 hrs/mo `db.t3.micro` + 20 GB | ✔ within limits |
| ALB     | NOT free (~$16/mo) | Used → costs money |
| NAT GW  | NOT free (~$32/mo) | **Disabled by default** |
| Data    | 100 GB egress/mo free | ✔ |

> **Money-saving tips for a portfolio demo:**
> - Use **one** EC2 instance (skip ALB, point Route 53/IP to frontend directly) to stay closer to $0/mo.
> - **Destroy with `terraform destroy` when not actively demoing.**
> - Set a **billing alert** in AWS Billing → Budgets.

---

## 13. Troubleshooting

### `terraform apply` fails on `InvalidKeyPair.NotFound`
Create the EC2 Key Pair in the AWS Console **in the same region** as `aws_region`, then set `key_pair_name` exactly.

### ALB shows `503 Service Temporarily Unavailable`
- Target group health → wait 2–3 min for first health check.
- SSH into frontend EC2: `curl localhost/healthz` (must return `ok`).
- Check that `cloud-init` finished: `sudo cat /var/log/cloud-init-output.log`.

### Frontend loads but API calls fail
- Open browser DevTools → Network. Are requests going to `/api/...`?  
  They should hit the same host as the page (the ALB DNS), then NGINX proxies them.
- SSH into frontend EC2 and run: `curl http://<backend_private_ip>:5000/api/health`.
- If that fails → Backend SG isn't allowing the Frontend SG. Verify in AWS Console.

### Backend can't connect to RDS
```bash
# from backend EC2
sudo docker logs app_backend
# Look for: ECONNREFUSED, ETIMEDOUT, Access denied
```
- ETIMEDOUT → RDS SG isn't allowing the Backend SG.
- Access denied → `DB_USER` / `DB_PASSWORD` env vars don't match RDS master creds.

### `Docker: command not found` after SSH
`cloud-init` may not be finished yet. Wait 1–2 minutes, or:
```bash
sudo cloud-init status --wait
```

### React build fails: `JavaScript heap out of memory`
Either build locally and push image, or temporarily increase Node memory in the Dockerfile:
```dockerfile
RUN NODE_OPTIONS=--max-old-space-size=4096 npm run build
```

### Reset the DB
```bash
mysql -h <RDS_ENDPOINT> -u admin -p -e "DROP DATABASE IF EXISTS appdb;"
mysql -h <RDS_ENDPOINT> -u admin -p < database/schema.sql
```

---

## 14. Tear Down

**Always do this when you're done to avoid surprise bills.**

```bash
cd terraform
terraform destroy
# type 'yes'
```

This removes the VPC, subnets, EC2, RDS (with no final snapshot), ALB — everything.

---

## 15. GitHub Push Commands

```bash
# Inside the project root
git init
git branch -M main
git add .
git status                  # confirm .env and terraform.tfvars are NOT staged
git commit -m "Initial commit: AWS 3-tier app (React + Node + MySQL + Terraform)"

# Create an empty repo on GitHub first, then:
git remote add origin https://github.com/<your-username>/aws-3tier-project.git
git push -u origin main
```

To enable CI/CD: in GitHub repo → **Settings → Secrets and variables → Actions → New secret**:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN` (Docker Hub → Account Settings → Security → New Access Token)

---

## 16. Resume Description

Use this on your CV / LinkedIn / portfolio:

> **AWS 3-Tier Web Application** — *React • Node.js • MySQL • Docker • NGINX • Terraform • AWS*  
> Designed and deployed a production-style 3-tier cloud application on AWS, fully provisioned with Infrastructure-as-Code (Terraform). Built a containerized Node.js/Express REST API and a React SPA, served behind an NGINX reverse proxy on EC2 Ubuntu instances, fronted by an Application Load Balancer. Persisted data in AWS RDS MySQL inside private subnets, with Security Group chains enforcing least-privilege network access between the presentation, application, and data tiers. Implemented Docker multi-stage builds, NGINX caching/compression, and a GitHub Actions CI/CD pipeline that publishes images to Docker Hub on every push to `main`.

**Skills to list:** AWS (VPC, EC2, RDS, ALB, IAM, Security Groups), Terraform, Docker, NGINX, Node.js, Express, React, MySQL, Linux (Ubuntu), CI/CD, Git/GitHub Actions, Infrastructure-as-Code.

---

### Final checklist before you call it done

- [ ] `docker compose up` works locally
- [ ] Pushed images to Docker Hub (or use GH Actions)
- [ ] Updated `terraform/ec2.tf` with your image names
- [ ] `terraform apply` succeeds
- [ ] `mysql -h <rds_endpoint> ... < database/schema.sql` ran
- [ ] `http://<alb_dns_name>` shows the UI and lists users
- [ ] Repo pushed to GitHub (without `.env` or `terraform.tfvars`)
- [ ] `terraform destroy` ran when finished demoing
