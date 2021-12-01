let nixpkgs = import
  (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/dad4fddd52923d90c5ad981d5e29963e829de3c1.tar.gz";
    sha256 = "03x4vz9fywk9bs59iszm6z8fqy6wb99ik365rsxdvvybhls5kbny";
  })
  { };

in
nixpkgs.mkShell {
  buildInputs = [
    nixpkgs.watchexec
    nixpkgs.zig
  ];
}
