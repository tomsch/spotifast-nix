{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  cmake,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  imagemagick,
  cacert,
  dbus,
  alsa-lib,
  libpulseaudio,
  pipewire,
  libxkbcommon,
  wayland,
  libGL,
  libx11,
  libxcursor,
  libxrandr,
  libxi,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "spotifast";
  version = "0.14.2";

  src = fetchFromGitHub {
    owner = "crmne";
    repo = "spotifast";
    rev = "v${finalAttrs.version}";
    hash = "sha256-LdhBPj7ZrXXMvQpM/DqYH5m7zH7duTZ/tZbHO3XI5CQ=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "cpal-0.18.2" = "sha256-ntJYSSipB0YyIpZ+zsJi0LXwtYcuBZbJHrZtGD5r4iw=";
      "dpi-0.1.1" = "sha256-zUErcFIlDxOtA8lnP4vHp6DHxsUziyXz9e1IIWnXq/U=";
      "ecolor-0.36.2" = "sha256-2InNvJTXd6du0Rux4BpZsPXY0lbf6sPlTxDYVtWJbjE=";
      "fastframe-audio-0.14.0" = "sha256-bKbq/Q3wrLXomtnDOe0UYcNcbNsGFYCWNc8v0TQL5Ds=";
      "hyper-proxy2-0.1.0" = "sha256-eyTslearajU7p/BfcSDByf/KbCeu+09WPwoJNr/7x6M=";
      "librespot-audio-0.8.0" = "sha256-WQcwAwJareTxWn519vdnPuCdWaPag/k0/AwomFhKpGw=";
      "projectm-sys-1.2.3" = "sha256-en0QJbg2oshnM5dfhGHVEJd9ibaIGWzIQjNNR25dhDs=";
    };
  };

  # importCargoLock includes the projectM submodules in the vendored source.
  # projectm-sys only searches lib, while CMake installs to lib64 on x86_64.
  postPatch = ''
    projectmVendorDir=
    for candidate in "$cargoDepsCopy"/projectm-sys-*; do
      if [ -n "$projectmVendorDir" ] || [ ! -d "$candidate" ]; then
        echo "Expected exactly one vendored projectm-sys directory" >&2
        exit 1
      fi
      projectmVendorDir="$candidate"
    done

    substituteInPlace "$projectmVendorDir/build.rs" \
      --replace-fail \
        'println!("cargo:rustc-link-search=native={}/lib", dst.display());' \
        'println!("cargo:rustc-link-search=native={}/lib64", dst.display());'
  '';

  nativeBuildInputs = [
    pkg-config
    cmake
    rustPlatform.bindgenHook
    makeWrapper
    copyDesktopItems
    imagemagick
  ];

  # Branding integration tests start a private bus with dbus-run-session.
  # librespot's rustls-native-certs tests need a real CA bundle; Nix's build
  # sandbox otherwise points SSL_CERT_FILE at /no-cert-file.crt.
  nativeCheckInputs = [
    cacert
    dbus
  ];

  preCheck = ''
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
  '';

  # Audio backends link ALSA, PulseAudio, and PipeWire directly;
  # projectM links OpenGL and uses X11 headers.
  buildInputs = [
    alsa-lib
    libpulseaudio
    pipewire
    libGL
    libx11
  ];

  # eframe's glow backend and winit's windowing backends dlopen these at
  # runtime, so they also need to be available on LD_LIBRARY_PATH.
  runtimeLibs = [
    libGL
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxrandr
    libxi
  ];

  postInstall = ''
    # Older releases also install the legacy command; newer releases omit it.
    rm -f "$out/bin/fastpotify"
    wrapProgram $out/bin/spotifast \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath finalAttrs.runtimeLibs}

    install -Dm644 packaging/macos/icon-1024.png \
      $out/share/icons/hicolor/1024x1024/apps/spotifast.png
    for size in 512 256 128 64 48; do
      iconDir="$out/share/icons/hicolor/''${size}x''${size}/apps"
      install -d "$iconDir"
      magick packaging/macos/icon-1024.png -resize "''${size}x''${size}" \
        "$iconDir/spotifast.png"
    done
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "spotifast";
      exec = "spotifast";
      icon = "spotifast";
      desktopName = "Spotifast";
      genericName = "Music Player";
      comment = "A fast, native Spotify client";
      categories = [
        "AudioVideo"
        "Audio"
        "Player"
        "Music"
      ];
      keywords = [
        "spotify"
        "music"
        "player"
        "streaming"
      ];
      mimeTypes = [ "x-scheme-handler/spotify" ];
      startupNotify = true;
      # Upstream retains this app-id for existing desktop/window rules.
      startupWMClass = "fastpotify";
    })
  ];

  meta = {
    description = "Fast, lightweight, native Spotify client built with Rust and egui, playing through librespot";
    homepage = "https://spotifast.rocks/";
    changelog = "https://github.com/crmne/spotifast/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "spotifast";
  };
})
