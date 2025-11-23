#!/bin/bash

# Script d'installation Gentoo Linux avec detection automatique et Gnome
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
    echo -e "${GREEN}         Installation Gentoo Linux avec Gnome                  ${NC}"
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

AUTO_DISK="/dev/$(lsblk -d -o NAME,SIZE,TYPE | grep disk | sort -k2 -h | tail -1 | awk '{print $1}')"
AUTO_DISK_SIZE=$(lsblk -d -o SIZE $AUTO_DISK | tail -1)

info "Disque recommande: $AUTO_DISK ($AUTO_DISK_SIZE)"
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
echo "  - Asia/Tokyo"
echo "  - UTC"
echo ""
read_input "Fuseau horaire" "Europe/Paris" "TIMEZONE"
success "Timezone: $TIMEZONE"
echo ""

info "Exemples de locales:"
echo "  - fr_FR.UTF-8 (Francais)"
echo "  - en_US.UTF-8 (Anglais)"
echo "  - de_DE.UTF-8 (Allemand)"
echo "  - es_ES.UTF-8 (Espagnol)"
echo ""
read_input "Locale principale" "fr_FR.UTF-8" "LOCALE"
success "Locale: $LOCALE"
echo ""

info "Configuration du clavier"
echo ""
echo "Choisissez votre disposition de clavier:"
echo ""
echo "  1. fr (AZERTY Francais)"
echo "  2. us (QWERTY Americain)"
echo "  3. uk (QWERTY Britannique)"
echo "  4. de (QWERTZ Allemand)"
echo "  5. es (QWERTY Espagnol)"
echo "  6. it (QWERTY Italien)"
echo "  7. pt (QWERTY Portugais)"
echo "  8. be (AZERTY Belge)"
echo "  9. ch (QWERTZ Suisse)"
echo "  10. ca (QWERTY Canadien)"
echo ""

while true; do
    read -p "Selectionnez une option (1-10): " kb_choice
    case "$kb_choice" in
        1) KEYMAP="fr"; X11_LAYOUT="fr"; break ;;
        2) KEYMAP="us"; X11_LAYOUT="us"; break ;;
        3) KEYMAP="uk"; X11_LAYOUT="gb"; break ;;
        4) KEYMAP="de"; X11_LAYOUT="de"; break ;;
        5) KEYMAP="es"; X11_LAYOUT="es"; break ;;
        6) KEYMAP="it"; X11_LAYOUT="it"; break ;;
        7) KEYMAP="pt"; X11_LAYOUT="pt"; break ;;
        8) KEYMAP="be"; X11_LAYOUT="be"; break ;;
        9) KEYMAP="ch"; X11_LAYOUT="ch"; break ;;
        10) KEYMAP="ca"; X11_LAYOUT="ca"; break ;;
        *) warning "Option invalide" ;;
    esac
done

success "Disposition clavier: $KEYMAP"
loadkeys $KEYMAP 2>/dev/null || true
echo ""
read -p "Tapez quelque chose pour tester: " keyboard_test
success "Configuration du clavier enregistree"
sleep 2

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

info "Selection du miroir Gentoo"
echo ""
echo "Choisissez votre region pour optimiser la vitesse de telechargement:"
echo ""
echo "  1. Automatique (recommande)"
echo "  2. Europe"
echo "  3. Amerique du Nord"
echo "  4. Asie"
echo "  5. Autre"
echo ""

while true; do
    read -p "Selectionnez une option (1-5): " mirror_choice
    case "$mirror_choice" in
        1)
            STAGE3_MIRROR="https://distfiles.gentoo.org/releases/amd64/autobuilds"
            success "Miroir automatique selectionne"
            break
            ;;
        2)
            STAGE3_MIRROR="https://ftp.belnet.be/gentoo/releases/amd64/autobuilds"
            success "Miroir Europe selectionne"
            break
            ;;
        3)
            STAGE3_MIRROR="https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds"
            success "Miroir Amerique du Nord selectionne"
            break
            ;;
        4)
            STAGE3_MIRROR="https://ftp.jaist.ac.jp/pub/Linux/Gentoo/releases/amd64/autobuilds"
            success "Miroir Asie selectionne"
            break
            ;;
        5)
            STAGE3_MIRROR="https://distfiles.gentoo.org/releases/amd64/autobuilds"
            success "Miroir par defaut selectionne"
            break
            ;;
        *)
            warning "Option invalide. Veuillez choisir entre 1 et 5"
            ;;
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

if [ $SWAP_SIZE -lt 2048 ]; then
    SWAP_SIZE=2048
elif [ $SWAP_SIZE -gt 16384 ]; then
    SWAP_SIZE=16384
fi

echo -e "${CYAN}Configuration systeme:${NC}"
echo "  * Disque: $DISK ($TOTAL_GB GB)"
echo "  * Hostname: $HOSTNAME"
echo "  * Timezone: $TIMEZONE"
echo "  * Locale: $LOCALE"
echo "  * Clavier: $KEYMAP"
echo ""
echo -e "${CYAN}Utilisateurs:${NC}"
echo "  * Root: ********"
echo "  * Utilisateur: $USERNAME (********)"
echo ""
echo -e "${CYAN}Partitionnement:${NC}"
echo "  * Partition Boot: 512 MB (/boot) - FAT32"
echo "  * Partition Swap: $SWAP_SIZE MB"
echo "  * Partition Root: $(($TOTAL_GB - $SWAP_SIZE / 1024 - 1)) GB (/) - ext4"
echo ""
echo -e "${CYAN}Logiciels:${NC}"
echo "  * Environnement: Gnome Desktop"
echo "  * Init: systemd"
echo "  * Bootloader: GRUB (UEFI)"
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
info "Cette etape peut prendre 2-4 heures selon votre connexion et votre materiel"
sleep 3

step "Partitionnement automatique du disque $DISK"
wipefs -a $DISK 2>/dev/null || true
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary fat32 1MiB 513MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary linux-swap 513MiB $((513 + SWAP_SIZE))MiB
parted -s $DISK mkpart primary ext4 $((513 + SWAP_SIZE))MiB 100%

sleep 2

if [ -e "${DISK}p1" ]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
    PART3="${DISK}p3"
else
    PART1="${DISK}1"
    PART2="${DISK}2"
    PART3="${DISK}3"
fi

step "Formatage des partitions"
mkfs.vfat -F32 $PART1
mkswap $PART2
mkfs.ext4 -F $PART3

success "Partitions creees et formatees"

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
exec 3< latest-stage3-amd64-systemd.txt
while read -u 3 line; do
    case "$line" in
        \#*|*BEGIN*|*END*|"")
            continue
            ;;
        *tar.xz*)
            STAGE3=$(echo "$line" | awk '{print $1}')
            break
            ;;
    esac
done
exec 3<&-

if [ -z "$STAGE3" ]; then
    warning "Erreur: Impossible de determiner le fichier Stage3"
    echo "Contenu du fichier:"
    cat latest-stage3-amd64-systemd.txt
    exit 1
fi

info "Telechargement de: $STAGE3"
wget -q --show-progress "${STAGE3_MIRROR}/${STAGE3}"

if [ ! -f stage3-*.tar.xz ]; then
    warning "Erreur: Le telechargement du Stage3 a echoue"
    exit 1
fi

success "Stage3 telecharge"

step "Extraction du Stage3 (quelques minutes)"
tar xpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

success "Stage3 extrait"

step "Detection automatique des CPU FLAGS"
if ! command -v cpuid2cpuflags &> /dev/null; then
    info "Installation de cpuid2cpuflags..."
    emerge --quiet app-portage/cpuid2cpuflags 2>/dev/null || true
fi

if command -v cpuid2cpuflags &> /dev/null; then
    CPU_FLAGS=$(cpuid2cpuflags | grep "CPU_FLAGS_X86" | cut -d: -f2- | xargs)
    info "CPU FLAGS detectes: $CPU_FLAGS"
else
    CPU_FLAGS=""
    warning "Impossible de detecter les CPU FLAGS automatiquement"
fi

step "Configuration automatique de make.conf"
CORES=$(nproc)
cat >> /mnt/gentoo/etc/portage/make.conf << EOF

# ============================================
# Configuration generee automatiquement
# ============================================

# Optimisations de compilation
COMMON_FLAGS="-O2 -pipe -march=native"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

# Parallelisation (${CORES} coeurs detectes)
MAKEOPTS="-j${CORES} -l${CORES}"
EMERGE_DEFAULT_OPTS="--jobs=${CORES} --load-average=${CORES}"

# CPU FLAGS optimises pour votre processeur
EOF

if [ -n "$CPU_FLAGS" ]; then
    echo "CPU_FLAGS_X86=\"${CPU_FLAGS}\"" >> /mnt/gentoo/etc/portage/make.conf
fi

cat >> /mnt/gentoo/etc/portage/make.conf << EOF

# Configuration pour Gnome Desktop
USE="systemd gnome gtk wayland pulseaudio networkmanager elogind dbus \\
     X gtk3 -qt4 -qt5 -kde cups jpeg png gif svg \\
     alsa bluetooth wifi usb udisks policykit"

ACCEPT_LICENSE="*"
GRUB_PLATFORMS="efi-64"

# Optimisations Portage
FEATURES="parallel-fetch candy"
GENTOO_MIRRORS="$STAGE3_MIRROR"

# Options de compilation pour eviter les erreurs
PORTAGE_NICENESS="15"
EOF

success "make.conf configure"

# Configuration des package.use pour eviter les dependances circulaires
step "Configuration des packages pour eviter les problemes de dependances"
mkdir -p /mnt/gentoo/etc/portage/package.use

cat > /mnt/gentoo/etc/portage/package.use/circular-deps << EOF
# Dependances circulaires
media-libs/libwebp -tiff
media-libs/tiff -webp
dev-libs/glib -sysprof

# Eviter les conflits LLVM/Rust
sys-devel/llvm -test
dev-lang/rust -test
media-libs/mesa -llvm

# Simplifier les dependances Gnome
gnome-base/gnome-shell -extensions
app-text/poppler -qt5
dev-libs/boost -python

# Eviter les dependances circulaires X11/mesa
x11-base/xorg-server -minimal
media-libs/libglvnd X

# Dependances Perl simplifiees
dev-lang/perl -minimal
EOF

cat > /mnt/gentoo/etc/portage/package.use/gnome << EOF
# Flags USE pour Gnome
gnome-base/gnome-shell bluetooth networkmanager
gnome-base/nautilus -previewer
gnome-extra/gnome-tweaks -gnome-shell
app-editors/gedit python
EOF

cat > /mnt/gentoo/etc/portage/package.use/system << EOF
# Flags USE systeme
sys-apps/systemd gnuefi
sys-boot/grub mount
net-misc/networkmanager wifi bluetooth wext
sys-fs/udisks elogind
sys-auth/polkit elogind
EOF

success "Configuration des packages terminee"

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

success "Filesystems montes"

step "Preparation de l'installation chroot"

# Creation du script chroot - SANS heredocs imbriques
cat > /mnt/gentoo/install_chroot.sh << 'XXYYZZ'
#!/bin/bash
set -e
source /etc/profile
echo "========================================================"
echo "  Installation dans l environnement chroot"
echo "========================================================"
echo ""
echo ">>> Mise a jour de l arbre Portage"
emerge --sync
echo ""
echo ">>> Selection du profil Gnome systemd"
eselect profile list
echo ""
echo "Recherche du profil Gnome/systemd..."
PROFNUM=$(eselect profile list | grep -i "gnome" | grep -i "systemd" | head -1 | awk '{print $1}' | tr -d '[]')
if [ -z "$PROFNUM" ]; then
    echo "Profil Gnome non trouve, utilisation du profil desktop systemd"
    PROFNUM=$(eselect profile list | grep "desktop" | grep "systemd" | head -1 | awk '{print $1}' | tr -d '[]')
fi
if [ -z "$PROFNUM" ]; then
    echo "Utilisation du profil par defaut"
    PROFNUM=1
fi
echo "Selection du profil numero: $PROFNUM"
eselect profile set $PROFNUM
eselect profile show
echo ""
echo ">>> Mise a jour du systeme"
echo "Premiere passe de compilation avec dependances simplifiees..."
emerge --update --deep --newuse --with-bdeps=y @world || true
echo ""
echo "Seconde passe de compilation complete..."
emerge --update --deep --newuse --with-bdeps=y @world
echo ""
echo ">>> Configuration du fuseau horaire"
echo "XXTIMEZONEXX" > /etc/timezone
emerge --config sys-libs/timezone-data
echo ""
echo ">>> Configuration de la locale"
echo "XXLOCALEXX UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set XXLOCALEXX
env-update && source /etc/profile
echo ""
echo ">>> Configuration du clavier"
mkdir -p /etc/vconsole.conf.d
echo "KEYMAP=XXKEYMAPXX" > /etc/vconsole.conf
echo "FONT=lat9w-16" >> /etc/vconsole.conf
mkdir -p /etc/X11/xorg.conf.d
echo 'Section "InputClass"' > /etc/X11/xorg.conf.d/00-keyboard.conf
echo '    Identifier "system-keyboard"' >> /etc/X11/xorg.conf.d/00-keyboard.conf
echo '    MatchIsKeyboard "on"' >> /etc/X11/xorg.conf.d/00-keyboard.conf
echo '    Option "XkbLayout" "XXX11LAYOUTXX"' >> /etc/X11/xorg.conf.d/00-keyboard.conf
echo 'EndSection' >> /etc/X11/xorg.conf.d/00-keyboard.conf
echo ""
echo ">>> Installation du firmware Linux"
emerge sys-kernel/linux-firmware
echo ""
echo ">>> Installation du kernel"
emerge sys-kernel/gentoo-kernel
echo ""
echo ">>> Installation de Gnome"
emerge --autounmask-write gnome-base/gnome gnome-extra/gnome-tweaks sys-boot/grub sys-fs/dosfstools net-misc/networkmanager app-admin/sudo
etc-update --automode -5
echo ""
echo ">>> Configuration de fstab"
echo "UUID=XXUUID3XX  /               ext4    defaults,noatime    0 1" > /etc/fstab
echo "UUID=XXUUID1XX  /boot           vfat    defaults            0 2" >> /etc/fstab
echo "UUID=XXUUID2XX  none            swap    sw                  0 0" >> /etc/fstab
echo ""
echo ">>> Activation des services"
systemctl enable NetworkManager
systemctl enable gdm
echo ""
echo ">>> Configuration du hostname"
hostnamectl set-hostname XXHOSTNAMEXX
echo ""
echo ">>> Configuration du mot de passe root"
echo "root:XXROOTPWDXX" | chpasswd
echo ""
echo ">>> Creation de l utilisateur"
useradd -m -G wheel,audio,video,usb,cdrom -s /bin/bash XXUSERNAMEXX
echo "XXUSERNAMEXX:XXUSERPWDXX" | chpasswd
echo ""
echo ">>> Configuration de sudo"
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo ""
echo ">>> Installation de GRUB"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
echo ""
echo ">>> Installation d outils supplementaires"
emerge --noreplace app-editors/nano app-editors/vim sys-apps/pciutils sys-apps/usbutils net-misc/wget net-misc/curl app-shells/bash-completion
echo ""
echo "Installation chroot terminee!"
XXYYZZ

PART1UUID=$(blkid -s UUID -o value $PART1)
PART2UUID=$(blkid -s UUID -o value $PART2)
PART3UUID=$(blkid -s UUID -o value $PART3)

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

chmod +x /mnt/gentoo/install_chroot.sh

step "Entree dans l environnement chroot"
info "La compilation de Gnome va prendre beaucoup de temps (2-4h)"
info "Allez prendre un cafe..."
sleep 3

chroot /mnt/gentoo /bin/bash /install_chroot.sh

step "Nettoyage des fichiers temporaires"
rm /mnt/gentoo/install_chroot.sh
rm /mnt/gentoo/stage3-*.tar.xz
rm /mnt/gentoo/latest-stage3-amd64-systemd.txt

success "Nettoyage termine"

# ETAPE 7: Finalisation
print_header
echo -e "${MAGENTA}=== ETAPE 7/7 : Installation terminee ! ===${NC}"
echo ""

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}   Installation de Gentoo avec Gnome terminee avec succes !    ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""

echo -e "${CYAN}Recapitulatif de votre installation:${NC}"
echo "  * Systeme: Gentoo Linux (systemd)"
echo "  * Desktop: Gnome"
echo "  * Disque: $DISK"
echo "  * Hostname: $HOSTNAME"
echo "  * Clavier: $KEYMAP"
echo "  * Utilisateur: $USERNAME"
echo ""

echo -e "${YELLOW}Prochaines etapes:${NC}"
echo "  1. Quitter le chroot (si necessaire): exit"
echo "  2. Demonter les partitions:"
echo "     cd /"
echo "     umount -R /mnt/gentoo"
echo "     swapoff $PART2"
echo "  3. Redemarrer le systeme:"
echo "     reboot"
echo ""

echo -e "${CYAN}Identifiants de connexion:${NC}"
echo "  * Root: $ROOT_PASSWORD"
echo "  * $USERNAME: $USER_PASSWORD"
echo ""

echo -e "${RED}IMPORTANT:${NC}"
echo "  Changez ces mots de passe immediatement apres la premiere connexion !"
echo ""

echo -e "${GREEN}Profitez de votre nouveau systeme Gentoo !${NC}"
echo ""