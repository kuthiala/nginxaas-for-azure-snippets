variable "location" {
  description = "Azure location name for NGINXaaS deployment."
  default     = "eastus"
}

variable "name" {
  description = "Name of NGINXaaS deployment and related resources."
  default     = "example-nginx"
}

variable "sku" {
  description = "SKU of NGINXaaS deployment."
  default     = "preview"
}

variable "tags" {
  description = "Tags for NGINXaaS deployment and related resources."
  type        = map(any)
  default = {
    env = "Production"
  }
}

variable "capacity" {
  description = "Capacity of NGINXaaS deployment."
  type        = number
  default     = 20
}
