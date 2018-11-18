### SETUP SCRIPT FOR TWO K8S CLUSTERS ON DC/OS ("2k8s") 
Revision 11-17-18

This is a script for Enterprise DC/OS 1.12 that will setup two Kubernetes clusters.

This script will:

Install Edge-LB with a configuration for kubectl for two K8s clusters

Install Kubernetes (MKE)

Install a K8s cluster named /prod/kubernetes-prod
   with 1 private node and 1 public node which will run traefik
   Configuration: RBAC enabled, control plane CPU lowered to 0.5, private reserved resources kube cpus lowered to 1
   and Apache and NGINX

Install a K8s cluster named /dev/kubernetes-dev
   1 private and 0 public nodes, control plane CPU lowered to 0.5, private reserved resources kube cpus lowered to 1

Install a Cassandra cluster named /cassandra

Install an allocation load /allocation-load so the dashboard entires are not flat

Install a DC/OS license file, if it exists

Insall an SSH key via ssh-add, if it exists

Your existing kubectl config file will be moved to /tmp/kubectl-config

Your existing /etc/hosts will be backed up to /tmp/hosts before being modifyed to add lines for www.apache.test and www.nginx.test

Your existing kubectl config file will be moved to /tmp/kubectl-config, so any existing kubectl configs will be removed

Your existing DC/OS cluster configs will be moved to /tmp/clusters because of a bug (that might be fixed) when too many clusters are defined, so any existing cluster configs will be removed

The DC/OS CLI and kubectl must already be installed

This script has only been tested on OS/X and with DC/OS 1.12

#### SETUP

1. Clone this repo
   `git clone https://github.com/joshbav/2k8s.git`
   `cd 2k8s`

2. (optional) Modify the script and set the LICENSE_FILE variable to point to your DC/OS EE license.

3. (optional) Modify the script and set the package versions. They are set to be older by default so upgrades can be shown.

4. (optional) Modify the script and set the SSH_KEY_FILE variable to point to your SSH key (CCM key?). The script will not use SSH, but it will do an ssh-add for you so you can ssh if desired. 

#### USAGE

1. Start a cluster, such as in CCM. Minimum of 10 private agents, 1 public agent, DC/OS EE 1.12

2. Copy the master's URL to your clipboard. If it begins with HTTP the script will change it to HTTPS.

3. `sudo ./runme <MASTER_URL>`

4. Wait for it to finish (~ 7 min)

5. Open your browser to www.apache.test and/or www.nginx.test

