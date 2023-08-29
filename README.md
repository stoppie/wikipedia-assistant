# Wikipedia Assistant Solution Documentation

## 1. General Description of the Solution

The Wikipedia Assistant solution provides an automated way to download, preprocess, and store Simple English Wikipedia data in a structured MySQL database hosted on Google's Cloud SQL service. Furthermore, an API, served on Google Cloud Run, exposes data from this database to fulfill specific query requirements. Scheduled updates to the database are facilitated using Google Cloud Scheduler, and the solution is easily deployable thanks to infrastructure-as-code principles and containerization.

## 2. Technical Details and Assumptions

- **Database Selection:** MySQL was chosen due to its structured data handling capabilities and compatibility with Wiki dump files produced by MariaDB.

- **Database Designation:** Two distinct databases differentiate production (`wiki_assistant`) and staging (`wiki_staging`) data.

- **Database Relationships:** `pagelinks` and `categorylinks` tables include foreign keys linking to the `page` table, enhancing data consistency.

- **Data Integrity and Constraints:** The raw `pagelinks` and `categorylinks` tables have discrepancies. Specifically, certain rows in these tables reference a `page_id` that doesn't exist in the `page` table. The `INSERT IGNORE INTO` statement is employed to bypass foreign key constraint violations. However, this method, though functional now, isn't ideal for long-term production use.

- **Data Processes:** 
  * The `pageoutdatedness` table is formed by gauging the maximum time gap between updates of related pages.
  * The `categoryoutdated` table sorts pages based on outdatedness within categories, pinpointing the most outdated page per category.

- **Update Protocol:** Updates are scheduled monthly, aligning with Wikimedia's dump release frequency.

- **Data Handling:** Uniform files and scripts cater to both initial data configuration and periodic refreshes.

- **API Deployment:** The API, hosted on Cloud Run Service, benefits from managed security and scalability.

- **Infrastructure Oversight:** Terraform outlines the infrastructure, ensuring auditable, versioned changes.

## 3. Implemented Security Measures

1. **Database Accessibility:** Despite the public nature of Wikimedia data, the database is designed without public exposure, emphasizing best data security practices.
  
2. **VM Access Control:** The virtual machine, instrumental for database operations, accepts connections solely from a specific external IP.

3. **User Management:** Two database users with distinct roles are established:
   - `wiki_user`: Manages the databases.
   - `api_user`: Has read-only privileges, ensuring the API remains non-intrusive.

4. **Guarding Against SQL Injection:** The API's custom SQL endpoint only supports SELECT queries, reducing SQL injection threats.

5. **Network Rules:** Firewall configurations include:
   * ICMP: Allows ICMP traffic.
   * SSH: Permits SSH access solely from a designated source IP.

## 5. Infrastructure Configuration

### 1. **Provider Configuration**
   - Google Cloud provider is used with version constraint `~> 4.0`.
  
### 2. **Networking**
   - A VPC network named `wiki-assistant-vpc` is created.
   - A global internal address is configured for VPC peering, aimed at connecting with Cloud SQL.
   - VPC Peering is set up to Google services using the above-defined private IP range.
   - A VPC Access Connector is provisioned, allowing for connections between Cloud Run services and VPC resources.

### 3. **Firewall Rules**
   - Two ingress firewall rules are set up: 
     * One to allow ICMP traffic.
     * Another to permit SSH access from a specific source IP.

### 4. **Database Configuration**
   - A MySQL instance (`wiki-assistant-db`) is created in Google Cloud SQL. 
   - This instance is only accessible via a private IP in the `wiki-assistant-vpc`, ensuring enhanced security.
   - Various configurations such as backup settings, IP configurations, and maintenance window are detailed.

### 5. **Compute Instances**
   - A compute instance (`wiki-assistant-sql-connector`) is deployed to facilitate database operations.
  
### 6. **Cloud Run**
   - A Docker image repository is created in the Artifact Registry.
   - A Cloud Run service (`wiki-assistant`) is defined, which utilizes the VPC Access Connector to interact with VPC resources securely.
   - This service's endpoint is made publicly accessible.
   - A Cloud Run job (`wiki-assistant-update`) is also defined for monthly update operations.

### 7. **Cloud Scheduler**
   - A Cloud Scheduler job (`wiki-assistant-update-scheduler`) is established to trigger the Cloud Run job at regular intervals.

**Note**: The overall design is focused on ensuring secure and efficient communication between services and the private Cloud SQL instance. The use of VPC peering, VPC access connectors, and specific firewall rules ensure that the database remains isolated from public access, while still being accessible to necessary services within the project.

## 6. Requirements

### A. APIs to be Enabled:

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

## 7. Instructions on How to Deploy

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
