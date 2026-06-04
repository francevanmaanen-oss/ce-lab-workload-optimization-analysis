import boto3

ec2 = boto3.client("ec2")


def lambda_handler(event, context):
    action = event.get("action")  # "start" or "stop"

    if action not in ("start", "stop"):
        return {"error": "action must be 'start' or 'stop'"}

    filters = [
        {"Name": "tag:Schedule",    "Values": ["business-hours"]},
        {"Name": "tag:Environment", "Values": ["development", "staging"]},
    ]

    if action == "stop":
        filters.append({"Name": "instance-state-name", "Values": ["running"]})
    else:
        filters.append({"Name": "instance-state-name", "Values": ["stopped"]})

    response = ec2.describe_instances(Filters=filters)
    instance_ids = [
        i["InstanceId"]
        for r in response["Reservations"]
        for i in r["Instances"]
    ]

    if not instance_ids:
        return {"message": f"No instances to {action}"}

    if action == "stop":
        ec2.stop_instances(InstanceIds=instance_ids)
    else:
        ec2.start_instances(InstanceIds=instance_ids)

    return {"action": action, "instances": instance_ids}
