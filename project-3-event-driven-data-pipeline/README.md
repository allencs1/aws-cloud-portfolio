AWS Project 3 — Event-Driven Data Pipeline with S3, Lambda, and DynamoDB

---
AWS Project 3: Event-Driven Data Pipeline with S3, Lambda, and DynamoDB
📌 Project Overview

In this project, I built an event-driven AWS automation pipeline using S3, Lambda, DynamoDB, IAM, and CloudWatch.

When a file is uploaded into an S3 bucket, the upload event automatically triggers a Lambda function. The Lambda function processes metadata about the uploaded file and stores the information inside a DynamoDB table.

This project demonstrates:

Event-driven architecture
Serverless computing
Cloud storage
NoSQL databases
IAM permissions
CloudWatch monitoring
Automation workflows
🏗️ Architecture
User uploads file to S3
          ↓
S3 detects object-created event
          ↓
S3 automatically triggers Lambda
          ↓
Lambda processes file metadata
          ↓
Lambda writes metadata into DynamoDB
          ↓
CloudWatch logs execution activity
☁️ AWS Services Used
Service	Purpose
Amazon S3	Stores uploaded files
AWS Lambda	Processes upload events automatically
DynamoDB	Stores uploaded file metadata
IAM	Controls service permissions
CloudWatch	Logs and monitors execution
⚙️ Workflow
A file is uploaded into S3.
S3 detects an object-created event.
S3 automatically triggers Lambda.
Lambda processes file metadata.
Lambda writes metadata into DynamoDB.
CloudWatch records execution logs.
Engineers validate the workflow using logs and database checks.
🔍 Troubleshooting

During the project, DynamoDB initially showed no data because the file had only been created locally on the Linux laptop using the terminal and had not actually been uploaded into S3.

After uploading the file correctly into the S3 bucket, the S3 trigger fired, Lambda executed successfully, and DynamoDB stored the uploaded file metadata.

This project helped demonstrate how cloud engineers troubleshoot event-driven workflows using:

CloudWatch logs
DynamoDB validation
trigger verification
event monitoring
💼 Real Business Use Cases

This type of architecture is commonly used for:

invoice processing
customer document uploads
image and video processing
malware scanning
log ingestion
AI/ML data ingestion
automated backup tracking

Businesses use serverless event-driven workflows because they:

automate repetitive work
reduce operational costs
scale automatically
improve processing speed
improve reliability
📸 Screenshots
Lambda Function




S3 Event Trigger




DynamoDB Table




Successful DynamoDB Entry




CloudWatch Logs




🎯 Key Takeaways
Built a fully serverless AWS workflow
Learned event-driven architecture concepts
Used S3 triggers to automate Lambda execution
Stored metadata inside DynamoDB
Learned the difference between local terminal actions and cloud actions
Practiced troubleshooting and workflow validation
Used CloudWatch for monitoring and troubleshooting
🧪 Interview Questions
What is event-driven architecture?

Event-driven architecture automatically triggers actions when events occur.

Example:

Uploading a file into S3 triggered Lambda automatically.

What is serverless computing?

Serverless computing means AWS manages the infrastructure while engineers focus on application logic and workflows.

What did DynamoDB store?

DynamoDB stored metadata about uploaded files such as:

file name
upload time
bucket name
Why was CloudWatch important?

CloudWatch helped validate and troubleshoot Lambda execution.

What issue occurred during the project?

The file was originally created locally on the Linux laptop but had not been uploaded into S3, so the automation workflow never triggered.

After uploading the file properly into S3, the workflow operated correctly.
