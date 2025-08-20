# Multi-Region NGINXaaS Deployment and Deletion Scripts

This repository provides scripts to automate the deployment and deletion of NGINXaaS across multiple Azure regions with capacity scaling and load balancer integration.

## Scripts Overview

### Deployment Script (`deploy-nginx-multi-region.sh`)
The deployment script performs the following operations for each specified region:

1. **Initial Deployment**: Deploys NGINXaaS with capacity 20
2. **Scale Up**: Increases capacity to 30
3. **Scale Down**: Returns capacity to 20
4. **Load Balancer Integration**: Executes Azure CLI commands to show load balancer backend addresses after each capacity change

### Deletion Script (`delete-nginx-multi-region.sh`)
The deletion script safely removes all deployed resources:

1. **Resource Discovery**: Finds all resource groups using deployment name tags
2. **Terraform Destroy**: Attempts clean Terraform resource destruction
3. **Direct Deletion**: Removes resource groups directly via Azure CLI
4. **State Cleanup**: Cleans up local Terraform state files
5. **Progress Monitoring**: Waits for deletions to complete

## Supported Regions

The script deploys to the following 22 Azure regions:

- West Central US
- West US
- East US 2
- West US 2
- West US 3
- East US
- Central US
- North Central US
- Canada Central
- Brazil South
- West Europe
- North Europe
- Sweden Central
- Germany West Central
- UK West
- UK South
- Australia East
- Japan East
- Korea Central
- Southeast Asia
- Central India
- South India

## Prerequisites

### Required Tools
- **Terraform** (version ~> 1.3)
- **Azure CLI** (az)
- **jq** (JSON processor)

### Azure Authentication
- You must be logged in to Azure CLI (`az login`)
- Appropriate permissions to create resources in the target subscriptions

### Terraform Configuration
The script uses the existing Terraform configuration in the `create-or-update/` directory with the following modifications:
- Added `capacity` variable to control NGINXaaS deployment capacity
- Uses modular approach with prerequisites from `../prerequisites`

## Usage

### Deployment
To deploy NGINXaaS across all regions:
```bash
./deploy-nginx-multi-region.sh
```

### Deletion
To delete all deployed NGINXaaS resources:
```bash
./delete-nginx-multi-region.sh
```

**Warning**: The deletion script will permanently remove all NGINXaaS resources for the current user across all regions. This action cannot be undone.

### What the Script Does

For each region, the script:

1. **Generates deployment name**: Creates a unique name based on the region (e.g., "nginxaas-west-central-us")

2. **Sets subscription context**:
   - Looks for resource groups with tag `DeploymentName=<nginxaas-deployment-name>`
   - Extracts subscription ID from the resource group ID
   - Sets the Azure CLI context to that subscription

3. **Performs capacity scaling cycle**:
   - **Phase 1**: Deploy with capacity 20
   - **Phase 2**: Scale to capacity 30
   - **Phase 3**: Scale back to capacity 20

4. **Executes load balancer commands**:
   - After each capacity change, runs:
   ```bash
   az network lb address-pool show --resource-group <lb-rg-name> --lb-name lb-pub --name backend | jq .loadBalancerBackendAddresses
   ```

## Script Features

### Error Handling
- Comprehensive prerequisite checks
- Graceful handling of missing resource groups or load balancers
- Detailed logging and status messages

### Rate Limiting
- 30-second pause between region deployments to avoid Azure API rate limits

### Flexible Resource Group Discovery
- Automatically discovers resource groups using deployment name tags
- Falls back to current subscription context if no tagged resources found

### Terraform State Management
- Initializes Terraform automatically if needed
- Uses `-auto-approve` for non-interactive execution

## Configuration Details

### Deployment Names
- Format: `<username>-nginxaas-<region-name-lowercase-with-hyphens>`
- The username is automatically determined using `whoami`
- Examples:
  - West Central US → `user-nginxaas-west-central-us`
  - East US 2 → `user-nginxaas-east-us-2`

## Deletion Process Details

### How the Deletion Script Works

The deletion script follows a comprehensive approach to ensure all resources are properly removed:

1. **User Confirmation**: Prompts for explicit confirmation before proceeding
2. **Resource Discovery**: Searches for resource groups tagged with each deployment name
3. **Subscription Management**: Automatically switches to the correct subscription for each deployment
4. **Dual Deletion Approach**:
   - **Terraform Destroy**: Attempts clean destruction using Terraform state
   - **Direct Resource Group Deletion**: Removes resource groups directly via Azure CLI
5. **Progress Monitoring**: Monitors deletion progress and waits for completion
6. **State Cleanup**: Backs up and removes local Terraform state files

### Deletion Features

- **Safe Execution**: Requires explicit "yes" confirmation to proceed
- **User-Specific**: Only deletes resources belonging to the current user (based on `whoami`)
- **Progress Tracking**: Shows real-time status of deletion operations
- **Timeout Protection**: Maximum 30-minute wait time for deletions
- **State Preservation**: Backs up Terraform state files before cleanup
- **Error Resilience**: Continues deletion even if individual operations fail

### Example Deletion Output

```
Starting multi-region NGINXaaS deletion script
Total regions to check: 22

WARNING: This script will DELETE ALL NGINXaaS resources
across multiple Azure regions for user: <username>

Are you sure you want to proceed with deletion? (yes/no)
yes

STARTING DELETION FOR REGION: West Central US

Getting subscription for deployment: <username>-nginxaas-west-central-us
Setting subscription: <subscription-id>

Attempting Terraform destroy...
Destroying Terraform resources for region: West Central US
[Terraform destroy output...]

Deleting resource groups directly...
Deleting resource group: <resource-group-name>

COMPLETED DELETION FOR REGION: West Central US

[...continues for all regions...]

Waiting for resource group deletions to complete...
All resource group deletions completed!

Cleaning up local Terraform state...
Local Terraform state cleanup completed

ALL DELETIONS COMPLETED
```

### Terraform Variables
The script passes the following variables to Terraform:
- `location`: Azure location code (e.g., "westcentralus")
- `name`: Deployment name
- `capacity`: Current capacity (20 or 30)
- `tags`: Resource tags including environment, region, and deployment name

### Resource Tags
Each deployment includes tags:
```json
{
  "env": "Production",
  "region": "<region-display-name>",
  "deployment": "<deployment-name>"
}
```

STARTING DEPLOYMENT FOR REGION: West Central US

Getting subscription for deployment: nginxaas-west-central-us
Setting subscription: 54177075-6398-4345-b901-f5f165bbed4c

Phase 1: Initial deployment with capacity 20
Deploying to region: West Central US
Location code: westcentralus
Deployment name: nginxaas-west-central-us
Capacity: 20

[Terraform output...]

Phase 2: Scaling to capacity 30
[...]

Phase 3: Scaling back to capacity 20
[...]

COMPLETED DEPLOYMENT FOR REGION: West Central US
```
## Monitoring and Logs

The script provides detailed output including:
- Progress indicators for each phase
- Terraform apply outputs
- Load balancer command results
- Error messages and warnings
- Overall completion summary

## Example Output

```
Starting multi-region NGINXaaS deployment script
Total regions to deploy: 22

STARTING DEPLOYMENT FOR REGION: West Central US

Getting subscription for deployment: <username>-nginxaas-west-central-us
Setting subscription: <subscription-id>

Phase 1: Initial deployment with capacity 20
Deploying to region: West Central US
Location code: westcentralus
Deployment name: <username>-nginxaas-west-central-us
Capacity: 20

[Terraform output...]

Phase 2: Scaling to capacity 30
[...]

Phase 3: Scaling back to capacity 20
[...]

COMPLETED DEPLOYMENT FOR REGION: West Central US
```
========================================================
STARTING DEPLOYMENT FOR REGION: West Central US
========================================================

Getting subscription for deployment: nginxaas-west-central-us
Setting subscription: 54177075-6398-4345-b901-f5f165bbed4c

Phase 1: Initial deployment with capacity 20
============================================
Deploying to region: West Central US
Location code: westcentralus
Deployment name: nginxaas-west-central-us
Capacity: 20
============================================

[Terraform output...]

Phase 2: Scaling to capacity 30
[...]

Phase 3: Scaling back to capacity 20
[...]

========================================================
COMPLETED DEPLOYMENT FOR REGION: West Central US
========================================================
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Ensure you're logged in: `az login`
   - Verify permissions in target subscriptions

2. **Terraform Errors**
   - Check Terraform version compatibility
   - Ensure all required providers are available

3. **Resource Group Not Found**
   - Verify the DeploymentName tag exists on resource groups
   - Check subscription access

4. **Load Balancer Commands Fail**
   - This is handled gracefully with warnings
   - May indicate load balancer doesn't exist yet

### Manual Intervention
If the script fails partway through:
- It can be safely re-run (Terraform handles state)
- Individual regions can be manually deployed using the Terraform configuration
- Use Terraform state commands to inspect current deployments

## Security Considerations

- The script uses service principal or user authentication via Azure CLI
- Ensure appropriate RBAC permissions are configured
- Monitor resource creation and costs across multiple regions
- Consider using Azure Policy for governance

## Cost Management

- Deploying to 22 regions will incur significant costs
- Monitor usage and consider scaling down or deleting test deployments
- Use Azure Cost Management to track expenses
- Consider implementing auto-shutdown policies for non-production environments
