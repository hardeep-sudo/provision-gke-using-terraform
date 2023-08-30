variable "example_subdomains" {
  description = "Subdomains used at all example.IO environments"
  type        = list(string)
  default     = ["app", "admin", "test"]
}
