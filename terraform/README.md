 # AWS Linux Modernization & Event-Driven Automation

## Project Overview

This project demonstrates the modernization of a legacy Linux workload on AWS using Terraform.

The environment began with a publicly accessible EC2-based application and was incrementally improved to implement more secure access, centralized traffic management, infrastructure automation, and event-driven orchestration.

The final architecture uses an Application Load Balancer for application access, AWS Systems Manager Session Manager for secure administrative access, and an automated workflow using Amazon EventBridge, AWS Step Functions, AWS Lambda, Python, and Amazon CloudWatch.

All infrastructure is provisioned and managed using Terraform.

## Architecture

The modernization architecture follows this traffic and automation flow:

### Application Traffic

Internet → Application Load Balancer → Target Group → EC2 Linux Application (Port 8080)

- The Application Load Balancer is deployed across two public subnets in separate Availability Zones.
- The EC2 application is registered with an ALB target group.
- Direct public access to the application's port 8080 is blocked.
- The EC2 security group allows application traffic only from the ALB security group.

### Secure Administration

Administrator → AWS Systems Manager Session Manager → EC2

- Public SSH access was removed from the EC2 security group.
- An IAM instance profile provides the permissions required by Systems Manager.
- Linux administration is performed through Session Manager without exposing port 22.

### Event-Driven Automation

EC2 State Change → Amazon EventBridge → AWS Step Functions → AWS Lambda (Python) → Amazon CloudWatch Logs

- EventBridge detects state changes for the EC2 instance.
- EventBridge starts the Step Functions state machine.
- Step Functions orchestrates the automation workflow.
- Lambda processes the EC2 state-change event using Python.
- CloudWatch Logs provides execution and event visibility.

## Modernization Improvements

The project was intentionally built in stages to demonstrate the modernization of a legacy-style AWS workload.

### 1. Application Access

The application runs on an EC2 Linux instance on port 8080. An Application Load Balancer was introduced as the public entry point instead of allowing users to connect directly to the application instance.

### 2. Network Security

The EC2 security group was restricted so port 8080 accepts traffic only from the Application Load Balancer security group.

This changed the access pattern from:

Internet → EC2:8080

to:

Internet → ALB:80 → EC2:8080

### 3. Administrative Access

Traditional inbound SSH access on port 22 was removed.

AWS Systems Manager Session Manager was configured using an IAM instance profile, allowing administrative access to the Linux instance without exposing an SSH port to the Internet.

### 4. Event-Driven Automation

Amazon EventBridge monitors the EC2 instance for state-change events.

Instead of invoking Lambda directly, EventBridge starts an AWS Step Functions workflow. Step Functions then invokes a Python Lambda function that processes the event and records the instance ID and state in CloudWatch Logs.

### 5. Infrastructure as Code

The AWS infrastructure is managed with Terraform, including networking, security groups, IAM roles and policies, EC2, the Application Load Balancer, EventBridge, Step Functions, and Lambda.

## Technologies Used

- **Amazon EC2** — Hosts the legacy Linux application workload.
- **Application Load Balancer (ALB)** — Provides the public entry point and forwards application traffic to EC2.
- **Amazon VPC** — Provides the network foundation, public subnets, routing, and security boundaries.
- **AWS Systems Manager Session Manager** — Provides secure administrative access to EC2 without public SSH.
- **AWS IAM** — Provides least-privilege service roles and permissions for EC2, Lambda, Step Functions, and EventBridge.
- **Amazon EventBridge** — Detects EC2 instance state-change events and initiates the automation workflow.
- **AWS Step Functions** — Orchestrates the event-driven automation workflow.
- **AWS Lambda** — Runs Python code that processes EC2 state-change events.
- **Amazon CloudWatch Logs** — Captures Lambda execution logs and processed EC2 state information.
- **Terraform** — Provisions and manages the AWS infrastructure as code.
- **Python** — Implements the Lambda event-processing logic.

## Validation and Testing

The environment was validated incrementally throughout the modernization process.

### Infrastructure Validation

Terraform configuration was formatted and validated using:

- `terraform fmt`
- `terraform validate`
- `terraform plan`

The final Terraform plan confirmed that the deployed AWS infrastructure matched the configuration with no detected changes.

### Application Load Balancer

The Application Load Balancer was tested through its public DNS endpoint.

The target group reported the EC2 instance as healthy, and the application successfully responded through the ALB.

### Security Validation

After restricting port 8080, application traffic continued to work through the ALB while direct public access to the EC2 application port was removed.

AWS Systems Manager Session Manager connectivity was verified before removing the inbound SSH rule. Administrative shell access continued to work after port 22 was closed.

### Automation Validation

The EC2 instance was stopped and started to generate real EC2 state-change events.

EventBridge successfully detected the events and started the Step Functions state machine.

Step Functions executions completed successfully and invoked the Python Lambda function.

CloudWatch Logs confirmed that Lambda received and processed EC2 state changes including:

- `stopping`
- `stopped`
- `pending`
- `running`

### Final State Validation

A final `terraform plan` was executed after implementation and testing.

Terraform reported:

`No changes. Your infrastructure matches the configuration.`

This confirmed that the deployed environment and Terraform-managed configuration were synchronized.

## Skills Demonstrated

This project demonstrates hands-on experience with:

- Designing AWS networking using VPCs, subnets, route tables, Internet Gateways, and security groups.
- Deploying and configuring an Application Load Balancer and target group.
- Applying security-group-to-security-group access controls instead of exposing backend application ports publicly.
- Replacing inbound SSH administration with AWS Systems Manager Session Manager.
- Configuring IAM roles, trust policies, managed policies, and service-to-service permissions.
- Building event-driven automation with EventBridge, Step Functions, and Lambda.
- Processing AWS events with Python.
- Using CloudWatch Logs to validate and troubleshoot automation.
- Managing AWS infrastructure through Terraform.
- Troubleshooting partial Terraform deployments and validating infrastructure state after changes.

## Repository Structure

```text
shields-linux-modernization/
├── .gitignore
└── terraform/
    ├── .terraform.lock.hcl
    ├── automation_lambda.py
    ├── main.tf
    ├── outputs.tf
    ├── providers.tf
    ├── README.md
    └── variables.tf
```

Generated and local Terraform files are excluded from version control, including:

- `.terraform/`
- `*.tfstate`
- `*.tfstate.*`
- `*.tfvars`
- `*.tfvars.json`
- `*.zip`

This prevents local Terraform state, variable files, generated deployment packages, and provider binaries from being committed to the repository.