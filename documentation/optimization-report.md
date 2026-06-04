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
