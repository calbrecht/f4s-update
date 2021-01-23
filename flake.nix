{
  description = "A flake for updating flakes.";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages."${system}";

      nix_bin = pkgs.nixFlakes + /bin/nix;
      jq_bin = pkgs.jq + /bin/jq;

      jq_input_with_repo = ''
        .nodes as $nodes |
        reduce ($nodes.root.inputs | keys)[] as $input
          ([];
            if null == $nodes[$input].original.repo
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
          params=$(${nix_bin} flake list-inputs --json | ${jq_bin} -r '${jq_input_with_repo}')
          ${nix_bin} flake update $params --commit-lock-file
        '') + /bin/update-repo-inputs.sh;
      };
    };
}
