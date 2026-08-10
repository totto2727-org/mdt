{
  lib,
  moonPlatform,
  moonRegistryIndex,
  stdenv,
}:
let
  dependencies = {
    "moonbitlang/async" = "0.20.3";
    "moonbitlang/x" = "0.4.47";
    "totto2727/admiral" = "0.6.2";
    "totto2727/opencode-sdk" = "0.2.2";
  };
  cachedRegistry = moonPlatform.buildCachedRegistry {
    moonModDepsSet = dependencies;
    registryIndexSrc = moonRegistryIndex;
  };
  moonHome = moonPlatform.bundleWithRegistry {
    inherit cachedRegistry;
  };
  packageSrc = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./moon.mod
      ./README.mbt.md
      ./README.md
      ./src
    ];
  };
in
stdenv.mkDerivation {
  pname = "mdt";
  version = "0.1.7";
  src = packageSrc;
  nativeBuildInputs = [ moonHome ];
  dontConfigure = true;
  buildPhase = ''
    runHook preBuild

    writable_home="$TMPDIR/moon_home"
    cp -rL ${moonHome} "$writable_home"
    chmod -R u+w "$writable_home"
    export MOON_HOME="$writable_home"
    export HOME="$TMPDIR"

    moon_bin="$MOON_HOME/bin/.moon-wrapped"
    "$moon_bin" build --release --strip

    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    install -Dm755 _build/native/release/build/mdt.exe "$out/bin/mdt"

    runHook postInstall
  '';
  meta = {
    description = "Native MoonBit CLI for translating Markdown with OpenCode";
    homepage = "https://github.com/totto2727-org/mdt";
    license = lib.licenses.mit;
    mainProgram = "mdt";
  };
}
