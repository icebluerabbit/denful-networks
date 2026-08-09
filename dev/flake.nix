{
  description = "Denful Networks — Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.git-hooks-nix.flakeModule ];
      systems = import inputs.systems;

      perSystem = { pkgs, config, ... }: {
        formatter = pkgs.nixfmt-tree;

        pre-commit = {
          check.enable = false;
          settings = {
            install.enable = false;
            hooks = {
              nixfmt-tree-check = {
                enable = true;
                name = "nixfmt-tree";
                description = "Format Nix files using the project formatter";
                # Note: paths in hooks will run relative to the git root directory (which is the parent)
                entry = "${pkgs.nixfmt-tree}/bin/treefmt";
                args = [ "--no-cache" ];
                files = "\\.nix$";
              };
            };
          };
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ config.pre-commit.devShell ];
          shellHook = ''
            GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
            cp -f ${config.pre-commit.settings.configFile} "$GIT_ROOT/.pre-commit-config.yaml"
            chmod +w "$GIT_ROOT/.pre-commit-config.yaml"
            if [ -d "$GIT_ROOT/.git" ]; then
              (cd "$GIT_ROOT" && pre-commit install)
            fi
          '';
          buildInputs = [ pkgs.nixfmt-tree ];
        };
      };
    };
}
