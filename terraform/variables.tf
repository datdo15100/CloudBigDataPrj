variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-southeast1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "asia-southeast1-b"
}

variable "machine_type" {
  description = "Machine type for Spark nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "worker_count" {
  description = "Number of Spark worker nodes"
  type        = number
  default     = 2
}
