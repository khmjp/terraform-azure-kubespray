# Install Kubernetes on Azure with terraform and kubespray

- Using cloudshell on Azure
- Deploy VMs with Terraform
- Deploy Kubernetes cluster with kubespray (Ansible)
- (For my learning about Kubernetes)

## Login Cloud Shell on Azure

See the [Overview of Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview)

## Deploy VMs and LoadBalancer with terraform

Get a terraform sample template from the github repository.  
This sample template create ...
- 3 Masters
- 3 Nodes
- 1 LoadBalancer for apiservers

```
$ git clone https://github.com/khmjp/terraform-azure-kubespray.git
```

Initialize the terraform environment to get modules and provider plugins for the Azure platform.
```
$ cd terraform-azure-kubespray
$ terraform init
```

Check terraform variables.
```
$ cat variables.tf
# // Azure location configuration
variable azure_location {
  default = "japaneast"
}


# // Azure resource configuration
...
...
...
```

Check the plan before deploying.  
Specify the ```admin_public_key``` for SSH public-key authentication to VMs.
```
$ myname=`whoami`
$ terraform plan \
  -var "admin_public_key=`cat /home/$myname/.ssh/id_rsa.pub`" \
  -out terraform.tfplan
```

Then deploy the VMs and LoadBalancer.
```
$ terraform apply terraform.tfplan
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

$ 
```

Set parameters from terraform outputs for the ansible playbook later.
```
$ TERRAFORM_RG=`terraform output resource_group_name`
$ TERRAFORM_RNP=`terraform output resource_name_prefix`
$ TERRAFORM_USER=`terraform output username`
```

Create an ansible inventory file with this playbook  ```generate-inventory``` that use azure cli for getting IP.
```
$ ansible-playbook generate-inventory.yml -e azure_resource_group=${TERRAFORM_RG} -e azure_resource_prefix=${TERRAFORM_RNP}
```

## Deploy Kubernetes with kubespray(Ansible)

Get kubespray codes from the github repository.
```
$ git clone https://github.com/kubernetes-sigs/kubespray.git
```

Setup a pipenv environment for kubespray, because ansible version in cloud shell is 2.8.4 (at 2019/9/14) although kubespray support version is 2.7.x.
```
$ pip install pipenv --user
$ PATH=/home/`whoami`/.local/bin:$PATH
$ pipenv --version

# Install dependencies from requirements.txt
$ pipenv install -r kubespray/requirements.txt
```

Deploy Kubernetes cluster with kubespray
```
$ cd kubespray
$ pipenv run ansible-playbook -i ../inventory.ini -u ${TERRAFORM_USER} -b -e "@inventory/sample/group_vars/all/all.yml" -e "@../loadbalancer_vars.yml" cluster.yml


# takes about 40 mins...
```

Test SSH connections with the ansible ping module.
```
$ export ANSIBLE_HOST_KEY_CHECKING=False
$ ansible -m ping -i ../inventory.ini -u ${TERRAFORM_USER} all
```

Get kubeconfig on master01 and setup ```KUBECONFIG``` variable on cloudshell
```
$ ansible -b -u ${TERRAFORM_USER} -i ../inventory.ini -m fetch -a "src=/etc/kubernetes/admin.conf dest=./kubespray_admin.conf flat=yes" kubespray-master-001-vm

$ export KUBECONFIG=$PWD/kubespray_admin.conf
```

Check if kubectl command is available.
```
$ kubectl get nodes
NAME                      STATUS   ROLES    AGE   VERSION
kubespray-master-001-vm   Ready    master   32m   v1.15.3
kubespray-master-002-vm   Ready    master   30m   v1.15.3
kubespray-master-003-vm   Ready    master   30m   v1.15.3
kubespray-node-001-vm     Ready    <none>   29m   v1.15.3
kubespray-node-002-vm     Ready    <none>   29m   v1.15.3
kubespray-node-003-vm     Ready    <none>   29m   v1.15.3
```

## Delete the cluster
If you no longer need this environment, delete it.
```
$ terraform destroy
```

## References
- [Terraform template for Kubespray](https://github.com/ams0/terraform-kubespray-azure) (Many Thanks!)