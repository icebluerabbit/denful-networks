# Denful Networks

[![CI](https://github.com/icebluerabbit/denful-networks/actions/workflows/ci.yml/badge.svg)](https://github.com/icebluerabbit/denful-networks/actions/workflows/ci.yml)
[![Release PR](https://github.com/icebluerabbit/denful-networks/actions/workflows/promote.yml/badge.svg)](https://github.com/icebluerabbit/denful-networks/actions/workflows/promote.yml)
[![Framework: Den](https://img.shields.io/badge/framework-den-blue.svg?logo=nixos&logoColor=white)](https://github.com/vic/den)

`denful-networks` is a reusable `den` extension that brings first-class declarative infrastructure management to the **Den** configuration framework using **Terranix** (Terraform/OpenTofu).

It registers a new `networks` entity type, allowing you to define your VPC subnets, routing tables, firewalls, and server resources declaratively in Nix, sharing configuration values natively between your NixOS hosts and your cloud orchestration.

---

## Installation

Add the flake input to your `flake-file.inputs` in your `dendritic.nix` (or `flake.nix`):

```nix
flake-file.inputs = {
  denful-networks = {
    url = "github:icebluerabbit/denful-networks";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

And import it in your dendritic module imports:

```nix
imports = [
  inputs.flake-file.flakeModules.dendritic
  inputs.den.flakeModules.dendritic
  inputs.denful-networks.flakeModules.default
];
```

Regenerate your flake outputs:
```bash
nix run .#write-flake
```

---

## Configuration

To create a new network, follow these steps:

### 1. Define the Network Aspect
Define your Terraform/OpenTofu resources inside an aspect named after your network (e.g., `home-infra`):

```nix
# modules/networking/home-infra.nix
{ den, ... }:
{
  den.aspects.home-infra = {
    terranix = {
      terraform.required_providers.hcloud = {
        source = "hetznercloud/hcloud";
        version = "~> 1.45";
      };
      
      provider.hcloud.token = "\${var.hcloud_token}";
      variable.hcloud_token = { type = "string"; sensitive = true; };

      # VPC Network
      resource.hcloud_network.vpc = {
        name = "home-vpc";
        ip_range = "10.0.0.0/16";
      };

      # Subnet
      resource.hcloud_network_subnet.subnet = {
        network_id = "\${hcloud_network.vpc.id}";
        type = "server";
        network_zone = "eu-central";
        ip_range = "10.0.0.0/24";
      };
    };
  };
}
```

### 2. Register the Network
Register the network under `den.networks.<system>.<name>`. By convention, Den will automatically look up the aspect with the same name (`den.aspects.home-infra`), so the minimal registration only requires an empty attribute set:

```nix
{ den, ... }:
{
  den.networks.x86_64-linux.home-infra = { };
}
```

If you need to customize settings (like using OpenTofu instead of Terraform), you can specify them here:

```nix
  den.networks.x86_64-linux.home-infra = {
    # Optional: defaults to pkgs.terraform
    terraformPackage = pkgs.opentofu;
  };
```
```

---

## Usage

Once configured, the extension automatically exports system-specific flake outputs and development shells for the network.

### Commands

| Command | Action |
| --- | --- |
| `nix run .#<networkName>.init` | Run `terraform init` / `tofu init` to download provider plugins |
| `nix run .#<networkName>.plan` | Generate the `config.tf.json` and run `terraform plan` |
| `nix run .#<networkName>` | Apply the configuration to provision the network |
| `nix run .#<networkName>.destroy` | Tear down the network and delete all provisioned resources |
| `nix develop .#<networkName>` | Drop into an interactive shell with the configured terraform package |
| `nix build .#<networkName>.config` | Build and output the raw `config.tf.json` file to `./result` |
