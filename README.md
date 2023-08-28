# Wikipedia Assistant Solution Documentation

## 1. General Description of the Solution

The Wikipedia Assistant solution provides an automated way to download, preprocess, and store Simple English Wikipedia data in a structured MySQL database hosted on Google Cloud's Cloud SQL service. Furthermore, an API exposes data from this database to fulfill specific query requirements. Scheduled updates to the database are facilitated using Google Cloud Scheduler, and the solution is easily deployable thanks to infrastructure-as-code principles and containerization.

## 2. Assumptions and Simplifications

- The choice of MySQL for the database solution, given the structured nature of the data and the compatibility with the Wiki dump files created by MariaDB.
- The periodic updates are set to occur monthly, based on the dump frequency from Wikimedia.
- The database is not publicly exposed to ensure heightened security.
- Raw and processed data are kept in separate databases to segregate data and simplify management.
- The provided API serves predefined query results, with some flexibility for custom SELECT queries.

## 3. Requirements

### A. APIs to be Enabled:

1. Cloud SQL API
2. Cloud Run API
3. Compute Engine API
4. Service Networking API
5. Cloud Scheduler API

### B. Permissions:

1. **Service Account for Terraform:**
   - `roles/cloudsql.admin`: Required to manage Cloud SQL instances.
   - `roles/compute.admin`: Allows management of Compute Engine resources.
   - `roles/servicenetworking.networks.admin`: Enables management of network resources.
   - `roles/run.admin`: Grants permission for Cloud Run services.
   - `roles/cloudscheduler.admin`: Necessary for scheduling Cloud Run jobs.

## 4. Instructions on How to Deploy

**Prerequisites:**
1. Ensure that the necessary Google APIs (as listed above) are enabled for your GCP project.
2. Create a service account in GCP. Grant it the aforementioned permissions. Download its JSON key.

**Steps:**
1. Clone the GitHub repository:
```
git clone https://github.com/[YOUR_USERNAME]/wikipedia-assistant.git
cd wikipedia-assistant
```

2. Initialize and configure Terraform:
```
cd terraform
terraform init
```

3. Set up the service account for Terraform:
```
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service/account/key.json"
```

4. Apply Terraform configurations:
```
terraform apply
```

5. Deploy API to Cloud Run:
```
cd ../api
./deploy.sh
```

6. Deploy the automation Docker image:
```
cd ../automation
./deploy.sh
```

7. Execute the database setup scripts:
```
cd ../database
./setup.sh
```

## 5. Implemented Security Measures

1. **Private IP for Database:** The Cloud SQL instance has only a private IP, ensuring no public access and thus increasing security.
2. **Restricted VM Access:** Access to the virtual machine (used for database tasks) is restricted to only one external IP address.
3. **Database Users and Roles:** Two distinct users are created:
- `wiki_user`: Maintains the databases.
- `api_user`: Has read-only access, ensuring the API cannot inadvertently modify data.
4. **SQL Injection Prevention:** The API endpoint accepting arbitrary SQL is limited to SELECT queries, mitigating potential SQL injection risks.
5. **Infrastructure as Code:** By using Terraform, we ensure reproducibility and transparency in our infrastructure setup.
