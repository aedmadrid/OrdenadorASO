# Edita este archivo de configuración para definir qué se debe instalar en
# tu sistema. La ayuda está disponible en la página del manual configuration.nix(5)
# y en el manual de NixOS (accesible ejecutando 'nixos-help').

{ config, pkgs, ... }:

{
  imports =
    [ # Incluir los resultados del escaneo de hardware.
      ./hardware-configuration.nix
    ];

  # Cargador de arranque.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define tu nombre de host.
  # networking.wireless.enable = true;  # Habilita soporte inalámbrico vía wpa_supplicant.

  # Configura el proxy de red si es necesario
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Habilitar red
  networking.networkmanager.enable = true;

  # Asegurar que NetworkManager espere por la red
  systemd.services.NetworkManager-wait-online.enable = true;

  # Establece tu zona horaria.
  time.timeZone = "Europe/Madrid";

  # Selecciona propiedades de internacionalización.
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

  # Habilitar el sistema de ventanas X11.
  services.xserver.enable = true;

  # Habilitar el entorno de escritorio GNOME.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configurar mapa de teclado en X11
  services.xserver.xkb = {
    layout = "es";
    variant = "";
  };

  # Configurar mapa de teclado en consola
  console.keyMap = "es";

  # Habilitar CUPS para imprimir documentos.
  services.printing.enable = true;

  # Habilitar sonido con pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # Si quieres usar aplicaciones JACK, descomenta esto
    #jack.enable = true;

    # usa el gestor de sesiones de ejemplo (ningún otro está empaquetado aún así que esto está habilitado por defecto,
    # no hay necesidad de redefinirlo en tu config por ahora)
    #media-session.enable = true;
  };

  # Habilitar soporte para touchpad (habilitado por defecto en la mayoría de desktopManager).
  # services.xserver.libinput.enable = true;

  # Definir una cuenta de usuario. No olvides establecer una contraseña con 'passwd'.
  users.users.aedm = {
    isNormalUser = true;
    description = "Asociación de Estudiantes de Diseño de Madrid";
    extraGroups = [ "networkmanager" "wheel" ];  # Añadido wheel
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Instalar firefox.
  programs.firefox.enable = true;

  # Permitir paquetes no libres
  nixpkgs.config.allowUnfree = true;

  # Lista de paquetes instalados en el perfil del sistema. Para buscar, ejecuta:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    curl
    chromium
    pkgs.notion-app
    vim  # Para editar logs si es necesario
  ];

  # Algunos programas necesitan wrappers SUID, se pueden configurar más o se
  # inician en sesiones de usuario.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Lista de servicios que quieres habilitar:

  # Habilitar el demonio OpenSSH.
  # services.openssh.enable = true;

  # Abrir puertos en el firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # O deshabilitar el firewall completamente.
  # networking.firewall.enable = false;

  # Este valor determina la versión de NixOS desde la cual se tomaron los ajustes
  # predeterminados para datos stateful, como ubicaciones de archivos y versiones
  # de bases de datos en tu sistema. Está perfectamente bien y recomendado dejar
  # este valor en la versión de la primera instalación de este sistema.
  # Antes de cambiar este valor lee la documentación para esta opción
  # (ej. man configuration.nix o en https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # ¿Leíste el comentario?

}
