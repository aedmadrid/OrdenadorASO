#!/run/current-system/sw/bin/bash

echo "##########################################"
echo "#      Actualizar/Instalar ASOLinux      #"
echo "##########################################"
echo ""
echo "Vamos a verificar tu sistema..."
echo "__________________________________________"

# Verificar si existe directorio /ASO
if [ ! -d "/ASO" ]; then
    echo "[ERROR] El directorio /ASO no existe."
    echo "Sigue las instrucciones en https://asolinux.aedm.org.es/install para continuar."
    exit 1
else
    echo "[OK] El directorio /ASO existe"
fi

# Verificar si es nixOS
if [ ! -f "/etc/nixos/configuration.nix" ]; then
    echo "[ERROR] Este sistema no tiene un archivo de configuración de nixOS."
    echo "Sigue las instrucciones en https://asolinux.aedm.org.es/install para continuar."
    exit 1
else
    echo "[OK] Este sistema base es nixOS"
fi

# Verificar si es una versión compatible de nixOS
if [[ ! "$(nixos-version)" =~ ^25\.11 ]]; then
    echo "[ERROR] Este sistema no tiene una versión compatible de nixOS."
    echo "Sigue las instrucciones en https://asolinux.aedm.org.es/install para continuar."
    exit 1
else
    echo "[OK] Este sistema tiene una versión compatible de nixOS"
fi

# Verificar si se tiene permiso de root
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] Este script debe ser ejecutado como root."
    echo "Sigue las instrucciones en https://asolinux.aedm.org.es/install para continuar."
    exit 1
else
    echo "[OK] Se tiene permiso de root"
fi

echo "Todo está listo para actualizar/instalar ASOLinux"
echo "Presiona Enter para continuar..."
read -p ""

echo "##########################################"
echo "#      Actualizar/Instalar ASOLinux      #"
echo "##########################################"
echo ""
echo "Borrando archivos temporales..."
rm -rf /tmp/*
echo "[OK] Archivos temporales borrados"
echo ""
echo "Eliminando configuración obsoleta..."
rm -rf /etc/nixos/configuration.nix
echo "[OK] Configuración obsoleta eliminada"
echo ""
echo "Descargando mapa del sistema..."

download_config() {
    local url="https://github.com/aedmadrid/OrdenadorASO/raw/refs/heads/main/www/os/configuration.nix"
    local dest="/etc/nixos/configuration.nix"

    if curl -L -o "$dest" "$url" --connect-timeout 10 --max-time 60 --silent --show-error; then
        echo "Archivo descargado en $dest"
        return 0
    else
        echo "[ERROR] Fallo en la descarga: Código de salida $?"
        return 1
    fi
}

# Intentar descargar y manejar errores
if download_config; then
    echo "[OK] Mapa del sistema descargado correctamente."
else
    echo "[ERROR] Error al descargar el mapa del sistema. Abortando."
    exit 1
fi

echo "Reconstruyendo sistema con las nuevas actualizaciones..."

rebuild_system() {
    if nixos-rebuild switch --upgrade; then
        echo "[OK] Sistema reconstruido y actualizado exitosamente."
        return 0
    else
        echo "[ERROR] Fallo en la reconstrucción del sistema: Código de salida $?"
        return 1
    fi
}

# Intentar reconstruir y manejar errores
if rebuild_system; then
    echo "Actualización completada exitosamente."
else
    echo "[ERROR] Error al reconstruir el sistema. Abortando."
    exit 1
fi

echo "##########################################"
echo "#      Actualizar/Instalar ASOLinux      #"
echo "##########################################"
echo ""
echo "Se ha actualizado el sistema."
echo ""
echo "Puedes reiniciar el sistema presionando cualquie tecla."
echo "Si no deseas reiniciar, presiona CTRL + C."
echo "Presiona cualquier tecla para reiniciar..."
echo "--------------------------------------------"

read -n 1 -s -r -p ""
echo "Reiniciando el sistema..."
sudo reboot
