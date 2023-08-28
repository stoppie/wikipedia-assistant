# Wikipedia Assistant Solution Documentation

## 1. General Description of the Solution

The Wikipedia Assistant solution provides an automated way to download, preprocess, and store Simple English Wikipedia data in a structured MySQL database hosted on Google Cloud's Cloud SQL service. Furthermore, an API, served on Google Cloud Run, exposes data from this database to fulfill specific query requirements. Scheduled updates to the database are facilitated using Google Cloud Scheduler, and the solution is easily deployable thanks to infrastructure-as-code principles and containerization.

## 2. Assumptions and Simplifications

- The choice of MySQL for the database solution, given the structured nature of the data and the compatibility with the Wiki dump files created by MariaDB.
- The periodic updates are set to occur monthly, based on the dump frequency from Wikimedia.
- The database is not publicly exposed to ensure heightened security.
- Raw and processed data are kept in separate databases to segregate data and simplify management.
- The provided API serves predefined query results, with some flexibility for custom SELECT queries.
- **Data Integrity in Raw Tables:** It is observed that the raw `pagelinks` and `categorylinks` tables contain some rows where the `page_id` does not have a corresponding entry in the `page` table. Specifically, this discrepancy exists for a singular `page_id`. The foreign key constraint would thus be violated when attempting standard insertions. As a workaround, the `INSERT IGNORE INTO` statement is utilized when populating the `pagelinks` and `categorylinks` tables. While effective for the current setup, it's vital to note that this is not an ideal solution for a production environment and requires further refinements to address potential data integrity concerns.

With the aforementioned strategy, the `INSERT IGNORE INTO` mechanism serves a dual purpose: 
1. It aids in the monthly refresh process by ensuring only new rows are added.
2. It circumvents the constraint violation for the specific `page_id` without a corresponding entry in the `page` table.

## 3. Implemented Security Measures

1. **Private IP for Database:** The Cloud SQL instance has only a private IP, ensuring no public access and thus increasing security.
2. **Restricted VM Access:** Access to the virtual machine (used for database tasks) is restricted to only one external IP address.
3. **Database Users and Roles:** Two distinct users are created:
- `wiki_user`: Maintains the databases.
- `api_user`: Has read-only access, ensuring the API cannot inadvertently modify data.
4. **SQL Injection Prevention:** The API endpoint accepting arbitrary SQL is limited to SELECT queries, mitigating potential SQL injection risks.
5. **Infrastructure as Code:** By using Terraform, we ensure reproducibility and transparency in our infrastructure setup.

## 4. Requirements

### A. APIs to be Enabled:
(Note: This list may not be comprehensive.)

1. Cloud Run Admin API
2. Compute Engine API
3. Serverless VPC Access API
4. Artifact Registry API	
5. Secret Manager API
6. Cloud SQL Admin API
7. Cloud Resource Manager API
8. Service Networking API
9. Cloud Deployment Manager V2 API
10. Cloud Logging API

### B. Permissions:

1. **Service Account for Terraform:**
- `roles/artifactregistry.admin`
- `roles/cloudscheduler.admin`
- `roles/cloudsql.admin`
- `roles/compute.admin`
- `roles/compute.networkAdmin`
- `roles/run.admin`
- `roles/secretmanager.secretAccessor`
- `roles/secretmanager.viewer`
- `roles/vpcaccess.admin`

## 5. Instructions on How to Deploy

### Prerequisites:

1. Ensure that the necessary Google APIs (as listed above) are enabled for your GCP project.
2. Create a service account in GCP. Grant it the aforementioned permissions. Download its JSON key.
3. Ensure `gcloud` is installed. You can follow the official [documentation](https://cloud.google.com/sdk/docs/install) for installation steps.
4. Ensure `terraform` is installed. See the official [Terraform website](https://learn.hashicorp.com/tutorials/terraform/install-cli) for installation guidelines.
5. Ensure `docker` is installed. For installation, refer to the official [Docker documentation](https://docs.docker.com/get-docker/).
6. Set the following environment variables:
   - `TF_VAR_source_ip`: The IP from which SSH will be allowed.
   - `TF_VAR_mysql_root_password`: The root password to set when the database is created.
7. Modify the `variables.tf` file to replace the service_account name with the one you plan to use for Cloud Run, Cloud Compute, and Cloud Scheduler operations.
8. Add the following secrets to the GCP Secret Manager:
   - `wiki-assistant-db-api-user-password`: Password for `api_user`
   - `wiki-assistant-db-root-password`: Root password
   - `wiki-assistant-db-wiki-user-password`: Password for `wiki_user`
9. Assign the `roles/secretmanager.secretAccessor` role to the service account (mentioned in point 7) for each of the secrets you've created.

### Steps:

1. Clone the GitHub repository:
```
   git clone git@github.com:stoppie/wikipedia-assistant.git
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

4. Create a repository in Artifact Registry named `wiki-assistant-repo`:
```
gcloud artifacts repositories create wiki-assistant-repo --location=[YOUR_LOCATION] --repository-format=docker
```

5. Build the Docker image for API and push it to Artifact Registry:
```
cd ../api
./deploy.sh [VERSION]
```

6. Build the Docker image for monthly updates and push it to Artifact Registry:
```
cd ../automation
./deploy.sh [VERSION]
```

7. Modify the `main.tf` file, inserting the Artifact Registry image URLs for both the `wiki_assistant_service` (Cloud Run API service) and `wiki_assistant_job` (Cloud Run service for monthly updates).

8. Apply Terraform configurations:
```
cd ../terraform
terraform apply
```

9. Execute the database setup scripts:
```
cd ../database
./setup.sh
```

10. Trigger the Cloud Run Job `wiki-assistant-update` to insert the data into the database:
```
gcloud run jobs execute wiki-assistant-update --project=[YOUR_PROJECT_ID]
```
