terraform {
  required_providers {
    appwrite = {
      source  = "appwrite/appwrite"
      version = "~> 1.0"
    }
  }
}

variable "endpoint" {
  type = string
}
variable "project_id" {
  type = string
}
variable "api_key" {
  type = string
  sensitive = true
}
provider "appwrite" {
  endpoint   = var.endpoint
  project_id = var.project_id
  api_key    = var.api_key
}



# 4. Define the Column
resource "appwrite_tablesdb_column" "description" {
  database_id = "69e992170000e2f90e12"
  table_id    = "profiles"
  key         = "userState"
  type        = "enum"    # <--- This is where you declare it's a string!
  elements    = ["New", "underReview", "approved", "unApproved", "onConflict", "chatBanned", "banned"]
  required    = false  # If true, you cannot set a default value
}

