#!/bin/bash

# left off: traefik, try stock config
# CCM cluster of 10 private and 1 public node

# list files, document their differences
# todo: pull in other todos, version
# groups and users for dev and prod
# ccm priv key
# mke to get options with sa
# look at runme
# rename to runme
# doc kubectl change context, make it part of the script
# cleanup: delete keys
# what permissions does MKE need in its service account? is it for a team's k8s, or for all k8s?

# make directions: ccm req, git clone, ssh key, license, example, how to demo it. 
# explain why elb is needed, why kubectl is moved 
# adds a binary secret
# creates dev and prod groups, and dev-user and prod-user, password deleteme

# prod options: stock except for kube CPU's lowered to 1, public node count raised to 1, calico cidr set to 192.168.100.0/24, no rbac!

# new prod: rbac, controplane cpu lowered to 0.5, priv reserved kube cpus lowered to 1, public node count raised to 1, 



######## VARIABLES ########

SCRIPT_VERSION="NOV-17-18"
LICENSE_FILE="dcos-1-12-license-50-nodes.txt"
EDGE_LB_VERSION="1.2.2"
K8S_MKE_VERSION="2.0.0-1.12.1"
K8S_PROD_VERSION="2.0.0-1.12.1"
K8S_DEV_VERSION="2.0.0-1.12.1"
CASSANDRA_VERSION="2.3.0-3.0.16"
SSH_KEY_FILE="/Users/josh/ccm-priv.key"
DCOS_USER="bootstrapuser"
DCOS_PASSWORD="deleteme"

#### TEST IF RAN AS ROOT

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, via sudo" 
   exit 1
fi

#### SETUP MASTER URL VARIABLE

# NOTE: elb url is not used in this script (yet) TODO
if [[ $1 == "" ]]
then
        echo
        echo " A master node's URL was not entered. Aborting."
        echo
        exit 1
fi

# For the master change http to https so kubectl setup doesn't break
MASTER_URL=$(echo $1 | sed 's/http/https/')

#### EXPLAIN WHAT THIS SCRIPT WILL DO

echo
echo
echo "Script version $SCRIPT_VERSION"
echo
echo "This script will install:"
echo
echo "  1. Edge-LB v$EDGE_LB_VERSION"
echo
echo "  2. Kubernetes (MKE) v$K8S_MKE_VERSION"
echo
echo "  3. A v$K8S_PROD_VERSION K8s cluster named /prod/kubernetes-prod"
echo "     this cluster will have 1 public node which will run traefik,"
echo "     and apache and NGINX"
echo
echo "  4. A v$K8S_DEV_VERSION K8s cluster named /dev/kubernetes-dev"
echo
echo "  5. A v$CASSANDRA_VERSION cassandra cluster named /cassandra"
echo
echo "  6. An allocation load /allocation-load so the dashboard stats are not flat" 
echo
echo "  7. A license file named $LICENSE_FILE, if it exists"
echo
echo "  8. The SSH key $SSH_KEY_FILE via ssh-add, if it exists"
echo
echo "Your existing kubectl config file will be moved to /tmp/kubectl-config"
echo
echo "Your existing /etc/hosts will be backed up to /tmp/hosts before modifying it to add" 
echo "   lines for www.apache.test and www.nginx.test"
echo
echo "Your existing DC/OS cluster configs will be moved to /tmp/clusters"
echo "  because of a bug (that might be fixed) when too many clusters are defined."
echo
echo "The DC/OS CLI and kubectl must already be installed, it will be configured for the cluster at"
echo "$MASTER_URL"
echo "with user name $DCOS_USER and password $DCOS_PASSWORD"
echo
echo "The user name that ran this script is $USER"
echo "and file ownership for kubectl and DC/OS CLI files will be chown'ed to that user"



#### MOVE DCOS CLI CLUSTERS TO /TMP/CLUSTERS

echo
echo "**** Moving DC/OS CLI configuration to /tmp/dcos-clusters"
echo "     So all existing DC/OS cluster configurations are now removed"
echo
rm -rf /tmp/dcos-clusters 2> /dev/null
mkdir /tmp/dcos-clusters
mv ~/.dcos/clusters/* /tmp/dcos-clusters 2> /dev/null
mv ~/.dcos/dcos.toml /tmp/dcos-clusters 2> /dev/null
rm -rf ~/.dcos 2> /dev/null

#### SETUP CLI

echo
echo "**** Running command: dcos cluster setup"
echo
dcos cluster setup $MASTER_URL --insecure --username=$DCOS_USER --password=$DCOS_PASSWORD
echo
echo "**** Installing enterprise CLI"
echo
dcos package install dcos-enterprise-cli --yes
echo
echo "**** Setting core.ssl_verify to false"
echo
dcos config set core.ssl_verify false

#### UPDATE DC/OS LICENSE TO > CCM'S DEFAULT LICENSE

if [[ -e $LICENSE_FILE ]]; then
    echo
    echo "**** Updating DC/OS license using $LICENSE_FILE"
    echo
    dcos license renew $LICENSE_FILE
else
    echo
    echo "**** License file $LICENSE_FILE not found, license will not be updated"
    echo
fi

#### ADDING SSH KEY, EVEN THOUGH THIS SCRIPT DOESN'T USE IT

if [[ -e $SSH_KEY_FILE ]]; then
    echo
    echo "**** Adding SSH key $SSH_KEY_FILE to this workstation's SSH keychain"
    echo
    ssh-add $SSH_KEY_FILE
else
    echo
    echo "**** SSH key $SSH_KEY_FILE not found, no key will be added to this workstation's SSH keychain"
    echo
fi

#### MOVE EXISTING KUBE CONFIG FILE, IF ANY, AND DISPLAY KUBECTL VERSION

if [[ -e ~/.kube/config ]]; then
    echo
    echo "**** ~/.kube/config exists, moving it to /tmp/kubectl-config"
    echo "     And deleting any existing /tmp/kubectl-config"
    echo "     Therefore you now have no active kubectl config file"
    echo
    rm -f /tmp/kubectl-config 2 > /dev/null
    mv ~/.kube/config /tmp/kube-config
fi

echo
echo "**** Ensure your client version of kubectl is up to date, this is your 'kubectl version --short' output:"
echo "     Ignore the statement of 'The connection to the server localhost:8080 was refused'"
echo
kubectl version --short
echo

#### INSTALL EDGE-LB

echo
echo "**** Installing Edge-LB v$EDGE_LB_VERSION"
echo
dcos package repo add --index=0 edge-lb https://downloads.mesosphere.com/edgelb/v$EDGE_LB_VERSION/assets/stub-universe-edgelb.json
dcos package repo add --index=0 edge-lbpool https://downloads.mesosphere.com/edgelb-pool/v$EDGE_LB_VERSION/assets/stub-universe-edgelb-pool.json

rm -f /tmp/edge-lb-private-key.pem 2> /dev/null
rm -f /tmp/edge-lb-public-key.pem 2> /dev/null
# CHANGE: commented out two lines
dcos security org service-accounts keypair /tmp/edge-lb-private-key.pem /tmp/edge-lb-public-key.pem
dcos security org service-accounts create -p /tmp/edge-lb-public-key.pem -d "Edge-LB service account" edge-lb-principal
# dcos security org service-accounts show edge-lb-principal
# TODO DEBUG Getting error on next line, says it already exists, assuming it was added for a strict mode cluster?
dcos security secrets create-sa-secret --strict /tmp/edge-lb-private-key.pem edge-lb-principal dcos-edgelb/edge-lb-secret
# TODO DEBUG Getting error on next line, says already part of group
dcos security org groups add_user superusers edge-lb-principal

dcos package install --package-version=$EDGE_LB_VERSION --options=edgelb-options.json edgelb --yes
# Is redundant but harmless
dcos package install edgelb --package-version=$EDGE_LB_VERSION --cli --yes

#### WAIT FOR EDGE-LB TO INSTALL

# This is done now so the next section that needs user input to get the sudo password can happen
# sooner rather than later, so you can walk away and let the script run after
echo
echo "**** Waiting for Edge-LB to install"
echo
sleep 20
echo "     Ignore any 404 errors on next line that begin with  dcos-edgelb: error: Get https://"
until dcos edgelb ping; do sleep 3 & echo "still waiting..."; done

#### DEPLOY EDGELB CONFIG FOR KUBECTL

echo
echo "**** Deploying Edge-LB config from edgelb-kubectl-two-clusters.json"
echo
dcos edgelb create edgelb-kubectl-two-clusters.json
echo
echo "**** Sleeping for 30 seconds since it takes some time for EdgeLB's config to load"
echo
sleep 30
echo
echo "**** Running dcos 'edgelb status edgelb-kubectl-two-clusters'"
echo
dcos edgelb status edgelb-kubectl-two-clusters
#echo
#echo "**** Running 'dcos edgelb show edgelb-kubectl-two-clusters'"
#echo
#dcos edgelb show edgelb-kubectl-two-clusters

#### GET PUBLIC IP OF EDGE-LB PUBLIC AGENT

# This is a real hack, and it might not work correctly!
echo
echo "**** Setting env var EDGELB_PUBLIC_AGENT_IP using a hack of a method"
echo
export EDGELB_PUBLIC_AGENT_IP=$(dcos task exec -it edgelb-pool-0-server curl ifconfig.co | tr -d '\r' | tr -d '\n')
echo Public IP of Edge-LB node is: $EDGELB_PUBLIC_AGENT_IP
# NOTE, if that approach to finding the public IP doesn't work, consider https://github.com/ably77/dcos-se/tree/master/Kubernetes/mke/public_ip

#### SETUP HOSTS FILE FOR APACHE AND NGINX

echo
echo "**** Copying /etc/hosts to /tmp/hosts as a backup, deleting /tmp/hosts if it exists"
echo
rm -f /tmp/hosts 2> /dev/null
cp /etc/hosts /tmp

if [ -n "$(grep www.apache.test /etc/hosts)" ]; then
    echo "**** www.apache.test line found in /etc/hosts, removing that line";
    echo
    sed -i '' '/www.apache.test/d' /etc/hosts
else
    echo "**** www.apache.test was not found in /etc/hosts";
    echo
fi

if [ -n "$(grep www.nginx.test /etc/hosts)" ]; then
    echo "**** www.nginx.test line found in /etc/hosts, removing that line";
    echo
    sed -i '' '/www.nginx.test/d' /etc/hosts
else
    echo "**** www.nginx.test was not found in /etc/hosts";
    echo
fi

echo "**** Adding entries to /etc/hosts for www.apache.test and www.nginx.test"
echo "     sudo may be needed, please enter your root password if prompted"

echo "$EDGELB_PUBLIC_AGENT_IP www.apache.test" >> /etc/hosts
echo "$EDGELB_PUBLIC_AGENT_IP www.nginx.test" >> /etc/hosts
# to bypass DNS & hosts file: curl -H "Host: www.apache.test" $EDGELB_PUBLIC_AGENT_IP

#### SETUP AND INSTALL MKE /kubernetes

echo
echo "**** Creating service account for MKE /kubernetes"
echo
bash setup_security_kubernetes-cluster.sh kubernetes kubernetes
echo
echo "**** Installing MKE /kubernetes"
echo
dcos package install kubernetes --package-version=$K8S_MKE_VERSION --options=kubernetes-mke-options.json --yes
# Might be redundant, but is harmless
dcos package install kubernetes --package-version=$K8S_MKE_VERSION --cli --yes
echo
echo "**** Sleeping for 20 seconds to wait for MKE to finish installing"
echo
sleep 20

#### SETUP SERVICE ACCOUNT FOR /PROD/KUBERNETES-PROD AND INSTALL K8S

echo
echo "**** Creating service account kubernetes-prod for use by /prod/kubernetes-prod"
echo
bash setup_security_kubernetes-cluster.sh prod/kubernetes-prod kubernetes-prod prod/kubernetes-prod
echo
echo "**** Installing /prod/kubernetes-prod K8s cluster, v$K8S_PROD_VERSION using kubernetes-prod-options.json"
echo "     This cluster has 1 private kubelet, and 1 public kubelet"
echo
dcos kubernetes cluster create --package-version=$K8S_PROD_VERSION --options=kubernetes-prod-options.json --yes
# TODO: calico: "192.168.100.0/24", 1 public node.
# dcos kubernetes cluster debug plan status deploy --cluster-name=prod/kubernetes-prod

#### SETUP SERVICE ACCOUNT FOR /DEV/KUBERNETES-DEV AND INSTALL K8S

echo
echo "**** Creating service account kubernetes-prod for use by /dev/kubernetes-dev"
echo
bash setup_security_kubernetes-cluster.sh dev/kubernetes-dev kubernetes-dev dev/kubernetes-dev
echo
echo "**** Installing /dev/kubernetes-dev K8s cluster, v$K8S_DEV_VERSION using kubernetes-dev-options.json"
echo
dcos kubernetes cluster create --package-version=$K8S_DEV_VERSION --options=kubernetes-dev-options.json --yes
# dcos kubernetes cluster debug plan status deploy --cluster-name=dev/kubernetes-dev
# TODO document diff

#### WAIT FOR BOTH K8S CLUSTERS TO COMPLETE THEIR INSTALL

echo
echo "**** Sleeping for 330 seconds before testing if K8s install of /prod/kubernetes-prod is done,"
echo "     since it takes a while for kubernetes to be installed"
echo
sleep 330
seconds=330
OUTPUT=1
while [ "$OUTPUT" != 0 ]; do
  # since the public kubelet is the last to deploy, we will monitor it
  OUTPUT=`dcos kubernetes cluster debug plan status deploy --cluster-name=prod/kubernetes-prod | grep kube-node-public-0 | awk '{print $3}'`;
  if [ "$OUTPUT" = "(COMPLETE)" ];then
        OUTPUT=0
  fi
  seconds=$((seconds+10))
  printf "Waited $seconds seconds for Kubernetes to start. Still waiting.\n"
  sleep 10
done

echo
echo "**** /prod/kubernetes-prod install complete"
echo
echo "**** Waiting for /dev/kubernetes-dev to install"
echo
seconds=0
OUTPUT=1
while [ "$OUTPUT" != 0 ]; do
  sleep 10
  seconds=$((seconds+10))
  printf "Waited $seconds seconds for Kubernetes to start. Still waiting.\n"
  OUTPUT=`dcos kubernetes cluster debug plan status deploy --cluster-name=dev/kubernetes-dev | grep kube-control-plane-0 | awk '{print $4}'`;
  if [ "$OUTPUT" = "(COMPLETE)" ];then
        OUTPUT=0
  fi
done
echo
echo "**** /dev/kubernetes-dev install complete"
echo
# sleep 5 more just to be safe
sleep 5

#### SETUP KUBECTL FOR /PROD/KUBERNETES-PROD

echo
echo "**** Running dcos kubernetes cluster kubeconfig for /prod/kubernetes-prod, as context 'prod'"
echo
dcos kubernetes cluster kubeconfig --insecure-skip-tls-verify --context-name=prod --cluster-name=prod/kubernetes-prod --apiserver-url=https://$EDGELB_PUBLIC_AGENT_IP:6443

#### TEST KUBECTL WITH /PROD/KUBERNETES-PROD

echo
echo "**** Running kubectl get nodes for /prod/kubernetes-prod"
echo
kubectl get nodes

#### INSTALL TRAEFIK, APACHE, AND NGINX TO /PROD/KUBERNETES-PROD CLUSTER

echo
echo "**** Installing Traefik to /prod/kubernetes-prod"
echo
kubectl create -f traefik.yaml
echo
echo "**** Installing Apache to /prod/kubernetes-prod"
echo
kubectl create -f apache.yaml
echo
echo "**** Installing NGINX to /prod/kubernetes-prod"
echo
kubectl create -f nginx.yaml

#### SETUP KUBECTL FOR /DEV/KUBERNETES-DEV

echo
echo "**** Running dcos kubernetes cluster kubeconfig for /dev/kubernetes-dev, as context 'dev'"
echo
dcos kubernetes cluster kubeconfig --insecure-skip-tls-verify --context-name=dev --cluster-name=dev/kubernetes-dev --apiserver-url=https://$EDGELB_PUBLIC_AGENT_IP:6444

#### TEST KUBECTL WITH /DEV/KUBERNETES-DEV

echo
echo "**** Running kubectl get nodes for /dev/kubernetes-dev"
echo
kubectl get nodes

#### SHOW KUBECTL CONFIG

echo
echo "**** Running kubectl config get-clusters"
echo
kubectl config get-clusters
# kubectl config use-context prod
echo
echo "**** Changing kubectl context back to prod"
echo
kubectl config use-context prod

#### INSTALL BINARY SECRET TO DC/OS (NOT K8S)

echo
echo "**** Adding binary secret /binary-secret to DC/OS's secret store"
echo "     To display it: dcos security secrets get /binary-secret"
echo
dcos security secrets create /binary-secret --file binary-secret.txt

#### SETUP USER PROD-USER & GROUP PROD & SECRET /PROD/SECRET

echo
echo
echo "**** Creating DC/OS user prod-user, group prod, secret /prod/example-secret, and example app"
echo
dcos security org users create prod-user --password=deleteme
dcos security org groups create prod
dcos security org groups add_user prod prod-user
dcos security secrets create /prod/example-secret --value="prod-team-secret"
dcos security org groups grant prod dcos:secrets:list:default:/prod full
dcos security org groups grant prod dcos:secrets:default:/prod/* full
dcos security org groups grant prod dcos:service:marathon:marathon:services:/prod full
dcos security org groups grant prod dcos:adminrouter:service:marathon full
# Appears to be necessary per COPS-2534
dcos security org groups grant prod dcos:secrets:list:default:/ read
# Make the marathon folder by making the app
dcos marathon app add prod-example-marathon-app.json

#### SETUP USER DEV-USER & GROUP DEV & SECRET /DEV/SECRET

echo
echo "**** Creating DC/OS user dev-user, group dev, secret /dev/example-secret, and example app"
echo
dcos security org users create dev-user --password=deleteme
dcos security org groups create dev
dcos security org groups add_user dev dev-user
dcos security secrets create /dev/example-secret --value="dev-team-secret"
dcos security org groups grant dev dcos:secrets:list:default:/dev full
dcos security org groups grant dev dcos:secrets:default:/dev/* full
dcos security org groups grant dev dcos:service:marathon:marathon:services:/dev full
dcos security org groups grant dev dcos:adminrouter:service:marathon full
# Appears to be necessary per COPS-2534
dcos security org groups grant dev dcos:secrets:list:default:/ read
# Make the marathon folder by making the app
dcos marathon app add dev-example-marathon-app.json

#### INSTALL CASSANDRA

echo
echo
echo "**** Installing cassandra v$CASSANDRA_VERSION"
echo
dcos package install cassandra --package-version=$CASSANDRA_VERSION --yes
# In case it was installed manually before running this script,
# which I do sometimes since I often terminate a node in AWS to show
# cassandra repairing, we will now install the CLI. So the above install of cassandra 
# will report it's already installed, but since it was installed from the GUI the CLI
# isn't yet installed. 
dcos package install cassandra --package-version=$CASSANDRA_VERSION --cli --yes

#### INSTALL ALLOCATION LOAD SO THE DASHBOARD ISN'T FLAT

dcos marathon app add allocation-load.json
 
#### CLEANUP, FIX DCOS CLI AND KUBECTL FILE OWNERSHIP BECAUSE OF SUDO

rm -f private-key.pem 2> /dev/null
rm -f public-key.pem 2> /dev/null

# This script is ran via sudo since /etc/hosts is modified. But it also sets up kubectl and the dcos CLI
# which means some of those files now belong to root

## $REAL_OWNER=$(ls -ld ~/.bash_history | awk 'NR==1 {print $3}')
echo
echo "**** Running chown -RH on ~/.kube and ~/.dcos since this script is ran via sudo"
echo
chown -RH $USER ~/.kube
chown -RH $USER ~/.dcos

echo
echo
echo
echo "**** FINISHED"
echo "     You can point your browser to www.apache.test and www.nginx.test"
echo "     You might need to wait up to 30 seconds first for everything to finish installing"
echo

