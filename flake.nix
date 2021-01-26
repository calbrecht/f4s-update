{
  description = "A flake for updating flakes.";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages."${system}";

      nix_bin = pkgs.nixFlakes + /bin/nix;
      jq_bin = pkgs.jq + /bin/jq;

      jq_base_config = {
        ignore = {
          repo = [ ];
        };
      };

      jq_input_with_repo = ''
        .nodes as $nodes |
        reduce ($nodes.root.inputs | keys)[] as $input
          ([];
            if null == $nodes[$input].original.repo
            or true == ($config.ignore.repo | contains([$nodes[$input].original.repo]))
            then .
            else . + ["--update-input " + $input]
            end) |
        join(" ")
      '';
    in
    {
      apps."${system}".repo-inputs = {
        type = "app";
        program = (pkgs.writeScriptBin "update-repo-inputs.sh" ''
          #!${pkgs.stdenv.shell}
          set -e
          config='${builtins.toJSON jq_base_config}'
          [[ ! -f flake.nix ]] && exit 0
          [[ -f .f4s-update.json ]] && config=$(${jq_bin} "$config * ." .f4s-update.json)
          params=$(
            ${nix_bin} flake list-inputs --json | \
            ${jq_bin} --argjson config "$config" -r '${jq_input_with_repo}'
          )
          ${nix_bin} flake update $params --commit-lock-file
        '') + /bin/update-repo-inputs.sh;
      };
    };
}
