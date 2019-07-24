{ pkgs }: {
  projectPath,
  pubPackages ? import "${projectPath}/pub-packages.nix" { inherit pkgs; },
}:

let stdenv = pkgs.stdenv; in
let lib = stdenv.lib; in

let step = (state: package:
  let cachePath = lib.concatStringsSep "/" [
    ".pub-cache"
    package.source
    (lib.removePrefix "https://" package.description.url)
    "${package.description.name}-${package.version}"
  ]; in
  {
    commands = state.commands + ''
      mkdir -p ${cachePath}
      cp -r ${package.storePath}/. ${cachePath}
    '';
    dotPackages = state.dotPackages + ''
      ${package.description.name}:file://${cachePath}/lib/
    '';
  }
); in

let installPackages = (projectPath: pubPackages:
  let initialState = {
    commands = "";
    dotPackages = "# This file was generated by pub2nix\n";
  }; in
  let packagesList = builtins.attrValues pubPackages.packages; in
  let result = builtins.foldl' step initialState packagesList; in
  ''
    ${result.commands}
    projectName=$(${pkgs.yq}/bin/yq -r '.name' pubspec.yaml)
    dotPackages="${result.dotPackages}$projectName:file://lib/"$'\n'
    echo -n "$dotPackages" > ".packages"
    export PUB_CACHE=.pub-cache
    ${pkgs.dart}/bin/pub get --no-precompile --offline
  ''
); in

''
  ${installPackages projectPath pubPackages}
''
