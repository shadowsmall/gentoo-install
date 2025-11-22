#!/bin/bash

# Script d'installation Gentoo Linux avec détection automatique et Gnome
# ATTENTION: Ce script doit être exécuté depuis un environnement live Gentoo
# Lisez et comprenez chaque section avant de l'exécuter

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Fonction pour afficher un header
print_header() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Installation Gentoo Linux avec Gnome                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Fonction pour afficher les étapes
step() {
    echo -e "\n${YELLOW}>>> $1${NC}"
}

# Fonction pour afficher un message d'information
info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Fonction pour afficher un message de succès
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Fonction pour afficher un avertissement
warning() {
    echo -e "${RED}⚠ $1${NC}"
}

# Fonction pour lire une entrée avec valeur par défaut
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

# Fonction pour lire un mot de passe
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
                warning "Le mot de passe doit contenir au moins 6 caractères"
                continue
            fi
            eval $var_name="$password"
            break
        else
            warning "Les mots de passe ne correspondent pas. Réessayez."
        fi
    done
}

# Fonction de menu de sélection
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    
    echo -e "${CYAN}$prompt${NC}"
    echo ""
    
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done
    echo ""
    
    while true; do
        read -p "Sélectionnez une option (1-${#options[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "${options[$((choice-1))]}"
            return
        else
            warning "Option invalide. Veuillez choisir entre 1 et ${#options[@]}"
        fi
    done
}

# Début de l'interface interactive
print_header
warning "ATTENTION: Ce script va formater et partitionner votre disque !"
warning "Assurez-vous d'avoir sauvegardé vos données importantes."
echo ""
read -p "Appuyez sur Entrée pour continuer ou Ctrl+C pour annuler..."

# ============================================
# SECTION 1: Configuration du disque
# ============================================
print_header
echo -e "${MAGENTA}═══ ÉTAPE 1/7 : Sélection du disque ═══${NC}"
echo ""

info "Disques disponibles:"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
echo ""

# Détection automatique du disque
AUTO_DISK="/dev/$(lsblk -d -o NAME,SIZE,TYPE | grep disk | sort -k2 -h | tail -1 | awk '{print $1}')"
AUTO_DISK_SIZE=$(lsblk -d -o SIZE $AUTO_DISK | tail -1)

info "Disque recommandé: $AUTO_DISK ($AUTO_DISK_SIZE)"
echo ""

read_input "Entrez le chemin du disque à utiliser" "$AUTO_DISK" "DISK"

if [ ! -b "$DISK" ]; then
    warning "Le disque $DISK n'existe pas!"
    exit 1
fi

success "Disque sélectionné: $DISK"
sleep 2

# ============================================
# SECTION 2: Configuration système
# ============================================
print_header
echo -e "${MAGENTA}═══ ÉTAPE 2/7 : Configuration système ═══${NC}"
echo ""

read_input "Nom de la machine (hostname)" "gentoo" "HOSTNAME"
success "Hostname: $HOSTNAME"
echo ""

# Configuration du fuseau horaire
info "Exemples de fuseaux horaires:"
echo "  - Europe/Paris"
echo "  - America/New_York"
echo "  - Asia/Tokyo"
echo "  - UTC"
echo ""
read_input "Fuseau horaire" "Europe/Paris" "TIMEZONE"
success "Timezone: $TIMEZONE"
echo ""

# Configuration de la locale
info "Exemples de locales:"
echo "  - fr_FR.UTF-8 (Français)"
echo "  - en_US.UTF-8 (Anglais)"
echo "  - de_DE.UTF-8 (Allemand)"
echo "  - es_ES.UTF-8 (Espagnol)"
echo ""
read_input "Locale principale" "fr_FR.UTF-8" "LOCALE"
success "Locale: $LOCALE"
echo ""

# Configuration du clavier
info "Configuration du clavier"
KEYMAP_CHOICE=$(select_option "Choisissez votre disposition de clavier:" \
    "fr (AZERTY Français)" \
    "us (QWERTY Américain)" \
    "uk (QWERTY Britannique)" \
    "de (QWERTZ Allemand)" \
    "es (QWERTY Espagnol)" \
    "it (QWERTY Italien)" \
    "pt (QWERTY Portugais)" \
    "be (AZERTY Belge)" \
    "ch (QWERTZ Suisse)" \
    "ca (QWERTY Canadien)" \
    "Autre (saisie manuelle)")

case "$KEYMAP_CHOICE" in
    "fr (AZERTY Français)")
        KEYMAP="fr"
        X11_LAYOUT="fr"
        ;;
    "us (QWERTY Américain)")
        KEYMAP="us"
        X11_LAYOUT="us"
        ;;
    "uk (QWERTY Britannique)")
        KEYMAP="uk"
        X11_LAYOUT="gb"
        ;;
    "de (QWERTZ Allemand)")
        KEYMAP="de"
        X11_LAYOUT="de"
        ;;
    "es (QWERTY Espagnol)")
        KEYMAP="es"
        X11_LAYOUT="es"
        ;;
    "it (QWERTY Italien)")
        KEYMAP="it"
        X11_LAYOUT="it"
        ;;
    "pt (QWERTY Portugais)")
        KEYMAP="pt"
        X11_LAYOUT="pt"
        ;;
    "be (AZERTY Belge)")
        KEYMAP="be"
        X11_LAYOUT="be"
        ;;
    "ch (QWERTZ Suisse)")
        KEYMAP="ch"
        X11_LAYOUT="ch"
        ;;
    "ca (QWERTY Canadien)")
        KEYMAP="ca"
        X11_LAYOUT="ca"
        ;;
    *)
        info "Liste des dispositions disponibles: fr, us, uk, de, es, it, pt, be, ch, ca, etc."
        read_input "Entrez le code du clavier" "fr" "KEYMAP"
        X11_LAYOUT="$KEYMAP"
        ;;
esac

success "Disposition clavier: $KEYMAP"

# Test du clavier
echo ""
info "Test de votre clavier - tapez quelques caractères pour vérifier:"
loadkeys $KEYMAP 2>/dev/null || warning "Impossible de charger la disposition $KEYMAP maintenant (sera configurée à l'installation)"
read -p "Tapez quelque chose: " keyboard_test
success "Configuration du clavier enregistrée"

sleep 2

# ============================================
# SECTION 3: Configuration utilisateurs
# ============================================
print_header
echo -e "${MAGENTA}═══ ÉTAPE 3/7 : Configuration des utilisateurs ═══${NC}"
echo ""

info "Configuration du mot de passe root"
read_password "Mot de passe root" "ROOT_PASSWORD"
success "Mot de passe root configuré"
echo ""

read_input "Nom de l'utilisateur principal" "user" "USERNAME"

# Validation du nom d'utilisateur
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    warning "Nom d'utilisateur invalide. Utilisation de 'user' par défaut."
    USERNAME="user"
fi

success "Utilisateur: $USERNAME"
echo ""

info "Configuration du mot de passe pour $USERNAME"
read_password "Mot de passe utilisateur" "USER_PASSWORD"
success "Mot de passe utilisateur configuré"
sleep 2

# ============================================
# SECTION 4: Options d'installation
# ============================================
print_header
echo -e "${MAGENTA}═══ ÉTAPE 4/7 : Options d'installation ═══${NC}"
echo ""

info "Sélection du miroir Gentoo"
MIRROR_CHOICE=$(select_option "Choisissez votre région pour les miroirs:" \
    "Automatique (recommandé)" \
    "Europe" \
    "Amérique du Nord" \
    "Asie" \
    "Autre")

case "$MIRROR_CHOICE" in
    "Europe")
        STAGE3_MIRROR="https://ftp.belnet.be/gentoo/releases/amd64/autobuilds"
        ;;
    "Amérique du Nord")
        STAGE3_MIRROR="https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds"
        ;;
    "Asie")
        STAGE3_MIRROR="https://ftp.jaist.ac.jp/pub/Linux/Gentoo/releases/amd64/autobuilds"
        ;;
    *)
        STAGE3_MIRROR="https://distfiles.gentoo.org/releases/amd64/autobuilds"
        ;;
esac

success "Miroir sélectionné"
sleep 2

# ============================================
# SECTION 5: Récapitulatif
# ============================================
print_header
echo -e "${MAGENTA}═══ ÉTAPE 5/7 : Récapitulatif de la configuration ═══${NC}"
echo ""

TOTAL_SIZE=$(lsblk -b -d -o SIZE $DISK | tail -1)
TOTAL_GB=$((TOTAL_SIZE / 1024 / 1024 / 1024))
SWAP_SIZE=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024))

if [ $SWAP_SIZE -lt 2048 ]; then
    SWAP_SIZE=2048
elif [ $SWAP_SIZE -gt 16384 ]; then
    SWAP_SIZE=16384
fi

echo -e "${CYAN}Configuration système:${NC}"
echo "  • Disque: $DISK ($TOTAL_GB GB)"
echo "  • Hostname: $HOSTNAME"
echo "  • Timezone: $TIMEZONE"
echo "  • Locale: $LOCALE"
echo "  • Clavier: $KEYMAP"
echo ""
echo -e "${CYAN}Utilisateurs:${NC}"
echo "  • Root: ********"
echo "  • Utilisateur: $USERNAME (********)"
echo ""
echo -e "${CYAN}Partitionnement:${NC}"
echo "  • Partition EFI: 512 MB (/boot)"
echo "  • Partition Swap: $SWAP_SIZE MB"
echo "  • Partition Root: $(($TOTAL_GB - $SWAP_SIZE / 1024 - 1)) GB (/)"
echo ""
echo -e "${CYAN}Logiciels:${NC}"
echo "  • Environnement: Gnome Desktop"
echo "  • Init: systemd"
echo "  • Bootloader: GRUB (UEFI)"
echo ""

warning "DERNIÈRE CHANCE: Toutes les données sur $DISK seront EFFACÉES!"
echo ""
read -p "Tapez 'OUI' en majuscules pour confirmer: " CONFIRM

if [ "$CONFIRM" != "OUI" ]; then
    echo "Installation annulée."
    exit 1
fi

# ============================================
# SECTION 6: Installation
# ============================================
print_header
echo -e "${MAGENTA}═══ ÉTAPE 6/7 : Installation en cours ═══${NC}"
echo ""
info "Cette étape peut prendre 2-4 heures selon votre connexion et votre matériel"
sleep 3

# Partitionnement automatique du disque
step "Partitionnement automatique du disque $DISK"
wipefs -a $DISK 2>/dev/null || true
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary fat32 1MiB 513MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary linux-swap 513MiB $((513 + SWAP_SIZE))MiB
parted -s $DISK mkpart primary ext4 $((513 + SWAP_SIZE))MiB 100%

sleep 2

# Détection automatique des noms de partitions
if [ -e "${DISK}p1" ]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
    PART3="${DISK}p3"
else
    PART1="${DISK}1"
    PART2="${DISK}2"
    PART3="${DISK}3"
fi

# Formatage
step "Formatage des partitions"
mkfs.vfat -F32 $PART1
mkswap $PART2
mkfs.ext4 -F $PART3

success "Partitions créées et formatées"

# Montage des partitions
step "Montage des partitions"
swapon $PART2
mount $PART3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount $PART1 /mnt/gentoo/boot

success "Partitions montées"

# Téléchargement du Stage3
step "Téléchargement du tarball Stage3"
cd /mnt/gentoo
wget -q --show-progress ${STAGE3_MIRROR}/latest-stage3-amd64-systemd.txt
STAGE3=$(grep -v '^#' latest-stage3-amd64-systemd.txt | awk '{print $1}')
info "Téléchargement de $STAGE3..."
wget -q --show-progress ${STAGE3_MIRROR}/${STAGE3}

success "Stage3 téléchargé"

step "Extraction du Stage3 (quelques minutes)"
tar xpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

success "Stage3 extrait"

# Détection automatique des CPU FLAGS
step "Détection automatique des CPU FLAGS"
if ! command -v cpuid2cpuflags &> /dev/null; then
    info "Installation de cpuid2cpuflags..."
    emerge --quiet app-portage/cpuid2cpuflags 2>/dev/null || true
fi

if command -v cpuid2cpuflags &> /dev/null; then
    CPU_FLAGS=$(cpuid2cpuflags | grep "CPU_FLAGS_X86" | cut -d: -f2- | xargs)
    info "CPU FLAGS détectés: $CPU_FLAGS"
else
    CPU_FLAGS=""
    warning "Impossible de détecter les CPU FLAGS automatiquement"
fi

# Configuration automatique de make.conf
step "Configuration automatique de make.conf"
CORES=$(nproc)
cat >> /mnt/gentoo/etc/portage/make.conf << EOF

# ============================================
# Configuration générée automatiquement
# ============================================

# Optimisations de compilation
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

# Parallélisation (${CORES} cœurs détectés)
MAKEOPTS="-j${CORES} -l${CORES}"
EMERGE_DEFAULT_OPTS="--jobs=${CORES} --load-average=${CORES}"

# CPU FLAGS optimisés pour votre processeur
EOF

if [ -n "$CPU_FLAGS" ]; then
    echo "CPU_FLAGS_X86=\"${CPU_FLAGS}\"" >> /mnt/gentoo/etc/portage/make.conf
fi

cat >> /mnt/gentoo/etc/portage/make.conf << EOF

# Configuration pour Gnome Desktop
USE="systemd gnome gtk wayland pulseaudio networkmanager elogind dbus"
ACCEPT_LICENSE="*"
GRUB_PLATFORMS="efi-64"

# Optimisations Portage
FEATURES="parallel-fetch"
GENTOO_MIRRORS="$STAGE3_MIRROR"
EOF

success "make.conf configuré"

# Configuration des repos
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# Copie DNS
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# Montage des filesystems système
step "Montage des filesystems système"
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

success "Filesystems montés"

# Création du script chroot
step "Préparation de l'installation chroot"
cat > /mnt/gentoo/install_chroot.sh << 'CHROOTEOF'
#!/bin/bash
set -e

source /etc/profile
export PS1="(chroot) ${PS1}"

echo "╔════════════════════════════════════════════════════════╗"
echo "║  Installation dans l'environnement chroot             ║"
echo "╚════════════════════════════════════════════════════════╝"

echo ""
echo ">>> Mise à jour de l'arbre Portage"
emerge-webrsync
emerge --sync --quiet

echo ""
echo ">>> Sélection du profil Gnome systemd"
PROFILE_NUM=$(eselect profile list | grep "default/linux/amd64.*gnome/systemd" | grep -v "/desktop" | tail -1 | awk '{print $1}' | tr -d '[]')
eselect profile set $PROFILE_NUM
echo "Profil sélectionné:"
eselect profile show

echo ""
echo ">>> Mise à jour du système (cela peut prendre du temps)"
emerge --update --deep --newuse --with-bdeps=y @world

echo ""
echo ">>> Configuration du fuseau horaire"
echo "TIMEZONE" > /etc/timezone
emerge --config sys-libs/timezone-data

echo ""
echo ">>> Configuration de la locale"
echo "LOCALE UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set LOCALE

env-update && source /etc/profile

echo ""
echo ">>> Configuration du clavier"
# Configuration du clavier console (systemd)
mkdir -p /etc/vconsole.conf.d
cat > /etc/vconsole.conf << VCONFEOF
KEYMAP=KEYMAP_VAR
FONT=lat9w-16
VCONFEOF

# Configuration du clavier X11 pour Gnome
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << X11CONFEOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "X11_LAYOUT_VAR"
EndSection
X11CONFEOF

echo ""
echo ">>> Installation du firmware Linux"
emerge sys-kernel/linux-firmware

echo ""
echo ">>> Installation du kernel (compilation longue)"
emerge sys-kernel/gentoo-kernel

echo ""
echo ">>> Installation de Gnome et des outils système"
echo "    Cette étape peut prendre 1-2 heures..."
emerge --autounmask-write \
    gnome-base/gnome \
    gnome-extra/gnome-tweaks \
    sys-boot/grub \
    sys-fs/dosfstools \
    net-misc/networkmanager \
    app-admin/sudo

# Accepter les changements
etc-update --automode -5

echo ""
echo ">>> Configuration de fstab"
cat > /etc/fstab << FSTABEOF
# <fs>          <mountpoint>    <type>  <opts>              <dump> <pass>
UUID=$(blkid -s UUID -o value PART3)  /               ext4    defaults,noatime    0 1
UUID=$(blkid -s UUID -o value PART1)  /boot           vfat    defaults            0 2
UUID=$(blkid -s UUID -o value PART2)  none            swap    sw                  0 0
FSTABEOF

echo ""
echo ">>> Activation des services"
systemctl enable NetworkManager
systemctl enable gdm

echo ""
echo ">>> Configuration du hostname"
hostnamectl set-hostname HOSTNAME

echo ""
echo ">>> Configuration du mot de passe root"
echo "root:ROOTPWD" | chpasswd

echo ""
echo ">>> Création de l'utilisateur USERNAME"
useradd -m -G wheel,audio,video,usb,cdrom -s /bin/bash USERNAME
echo "USERNAME:USERPWD" | chpasswd

echo ""
echo ">>> Configuration de sudo"
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo ""
echo ">>> Installation de GRUB"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo ">>> Installation d'outils supplémentaires"
emerge --noreplace \
    app-editors/nano \
    app-editors/vim \
    sys-apps/pciutils \
    sys-apps/usbutils \
    net-misc/wget \
    net-misc/curl \
    app-shells/bash-completion

echo ""
echo "✓ Installation chroot terminée avec succès!"
CHROOTEOF

# Remplacer les variables
sed -i "s|TIMEZONE|$TIMEZONE|g" /mnt/gentoo/install_chroot.sh
sed -i "s|LOCALE|$LOCALE|g" /mnt/gentoo/install_chroot.sh
sed -i "s|HOSTNAME|$HOSTNAME|g" /mnt/gentoo/install_chroot.sh
sed -i "s|ROOTPWD|$ROOT_PASSWORD|g" /mnt/gentoo/install_chroot.sh
sed -i "s|USERNAME|$USERNAME|g" /mnt/gentoo/install_chroot.sh
sed -i "s|USERPWD|$USER_PASSWORD|g" /mnt/gentoo/install_chroot.sh
sed -i "s|KEYMAP_VAR|$KEYMAP|g" /mnt/gentoo/install_chroot.sh
sed -i "s|X11_LAYOUT_VAR|$X11_LAYOUT|g" /mnt/gentoo/install_chroot.sh
sed -i "s|PART1|$PART1|g" /mnt/gentoo/install_chroot.sh
sed -i "s|PART2|$PART2|g" /mnt/gentoo/install_chroot.sh
sed -i "s|PART3|$PART3|g" /mnt/gentoo/install_chroot.sh

chmod +x /mnt/gentoo/install_chroot.sh

step "Entrée dans l'environnement chroot"
info "La compilation de Gnome va prendre beaucoup de temps (2-4h)"
info "Allez prendre un café (ou plusieurs)... ☕"
sleep 3

chroot /mnt/gentoo /bin/bash /install_chroot.sh

# Nettoyage
step "Nettoyage des fichiers temporaires"
rm /mnt/gentoo/install_chroot.sh
rm /mnt/gentoo/stage3-*.tar.xz
rm /mnt/gentoo/latest-stage3-amd64-systemd.txt

success "Nettoyage terminé"

# ============================================
# SECTION 7: Finalisation
# ============================================
print_header
echo -e "${MAGENTA}═══ ÉTAPE 7/7 : Installation terminée ! ═══${NC}"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}║   🎉 Installation de Gentoo avec Gnome terminée avec succès ! ║${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}📋 Récapitulatif de votre installation:${NC}"
echo "  • Système: Gentoo Linux (systemd)"
echo "  • Desktop: Gnome"
echo "  • Disque: $DISK"
echo "  • Hostname: $HOSTNAME"
echo "  • Clavier: $KEYMAP"
echo "  • Utilisateur: $USERNAME"
echo ""

echo -e "${YELLOW}🔧 Prochaines étapes:${NC}"
echo "  1. Quitter le chroot (si nécessaire): exit"
echo "  2. Démonter les partitions:"
echo "     cd /"
echo "     umount -R /mnt/gentoo"
echo "     swapoff $PART2"
echo "  3. Redémarrer le système:"
echo "     reboot"
echo ""

echo -e "${CYAN}🔑 Identifiants de connexion:${NC}"
echo "  • Root: $ROOT_PASSWORD"
echo "  • $USERNAME: $USER_PASSWORD"
echo ""

echo -e "${RED}⚠️  IMPORTANT:${NC}"
echo "  Changez ces mots de passe immédiatement après la première connexion !"
echo "  Commandes: passwd (pour root) et passwd $USERNAME (pour l'utilisateur)"
echo ""

echo -e "${GREEN}✨ Profitez de votre nouveau système Gentoo ! ✨${NC}"
echo ""