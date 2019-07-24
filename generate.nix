{ pkgs }:

let stdenv = pkgs.stdenv; in
let lib = stdenv.lib; in

let jqFilter = ''
  .packages[] as { $dependency, description: { $name, $url }, $source, $version }
  | $name, $url, $version, $source, $dependency
''; in

let nixPrefetchUrlCmd = ''
  nix-prefetch-url $archive_url \
    --unpack \
    --print-path \
    --name "$name-$version" \
    --type sha256 \
''; in

pkgs.mkShell {
  name = "pub2nix-generate";
  src = lib.sourceByRegex ./. [
    "^pubspec.lock"
    "^pubspec.yaml$"
  ];
  buildInputs = [
    pkgs.cacert
    pkgs.dart
    pkgs.nix
    pkgs.yq
  ];
  shellHook = ''
    HOME=$TMPDIR
    rm -rf .packages
    pub get --no-precompile

    output="# This file was generated by pub2nix"$'\n'
    output+=""$'\n'
    output+="{ pkgs }:"$'\n'
    output+=""$'\n'
    output+="let packages = {"$'\n'

    while read -r name; do
      read -r url
      read -r version
      read -r source
      read -r dependency
      archive_url="$url/packages/$name/versions/$version.tar.gz"

      echo ""
      echo "$name $version"
      read -d "\n" -r sha256 store_path <<< $(${nixPrefetchUrlCmd})

      output+="  \"$name\" = pkgs.stdenv.mkDerivation {"$'\n'

      # Standard Nix derivation attributes
      output+="    name = \"$name-$version\";"$'\n'
      output+="    src = pkgs.fetchzip {"$'\n'
      output+="      stripRoot = false;"$'\n'
      output+="      url = \"$archive_url\";"$'\n'
      output+="      sha256 = \"$sha256\";"$'\n'
      output+="    };"$'\n'
      output+="    installPhase = \"ln -s \$src \$out\";"$'\n'

      # Mirror pubspec format
      output+="    dependency = \"$dependency\";"$'\n'
      output+="    description = {"$'\n'
      output+="      name = \"$name\";"$'\n'
      output+="      url = \"$url\";"$'\n'
      output+="    };"$'\n'
      output+="    source = \"$source\";"$'\n'
      output+="    version = \"$version\";"$'\n'

      # Additional data needed to produce pub cache
      output+="    storePath = $store_path;"$'\n'

      output+="  };"$'\n'

      done < <(yq -r '${jqFilter}' pubspec.lock)

    output+="}; in"$'\n'
    output+=""$'\n'
    output+="{"$'\n'
    output+="  inherit packages;"$'\n'
    output+="}"$'\n'

    echo ""

    echo "$output" > pub-packages.nix

    rm -rf .packages
    exit
  '';
}
