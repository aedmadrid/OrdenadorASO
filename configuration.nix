# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

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
    buildInputs = [ pkgs.dos2unix ];
    installPhase = ''
      mkdir -p $out/share/icons/Elementary-KDE
      # Convertir line endings y copiar
      dos2unix **/*
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
  services.xserver.enable = true;

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

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account sin contraseña
  users.users.aso = {
    isNormalUser = true;
    description = "Asociación de Estudiantes de Diseño de Madrid";
    initialPassword = ""; # Si tienes problemas de login, prueba a omitir este campo
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
    kdePackages.plasma-workspace
    curl
    elementary-kde-icons
  ] ++ (if stdenv.hostPlatform.system == "x86_64-linux"
        then [ google-chrome ]
        else [ chromium ]);

  # Enlazar iconos para que Plasma los vea
  environment.pathsToLink = [ "/share/icons" ];

  # ============================================
  # SERVICIO: Descargar wallpaper y config antes de apagar + nixos-rebuild + limpiar home
  # ============================================
  systemd.services.aedm-update-on-shutdown = {
    description = "Actualizar configuración, wallpaper y rebuild NixOS antes de apagar + limpiar home";
    wantedBy = [ "multi-user.target" ];
    before = [ "shutdown.target" "reboot.target" "halt.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.curl}/bin/curl -s --connect-timeout 5 -o /var/lib/aedm/wallpaper.jpg https://raw.githubusercontent.com/aedmadrid/OrdenadorASO/b676d6f4f354c3122c999c087adaf71871c8a134/.bg.jpg && chmod 644 /var/lib/aedm/wallpaper.jpg; ${pkgs.curl}/bin/curl -s --connect-timeout 5 -o /etc/nixos/configuration.nix https://raw.githubusercontent.com/aedmadrid/OrdenadorASO/main/configuration.nix && find /home/aso -mindepth 1 -maxdepth 1 ! -name Documentos ! -name .config -exec sh -c \"rm -rf \\\"$1\\\" || true\" _ {} \;  && ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch || true'";
    };
  };

  # ============================================
  # REINICIO AUTOMÁTICO DIARIO A LAS 6:00 AM
  # ============================================
  systemd.services.daily-reboot = {
    description = "Reinicio automático diario";
    wantedBy = [ "multi-user.target" ];
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
  # LIMPIAR BUILDS DE NIX: Mantener solo las 2 últimas
  # ============================================
  systemd.services.clean-nix-builds = {
    description = "Mantener solo las 2 últimas builds exitosas de Nix";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +2'";
    };
  };

  # ============================================
  # CREAR CARPETAS XDG USER DIRS EN ESPAÑOL AL BOOT
  # ============================================
  systemd.services.create-xdg-dirs = {
    description = "Crear carpetas XDG user dirs en español al boot";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p /home/aso/{Escritorio,Descargas,Imágenes,Música,Vídeos,Plantillas,Público}; chown -R aso:users /home/aso/{Escritorio,Descargas,Imágenes,Música,Vídeos,Plantillas,Público}'";
    };
  };

  # ============================================
  # DESCARGAR WALLPAPER AL BOOT SI NO EXISTE
  # ============================================
  systemd.services.download-wallpaper-on-boot = {
    description = "Descargar wallpaper al boot si no existe";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'if [ ! -f /var/lib/aedm/wallpaper.jpg ]; then ${pkgs.curl}/bin/curl -s --connect-timeout 5 -o /var/lib/aedm/wallpaper.jpg https://raw.githubusercontent.com/aedmadrid/OrdenadorASO/b676d6f4f354c3122c999c087adaf71871c8a134/.bg.jpg && chmod 644 /var/lib/aedm/wallpaper.jpg; fi'";
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

    # Configurar XDG user dirs en español
    xdg.userDirs = {
      enable = true;
      desktop = "$HOME/Escritorio";
      download = "$HOME/Descargas";
      documents = "$HOME/Documentos";
      pictures = "$HOME/Imágenes";
      music = "$HOME/Música";
      videos = "$HOME/Vídeos";
      templates = "$HOME/Plantillas";
      publicShare = "$HOME/Público";
    };

    # Configuración de Plasma Desktop
    programs.plasma = {
      enable = true;
      workspace = {
        # Fondo de pantalla
        wallpaperPlugin = "org.kde.image";
      };
      configFile = {
        kdeglobals = {
          General = {
            ColorScheme = "BreezeLight";
          };
        };
        # Iconos Elementary
        kdeglobals.Icons.Theme = "Elementary-KDE";
      };
    };

    # Desktop entries personalizados
    xdg.desktopEntries = {
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

      # Ocultar KWalletManager
      "org.kde.kwalletmanager" = {
        name = "KWalletManager";
        exec = "";
        noDisplay = true;
      };

      # Ocultar Preferencias del Sistema KDE
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

    # Script para aplicar wallpaper después de que Plasma arranque
    home.file = {
      ".config/autostart/apply-wallpaper.desktop" = {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Apply Wallpaper
          Exec=${pkgs.bash}/bin/bash -c 'sleep 3 && ${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-wallpaperimage /var/lib/aedm/wallpaper.jpg 2>/dev/null || true'
          NoDisplay=true
        '';
      };
    };
  };

  # Crear directorio para wallpaper
  systemd.tmpfiles.rules = [
    "d /var/lib/aedm 0755 root root -"
  ];

  # System state version
  system.stateVersion = "25.11";

}
