###########################################################################
# Required variables
###########################################################################
variable "project" {
  type = string
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "location" {
  type = string
}

variable "network" {
  type = string
}

variable "cluster_subnetwork" {
  type = string
}

###########################################################################
# Optional variables
###########################################################################
variable "write_output" {
  description = "writes certain output to disk for use by an init script"
  default     = true
}

variable "enable_stackdriver_service_account" {
  description = "service account used for prometheus-to-sd"
  default     = true
}

variable "enable_security_policy" {
  description = "creates security policy to restrict access to load balancer"
  default     = false
}

variable "enable_cf_security_policy" {
  description = "creates security policy for load balancer that allows cloudflare IPs + VPN"
  default     = false
}

variable "ip_whitelist" {
  default = []
}

variable "enable_binary_authorization" {
  default = true
}

variable "node_locations" {
  default = []
}

variable "min_master_version" {
  default = ""
}

variable "daily_maintenance_start_time" {
  description = "Specify in RFC3330 format HH:MM GMT"
  default     = "00:00"
}

variable "master_authorized_cidr_blocks" {
  default = [
    {
      cidr_block   = "ip-address/32"
      display_name = "vpn-access"
    },
    {
      cidr_block   = "ip-address/32"
      display_name = "CI-nat-0"
    },
    {
      cidr_block   = "ip-address/32"
      display_name = "CI-nat-1"
    },
  ]
}

variable "node_auto_upgrade" {
  default = true
}

variable "node_version" {
  default = ""
}

variable "pod_security_policy_enabled" {
  default = true
}

variable "default_node_pool_node_count" {
  default = 1
}

variable "default_node_pool_machine_type" {
  default = "n1-standard-2"
}

variable "default_node_pool_max_pods" {
  default = 110
}

#################################
### Matching Engine Node Pool ###
#################################

variable "enable_matching_engine_node_pool" {
  default = false
}

variable "matching_engine_node_pool_node_count" {
  default = 1
}

variable "matching_engine_node_pool_machine_type" {
  default = "n1-standard-8"
}

variable "matching_engine_node_pool_max_pods" {
  default = 110
}

##########################
### blockbook nodepool ###
##########################

variable "enable_blockbook_node_pool" {
  default = false
}

variable "blockbook_node_pool_node_count" {
  default = 1
}

variable "blockbook_node_pool_machine_type" {
  default = "n1-standard-8"
}

variable "blockbook_node_pool_max_pods" {
  default = 110
}

##########################
### redis nodepool ###
##########################

variable "enable_redis_node_pool" {
  default = false
}

variable "redis_node_pool_node_count" {
  default = 1
}

variable "redis_node_pool_machine_type" {
  default = "n2-highmem-32"
}

variable "redis_node_pool_max_pods" {
  default = 110
}

#######################
### CAS Node Pool #####
#######################
variable "enable_cas_node_pool" {
  default = false
}

variable "cas_node_pool_count" {
  default = 1
}

variable "cas_node_pool_machine_type" {
  default = "n1-highcpu-8"
}

#######################
### Kafka Node Pool ###
#######################

variable "enable_kafka_node_pool" {
  default = false
}

variable "kafka_node_pool_node_count" {
  default = 2
}

variable "kafka_node_pool_machine_type" {
  default = "n1-standard-4"
}

variable "kafka_node_pool_max_pods" {
  default = 110
}

variable "pods_ip_range" {
  default = "pods"
}

variable "services_ip_range" {
  default = "services"
}

variable "master_ipv4_cidr_block" {
  default = "172.16.0.0/28"
}

variable "enable_private_endpoint" {
  description = "Enable if you want the Kubernetes master to have only an internal IP RFC1918"
  default     = true
}

variable "enable_private_nodes" {
  description = "Enable if you want the nodes to not have public IPs"
  default     = true
}

variable "container_registry_bucket" {
  description = "Provides image pull access"
  default     = "us.artifacts.example-ops.appspot.com"
}

variable "logging_service" {
  description = "logging.googleapis.com, logging.googleapis.com/kubernetes, or none"
  default     = "logging.googleapis.com"
}

variable "monitoring_service" {
  description = "monitoring.googleapis.com, monitoring.googleapis.com/kubernetes, or none"
  default     = "monitoring.googleapis.com"
}

