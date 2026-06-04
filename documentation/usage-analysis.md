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
