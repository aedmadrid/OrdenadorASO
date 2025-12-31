{ config, pkgs, lib, ... }:

let
  # Importar Home Manager y Plasma Manager
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
  };
  plasma-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/plasma-manager/archive/trunk.tar.gz";
  };
  # Iconos Elementary KDE
  elementary-kde-icons = pkgs.stdenv.mkDerivation {
    pname = "elementary-kde-icons";
    version = "1.0";
    src = builtins.fetchGit {
      url = "https://github.com/zayronxio/Elementary-KDE-Icons.git";
      ref = "master";
    };
    # Desactivar check de symlinks rotos
    dontCheckForBrokenSymlinks = true;
    installPhase = ''
      mkdir -p $out/share/icons/Elementary-KDE
      cp -rL --no-preserve=mode . $out/share/icons/Elementary-KDE || true
      # Eliminar symlinks rotos
      find $out/share/icons/Elementary-KDE -xtype l -delete || true
    '';
  };
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # Home Manager
      (import "${home-manager}/nixos")
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "AEDM"; # Define your hostname.


  # Enable networking
  networking.networkmanager.enable = true;

  # Configuración WiFi predeterminada
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ ];
    profiles = {
      "ESDMADRID_WIFI" = {
        connection = {
          id = "ESDMADRID_WIFI";
          type = "wifi";
          autoconnect = true;
        };
        wifi = {
          ssid = "ESDMADRID_WIFI";
          mode = "infrastructure";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "ESDMadrid2019";
        };
        ipv4 = {
          method = "auto";
        };
        ipv6 = {
          method = "auto";
        };
      };
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "es_ES.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_ES.UTF-8";
    LC_IDENTIFICATION = "es_ES.UTF-8";
    LC_MEASUREMENT = "es_ES.UTF-8";
    LC_MONETARY = "es_ES.UTF-8";
    LC_NAME = "es_ES.UTF-8";
    LC_NUMERIC = "es_ES.UTF-8";
    LC_PAPER = "es_ES.UTF-8";
    LC_TELEPHONE = "es_ES.UTF-8";
    LC_TIME = "es_ES.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = false;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "es";
    variant = "winkeys";
  };

  # Configure console keymap
  console.keyMap = "es";


  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

  };

  # ============================================
  # USUARIOS: Definir
  # ============================================

  users.allowNoPasswordLogin = true;


  users.users.aso = {
    isNormalUser = true;
    description = "Asociación de Estudiantes de Diseño de Madrid";
    password = null;
    uid = 1000;
    home = "/home/aso";
    extraGroups = [ "networkmanager" ];
  };

  # Permitir login sin contraseña
  security.pam.services.sddm.allowNullPassword = true;
  security.pam.services.login.allowNullPassword = true;

  services.displayManager = {
    autoLogin.enable = true;
    autoLogin.user = "aso";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.bluetooth.enable = true;

  # Excluir aplicaciones de KDE no deseadas
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa        # Reproductor de música
    khelpcenter  # Centro de ayuda
    oxygen       # Tema antiguo
    plasma-browser-integration
  ];

  environment.systemPackages = with pkgs; [
    maliit-keyboard
    maliit-framework
    vim
    inkscape-with-extensions
    vlc
    unixtools.quota
    zed-editor
    git
    kdePackages.kate
    curl
    elementary-kde-icons
  ] ++ (if stdenv.hostPlatform.system == "x86_64-linux"
        then [ google-chrome ]
        else [ chromium ]);

  # ============================================
  # SERVICIO: Descargar wallpaper y config antes de apagar + nixos-rebuild
  # ============================================
  systemd.services.aedm-update-on-shutdown = {
    description = "Actualizar configuración, wallpaper y rebuild NixOS antes de apagar";
    wantedBy = [ "multi-user.target" ];
    before = [ "shutdown.target" "reboot.target" "halt.target" ];
    after = [ "network-online.target" ];  # Asegura que la red esté up antes de ejecutar
    wants = [ "network-online.target" ];  # Requiere que network-online esté activo
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.curl}/bin/curl -s --connect-timeout 5 -o /var/lib/aso/Wallpaper.jpg https://rawcdn.githack.com/aedmadrid/OrdenadorASO/b676d6f4f354c3122c999c087adaf71871c8a134/.bg.jpg && chown aso:users /var/lib/aso/Wallpaper.jpg; ${pkgs.curl}/bin/curl -s --connect-timeout 5 -o /etc/nixos/configuration.nix https://raw.githack.com/aedmadrid/OrdenadorASO/main/configuration.nix && ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch || true'";
    };
  };

  # ============================================
  # Bibliotecas dinámicas para programas no empaquetados
  # ============================================

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add any missing dynamic libraries for unpackaged programs
    # here, NOT in environment.systemPackages
    # Libraries for Electron/Chromium apps
    glib
    gtk3
    nss
    nspr
    atk
    cairo
    pango
    gdk-pixbuf
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    libdrm
    libxkbcommon
    mesa
    libgbm
    alsa-lib
    pulseaudio
    cups
    dbus
    expat
    freetype
    fontconfig
    libjpeg
    libpng
    libtiff
    libwebp
    libxml2
    sqlite
    zlib
    openssl

  ];


  # ============================================
  # REINICIO AUTOMÁTICO DIARIO A LAS 6:00 AM
  # ============================================
  systemd.services.daily-reboot = {
    description = "Reinicio automático diario";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reboot";
    };
  };

  systemd.timers.daily-reboot = {
    description = "Timer para reinicio diario a las 6:00 AM";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00";
      Persistent = true;
    };
  };

  # ============================================
  # HOME MANAGER - Configuración del usuario aso
  # ============================================
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.aso = { config, pkgs, lib, ... }: {
    imports = [
      (import "${plasma-manager}/modules")
    ];

    home.stateVersion = "24.11";
    home.enableNixpkgsReleaseCheck = false;

    # Configuración de Plasma con plasma-manager
    programs.plasma = {
      enable = true;

      # Configuración del workspace
      workspace = {
        # Tema
        theme = "breeze";
        colorScheme = "Breeze";
        # Wallpaper
        wallpaper = "/home/aso/.bg.jpg";
        # Iconos Elementary KDE
        iconTheme = "Elementary-KDE";
      };

      # Atajos de teclado personalizados
      shortcuts = {
        "kwin"."Window Close" = "Ctrl+W";
        "kwin"."Window Minimize" = "Ctrl+H";
        "kwin"."Window Maximize" = "Ctrl+M";
        "kwin"."Window Restore" = "Ctrl+M";
        "kwin"."Window Fullscreen" = "Ctrl+Shift+F11";
      };
    };

    # ============================================
    # LANZADORES PERSONALIZADOS (.desktop files)
    # ============================================
    xdg.desktopEntries = {
      # Navegador con --guest abriendo aedm.org.es
      browser-guest = {
        name = "Chrome";
        comment = "Navegar en Internet";
        exec =
          if pkgs.stdenv.hostPlatform.system == "x86_64-linux"
          then "google-chrome-stable --guest https://aedm.org.es/web"
          else "chromium --guest https://aedm.org.es/web";
        icon = "google-chrome";
        terminal = false;
        type = "Application";
        categories = [ "Network" "WebBrowser" ];
      };

      # ============================================
      # RENOMBRAR APLICACIONES DE KDE
      # ============================================

      # Okular -> Visor PDF (icono de Acrobat)
      "org.kde.okular" = {
        name = "Visor PDF";
        comment = "Visor de documentos PDF";
        exec = "okular %U";
        icon = "acroread";
        terminal = false;
        type = "Application";
        categories = [ "Office" "Viewer" ];
        mimeType = [ "application/pdf" ];
      };

      # Gwenview -> Visor de Imágenes
      "org.kde.gwenview" = {
        name = "Visor de Imágenes";
        comment = "Visor de imágenes";
        exec = "gwenview %U";
        icon = "gwenview";
        terminal = false;
        type = "Application";
        categories = [ "Graphics" "Viewer" ];
      };

      # Kate -> Bloc de Notas
      "org.kde.kate" = {
        name = "Bloc de Notas";
        comment = "Editor de texto";
        exec = "kate %U";
        icon = "kate";
        terminal = false;
        type = "Application";
        categories = [ "Utility" "TextEditor" ];
      };

      # Dolphin -> Archivos
      "org.kde.dolphin" = {
        name = "Archivos";
        comment = "Gestor de archivos";
        exec = "dolphin %U";
        icon = "system-file-manager";
        terminal = false;
        type = "Application";
        categories = [ "System" "FileManager" ];
      };

      # Ark -> Descomprimir
      "org.kde.ark" = {
        name = "Descomprimir";
        comment = "Herramienta de compresión y descompresión";
        exec = "ark %U";
        icon = "ark";
        terminal = false;
        type = "Application";
        categories = [ "Utility" "Archiving" ];
      };

      # Spectacle -> Recortes
      "org.kde.spectacle" = {
        name = "Recortes";
        comment = "Captura de pantalla";
        exec = "spectacle";
        icon = "spectacle";
        terminal = false;
        type = "Application";
        categories = [ "Graphics" "Utility" ];
      };

      # Konsole -> Terminal
      "org.kde.konsole" = {
        name = "Terminal";
        comment = "Emulador de terminal";
        exec = "konsole";
        icon = "utilities-terminal";
        terminal = false;
        type = "Application";
        categories = [ "System" "TerminalEmulator" ];
      };

      # ============================================
      # OCULTAR APLICACIONES NO DESEADAS
      # ============================================

      # Ocultar Chrome/Chromium originales
      "google-chrome" = {
        name = "Google Chrome";
        exec = "";
        noDisplay = true;
      };

      "chromium-browser" = {
        name = "Chromium";
        exec = "";
        noDisplay = true;
      };

      # Ocultar Elisa
      "org.kde.elisa" = {
        name = "Elisa";
        exec = "";
        noDisplay = true;
      };

      # Ocultar NixOS Manual
      "nixos-manual" = {
        name = "NixOS Manual";
        exec = "";
        noDisplay = true;
      };

      # Ocultar Editor del Menú (kmenuedit)
      "org.kde.kmenuedit" = {
        name = "Editor del Menú";
        exec = "";
        noDisplay = true;
      };

      # Ocultar Visor de Procesos que han fallado (drkonqi)
      "org.kde.drkonqi" = {
        name = "Visor de Procesos";
        exec = "";
        noDisplay = true;
      };

      # Ocultar XTerm
      "xterm" = {
        name = "XTerm";
        exec = "";
        noDisplay = true;
      };

      # Ocultar KWalletManager
      "org.kde.kwalletmanager5" = {
        name = "KWalletManager";
        exec = "";
        noDisplay = true;
      };

      # Ocultar Administrar impresión (system-config-printer)
      "system-config-printer" = {
        name = "Administrar impresión";
        exec = "";
        noDisplay = true;
      };

      # Ocultar también print-manager de KDE
      "org.kde.print-manager" = {
        name = "Print Manager";
        exec = "";
        noDisplay = true;
      };

      # Ocultar Interfaz de impresión (cups)
      "cups" = {
        name = "Interfaz de impresión";
        exec = "";
        noDisplay = true;
      };

      # Ocultar kwrite (por si queda algún .desktop)
      "org.kde.kwrite" = {
        name = "KWrite";
        exec = "";
        noDisplay = true;
      };

      # Ocultar Visor de procesos que han fallado (coredump gui)
      "org.kde.drkonqi.coredump.gui" = {
        name = "Visor de procesos fallados";
        exec = "";
        noDisplay = true;
      };

      # Ocultar Vim
      "vim" = {
        name = "Vim";
        exec = "";
        noDisplay = true;
      };

      # Ocultar gvim también
      "gvim" = {
        name = "GVim";
        exec = "";
        noDisplay = true;
      };

      # Ocultar KWalletManager (otra variante)
      "org.kde.kwalletmanager" = {
        name = "KWalletManager";
        exec = "";
        noDisplay = true;
      };

      # Ocultar Preferencias del Sistema KDE (solo del menú, sigue accesible)
      "systemsettings" = {
        name = "Preferencias del sistema";
        exec = "systemsettings";
        icon = "systemsettings";
        noDisplay = true;
        terminal = false;
        type = "Application";
        categories = [ "Settings" ];
      };
    };
  };

  system.stateVersion = "25.11"; # Did you read the comment?

}
