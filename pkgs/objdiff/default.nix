{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  cmake,
  protobuf,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  fontconfig,
  freetype,
  libxkbcommon,
  wayland,
  libGL,
  vulkan-loader,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  xdg-utils,
  gui ? false,
}:
let
  source = builtins.fromJSON (builtins.readFile ./source.json);
  pname = if gui then "objdiff-gui" else "objdiff-cli";
  runtimeLibraries = [
    fontconfig
    freetype
    libxkbcommon
    wayland
    libGL
    vulkan-loader
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in
rustPlatform.buildRustPackage {
  inherit pname;
  inherit (source) version cargoHash;
  src = fetchFromGitHub {
    owner = "encounter";
    repo = "objdiff";
    inherit (source) rev hash;
  };
  patches = lib.optionals gui [ ./disable-updater.patch ];
  nativeBuildInputs = [
    pkg-config
    cmake
    protobuf
  ]
  ++ lib.optionals gui [
    makeWrapper
    copyDesktopItems
  ];
  buildInputs = lib.optionals gui [
    fontconfig
    freetype
  ];
  cargoBuildFlags = [
    "-p"
    pname
  ];
  cargoTestFlags = [
    "-p"
    pname
    "-p"
    "objdiff-core"
  ];
  doCheck = true;
  desktopItems = lib.optionals gui [
    (makeDesktopItem {
      name = "objdiff";
      desktopName = "objdiff";
      comment = "Compare object files for decompilation projects";
      exec = "objdiff";
      icon = "objdiff";
      categories = [ "Development" ];
      terminal = false;
      startupWMClass = "objdiff";
    })
  ];
  postInstall = lib.optionalString gui ''
    install -Dm644 objdiff-gui/assets/icon_64.png $out/share/icons/hicolor/64x64/apps/objdiff.png
    install -Dm644 objdiff-gui/assets/icon.png $out/share/icons/hicolor/512x512/apps/objdiff.png
    wrapProgram $out/bin/objdiff \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibraries} \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
  '';
  meta = {
    description = "Object diffing tool for decompilation projects (${if gui then "GUI" else "CLI"})";
    homepage = "https://github.com/encounter/objdiff";
    changelog = "https://github.com/encounter/objdiff/releases/tag/v${source.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = if gui then "objdiff" else "objdiff-cli";
    platforms = [ "x86_64-linux" ];
  };
}
