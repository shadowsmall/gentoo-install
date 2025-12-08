#!/bin/bash

# Script d'installation Gentoo Linux avec detection automatique
# ATTENTION: Ce script doit etre execute depuis un environnement live Gentoo

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}          Installation Gentoo Linux Automatisée                 ${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
}

step() {
    echo -e "\n${YELLOW}>>> $1${NC}"
}

info() {
    echo -e "${CYAN}i $1${NC}"
}

success() {
    echo -e "${GREEN}v $1${NC}"
}

warning() {
    echo -e "${RED}! $1${NC}"
}

read_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$(echo -e ${CYAN}$prompt ${NC}[${GREEN}$default${NC}]: )" input
        eval $var_name="\${input:-$default}"
    else
        read -p "$(echo -e ${CYAN}$prompt${NC}: )" input
        eval $var_name="$input"
    fi
}

read_password() {
    local prompt="$1"
    local var_name="$2"
    local password
    local password_confirm
    
    while true; do
        read -s -p "$(echo -e ${CYAN}$prompt${NC}: )" password
        echo
        read -s -p "$(echo -e ${CYAN}Confirmez le mot de passe${NC}: )" password_confirm
        echo
        
        if [ "$password" = "$password_confirm" ]; then
            if [ ${#password} -lt 6 ]; then
                warning "Le mot de passe doit contenir au moins 6 caracteres"
                continue
            fi
            eval $var_name="$password"
            break
        else
            warning "Les mots de passe ne correspondent pas. Reessayez."
        fi
    done
}

print_header
warning "ATTENTION: Ce script va formater et partitionner votre disque !"
warning "Assurez-vous d'avoir sauvegarde vos donnees importantes."
echo ""
read -p "Appuyez sur Entree pour continuer ou Ctrl+C pour annuler..."

# ETAPE 1: Selection du disque
print_header
echo -e "${MAGENTA}=== ETAPE 1/7 : Selection du disque ===${NC}"
echo ""

info "Disques disponibles:"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
echo ""

# Tentative de détection automatique sécurisée
AUTO_DISK_NAME=$(lsblk -d -o NAME,TYPE | grep disk | head -n 1 | awk '{print $1}')
if [ -n "$AUTO_DISK_NAME" ]; then
    AUTO_DISK="/dev/$AUTO_DISK_NAME"
    AUTO_DISK_SIZE=$(lsblk -d -o SIZE $AUTO_DISK | tail -1)
    info "Disque recommande: $AUTO_DISK ($AUTO_DISK_SIZE)"
else
    AUTO_DISK=""
fi
echo ""

read_input "Entrez le chemin du disque a utiliser" "$AUTO_DISK" "DISK"

if [ ! -b "$DISK" ]; then
    warning "Le disque $DISK n'existe pas!"
    exit 1
fi

success "Disque selectionne: $DISK"
sleep 2

# ETAPE 2: Configuration systeme
print_header
echo -e "${MAGENTA}=== ETAPE 2/7 : Configuration systeme ===${NC}"
echo ""

read_input "Nom de la machine (hostname)" "gentoo" "HOSTNAME"
success "Hostname: $HOSTNAME"
echo ""

info "Exemples de fuseaux horaires:"
echo "  - Europe/Paris"
echo "  - America/New_York"
echo "  - UTC"
echo ""
read_input "Fuseau horaire" "Europe/Paris" "TIMEZONE"
success "Timezone: $TIMEZONE"
echo ""

info "Exemples de locales:"
echo "  - fr_FR.UTF-8"
echo "  - en_US.UTF-8"
echo ""
read_input "Locale principale" "fr_FR.UTF-8" "LOCALE"
success "Locale: $LOCALE"
echo ""

info "Configuration du clavier"
echo "  1. fr (AZERTY Francais)"
echo "  2. us (QWERTY Americain)"
echo "  3. be (AZERTY Belge)"
echo "  4. ch (QWERTZ Suisse)"
echo "  5. ca (QWERTY Canadien)"
echo ""

while true; do
    read -p "Selectionnez une option (1-5): " kb_choice
    case "$kb_choice" in
        1) KEYMAP="fr"; X11_LAYOUT="fr"; break ;;
        2) KEYMAP="us"; X11_LAYOUT="us"; break ;;
        3) KEYMAP="be"; X11_LAYOUT="be"; break ;;
        4) KEYMAP="ch"; X11_LAYOUT="ch"; break ;;
        5) KEYMAP="ca"; X11_LAYOUT="ca"; break ;;
        *) warning "Option invalide" ;;
    esac
done

success "Disposition clavier: $KEYMAP"
loadkeys $KEYMAP 2>/dev/null || true
sleep 1

# ETAPE 3: Configuration utilisateurs
print_header
echo -e "${MAGENTA}=== ETAPE 3/7 : Configuration des utilisateurs ===${NC}"
echo ""

info "Configuration du mot de passe root"
read_password "Mot de passe root" "ROOT_PASSWORD"
success "Mot de passe root configure"
echo ""

read_input "Nom de l'utilisateur principal" "user" "USERNAME"

if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    warning "Nom d'utilisateur invalide. Utilisation de 'user' par defaut."
    USERNAME="user"
fi

success "Utilisateur: $USERNAME"
echo ""

info "Configuration du mot de passe pour $USERNAME"
read_password "Mot de passe utilisateur" "USER_PASSWORD"
success "Mot de passe utilisateur configure"
sleep 2

# ETAPE 4: Options d'installation
print_header
echo -e "${MAGENTA}=== ETAPE 4/7 : Options d'installation ===${NC}"
echo ""

info "Selection de l'environnement de bureau"
echo "  1. Gnome (Wayland)"
echo "  2. KDE Plasma"
echo "  3. XFCE"
echo "  4. MATE"
echo "  5. Cinnamon"
echo "  6. LXQt"
echo "  7. Aucun (Minimal)"
echo ""

while true; do
    read -p "Selectionnez une option (1-7): " de_choice
    case "$de_choice" in
        1)
            DESKTOP_ENV="gnome"
            DESKTOP_PROFILE="gnome/systemd"
            DESKTOP_PACKAGES="gnome-base/gnome gnome-extra/gnome-tweaks"
            DISPLAY_MANAGER="gdm"
            USE_FLAGS="systemd gnome gtk wayland"
            success "Gnome selectionne"
            break ;;
        2)
            DESKTOP_ENV="kde"
            DESKTOP_PROFILE="desktop/plasma/systemd"
            DESKTOP_PACKAGES="kde-plasma/plasma-meta kde-apps/dolphin kde-apps/konsole"
            DISPLAY_MANAGER="sddm"
            USE_FLAGS="systemd kde qt5 qt6 plasma"
            success "KDE Plasma selectionne"
            break ;;
        3)
            DESKTOP_ENV="xfce"
            DESKTOP_PROFILE="desktop/systemd"
            DESKTOP_PACKAGES="xfce-base/xfce4-meta xfce-extra/xfce4-notifyd"
            DISPLAY_MANAGER="lightdm"
            USE_FLAGS="systemd gtk X xfce"
            success "XFCE selectionne"
            break ;;
        4)
            DESKTOP_ENV="mate"
            DESKTOP_PROFILE="desktop/systemd"
            DESKTOP_PACKAGES="mate-base/mate mate-extra/mate-utils"
            DISPLAY_MANAGER="lightdm"
            USE_FLAGS="systemd gtk X mate"
            success "MATE selectionne"
            break ;;
        5)
            DESKTOP_ENV="cinnamon"
            DESKTOP_PROFILE="desktop/systemd"
            DESKTOP_PACKAGES="gnome-extra/cinnamon"
            DISPLAY_MANAGER="lightdm"
            USE_FLAGS="systemd gtk X cinnamon"
            success "Cinnamon selectionne"
            break ;;
        6)
            DESKTOP_ENV="lxqt"
            DESKTOP_PROFILE="desktop/systemd"
            DESKTOP_PACKAGES="lxqt-base/lxqt-meta"
            DISPLAY_MANAGER="sddm"
            USE_FLAGS="systemd qt5 qt6 X lxqt"
            success "LXQt selectionne"
            break ;;
        7)
            DESKTOP_ENV="none"
            DESKTOP_PROFILE="default/linux/amd64/23.0/systemd"
            DESKTOP_PACKAGES=""
            DISPLAY_MANAGER=""
            USE_FLAGS="systemd"
            success "Installation minimale selectionnee"
            break ;;
        *)
            warning "Option invalide." ;;
    esac
done

echo ""
sleep 1

info "Selection du miroir Gentoo"
echo "  1. Automatique (recommande)"
echo "  2. Europe"
echo "  3. Amerique du Nord"
echo ""

while true; do
    read -p "Selectionnez une option (1-3): " mirror_choice
    case "$mirror_choice" in
        1) STAGE3_MIRROR="https://distfiles.gentoo.org/releases/amd64/autobuilds"; break ;;
        2) STAGE3_MIRROR="https://ftp.belnet.be/gentoo/releases/amd64/autobuilds"; break ;;
        3) STAGE3_MIRROR="https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds"; break ;;
        *) warning "Option invalide" ;;
    esac
done

echo ""
sleep 2

# ETAPE 5: Recapitulatif
print_header
echo -e "${MAGENTA}=== ETAPE 5/7 : Recapitulatif de la configuration ===${NC}"
echo ""

TOTAL_SIZE=$(lsblk -b -d -o SIZE $DISK | tail -1)
TOTAL_GB=$((TOTAL_SIZE / 1024 / 1024 / 1024))
SWAP_SIZE=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024))

if [ $SWAP_SIZE -lt 2048 ]; then SWAP_SIZE=2048; elif [ $SWAP_SIZE -gt 16384 ]; then SWAP_SIZE=16384; fi

echo -e "${CYAN}Configuration systeme:${NC}"
echo "  * Disque: $DISK ($TOTAL_GB GB)"
echo "  * Environnement: $DESKTOP_ENV"
echo "  * Utilisateur: $USERNAME"
echo ""

warning "DERNIERE CHANCE: Toutes les donnees sur $DISK seront EFFACEES!"
echo ""
read -p "Tapez 'OUI' en majuscules pour confirmer: " CONFIRM

if [ "$CONFIRM" != "OUI" ]; then
    echo "Installation annulee."
    exit 1
fi

# ETAPE 6: Installation
print_header
echo -e "${MAGENTA}=== ETAPE 6/7 : Installation en cours ===${NC}"
echo ""
info "Cette etape peut prendre plusieurs heures..."
sleep 3

step "Partitionnement du disque $DISK"
wipefs -a $DISK 2>/dev/null || true
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary fat32 1MiB 513MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary linux-swap 513MiB $((513 + SWAP_SIZE))MiB
parted -s $DISK mkpart primary ext4 $((513 + SWAP_SIZE))MiB 100%

sleep 2
# Detection partitions (p1/p2 ou 1/2)
if [ -e "${DISK}p1" ]; then PART1="${DISK}p1"; PART2="${DISK}p2"; PART3="${DISK}p3"; else PART1="${DISK}1"; PART2="${DISK}2"; PART3="${DISK}3"; fi

step "Formatage des partitions"
mkfs.vfat -F32 $PART1
mkswap $PART2
mkfs.ext4 -F $PART3

success "Partitions formatees"

step "Montage des partitions"
mkdir -p /mnt/gentoo
swapon $PART2
mount $PART3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount $PART1 /mnt/gentoo/boot

success "Partitions montees"

step "Telechargement du tarball Stage3"
cd /mnt/gentoo
wget -q --show-progress ${STAGE3_MIRROR}/latest-stage3-amd64-systemd.txt

STAGE3=""
# Logique simplifiée de lecture
STAGE3=$(grep -v "^#" latest-stage3-amd64-systemd.txt | grep "tar.xz" | head -1 | awk '{print $1}')

if [ -z "$STAGE3" ]; then
    warning "Erreur: Impossible de determiner le fichier Stage3"
    exit 1
fi

info "Telechargement de: $STAGE3"
wget -q --show-progress "${STAGE3_MIRROR}/${STAGE3}"

if [ ! -f stage3-*.tar.xz ]; then
    warning "Erreur telechargement Stage3"
    exit 1
fi

step "Extraction du Stage3"
tar xpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

step "Configuration make.conf"
CORES=$(nproc)
cat >> /mnt/gentoo/etc/portage/make.conf << EOF

# Optimisations
COMMON_FLAGS="-O2 -pipe -march=native"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"
MAKEOPTS="-j${CORES} -l${CORES}"
EMERGE_DEFAULT_OPTS="--jobs=${CORES} --load-average=${CORES}"

USE="${USE_FLAGS} pulseaudio networkmanager elogind dbus X gtk3 -qt4 cups jpeg png gif svg alsa bluetooth wifi usb udisks policykit"
ACCEPT_LICENSE="*"
GRUB_PLATFORMS="efi-64"
FEATURES="parallel-fetch candy"
GENTOO_MIRRORS="$STAGE3_MIRROR"
EOF

success "make.conf configure"

step "Configuration des packages (package.use)"
mkdir -p /mnt/gentoo/etc/portage/package.use

cat > /mnt/gentoo/etc/portage/package.use/circular-deps << EOF
media-libs/libwebp -tiff
media-libs/tiff -webp
dev-libs/glib -sysprof
dev-python/pillow -truetype -avif
media-libs/libavif -gdk-pixbuf
media-libs/mesa llvm
sys-devel/llvm -test
dev-lang/rust -test
app-text/poppler -qt5
dev-libs/boost -python
x11-libs/cairo X
x11-libs/pango X
media-libs/harfbuzz introspection
x11-base/xorg-server -minimal
media-libs/libglvnd X
dev-lang/perl -minimal
EOF

# Configuration selon desktop
if [ "$DESKTOP_ENV" = "gnome" ]; then
    echo "gnome-base/gnome-shell -extensions bluetooth networkmanager" >> /mnt/gentoo/etc/portage/package.use/desktop
    echo "gnome-base/nautilus -previewer" >> /mnt/gentoo/etc/portage/package.use/desktop
    echo "gnome-extra/gnome-tweaks -gnome-shell" >> /mnt/gentoo/etc/portage/package.use/desktop
elif [ "$DESKTOP_ENV" = "kde" ]; then
    echo "kde-plasma/plasma-meta -qt4" >> /mnt/gentoo/etc/portage/package.use/desktop
    echo "kde-apps/dolphin thumbnail" >> /mnt/gentoo/etc/portage/package.use/desktop
elif [ "$DESKTOP_ENV" = "xfce" ]; then
    echo "xfce-base/xfce4-meta minimal" >> /mnt/gentoo/etc/portage/package.use/desktop
    echo "x11-misc/lightdm gtk" >> /mnt/gentoo/etc/portage/package.use/desktop
fi

cat > /mnt/gentoo/etc/portage/package.use/system << EOF
sys-apps/systemd gnuefi
sys-boot/grub mount
net-misc/networkmanager wifi bluetooth wext
sys-fs/udisks elogind
sys-auth/polkit elogind
EOF

mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
cp -L /etc/resolv.conf /mnt/gentoo/etc/

step "Montage des filesystems systeme"
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

success "Pret pour le chroot"

step "Creation du script d'installation chroot"

# ==============================================================================
# SCRIPT CHROOT CORRIGÉ (Suppression des antislashs devant les variables)
# ==============================================================================
cat > /mnt/gentoo/install_chroot.sh << 'XXYYZZ'
#!/bin/bash
set -e
source /etc/profile
echo "--------------------------------------------------------"
echo " Installation dans l'environnement chroot"
echo "--------------------------------------------------------"

echo ">>> Sync Portage..."
emerge --sync --quiet

echo ">>> Selection du profil..."
if [ "XXDESKTOPENVXX" != "none" ]; then
    PROFNUM=$(eselect profile list | grep -i "XXDESKTOPPROFILEXX" | head -1 | awk '{print $1}' | sed 's/\[//g' | sed 's/\]//g')
    if [ -z "$PROFNUM" ]; then
        PROFNUM=$(eselect profile list | grep "desktop" | grep "systemd" | head -1 | awk '{print $1}' | sed 's/\[//g' | sed 's/\]//g')
    fi
else
    PROFNUM=$(eselect profile list | grep "default/linux/amd64/.*/systemd" | grep -v "desktop" | head -1 | awk '{print $1}' | sed 's/\[//g' | sed 's/\]//g')
fi

# Fallback si echec detection
if [ -z "$PROFNUM" ]; then PROFNUM=2; fi

echo "Profil choisi: $PROFNUM"
eselect profile set $PROFNUM

echo ">>> Mise a jour initiale..."
emerge --deselect dev-lang/perl 2>/dev/null || true
emerge --update --deep --newuse --with-bdeps=y @world --autounmask-write --keep-going
etc-update --automode -5
emerge --update --deep --newuse --with-bdeps=y @world --keep-going

echo ">>> Configuration locale/timezone..."
echo "XXTIMEZONEXX" > /etc/timezone
emerge --config sys-libs/timezone-data
echo "XXLOCALEXX UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set XXLOCALEXX
env-update && source /etc/profile

echo ">>> Configuration clavier..."
echo "KEYMAP=XXKEYMAPXX" > /etc/vconsole.conf
mkdir -p /etc/X11/xorg.conf.d
echo 'Section "InputClass"' > /etc/X11/xorg.conf.d/00-keyboard.conf
echo '    Identifier "system-keyboard"' >> /etc/X11/xorg.conf.d/00-keyboard.conf
echo '    MatchIsKeyboard "on"' >> /etc/X11/xorg.conf.d/00-keyboard.conf
echo '    Option "XkbLayout" "XXX11LAYOUTXX"' >> /etc/X11/xorg.conf.d/00-keyboard.conf
echo 'EndSection' >> /etc/X11/xorg.conf.d/00-keyboard.conf

echo ">>> Installation Kernel & Firmware..."
emerge sys-kernel/linux-firmware sys-kernel/gentoo-kernel

echo ">>> Installation Environnement & Outils..."
PKGS_TO_INSTALL="sys-boot/grub sys-fs/dosfstools net-misc/networkmanager app-admin/sudo app-editors/nano"

if [ "XXDESKTOPENVXX" != "none" ]; then
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL XXDESKTOPPACKAGESXX"
fi

echo "Installation de: $PKGS_TO_INSTALL"
emerge --autounmask-write $PKGS_TO_INSTALL
etc-update --automode -5

echo ">>> Configuration fstab..."
printf "UUID=XXUUID3XX\t/\t\text4\tdefaults,noatime\t0 1\n" > /etc/fstab
printf "UUID=XXUUID1XX\t/boot\t\tvfat\tdefaults\t0 2\n" >> /etc/fstab
printf "UUID=XXUUID2XX\tnone\t\tswap\tsw\t\t0 0\n" >> /etc/fstab

echo ">>> Activation Services..."
systemctl enable NetworkManager
if [ -n "XXDISPLAYMANAGERXX" ]; then
    systemctl enable XXDISPLAYMANAGERXX
fi

echo ">>> Finalisation..."
hostnamectl set-hostname XXHOSTNAMEXX
echo "root:XXROOTPWDXX" | chpasswd
useradd -m -G wheel,audio,video,usb,cdrom -s /bin/bash XXUSERNAMEXX
echo "XXUSERNAMEXX:XXUSERPWDXX" | chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

echo "FIN DU SCRIPT CHROOT"
XXYYZZ

# Récupération des UUID
PART1UUID=$(blkid -s UUID -o value $PART1)
PART2UUID=$(blkid -s UUID -o value $PART2)
PART3UUID=$(blkid -s UUID -o value $PART3)

# Remplacement des variables dans le script chroot
sed -i "s|XXTIMEZONEXX|$TIMEZONE|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXLOCALEXX|$LOCALE|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXHOSTNAMEXX|$HOSTNAME|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXROOTPWDXX|$ROOT_PASSWORD|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXUSERNAMEXX|$USERNAME|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXUSERPWDXX|$USER_PASSWORD|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXKEYMAPXX|$KEYMAP|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXX11LAYOUTXX|$X11_LAYOUT|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXUUID1XX|$PART1UUID|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXUUID2XX|$PART2UUID|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXUUID3XX|$PART3UUID|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXDESKTOPENVXX|$DESKTOP_ENV|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXDESKTOPPROFILEXX|$DESKTOP_PROFILE|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXDESKTOPPACKAGESXX|$DESKTOP_PACKAGES|g" /mnt/gentoo/install_chroot.sh
sed -i "s|XXDISPLAYMANAGERXX|$DISPLAY_MANAGER|g" /mnt/gentoo/install_chroot.sh

chmod +x /mnt/gentoo/install_chroot.sh

step "Lancement du chroot"
chroot /mnt/gentoo /bin/bash /install_chroot.sh

step "Nettoyage"
rm /mnt/gentoo/install_chroot.sh
rm /mnt/gentoo/stage3-*.tar.xz
rm /mnt/gentoo/latest-stage3-amd64-systemd.txt

# ETAPE 7: Finalisation
print_header
echo -e "${MAGENTA}=== ETAPE 7/7 : Installation terminee ! ===${NC}"
echo ""
echo -e "${GREEN}Le systeme est pret.${NC}"
echo "Redemarrez votre ordinateur et retirez le support d'installation."
echo ""
echo -e "${CYAN}Tapez 'reboot' pour redemarrer.${NC}"