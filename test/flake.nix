{
  inputs = { flake-utils.url = "github:numtide/flake-utils"; };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            docker
            janet
            jpm
          ];
          # needed for jpm to build janet executables (like jfmt)
          JANET_LIBPATH = nixpkgs.lib.makeLibraryPath [pkgs.janet];
        };
      });
}
