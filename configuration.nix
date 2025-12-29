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
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

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
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account sin contraseña
  users.users.aso = {
    isNormalUser = true;
    description = "Asociación de Estudiantes de Diseño de Madrid";
    initialPassword = "";
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
  # SERVICIO: Limpiar home de aso en cada arranque
  # ============================================
  systemd.services.clean-aso-home = {
    description = "Limpiar home de usuario aso manteniendo Documentos y wallpaper";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.curl pkgs.coreutils pkgs.findutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      HOME_DIR="/home/aso"
      WALLPAPER_URL="https://raw.githubusercontent.com/aedmadrid/OrdenadorASO/main/.bg.jpg"
      WALLPAPER_PATH="/var/lib/aedm/wallpaper.jpg"

      # Crear directorio para wallpaper del sistema
      mkdir -p /var/lib/aedm

      # Descargar wallpaper si hay internet
      curl -s --connect-timeout 10 -o "$WALLPAPER_PATH" "$WALLPAPER_URL" || true

      if [ -d "$HOME_DIR" ]; then
        # Guardar temporalmente los directorios/archivos que queremos mantener
        mkdir -p /tmp/aso-backup
        [ -d "$HOME_DIR/Documentos" ] && cp -a "$HOME_DIR/Documentos" /tmp/aso-backup/
        [ -d "$HOME_DIR/Documents" ] && cp -a "$HOME_DIR/Documents" /tmp/aso-backup/

        # Borrar todo en home usando rm -rf
        rm -rf "$HOME_DIR"/* 2>/dev/null || true
        rm -rf "$HOME_DIR"/.[!.]* 2>/dev/null || true

        # Restaurar los directorios/archivos guardados
        [ -d "/tmp/aso-backup/Documentos" ] && cp -a /tmp/aso-backup/Documentos "$HOME_DIR/"
        [ -d "/tmp/aso-backup/Documents" ] && cp -a /tmp/aso-backup/Documents "$HOME_DIR/"

        # Crear directorios si no existen
        mkdir -p "$HOME_DIR/Documentos"
        mkdir -p "$HOME_DIR/Documents"

        # Ajustar permisos
        chown -R aso:users "$HOME_DIR"

        # Limpiar backup temporal
        rm -rf /tmp/aso-backup
      fi
    '';
  };

  # ============================================
  # SERVICIO: Descargar config y rebuild NixOS antes de apagar
  # ============================================
  systemd.services.aedm-update-on-shutdown = {
    description = "Actualizar configuración y rebuild NixOS antes de apagar";
    wantedBy = [ "multi-user.target" ];
    before = [ "shutdown.target" "reboot.target" "halt.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.curl}/bin/curl -s --connect-timeout 5 -o /etc/nixos/configuration.nix https://raw.githubusercontent.com/aedmadrid/OrdenadorASO/main/configuration.nix && ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch || true'";
    };
    script = "true";
  };

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
        # Wallpaper (guardado en ruta del sistema para que persista)
        wallpaper = "/var/lib/aedm/wallpaper.jpg";
        # Iconos Elementary KDE
        iconTheme = "Elementary-KDE";
      };

      # Atajos de teclado personalizados
      shortcuts = {
        "kwin"."Window Close" = "Alt+F4";
        "kwin"."Window Fullscreen" = "Meta+F11";
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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
