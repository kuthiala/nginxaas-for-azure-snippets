#!/bin/bash

# Multi-region NGINXaaS deployment script
# This script deploys NGINXaaS across multiple Azure regions with capacity scaling

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
        return 0
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
        return 0
    fi
}

# Function to get load balancer resource group name
get_lb_resource_group() {
    local deployment_name="$1"
    
    echo "Getting load balancer resource group for deployment: $deployment_name"
    
    # Get the resource group name
    local lb_rg_name=$(az group list --tag "DeploymentName=$deployment_name" --query '[0].name' -o tsv 2>/dev/null || echo "")
    
    if [ "$lb_rg_name" = "" ]; then
        echo "Warning: No resource group found with DeploymentName tag: $deployment_name"
        return 1
    fi
    
    echo "$lb_rg_name"
    return 0
}

# Function to execute load balancer command
execute_lb_command() {
    local lb_rg_name="$1"
    
    if [ "$lb_rg_name" = "" ]; then
        echo "Skipping load balancer command - no resource group name available"
        return 0
    fi
    
    echo "Executing load balancer command for resource group: $lb_rg_name"
    
    # Execute the load balancer command
    az network lb address-pool show \
        --resource-group "$lb_rg_name" \
        --lb-name lb-pub \
        --name backend | jq .loadBalancerBackendAddresses || {
        echo "Warning: Load balancer command failed or no load balancer found"
        return 0
    }
}

# Function to deploy with specific capacity
deploy_terraform() {
    local region="$1"
    local capacity="$2"
    local deployment_name="$3"
    local location_code="$4"
    
    echo "============================================"
    echo "Deploying to region: $region"
    echo "Location code: $location_code"
    echo "Deployment name: $deployment_name"
    echo "Capacity: $capacity"
    echo "============================================"
    
    # Change to the create-or-update directory
    cd create-or-update
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init
    fi
    
    # Apply Terraform with the specified parameters
    echo "Applying Terraform configuration..."
    terraform apply -auto-approve \
        -var="location=$location_code" \
        -var="name=$deployment_name" \
        -var="capacity=$capacity" \
        -var="tags={env=\"Production\",region=\"$region\",deployment=\"$deployment_name\"}"
    
    # Return to parent directory
    cd ..
    
    echo "Deployment completed for $region with capacity $capacity"
}

# Function to scale capacity and execute commands
deploy_region() {
    local region="$1"
    local deployment_name=$(get_deployment_name "$region")
    local location_code=$(get_location_code "$region")
    
    echo ""
    echo "========================================================"
    echo "STARTING DEPLOYMENT FOR REGION: $region"
    echo "========================================================"
    
    # Get and set subscription, get resource group
    get_and_set_subscription "$deployment_name"
    lb_rg_name=$(get_lb_resource_group "$deployment_name" || echo "")
    
    # Phase 1: Deploy with capacity 20
    echo "Phase 1: Initial deployment with capacity 20"
    deploy_terraform "$region" 20 "$deployment_name" "$location_code"
    
    # Execute load balancer command after initial deployment
    echo "Executing load balancer command after initial deployment..."
    execute_lb_command "$lb_rg_name"
    
    # Phase 2: Scale to capacity 30
    echo "Phase 2: Scaling to capacity 30"
    deploy_terraform "$region" 30 "$deployment_name" "$location_code"
    
    # Execute load balancer command after scaling up
    echo "Executing load balancer command after scaling up..."
    execute_lb_command "$lb_rg_name"
    
    # Phase 3: Scale back to capacity 20
    echo "Phase 3: Scaling back to capacity 20"
    deploy_terraform "$region" 20 "$deployment_name" "$location_code"
    
    # Execute load balancer command after scaling down
    echo "Executing load balancer command after scaling down..."
    execute_lb_command "$lb_rg_name"
    
    echo "========================================================"
    echo "COMPLETED DEPLOYMENT FOR REGION: $region"
    echo "========================================================"
    echo ""
}

# Main execution
main() {
    echo "Starting multi-region NGINXaaS deployment script"
    echo "Total regions to deploy: ${#regions[@]}"
    echo ""
    
    # Check if required tools are installed
    if ! command -v terraform &> /dev/null; then
        echo "Error: Terraform is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v az &> /dev/null; then
        echo "Error: Azure CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed or not in PATH"
        exit 1
    fi
    
    # Check if user is logged in to Azure
    if ! az account show &> /dev/null; then
        echo "Error: Not logged in to Azure. Please run 'az login' first"
        exit 1
    fi
    
    echo "Prerequisites check passed. Starting deployments..."
    echo ""
    
    # Deploy to each region
    for region in "${regions[@]}"; do
        deploy_region "$region"
        
        # Add a pause between regions to avoid rate limiting
        echo "Waiting 30 seconds before next region deployment..."
        sleep 30
    done
    
    echo ""
    echo "========================================================"
    echo "ALL DEPLOYMENTS COMPLETED"
    echo "========================================================"
    echo "Successfully deployed NGINXaaS to ${#regions[@]} regions"
    echo "Each deployment went through the capacity scaling cycle: 20 -> 30 -> 20"
}

# Execute main function
main "$@"
