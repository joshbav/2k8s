### SETUP SCRIPT FOR TWO K8S CLUSTERS ON DC/OS ("2k8s") 
Revision 11-17-18

This is a script for Enterprise DC/OS 1.12 that will setup two Kubernetes clusters  
This script has only been tested on OS X and with DC/OS 1.12  

This script will:

1. Install Edge-LB with a configuration for kubectl for the two K8s clusters

2. Install Mesosphere Kubernetes Engine (MKE)

3. Install a K8s cluster named /prod/kubernetes-prod  
   With 1 private node and 1 public node running traefik, RBAC enabled, control plane CPU lowered to 0.5, private reserved resources kube cpus lowered to 1  
   Apache and NGINX via host based ingress   

4. Install a K8s cluster named /dev/kubernetes-dev   
   1 private and 0 public nodes, control plane CPU lowered to 0.5, private reserved resources kube cpus lowered to 1  

5. Install a Cassandra cluster named /cassandra  
   With stock configuration (3 nodes)  

6. Install Jenkins to Marathon named /dev/jenkins  
   With Jenkins master CPU lowered to 0.2  

7. Install an allocation loader to Marathon named /allocation-load so the dashboard entires are not flat

8. Install a DC/OS license file, if it exists

9. Install an SSH key via ssh-add, if it exists

Your existing kubectl config file will be moved to /tmp/kubectl-config

Your existing /etc/hosts will be backed up to /tmp/hosts before being modifyed with new entries for www.apache.test and www.nginx.test

Your existing kubectl config file will be moved to /tmp/kubectl-config, so any existing kubectl configs will be removed

Your existing DC/OS cluster configs will be moved to /tmp/clusters because of a bug (that might be fixed) when too many clusters are defined, so any existing DC/OS cluster configs will be removed

The DC/OS CLI and kubectl must already be installed

#### SETUP

1. Clone this repo  
   `git clone https://github.com/joshbav/2k8s.git`  
   `cd 2k8s`

2. (optional) Modify the script and set the LICENSE_FILE variable to point to your DC/OS EE license.

3. (optional) Modify the script and set the package version variables. They are set to be older by default so upgrades can be shown.

4. (optional) Modify the script and set the SSH_KEY_FILE variable to point to your SSH key (CCM key?). The script will not use SSH, but it will do an ssh-add for you so you can ssh later if desired. 

#### USAGE

1. Start a cluster, such as in CCM. Minimum of 7 private agents, only 1 public agent, DC/OS EE 1.12

2. Copy the master's URL to your clipboard. If it begins with HTTP the script will change it to HTTPS.

3. `sudo ./runme <MASTER_URL>`

4. Wait for it to finish (~ 7 min)

5. Open your browser to www.apache.test and/or www.nginx.test

#### DEMO

This is an incomplete section, ignore it.

1. Deploy older cassandra via GUI before running script, then in AWS kill instance with node 1.
2. Run script.
begin demo
3. Explain HDMK, show RBAC, secrets, etc.
4. 
6. kubectl get nodes  (is already in prod context)
   kubectl get deploy
   kubectl get pod
   kubectl get ds -n kube-system |grep traefik
7. Login as dev-user (pw=deleteme) using an incognito window to show limted access, 
   also show secrets (TODO: fix permissions, doesn't yet work)
8. cassandra demo: 
   dcos cassandra --name=/cassandra pod replace node-1
   wait 10
   dcos cassandra --name=/cassandra plan status recovery
   dcos cassandra --name=/cassandra update start --package-version=2.4.0-3.0.16
   wait 10
   dcos cassandra --name=/cassandra update status
   dcos cassandra --name=/cassandra plan start repair
   dcos cassandra --name=/cassandra plan status repair
   go to GUI and add a cassandra node
   wait 10
   dcos cassandra --name=/cassandra update status (show 4th node is being added)
9. Upgrade dev k8s  
   dcos kubernetes cluster update --cluster-name=dev/kubernetes-dev --package-version=2.0.1-1.12.2 --yes
   Switch to GUI, talk about it
   TODO: why doens't this work? dcos kubernetes cluster debug plan status update --cluster-name=dev/kubernetes-dev
10. Increase private node count in prod k8s to 2 via GUI
11. Enable HA on dev k8's, not prod. 
12. Show nodes screen and dashboard
13. Show Networking -> Services Addresses -> nginx-example.marathon:80, select Connection Latency drop down
14. [K8s RBAC lab](https://github.com/joshbav/2k8s/blob/master/k8s-rbac.md)


