# Cluster Module

This module creates a GKE cluster. By default it follows the security best practices outlined in [GKE Hardening](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster).

The cluster is currently setup as a `zonal cluster`, which means that the `master node` operates in only one zone. The cluster can be configured to run nodes in multiple zone by changing the `additional_zones` variable, but the master will still operate in a single zone. If the master zone fails or is degraded you will not be able to interact with the Kubernetes API, but resources will continue to operate as usual (assuming that you've set additional zones).

We may want to consider moving to a `regional cluster`, which will run multiple masters. Regional clusters are covered in [GKE Regional Cluster](https://cloud.google.com/kubernetes-engine/docs/concepts/regional-clusters).

## Production/Staging

Update the following settings based on required resources and availability:

* `main_node_pool_node_count`
* `main_node_pool_machine_type`
* `additional_zones`

The following setting(s) are configured for convenience but should be changed for security:

* `master_authorized_cidr_blocks`
	* defaults to `0.0.0.0/0`
	* should be set to the bastion
