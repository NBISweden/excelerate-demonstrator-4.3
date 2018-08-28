# Elixir-Excelerate Demonstrator 4.3


<img align="left" height="100" alt="Elixir logo" src="https://nbis.se/assets/img/logos/elixir.png">


<img align="left" height="100" alt="Excelerate logo" src="https://nbis.se/assets/img/logos/excelerate-logo.png">  



## Introduction 

Massive sequencing and genotyping of crop and forest plants and their pathogens
and pests generates large quantities of genomic variation data.
[ELIXIR](https://www.elixir-europe.org/) is designing an infrastructure to
allow genotype-phenotype analysis for crop plants based on the widest available
public datasets. Data is scattered across the laboratories seeking to describe
and understand the life of plants at the molecular level. 

[ELIXIR Compute](https://www.elixir-europe.org/platforms/compute) supports the
[plant science
community](https://www.elixir-europe.org/use-cases/plant-sciences) to track and
bring these data together, which enriches data analysis capabilities of the
scientific community – local data can be interpreted in the global context.
This
[EXCELERATE](https://www.elixir-europe.org/about-us/how-funded/eu-projects/excelerate)
demonstrator show the fundamental technical integration needed to achieve data
transfers from geographically distributed sites onto the scalable Compute
platform built by ELIXIR.

This repository contains instructions and scripts for setting up a cloud
resource using Elixir id, deploying a storage endpoint VM, and using the Elixir
Data Transfer Service to move a set of files to the cloud instance.

By cloning this repository and following the instructions, it should be
possible to reproduce the demonstration.

A terminal session recording is available at https://asciinema.org/a/5XlGftbaq0KXGgQeGdEpAq4nd .

## Prerequisites

* [git](https://git-scm.com/) - for cloning this repository
  * `git clone https://github.com/NBISweden/excelerate-demonstrator-4.3.git`
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

We use terraform to deploy a VM running a
[gridftp](http://gridcf.org/gct-docs/gridftp/index.html) daemon.

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
Randomstring`. The identity can of course also be extracted from the proxy
certificate itself, using e.g. the `openssl` tool:
```sh
openssl x509 -subject -noout -in cert.txt
```

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

Next, we deploy a VM and install the gridftp daemon by using the terraform
scripts. We start by initializing terraform, which will download the terraform
Openstack provider, in case it's missing. 
```sh
terraform init
```

The VM specifications and network rules can be found in `main.tf`, settings that
might be different for different providers are in the file `variables.tf`. We
tell terraform to apply this at our cloud provider:
```sh
terraform apply \
-var 'external_gateway=52b76a82-5f02-4a3e-9836-57536ef1cb63' \
-var 'pool="Public External IPv4 Network"' \
-var 'certificate="/DC=eu/DC=rcauth/DC=rcauth-clients/O=ELIXIR/CN=Firstname Lastname abc123"' \
-var 'email=firstname.lastname@example.com'
```
Note that if the variables are not specified as arguments, terraform will ask the user for them.


For cases where the cloud provider do not have domain names registered for the
public IP numbers, it is possible to explicitly set the domain name via the
variable `fqdn`. Then it is necessary to create a DNS record pointing to the IP
number.  This can be carried out by the installation script by specifying an
additional DNS update script via the variable `dnsupdatescript`.


Upon `apply`, terraform will spin up a VM based on Centos 7, attach a public IP number
and apply some network rules. The details of this can be found in `main.tf`.

Finally the gridftp server is installed, equipped with a
[letsencrypt](https://letsencrypt.org/) server certificate, and set to map the
user certificate to a user account called `gridftp` on the VM. This is done by
terraform by uploading the script `centos-gridftp-rw.sh` and running it on the
VM with our certificate identity and e-mail address as arguments.

The terraform provisioning takes a few minutes. Once done, terraform will print
the ip number to the VM once the provisioning is complete. It is then possible
to log in to the VM with ssh (user name: centos). A log of the software
installation can be found in `/tmp/centos-gridftp-rw.log`.

## TODO: Locating data

_It would be nice if we could have a section here on finding data that we want
to copy to the VM. For example, by using the Plant user community query interface._


## Transfering data to the virtual machine

Next, we transfer data from different sources to our cloud instance.

### Specifying endpoint as destination

The files that we will transfer to the VM are listed in `url.txt`. For the
transfer job, we need to specify a destination for each file. Here, we choose
to store all files on the VM in a directory structure of the form `/srv/data/$PRURL`, where
`$PRURL`is the protocol-relative URL. E.g. a URL
`https://www.elixir-europe.org/system/files/white-orange-logo.png` would be
stored on the VM as
`/srv/data/www.elixir-europe.org/system/files/white-orange-logo.png`.

We append the destination URL (where we use `gsiftp` as protocol) for each
source URL and save it in a new file:
```sh
PREFIX='gsiftp:\/\/vm-123.denbi.de\/srv\/data'
sed "s/\(.*:\/\)\(.*$\)/\1\2 $PREFIX\2/" urls.txt > transfers.txt
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
provided by the [SNIC Science Cloud](https://cloud.snic.se/) and the [deNBI
Cloud](https://www.denbi.de/cloud).

<a href="http://www.denbi.de/"><img align="left" height="100" alt="deNBI logo" src="https://www.denbi.de/templates/de.nbi2/img/deNBI_logo.jpg"></a>
<a href="https://nbis.se"><img align="left" height="100" alt="NBIS logo" src="https://nbis.se/assets/img/logos/nbislogo-green-txt.svg"></a>
<a href="https://www.terraform.io/"><img align="left" height="100" alt="terraform logo" src="https://www.terraform.io/assets/images/logo-hashicorp-3f10732f.svg"></a>


