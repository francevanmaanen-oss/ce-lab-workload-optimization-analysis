# Lab Instructions — Instance Scheduling & Storage Optimization

Free-tier compatible lab. EC2 instances and the orphaned EBS volume are
deployed via Terraform and GitHub Actions. Lambda, EventBridge, and the
EBS audit are done manually via the AWS CLI.

---

## Prerequisites

- AWS account within its first 12 months (free tier active)
- AWS CLI installed and configured locally
- Git installed locally
- A text editor

---

## Part 1: Create the GitHub Repository

1. Go to https://github.com and click the + icon (top right) then
   New repository
2. Name it ce-lab-scheduling-optimization
3. Set visibility to Private
4. Leave everything else as default and click Create repository

---

## Part 2: Add GitHub Secrets

1. In your new repo click the Settings tab
2. In the left sidebar click Secrets and variables then Actions
3. Click New repository secret and add each of the following:

   Secret Name             | Value
   ------------------------|----------------------------------------
   AWS_ACCESS_KEY_ID       | Your IAM user access key ID
   AWS_SECRET_ACCESS_KEY   | Your IAM user secret access key
   AWS_REGION              | us-east-1

   If you completed Lab 1 you already have an IAM user called
   github-actions-lab — reuse those same credentials here.
   If not, create one following Part 2 of the Lab 1 instructions.

---

## Part 3: Set Up the Project Locally

1. Clone your new repo:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ce-lab-scheduling-optimization.git
   cd ce-lab-scheduling-optimization
   ```

2. Copy all the provided project files into this folder. Your directory
   should look like this when done:
   ```
   ce-lab-scheduling-optimization/
   ├── .github/
   │   └── workflows/
   │       ├── deploy.yml
   │       └── destroy.yml
   ├── documentation/        (empty folder for now)
   ├── main.tf
   ├── variables.tf
   ├── outputs.tf
   ├── scheduler.py
   ├── example.tfvars
   ├── .gitignore
   └── README.md
   ```

3. Create the empty documentation folder if it doesn't exist:
   ```bash
   mkdir -p documentation
   ```

---

## Part 4: Deploy the Infrastructure

1. Commit and push everything to main:
   ```bash
   git add .
   git commit -m "initial lab setup"
   git push origin main
   ```

2. Go to your GitHub repo in the browser and click the Actions tab

3. Click on the Deploy Lab Infrastructure workflow run and watch it
   complete. It takes about 2-3 minutes.

4. When it finishes, click the workflow Summary. You will see:
   ```
   ## Lab Infrastructure Deployed

   ### Instance IDs
   {
     "dev-backend":  "i-0abc123def456789a",
     "dev-frontend": "i-0bcd234ef5678901b"
   }

   ### Orphaned Volume ID
   "vol-0abc123def456789a"
   ```

5. Copy all three IDs and set them in your terminal:
   ```bash
   FRONTEND_ID="i-0xxxx"
   BACKEND_ID="i-0xxxx"
   ORPHAN_VOL="vol-0xxxx"

   INSTANCE_IDS=("$FRONTEND_ID" "$BACKEND_ID")

   echo "Frontend: $FRONTEND_ID"
   echo "Backend:  $BACKEND_ID"
   echo "Volume:   $ORPHAN_VOL"
   ```

6. Verify instances are running in the AWS Console under EC2 Instances.
   You should see dev-frontend and dev-backend both in running state,
   tagged with Schedule=business-hours and Environment=development.

---

## Part 5: Analyse Usage Patterns

Query CPU utilisation over the last 24 hours to understand workload patterns.

```bash
END_TIME=$(date -u '+%Y-%m-%dT%H:%M:%S')
START_TIME=$(date -u -v-1d '+%Y-%m-%dT%H:%M:%S')

for ID in "${INSTANCE_IDS[@]}"; do
  NAME=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$ID" "Name=key,Values=Name" \
    --query 'Tags[0].Value' --output text)

  echo "--- $NAME ($ID) ---"

  aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value="$ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 3600 \
    --statistics Average \
    --query 'Datapoints | sort_by(@, &Timestamp)[].{Time:Timestamp,CPU:Average}' \
    --output table
done
```

CPU will be near zero since these are fresh instances with no workload.
This is exactly what you would see with idle dev instances in a real
environment — running and billing 24/7 but barely used.

Create documentation/usage-analysis.md with your findings:
```bash
cat > documentation/usage-analysis.md << 'EOF'
# Workload Usage Pattern Analysis

## Observations
- Dev instances show near-zero CPU outside business hours
- Weekend utilization is effectively 0% across all dev instances
- Business-hours average CPU: ~25-40% (estimated for real workloads)
- Off-hours average CPU: <2%

## Active Window
- Business hours: Monday-Friday 8:00 AM - 7:00 PM local time
- Idle hours: Weeknights + full weekends = ~76% of total hours

## Conclusion
Instances are running and being billed 24/7 but are only needed for
24% of that time. Scheduling would cut instance costs by ~67%.
EOF
```

---

## Part 6: Calculate Scheduling Savings

Run this to print a savings breakdown:

```bash
cat << 'EOF'
=== Scheduling Savings Calculator ===

Note: Savings use production-equivalent instance sizes.
Lab instances are t3.micro for free tier compatibility.

Instance: dev-frontend (simulates t3.medium)
  On-Demand rate:        $0.0416/hr
  Monthly cost (24x7):   $30.37
  Business hours/month:  Mon-Fri 8AM-7PM = 11hrs x 22 days = 242 hrs
  Scheduled cost:        $10.07
  Monthly savings:       $20.30 (67%)

Instance: dev-backend (simulates t3.large)
  On-Demand rate:        $0.0832/hr
  Monthly cost (24x7):   $60.74
  Business hours/month:  242 hrs
  Scheduled cost:        $20.13
  Monthly savings:       $40.61 (67%)

TOTAL MONTHLY SAVINGS:   $60.91
ANNUAL SAVINGS:          $730.92
EOF
```

---

## Part 7: Create the IAM Role for Lambda

```bash
aws iam create-role \
  --role-name InstanceSchedulerRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam put-role-policy \
  --role-name InstanceSchedulerRole \
  --policy-name EC2StartStop \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*"
      }
    ]
  }'

echo "IAM role created"
```

---

## Part 8: Deploy the Lambda Scheduler

### 8.1 Package the function

The scheduler.py file is already in your project folder. Package it:

```bash
zip scheduler.zip scheduler.py
```

### 8.2 Get your account details

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

echo "Account: $ACCOUNT_ID"
echo "Region:  $REGION"
```

### 8.3 Deploy the Lambda function

```bash
echo "Waiting 10 seconds for IAM role propagation..."
sleep 10

aws lambda create-function \
  --function-name InstanceScheduler \
  --runtime python3.12 \
  --role "arn:aws:iam::${ACCOUNT_ID}:role/InstanceSchedulerRole" \
  --handler scheduler.lambda_handler \
  --zip-file fileb://scheduler.zip \
  --timeout 60

echo "Lambda deployed"
```

### 8.4 Test stop

```bash
aws lambda invoke \
  --function-name InstanceScheduler \
  --payload '{"action": "stop"}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json
```

Expected output:
{"action": "stop", "instances": ["i-0xxxx", "i-0xxxx"]}

Verify both instances stopped:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=m7-04" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name]' \
  --output table
```

### 8.5 Test start

```bash
aws lambda invoke \
  --function-name InstanceScheduler \
  --payload '{"action": "start"}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json
```

Verify both instances started again:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=m7-04" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name]' \
  --output table
```

---

## Part 9: Create EventBridge Scheduled Rules

Wire up automatic start and stop on a Monday-Friday schedule.
Times are in UTC — adjust if your timezone differs from EST.

```bash
aws events put-rule \
  --name "StopDevInstances" \
  --schedule-expression "cron(0 23 ? * MON-FRI *)" \
  --description "Stop development instances at 7 PM EST (23:00 UTC)" \
  --state ENABLED

aws events put-rule \
  --name "StartDevInstances" \
  --schedule-expression "cron(0 12 ? * MON-FRI *)" \
  --description "Start development instances at 8 AM EST (12:00 UTC)" \
  --state ENABLED

LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:InstanceScheduler"

aws lambda add-permission \
  --function-name InstanceScheduler \
  --statement-id StopPermission \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "arn:aws:events:${REGION}:${ACCOUNT_ID}:rule/StopDevInstances"

aws lambda add-permission \
  --function-name InstanceScheduler \
  --statement-id StartPermission \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "arn:aws:events:${REGION}:${ACCOUNT_ID}:rule/StartDevInstances"

aws events put-targets \
  --rule StopDevInstances \
  --targets "Id=StopTarget,Arn=$LAMBDA_ARN,Input={\"action\":\"stop\"}"

aws events put-targets \
  --rule StartDevInstances \
  --targets "Id=StartTarget,Arn=$LAMBDA_ARN,Input={\"action\":\"start\"}"

echo "EventBridge rules created"
```

Verify the rules exist:
```bash
aws events list-rules \
  --query 'Rules[?contains(Name,`DevInstances`)].{Name:Name,Schedule:ScheduleExpression,State:State}' \
  --output table
```

Expected output:
```
--------------------------------------------------------------------
|                          ListRules                               |
+--------------------+---------------------------+----------------+
|       Name         |         Schedule          |     State      |
+--------------------+---------------------------+----------------+
|  StartDevInstances | cron(0 12 ? * MON-FRI *)  |    ENABLED     |
|  StopDevInstances  | cron(0 23 ? * MON-FRI *)  |    ENABLED     |
+--------------------+---------------------------+----------------+
```

---

## Part 10: Audit EBS Volumes and Snapshots

### Unattached volumes

```bash
echo "=== Unattached EBS Volumes ==="
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query 'Volumes[].{
    VolumeId: VolumeId,
    Size: Size,
    Type: VolumeType,
    Created: CreateTime,
    Name: Tags[?Key==`Name`].Value | [0]
  }' --output table
```

You should see orphaned-data-volume (1 GB) in the results.

### Snapshots older than 90 days

```bash
echo "=== Snapshots Older Than 90 Days ==="
NINETY_DAYS_AGO=$(date -u -v-90d '+%Y-%m-%dT%H:%M:%S')

aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[?StartTime<='${NINETY_DAYS_AGO}'].{
    SnapshotId: SnapshotId,
    Size: VolumeSize,
    Created: StartTime,
    Description: Description
  }" --output table
```

### Calculate storage waste

```bash
UNATTACHED_GB=$(aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query 'sum(Volumes[].Size)' \
  --output text)

echo "Unattached volume storage: ${UNATTACHED_GB:-0} GB"
echo "Estimated monthly cost: \$$(echo "scale=2; ${UNATTACHED_GB:-0} * 0.08" | bc)"
```

---

## Part 11: Write the Optimization Report

```bash
cat > documentation/optimization-report.md << 'EOF'
# Workload Optimization Report

## Executive Summary
Two savings opportunities identified: instance scheduling and orphaned
storage cleanup. Total projected monthly saving: $60.91+.

## 1. Instance Scheduling (Priority: HIGH)

| Instance     | Simulates  | Always-On Cost | Scheduled Cost | Monthly Saving |
|--------------|------------|----------------|----------------|----------------|
| dev-frontend | t3.medium  | $30.37         | $10.07         | $20.30         |
| dev-backend  | t3.large   | $60.74         | $20.13         | $40.61         |
| Total        |            | $91.11         | $30.20         | $60.91         |

Implementation: EventBridge + Lambda scheduler deployed in this lab.
Instances stop at 7 PM EST and start at 8 AM EST Monday-Friday.

## 2. Orphaned EBS Volumes (Priority: MEDIUM)

Unattached volumes found: 1 (orphaned-data-volume, 1 GB)
Action: Delete after verifying no dependencies.

## 3. Old Snapshots (Priority: LOW)

Review and delete snapshots older than 90 days.
Implement a snapshot lifecycle policy to prevent future accumulation.

## Prioritized Recommendations

1. Enable instance scheduling    — $60.91/mo saving, zero performance impact
2. Delete orphaned volumes       — eliminates storage waste immediately
3. Implement snapshot lifecycle  — prevents accumulation going forward

## Annual Projected Savings: $730.92
EOF
```

Commit all documentation:
```bash
git add documentation/usage-analysis.md documentation/optimization-report.md
git commit -m "add usage analysis and optimization report"
git push origin main
```

---

## Part 12: Clean Up

Do these steps in order. Do not skip any step.

### Step 1 — Remove EventBridge targets and rules

```bash
aws events remove-targets --rule StopDevInstances --ids StopTarget
aws events remove-targets --rule StartDevInstances --ids StartTarget
aws events delete-rule --name StopDevInstances
aws events delete-rule --name StartDevInstances
echo "EventBridge rules deleted"
```

### Step 2 — Delete the Lambda function

```bash
aws lambda delete-function --function-name InstanceScheduler
echo "Lambda deleted"
```

### Step 3 — Delete the IAM role

```bash
aws iam delete-role-policy \
  --role-name InstanceSchedulerRole \
  --policy-name EC2StartStop

aws iam delete-role --role-name InstanceSchedulerRole
echo "IAM role deleted"
```

### Step 4 — Destroy EC2 and EBS via Terraform

```bash
git checkout -b destroy
git push origin destroy
```

Watch the Destroy Lab Infrastructure workflow complete in the Actions tab.
It will remove both EC2 instances and the orphaned EBS volume.

### Step 5 — Verify everything is gone

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=m7-04" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name]' \
  --output table

aws ec2 describe-volumes \
  --filters "Name=tag:Lab,Values=m7-04" \
  --query 'Volumes[].{VolumeId:VolumeId,State:State}' \
  --output table
```

Both should return empty or show terminated/deleted state.

### Step 6 — Clean up the destroy branch

```bash
git checkout main
git push origin --delete destroy
git branch -d destroy
```

---

## Troubleshooting

### Lambda returns "No instances to stop"

The tags may not match. Verify the instances have the right tags:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Schedule,Values=business-hours" \
            "Name=tag:Environment,Values=development" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output table
```

### Lambda returns an IAM or permissions error

The IAM role may not have propagated yet. Wait 15 seconds and retry.
If it persists check the role exists:
```bash
aws iam get-role --role-name InstanceSchedulerRole
```

### Orphaned volume not showing in audit

The volume may still be in creating state. Wait 30 seconds and rerun
the describe-volumes command.

### Destroy workflow fails — no state artifact

The deploy may not have completed fully. Manually clean up:
```bash
aws ec2 terminate-instances --instance-ids "$FRONTEND_ID" "$BACKEND_ID"
aws ec2 delete-volume --volume-id "$ORPHAN_VOL"
```

### Instance variables are empty after reopening terminal

Re-run this block to restore them:
```bash
FRONTEND_ID="i-0xxxx"
BACKEND_ID="i-0xxxx"
ORPHAN_VOL="vol-0xxxx"
INSTANCE_IDS=("$FRONTEND_ID" "$BACKEND_ID")
```

---

## Quick Reference

| Action              | Command                                                                 |
|---------------------|-------------------------------------------------------------------------|
| Deploy              | git push origin main                                                    |
| Check instances     | aws ec2 describe-instances --filters "Name=tag:Lab,Values=m7-04" --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name]' --output table |
| Test stop Lambda    | aws lambda invoke --function-name InstanceScheduler --payload '{"action":"stop"}' --cli-binary-format raw-in-base64-out response.json && cat response.json |
| Test start Lambda   | aws lambda invoke --function-name InstanceScheduler --payload '{"action":"start"}' --cli-binary-format raw-in-base64-out response.json && cat response.json |
| Destroy             | git checkout -b destroy && git push origin destroy                      |

---

## Free Tier Usage Summary

| Resource     | Free Tier Allowance    | This Lab (2hr session) |
|--------------|------------------------|------------------------|
| EC2 t3.micro | 750 hrs/month combined | ~4 hrs (2 instances)   |
| EBS gp3      | 30 GB/month            | 17 GB (2x8 + 1)        |
| Lambda       | 1M requests/month      | ~5 requests            |
| EventBridge  | Free                   | Free                   |
| CloudWatch   | Free                   | Free                   |
