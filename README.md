# Instance Scheduling & Storage Optimization Lab

A free-tier compatible AWS lab covering EC2 instance scheduling with
Lambda and EventBridge, and EBS storage auditing.

## What This Lab Does

- Deploys two t3.micro EC2 instances tagged for business-hours scheduling
- Creates an orphaned EBS volume to simulate forgotten storage
- Builds a Lambda function that starts and stops instances on a schedule
- Wires the Lambda to EventBridge rules for automatic weekday start/stop
- Audits unattached EBS volumes and old snapshots
- Produces a workload optimization report with savings projections

## Project Structure

```
├── .github/workflows/
│   ├── deploy.yml          # Runs terraform apply on push to main
│   └── destroy.yml         # Runs terraform destroy on push to destroy branch
├── main.tf                 # EC2 instances + orphaned EBS volume
├── variables.tf            # Input variables
├── outputs.tf              # Instance IDs and volume ID printed after deploy
├── scheduler.py            # Lambda function — starts/stops tagged instances
├── documentation/
│   ├── usage-analysis.md       # CloudWatch usage pattern findings
│   └── optimization-report.md  # Savings report with recommendations
└── INSTRUCTIONS.md
```

## Prerequisites

- AWS account (free tier)
- GitHub account
- AWS CLI configured locally

## Setup

1. Create a new GitHub repo and add these three secrets under
   Settings → Secrets and variables → Actions:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`

2. Clone the repo, copy in all project files, and push to main.

## Usage

**Deploy:**
```bash
git push origin main
```

**Destroy EC2 and EBS when done:**
```bash
git checkout -b destroy
git push origin destroy
```

Lambda, EventBridge rules, and the IAM role must be cleaned up manually
— see Part 10 of the instructions.

## Results

| Instance     | Simulates  | Always-On Cost | Scheduled Cost | Monthly Saving |
|--------------|------------|----------------|----------------|----------------|
| dev-frontend | t3.medium  | $30.37         | $10.07         | $20.30         |
| dev-backend  | t3.large   | $60.74         | $20.13         | $40.61         |
| **Total**    |            | **$91.11**     | **$30.20**     | **$60.91**     |

**Annual projected savings: $730.92**

## Free Tier Usage

| Resource     | Free Tier Allowance    | This Lab          |
|--------------|------------------------|-------------------|
| EC2 t3.micro | 750 hrs/month combined | ~4 hrs (2 x 2hrs) |
| EBS gp3      | 30 GB/month            | 17 GB (2x8 + 1)   |
| Lambda       | 1M requests/month      | ~5 requests       |
| EventBridge  | Free                   | Free              |
