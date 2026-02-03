# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

let
  updateScript = pkgs.writeShellScript "update-nixos-config-robust" ''
    set -x  # Debug mode

    CONFIG_URL="http://asolinux.aedm.org.es/os/configuration.nix"
    BACKUP_DIR="/etc/nixos/backups"
    CONFIG_FILE="/etc/nixos/configuration.nix"
    LOG_FILE="/var/log/nixos-shutdown-update.log"
    MAX_RETRIES=5

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    }

    log "=== INICIO: Actualización de configuración antes del apagado ==="
    log "URL: $CONFIG_URL"

    # Verificar conectividad
    log "Verificando conectividad de red..."
    if ! ${pkgs.curl}/bin/curl -s --connect-timeout 5 http://example.com > /dev/null; then
      log "ADVERTENCIA: No hay conectividad a internet"
      log "Esperando 10 segundos por la red..."
      sleep 10
    fi

    # Crear directorio de backups
    mkdir -p "$BACKUP_DIR"
    log "Directorio de backups: $BACKUP_DIR"

    # Backup de configuración actual
    if [ -f "$CONFIG_FILE" ]; then
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      cp "$CONFIG_FILE" "$BACKUP_DIR/configuration.nix.$TIMESTAMP"
      log "✓ Backup creado: configuration.nix.$TIMESTAMP"

      # Mantener solo los últimos 10 backups
      ls -t "$BACKUP_DIR"/configuration.nix.* 2>/dev/null | tail -n +11 | xargs -r rm
    else
      log "ADVERTENCIA: No existe $CONFIG_FILE"
    fi

    # Descargar con reintentos
    RETRY=0
    SUCCESS=0
    while [ $RETRY -lt $MAX_RETRIES ]; do
      log "Intento $((RETRY + 1)) de $MAX_RETRIES: Descargando desde $CONFIG_URL"

      if ${pkgs.curl}/bin/curl -v -f -L --connect-timeout 10 --max-time 60 -o "$CONFIG_FILE.new" "$CONFIG_URL" 2>&1 | tee -a "$LOG_FILE"; then
        if [ -s "$CONFIG_FILE.new" ]; then
          FILESIZE=$(stat -c%s "$CONFIG_FILE.new")
          log "✓ Descarga exitosa (tamaño: $FILESIZE bytes)"
          SUCCESS=1
          break
        else
          log "✗ ERROR: Archivo descargado está vacío"
          rm -f "$CONFIG_FILE.new"
        fi
      else
        log "✗ ERROR: Fallo en la descarga (curl exit code: $?)"
      fi

      RETRY=$((RETRY + 1))
      if [ $RETRY -lt $MAX_RETRIES ]; then
        log "Esperando 5 segundos antes de reintentar..."
        sleep 5
      fi
    done

    if [ $SUCCESS -eq 0 ]; then
      log "✗ FALLO FINAL: No se pudo descargar después de $MAX_RETRIES intentos"
      log "Manteniendo configuración actual"
      exit 0
    fi

    # Mostrar primeras líneas del archivo descargado
    log "Primeras líneas del archivo descargado:"
    head -n 5 "$CONFIG_FILE.new" | tee -a "$LOG_FILE"

    # Validar sintaxis básica del archivo Nix
    log "Validando sintaxis Nix..."
    if ! ${pkgs.nix}/bin/nix-instantiate --parse "$CONFIG_FILE.new" > /dev/null 2>&1; then
      log "✗ ERROR: Sintaxis Nix inválida"
      rm "$CONFIG_FILE.new"
      exit 0
    fi
    log "✓ Sintaxis Nix válida"

    # Comparar con configuración actual
    if [ -f "$CONFIG_FILE" ] && ${pkgs.diffutils}/bin/cmp -s "$CONFIG_FILE" "$CONFIG_FILE.new"; then
      log "⚠ La configuración descargada es idéntica a la actual"
      log "No es necesario hacer rebuild"
      rm "$CONFIG_FILE.new"
      exit 0
    fi

    # Aplicar nueva configuración
    mv "$CONFIG_FILE.new" "$CONFIG_FILE"
    log "✓ Nueva configuración en $CONFIG_FILE"

    log "Ejecutando nixos-rebuild switch..."
    if ${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch 2>&1 | tee -a "$LOG_FILE"; then
      log "✓✓✓ Rebuild exitoso, sistema actualizado ==="
      exit 0
    else
      log "✗✗✗ ERROR en nixos-rebuild switch"
      log "Restaurando configuración de backup..."
      LAST_BACKUP=$(ls -t "$BACKUP_DIR"/configuration.nix.* 2>/dev/null | head -n1)
      if [ -n "$LAST_BACKUP" ]; then
        cp "$LAST_BACKUP" "$CONFIG_FILE"
        log "Restaurando desde: $LAST_BACKUP"
        ${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch 2>&1 | tee -a "$LOG_FILE" || true
      fi
      exit 0
    fi
  '';
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Asegurar que NetworkManager espere por la red
  systemd.services.NetworkManager-wait-online.enable = true;

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

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "es";
    variant = "";
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

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.aedm = {
    isNormalUser = true;
    description = "Asociación de Estudiantes de Diseño de Madrid";
    extraGroups = [ "networkmanager" "wheel" ];  # Añadido wheel
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    curl
    chromium
    vim  # Para editar logs si es necesario
  ];

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

  # ============================================================
  # Sistema de actualización automática antes del apagado
  # ============================================================

  # Servicio que descarga y aplica configuración antes de apagar
  systemd.services.nixos-update-on-shutdown = {
    description = "Download and apply NixOS configuration before shutdown";

    # CRUCIAL: Ejecutar cuando se INICIA el target de shutdown
    wantedBy = [ "halt.target" "poweroff.target" "reboot.target" ];

    # Debe ejecutarse ANTES de estos targets
    before = [ "shutdown.target" "final.target" ];

    # Requiere red
    after = [ "network-online.target" "NetworkManager.service" ];
    wants = [ "network-online.target" ];
    requires = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = updateScript;
      TimeoutStartSec = "infinity";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };

    # Forzar que se ejecute
    unitConfig = {
      DefaultDependencies = "no";
      ConditionPathExists = "/etc/nixos/configuration.nix";
    };
  };

  # Asegurar que el directorio de logs existe
  systemd.tmpfiles.rules = [
    "f /var/log/nixos-shutdown-update.log 0644 root root -"
    "d /etc/nixos/backups 0755 root root -"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
