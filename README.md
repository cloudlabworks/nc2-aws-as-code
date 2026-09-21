# NC2 on AWS, as code

Nutanix Cloud Clusters on AWS from the NC2 console to the first VM, with OpenTofu on the v4 APIs.
The runnable half of the walkthrough at <https://cloudlabworks.dev/nutanix/nc2-aws-as-code-nc2-console-to-first-vm>.

```text
 ┌─ NC2 console (cloud.nutanix.com) ─────────────────────────────────────┐
 │  1. org ─▶ 2. AWS cloud account (CloudFormation) ─▶ 3. Create Cluster │
 │                                                    + Prism Central    │
 └───────────────────────────────┬───────────────────────────────────────┘
                                 │ orchestrates, over TCP/443
                                 ▼
 ┌─ AWS account · region · AZ ───────────────────────────────────────────┐
 │  VPC                                                                  │
 │   ├─ management subnet (private)  ── bare-metal nodes  ── cluster     │
 │   ├─ Prism Central subnet  /28    ── PC VM(s)  ◀── you talk to this   │
 │   └─ Flow Virtual Networking /24  ── transit-vpc, external subnets    │
 └───────────────────────────────┬───────────────────────────────────────┘
                                 │ v4 APIs, :9440
                                 ▼
 ┌─ laptop ─ tofu ─ one provider, one endpoint: Prism Central ───────────┐
 │  4. VPC + overlay subnets  5. default route  6. image + VM + FIP      │
 └───────────────────────────────────────────────────────────────────────┘
```

## What the NC2 console does, and what this repo does

The NC2 console owns the cluster, Prism Central, the transit VPC and the external subnets — the
walkthrough covers onboarding the AWS account, the allowlist the cluster must reach, and the
Create Cluster wizard with Flow Virtual Networking. **With Flow Virtual Networking there is no
Prism Element in the workflow.** Everything after Running is a Prism Central v4 API call, and
that is what this repo is:

| File | Builds |
|---|---|
| `versions.tf` | provider `nutanix/nutanix` 2.4.2 (v4 API based), OpenTofu ≥ 1.6 |
| `providers.tf` | one provider, endpoint = Prism Central `:9440` |
| `network.tf` | a Flow VPC off the NC2-built `overlay-external-subnet-nat`, two overlay subnets with DHCP pools and the AWS `.2` resolver, the VPC's default route to the external subnet |
| `vm.tf` | an Ubuntu cloud image, a category, `web-01` from the image with cloud-init, a floating IP from the AWS VPC range on its NIC |
| `templates/web.yaml` | the cloud-init |

## Run

```sh
export NUTANIX_USERNAME=admin
export NUTANIX_PASSWORD='…'          # from your vault; never in a .tf, never in state you don't encrypt
cp terraform.tfvars.example terraform.tfvars   # and edit
tofu init
tofu plan
tofu apply
tofu plan                            # the deliverable: "No changes."
```

The provider is on the OpenTofu registry; `tofu init` needs no mirror configuration.
Terraform works the same — the HCL is identical.

## Status

Every resource, block and argument was checked against the provider's documentation and its
`examples/nc2` samples on 2026-09-20 (provider 2.4.2; the NC2 samples were tested by Nutanix
on pc.2024.3.1.1 / AOS 10.0.1). **This repo has not yet been applied against a live NC2
cluster by its author.** Match the provider version to the Prism Central version the NC2
console deployed (compatibility matrix on the provider's index page), and treat a mismatch
as the first suspect when something fails late.

## Watch for

- The VPC's route table is created asynchronously with the VPC; `network.tf` reads it after
  the subnets exist for that reason. If `route_tables[0]` is empty on a fast apply, that is why.
- Changing `guest_customization` replaces the VM — the provider says so. Plan for it.
- The new Prism Central's first password is the documented default. Change it before the
  provider ever sees it.
- Don't manage the NC2-built objects (transit VPC, external subnets, the cluster) from state;
  look them up with data sources, as this repo does.

## License

MIT. Written by Alex Alvord with Waku, the Duvall lab's agent. Sources: the public NC2 on AWS
Deployment and User Guide and the Nutanix Terraform provider docs and examples on GitHub.
