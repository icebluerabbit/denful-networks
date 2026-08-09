{
  description = "Denful Networks — Terranix integration extension for Den";

  outputs = _: {
    flakeModules.default =
      {
        lib,
        den,
        config,
        inputs,
        ...
      }:
      let
        networkType =
          system:
          lib.types.submodule (
            { name, config, ... }:
            {
              freeformType = lib.types.attrsOf lib.types.anything;
              imports = [ den.schema.network ];
              config._module.args.network = config;

              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = "Network configuration name";
                };
                terraformPackage = lib.mkOption {
                  type = lib.types.nullOr lib.types.raw;
                  default = null;
                  description = "The Terraform or OpenTofu package to use for this network. Defaults to pkgs.opentofu.";
                };
                system = lib.mkOption {
                  type = lib.types.str;
                  default = system;
                  description = "Target platform system for compilation";
                };
                class = lib.mkOption {
                  type = lib.types.str;
                  default = "terranix";
                  description = "Nix configuration class for the network";
                };
                aspect = lib.mkOption {
                  description = "Aspect that configures this network.";
                  type = lib.types.raw;
                  default = if den.aspects ? ${config.name} then den.aspects.${config.name} else { };
                };
                instantiate = lib.mkOption {
                  description = "Instantiation function for Terranix (returns raw modules)";
                  type = lib.types.raw;
                  default = { modules, ... }: builtins.filter (m: !(builtins.isAttrs m && m ? nixpkgs)) modules;
                };
                intoAttr = lib.mkOption {
                  description = "Flake attribute path where to output collected modules";
                  type = lib.types.listOf lib.types.str;
                  default = [
                    "terranixModules"
                    config.name
                  ];
                };
                mainModule = lib.mkOption {
                  internal = true;
                  visible = false;
                  readOnly = true;
                  type = lib.types.deferredModule;
                  default = den.lib.aspects.resolve config.class config.resolved;
                };
              };
            }
          );
      in
      {
        imports = lib.optionals (inputs ? terranix) [ inputs.terranix.flakeModule ];

        options.den.networks = lib.mkOption {
          description = "Declarative network configurations via Terranix";
          default = { };
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }:
              {
                freeformType = lib.types.attrsOf (networkType name);
              }
            )
          );
        };

        config = {
          den.schema.network.imports = [ den.schema.conf ];

          den.classes.terranix = { };

          den.policies.system-to-network-outputs =
            { system, ... }:
            let
              networks = den.networks.${system} or { };
            in
            lib.concatMap (
              network:
              lib.optionals (network.intoAttr != [ ]) [
                (den.lib.policy.resolve.to "network" { inherit network; })
                (den.lib.policy.instantiate network)
              ]
            ) (builtins.attrValues networks);

          den.schema.flake-system.includes = [
            den.policies.system-to-network-outputs
          ];

          perSystem =
            { pkgs, system, ... }:
            let
              networks = den.networks.${system} or { };
            in
            {
              terranix.terranixConfigurations = lib.mapAttrs (name: modules: {
                inherit modules;
                terraformWrapper.package =
                  let
                    net = networks.${name} or { };
                    pkg = net.terraformPackage or null;
                  in
                  if pkg != null then pkg else pkgs.opentofu;
              }) (config.flake.terranixModules or { });
            };
        };
      };
  };
}
