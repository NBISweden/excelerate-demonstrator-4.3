# Elixir-Excelerate Demonstrator 4.3

This repository contains instructions and scripts for setting up a cloud
resource using Elixir id, deploying a storage endpoint VM, and using the Elixir
Data Transfer Service to move a set of files to the cloud instance.

## Prerequisites

* an Elixir id
  * [sign up at the Elixir web site](https://www.elixir-europe.org/intranet)
* an ssh key pair
  * [instructions](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/)
* access to resources from a cloud provider
  * in this demonstor, we have used the [denbi cloud](https://www.denbi.de/cloud), which is integrated with the Elixir AAI system
* [terraform](https://www.terraform.io/) (infrastructure as code software by [HashiCorp](https://www.hashicorp.com/))
* [fts3](https://fts.web.cern.ch/) command line tools
  * [documentation](https://fts3-docs.web.cern.ch/fts3-docs/)
  * for a workstation running [CentOS](https://centos.org/) with the [EPEL](https://fedoraproject.org/wiki/EPEL) repository enabled, simply run `yum install fts-client`

## Deploying a storage endpoint

We use terraform to deploy a VM running a gridftp daemon.

First we download a proxy certificate that will be used to authentate with the
Elixir Transfer service. For this the user must have access to the [VO
Portal](https://elixir-cilogon-mp.grid.cesnet.cz/vo-portal/).

### Registering for the Elixir VO

1. Visit the [Elixir VO registration page](https://perun.cesnet.cz/elixir/registrar/?vo=vo.elixir-europe.org)
2. Send an e-mail to
   [aai-contact@elixir-europe.org](mailto:aai-contact@elixir-europe.org) and
   state that you would like to have access to the VO portal.

### Obtaining a proxy certificate 

Once the VO access is approved, we can log in at the portal and save the proxy
certificate in a text file, e.g. by pasting it into `cert.txt`.

From the VO Portal, we also take note of the `identity` (typically a string of
the form `/DC=eu/DC=rcauth/DC=rcauth-clients/O=ELIXIR/CN=Firstname Lastname
Randomstring` (the identity can of course also be extracted from the proxy
certificate itself, using e.g. the `openssl` tool).

### Deploying endpoint

In this example, we are using a clod provider that is running [Open
Stack](https://www.openstack.org/), so in addition to terraform, we need the
openstack command line tools, which can be
installed by e.g. `pip install openstack`.

We also need the api keys associated with our project from the cloud provider.
These can be downloaded from the Horizon interface in OpenStack (log in to the
cloud dashboard, go to "Access & Security", click "Download OpenStack RC file"
and save the file as e.g. `openstack.rc`).

We source the OpenStack rc file and query the cloud provider for details about the public network:
```sh
source openstack.rc
openstack network list --external
```

Next, we deploy a VM and install the gridftp daemon by using the terraform scripts:

```sh
terraform apply \
-var 'external_gateway=52b76a82-5f02-4a3e-9836-57536ef1cb63' \
-var 'pool="Public External IPv4 Network"' \
-var 'certificate="/DC=eu/DC=rcauth/DC=rcauth-clients/O=ELIXIR/CN=Firstname Lastname abc123"'
```
Note that if the variables are not specified as arguments, terraform will ask the user for them.

Terraform will then spin up a VM based on Centos 7 and apply some network
rules. The details of this can be found in `main.tf`.

Finally the gridftp server is installed, equipped with a server certificate,
and set to map the user certificate to a user called `gridftp` on the VM. This
is done by terraform by uploading the script `centos-gridftp-rw.sh` and running
it on the VM with our certificate identity as argument.

The terraform provisioning takes a few minutes, Once done, terraform will print
the ip number to the VM once the provisioning is complete. Then it is possible
to log in to the VM with ssh. 

## Transfering data to the virtual machine

Next, we transfer data from different sources to our cloud instance.

### Specifying endpoint as destination

The files that we will transfer to the VM are listed in `url.txt`. For the
transfer job, we need to specify a destination for each file. Here, we choose
to store all files on the VM in a directory structure of the form `/srv/data/$PRURL`, where
`$PRURL`is the protocol-relative URL. E.g. a URL
"https://www.elixir-europe.org/system/files/white-orange-logo.png" would be
stored on the VM as
"/srv/data/www.elixir-europe.org/system/files/white-orange-logo.png".

We append the destination URL (where we use `gsiftp` as protocol) for each
source URL and save it in a new file:
```sh
PREFIX='gsiftp:\/\/vm-123.denbi.de\/srv\/data'
sed "s/\(\".*:\/\)\(.*$\)/\1\2 \"$PREFIX\2/" urls.txt > transfers.txt
```
where `vm-123.denbi.de` is the host name of our VM.

### Submitting a transfer job

We start by using our certificate to authenticate to the Elixir Data Transfer Service:

```
fts-delegation-init --proxy cert.txt -v -s https://fts3.du2.cesnet.cz:8446
```

We can then submit our transfer job to the fts3 server:
```sh
fts-transfer-submit --proxy cert.txt --nostreams 8 -s https://fts3.du2.cesnet.cz:8446 -f transfers.txt
```
The data transfer job is then carried out and monitored by the Elixir data transfer service.

### Monitoring the transfer

The fts3 service can also be used to monitor the status and progress of
transfer jobs. When we submitted the transfer job, a string identifying the
transfer was returned. We can query the fts3 service for the status on the job
with this id, viz:
```sh
fts-transfer-status --proxy cert.txt --verbose -d -s https://fts3.du2.cesnet.cz:8446 -l bc6b2602-2e83-11e8-a97e-525400cb6b4b
```

Once the data has been transferred to the cloud instance, we can of course log
in, process the data there, and finally use the transfer service to copy the
result to some other endpoint, or download to our workstation.

## Conclusion

In this short demonstration, we have used our Elixir identity to deploy a cloud
instance, and to copy a data set to it using the Elixir Transfer Service.

## Acknowledgements

In setting up this demonstrator, we have used cloud resources graciously
provided by the [SNIC Science Cloud](https://cloud.snic.se/) and the [denbi
cloud](https://www.denbi.de/cloud).

<img align="left" height="100" alt="Elixir logo" src="https://nbis.se/assets/img/logos/elixir.png">
<img align="left" height="100" alt="Excelerate logo" src="https://nbis.se/assets/img/logos/excelerate-logo.png">
<img align="left" height="100" alt="deNBI logo" src="https://www.denbi.de/templates/de.nbi2/img/deNBI_logo.jpg">
<img align="left" height="100" alt="NBIS logo" src="https://nbis.se/assets/img/logos/nbislogo-green-txt.svg">
<img align="left" height="100" alt="terraform logo" src="https://www.terraform.io/assets/images/logo-hashicorp-3f10732f.svg">

