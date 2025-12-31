# Configuración de sistemas de archivos

# home/aso sda3 como no persistente
mkfs.ext4 /dev/sda3
mount /dev/sda3 /home/aso
chmod 700 /home/aso



# documentos persistentes
mkfs.ext4 /dev/sda4
mkdir /home/aso/Documents
chmod 700 /home/aso/Documents
