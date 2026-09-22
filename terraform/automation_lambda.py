import json

def lambda_handler(event, context):
    print("Shields automation triggered")
    print(json.dumps(event))

    detail = event.get("detail", {})
    instance_id = detail.get("instance-id", "unknown")
    state = detail.get("state", "unknown")

    print(f"EC2 instance {instance_id} changed state to {state}")

    return {
        "statusCode": 200,
        "body": f"Processed EC2 state change: {instance_id} -> {state}"
    }