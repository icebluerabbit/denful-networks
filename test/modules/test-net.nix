{ den, ... }:
{
  # Register the test network
  den.networks.x86_64-linux.test-net = { };

  # Define the aspect that configures this network
  den.aspects.test-net = {
    terranix = {
      terraform.required_providers.null = {
        source = "hashicorp/null";
        version = "~> 3.2";
      };
      resource.null_resource.test = {
        triggers = {
          hello = "world";
        };
      };
    };
  };

  # Validate the generated Terranix configuration in flake checks
  perSystem = { config, ... }: {
    checks.validate-test-net =
      let
        raw = config.terranix.terranixConfigurations.test-net.result.terraformConfiguration.value;
        tfConfig = if builtins.isString raw then builtins.fromJSON raw else raw;
      in
      if tfConfig.resource.null_resource.test.triggers.hello == "world" then
        config.packages.test-net
      else
        throw "Assertion failed: triggers.hello != world";
  };
}
