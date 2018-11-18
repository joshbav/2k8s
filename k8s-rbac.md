#### A K8S RBAC TUTORIAL
Revision 11-17-18 

Goal: create new role named help-desk, using existing cluster role binding view, then change its role to a new role we will create that has more access but it still read only.

Note: kubectl auth can-i <verb> <object> --as <object> is a handy way to configure RBAC.

`kubectl auth can-i get pods --as dev-ops`  
No, because dev-ops doesn’t yet exist yet. 

`kubectl get clusterrolebinding` 
There’s a lot of them built into kubernetes
Let’s create another named help-desk-binding:

`kubectl create -f dev-ops-cluster-role-binding.yaml` 

Let’s examine it:
`kubectl describe clusterrolebinding dev-ops-binding` 

This new role binding uses an existing role named view, let’s look at view:
`kubectl describe clusterrole view` 

Note it has get, list, and watch permissions, but not describe

`kubectl auth can-i get pods --as dev-ops` 
Yes

`kubectl auth can-i delete pods --as dev-ops` 
No, it's read only

`kubectl auth can-i describe pods --as dev-ops` 

No, because describe shows things like secrets and such, so the view role that we used is not a full read-only access method, it’s more limited. But we trust our dev-ops staff, and want them to have read-only access in this namespace. So we want them to be able to describe objects, we just don’t want them to change anything. So let’s create a new role named help-desk that is simply the view role plus the ability to do a describe of objects.

`kubectl create -f dev-ops-cluster-role.yaml` 

(Review dev-ops-cluster-role.yaml and how it was created)

Now that we’ve created the role, we have to bind it to a user (actually a service account) like we did before in order for it to be put to use. So let’s delete the old binding that used the view role first since we will soon replace it:

`kubectl delete clusterrolebinding dev-ops-binding` 

And now we will create the v2 of the help-desk binding:

`kubectl create -f dev-ops-cluster-role-binding2.yaml` 

Now let’s see if help-desk is allowed to describe a pod:

`kubectl auth can-i describe pods --as dev-ops` 

Yes, help-desk can now describe pods (and all other objects)

We’re done. We created a cluster role named dev-ops by copying the default role of view,  adding the describe verb to it. We then bound that role to a (non-existent) user (actually service account) named dev-ops, and used the ‘auth can-i’ feature of kubectl to test what the user dev-ops could do using the new dev-ops role, and verified they could use the describe command, which shows lots of details that dev-ops people often need.  

