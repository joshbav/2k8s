#### A K8S RBAC TUTORIAL
Revision 11-17-18 

Goal: Create new role "dev-ops" cluster role binding using existing cluster role "view", then create a new cluster role "dev-ops" and change the dev-ops cluster role binding to use the new dev-ops cluster role, so it can do kubectl describes in order to get more detailed information that the cluster role view does not provide. (TODO: rewrite, add explanations of the objects and links to k8s docs, begin with an example. Cover difference between role and cluster roles, etc)

Note: `kubectl auth can-i <verb> <object> --as <object>` is a handy way to test RBAC.

Let's test if the dev-ops user (actually service account) can do 'kubectl get pod' commands:  
`kubectl auth can-i get pods --as dev-ops`  
No, because the dev-ops user (actually service account) doesn’t yet exist yet.

Let's list all the existing cluster roles bindings:  
`kubectl get clusterrolebinding`  
There’s a lot of them built into kubernetes.

Let’s create another cluster role binding named "dev-ops-binding":   
`kubectl create -f dev-ops-cluster-role-binding.yaml`  

Let’s examine it:  
`kubectl describe clusterrolebinding dev-ops-binding`  

This new role binding uses an existing role named "view", let’s examine view:  
`kubectl describe clusterrole view`  
Note it has get, list, and watch permissions, but not describe.

Let's see if we can do get pods as dev-ops, which is currently using the built in role view:  
`kubectl auth can-i get pods --as dev-ops`  
Yes, as expected. 

Let's see if we can delete pods:  
`kubectl auth can-i delete pods --as dev-ops`  
No, view is read only, and it only supports get, list, and watch. 

Let's see if we can describe pods, which is important for dev-ops since that's how you get logs and many other details:  
`kubectl auth can-i describe pods --as dev-ops`  
No, and that's a problem we're going to fix. Describe shows things like secrets and logs, so the view role that we used is not a full read-only access method, it’s much more limited, it can only do get, list and watch. It's more helpful for a limited help desk role, but it's not useful for dev-ops. Since we trust our dev-ops staff we want them to have full read-only access in this namespace. So we want them to be able to do describes, we just don’t want them to change/delete anything in this namespace. 

So let’s create a new cluster role named dev-ops that is simply the view role plus the ability to do describes.
`kubectl create -f dev-ops-cluster-role.yaml`  

(Review dev-ops-cluster-role.yaml and how it was created)

Now that we’ve created the role, we have to bind it to a user (actually a service account) like we did before in order for it to be put to use. Cluster role bindings bind roles to service accounts. So let’s delete the old binding that used the view role first since we will soon replace it:
`kubectl delete -f dev-ops-cluster-role-binding.yaml`  
We told kubectl to look at the file, get all objects within it, and delete them from the K8s cluster. We could have also done a "kubectl delete clusterrolebinding dev-ops-binding" command.

And now we will create the v2 of the dev-ops binding that uses the new dev-ops role that is defined in this file:  
`kubectl create -f dev-ops-cluster-role-binding2.yaml`  

Now let’s try again to see if dev-ops is allowed to describe a pod:
`kubectl auth can-i describe pods --as dev-ops`  
Yes, dev-ops can now describe pods (and all other objects).

We’re done. We created a cluster role named dev-ops by copying the default role of view, adding the describe verb to it. We then bound that role to a (non-existent) user (actually service account) named dev-ops, and used the ‘auth can-i’ feature of kubectl to test what the user dev-ops could do using the new dev-ops role, and verified they could use the describe command, which shows lots of details that dev-ops people often need.  

