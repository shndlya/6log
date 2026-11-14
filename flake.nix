{
  description = "6log — the personal site of shndlya";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          pandoc # markdown -> html
          python3 # local static server
        ];
        shellHook = ''
          echo "6log dev shell — ./build.sh to build, 'nix run .#serve' to serve"
        '';
      };

      packages.site = pkgs.stdenvNoCC.mkDerivation {
        pname = "6log-site";
        version = "0.1.0";
        src = self;
        nativeBuildInputs = [pkgs.pandoc];
        buildPhase = "bash build.sh";
        installPhase = ''
          mkdir -p "$out"
          cp -r site/. "$out/"
        '';
      };

      apps = {
        build = {
          type = "app";
          program = let
            build = pkgs.writeShellApplication {
              name = "build-6log";
              runtimeInputs = with pkgs; [bash pandoc];
              text = "exec bash build.sh";
            };
          in "${build}/bin/build-6log";
        };
        serve = {
          type = "app";
          program = let
            serve = pkgs.writeShellApplication {
              name = "serve-6log";
              runtimeInputs = with pkgs; [bash pandoc python3];
              text = ''
                bash build.sh
                exec python3 -m http.server "''${PORT:-8101}" -d site
              '';
            };
          in "${serve}/bin/serve-6log";
        };
      };

      checks.site = self.packages.${system}.site;
    });
}
