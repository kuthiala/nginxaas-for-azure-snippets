#!/bin/bash

# Multi-region NGINXaaS deletion script
# This script deletes all NGINXaaS deployments across multiple Azure regions

set -e  # Exit on any error

# Define regions array
regions=(
    # "West Central US"
    # "West US"
    # "East US 2" 
    # "West US 2"
    # "West US 3"
    "East US"
    "Central US"
    # "North Central US"
    # "Canada Central"
    # "Brazil South"
    # "West Europe"
    # "North Europe"
    # "Sweden Central"
    # "Germany West Central"
    # "UK West"
    # "UK South"
    # "Australia East"
    # "Japan East"
    # "Korea Central"
    # "Southeast Asia"
    # "Central India"
    # "South India"
)

# Function to convert region display name to Azure location code
get_location_code() {
    local region="$1"
    case "$region" in
        "West Central US") echo "westcentralus" ;;
        "West US") echo "westus" ;;
        "East US 2") echo "eastus2" ;;
        "West US 2") echo "westus2" ;;
        "West US 3") echo "westus3" ;;
        "East US") echo "eastus" ;;
        "Central US") echo "centralus" ;;
        "North Central US") echo "northcentralus" ;;
        "Canada Central") echo "canadacentral" ;;
        "Brazil South") echo "brazilsouth" ;;
        "West Europe") echo "westeurope" ;;
        "North Europe") echo "northeurope" ;;
        "Sweden Central") echo "swedencentral" ;;
        "Germany West Central") echo "germanywestcentral" ;;
        "UK West") echo "ukwest" ;;
        "UK South") echo "uksouth" ;;
        "Australia East") echo "australiaeast" ;;
        "Japan East") echo "japaneast" ;;
        "Korea Central") echo "koreacentral" ;;
        "Southeast Asia") echo "southeastasia" ;;
        "Central India") echo "centralindia" ;;
        "South India") echo "southindia" ;;
        *) echo "eastus" ;;  # Default fallback
    esac
}

# Function to create deployment name from region
get_deployment_name() {
    local region="$1"
    local username=$(whoami)
    echo "${username}-nginxaas-$(echo "$region" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')"
}

# Function to get subscription ID and set subscription
get_and_set_subscription() {
    local deployment_name="$1"
    
    echo "Getting subscription for deployment: $deployment_name"
    
    # Get the resource group information
    local rg_info=$(az group list --tag "DeploymentName=$deployment_name" --query '[0]' 2>/dev/null || echo "null")
    
    if [ "$rg_info" = "null" ] || [ "$rg_info" = "" ]; then
        echo "Warning: No resource group found with DeploymentName tag: $deployment_name"
        echo "Using current subscription context"
        return 1
    fi
    
    # Extract subscription ID from the resource group ID
    local subscription_id=$(echo "$rg_info" | jq -r '.id' | sed 's|/subscriptions/\([^/]*\)/.*|\1|')
    
    if [ "$subscription_id" != "null" ] && [ "$subscription_id" != "" ]; then
        echo "Setting subscription: $subscription_id"
        az account set --subscription "$subscription_id"
        echo "Subscription set successfully"
        return 0
    else
        echo "Warning: Could not extract subscription ID, using current subscription context"
        return 1
    fi
}

# Function to find and delete resource groups
delete_resource_groups() {
    local deployment_name="$1"
    
    echo "Finding resource groups for deployment: $deployment_name"
    
    # Get all resource groups with the deployment name tag
    local resource_groups=$(az group list --tag "DeploymentName=$deployment_name" --query '[].name' -o tsv 2>/dev/null || echo "")
    
    if [ "$resource_groups" = "" ]; then
        echo "No resource groups found with DeploymentName tag: $deployment_name"
        return 0
    fi
    
    # Delete each resource group
    echo "$resource_groups" | while read -r rg_name; do
        if [ "$rg_name" != "" ]; then
            echo "Deleting resource group: $rg_name"
            az group delete --name "$rg_name" --yes --no-wait || {
                echo "Warning: Failed to delete resource group $rg_name"
            }
        fi
    done
    
    echo "Initiated deletion of resource groups for deployment: $deployment_name"
}

# Function to destroy Terraform resources
destroy_terraform() {
    local region="$1"
    local deployment_name="$2"
    local location_code="$3"
    
    echo "============================================"
    echo "Destroying Terraform resources for region: $region"
    echo "Location code: $location_code"
    echo "Deployment name: $deployment_name"
    echo "============================================"
    
    # Change to the create-or-update directory
    cd create-or-update
    
    # Check if Terraform state exists
    if [ ! -f ".terraform/terraform.tfstate" ] && [ ! -f "terraform.tfstate" ]; then
        echo "No Terraform state found, skipping terraform destroy"
        cd ..
        return 0
    fi
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init
    fi
    
    # Destroy Terraform resources
    echo "Destroying Terraform configuration..."
    terraform destroy -auto-approve \
        -var="location=$location_code" \
        -var="name=$deployment_name" \
        -var="capacity=20" \
        -var="tags={env=\"Production\",region=\"$region\",deployment=\"$deployment_name\"}" || {
        echo "Warning: Terraform destroy failed for $deployment_name"
    }
    
    # Return to parent directory
    cd ..
    
    echo "Terraform destroy completed for $region"
}

# Function to delete all resources for a region
delete_region() {
    local region="$1"
    local deployment_name=$(get_deployment_name "$region")
    local location_code=$(get_location_code "$region")
    
    echo ""
    echo "========================================================"
    echo "STARTING DELETION FOR REGION: $region"
    echo "========================================================"
    
    # Get and set subscription
    if get_and_set_subscription "$deployment_name"; then
        # Method 1: Try Terraform destroy first
        echo "Attempting Terraform destroy..."
        destroy_terraform "$region" "$deployment_name" "$location_code"
        
        # Method 2: Delete resource groups directly (more reliable)
        echo "Deleting resource groups directly..."
        delete_resource_groups "$deployment_name"
    else
        echo "Skipping region $region - no deployment found"
    fi
    
    echo "========================================================"
    echo "COMPLETED DELETION FOR REGION: $region"
    echo "========================================================"
    echo ""
}

# Function to wait for deletions to complete
wait_for_deletions() {
    echo "Waiting for resource group deletions to complete..."
    echo "This may take several minutes..."
    
    local username=$(whoami)
    local pending_deletions=true
    local check_count=0
    local max_checks=60  # Maximum 30 minutes (60 * 30 seconds)
    
    while [ "$pending_deletions" = true ] && [ $check_count -lt $max_checks ]; do
        pending_deletions=false
        
        # Check for any resource groups with our naming pattern
        for region in "${regions[@]}"; do
            local deployment_name="${username}-nginxaas-$(echo "$region" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')"
            local rg_exists=$(az group list --tag "DeploymentName=$deployment_name" --query '[].name' -o tsv 2>/dev/null || echo "")
            
            if [ "$rg_exists" != "" ]; then
                pending_deletions=true
                echo "Still waiting for deletion of: $rg_exists"
                break
            fi
        done
        
        if [ "$pending_deletions" = true ]; then
            echo "Deletions still in progress... (check $((check_count + 1))/$max_checks)"
            sleep 30
            check_count=$((check_count + 1))
        fi
    done
    
    if [ $check_count -ge $max_checks ]; then
        echo "Warning: Reached maximum wait time. Some deletions may still be in progress."
        echo "You can check the Azure portal for remaining resources."
    else
        echo "All resource group deletions completed!"
    fi
}

# Function to clean up Terraform state
cleanup_terraform_state() {
    echo "Cleaning up local Terraform state..."
    
    if [ -d "create-or-update/.terraform" ]; then
        echo "Removing .terraform directory..."
        rm -rf create-or-update/.terraform
    fi
    
    if [ -f "create-or-update/terraform.tfstate" ]; then
        echo "Backing up terraform.tfstate..."
        mv create-or-update/terraform.tfstate create-or-update/terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    if [ -f "create-or-update/terraform.tfstate.backup" ]; then
        echo "Backing up terraform.tfstate.backup..."
        mv create-or-update/terraform.tfstate.backup create-or-update/terraform.tfstate.backup.old.$(date +%Y%m%d_%H%M%S)
    fi
    
    echo "Local Terraform state cleanup completed"
}

# Main execution
main() {
    echo "Starting multi-region NGINXaaS deletion script"
    echo "Total regions to check: ${#regions[@]}"
    echo ""
    
    # Warning message
    echo "========================================================"
    echo "WARNING: This script will DELETE ALL NGINXaaS resources"
    echo "across multiple Azure regions for user: $(whoami)"
    echo "========================================================"
    echo ""
    
    # Check if required tools are installed
    if ! command -v az &> /dev/null; then
        echo "Error: Azure CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        echo "Warning: Terraform is not installed or not in PATH"
        echo "Will skip Terraform destroy and rely on resource group deletion"
    fi
    
    # Check if user is logged in to Azure
    if ! az account show &> /dev/null; then
        echo "Error: Not logged in to Azure. Please run 'az login' first"
        exit 1
    fi
    
    # Confirmation prompt
    echo "Are you sure you want to proceed with deletion? (yes/no)"
    read -r confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo "Deletion cancelled"
        exit 0
    fi
    
    echo "Prerequisites check passed. Starting deletions..."
    echo ""
    
    # Delete resources for each region
    for region in "${regions[@]}"; do
        delete_region "$region"
        
        # Short pause between regions
        echo "Waiting 10 seconds before next region..."
        sleep 10
    done
    
    echo ""
    echo "========================================================"
    echo "DELETION INITIATED FOR ALL REGIONS"
    echo "========================================================"
    
    # Wait for deletions to complete
    wait_for_deletions
    
    # Clean up local Terraform state
    cleanup_terraform_state
    
    echo ""
    echo "========================================================"
    echo "ALL DELETIONS COMPLETED"
    echo "========================================================"
    echo "Successfully initiated deletion of NGINXaaS resources in ${#regions[@]} regions"
    echo "Local Terraform state has been cleaned up"
}

# Execute main function
main "$@"
