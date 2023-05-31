#!/usr/bin/env bash

# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

# Este script foi alterado por mim para adequar às minhas necessidades
# para o script original por favor visitar tteck/Proxmox

function header_info {
  clear
  cat <<"EOF"
    __  __                        ___              _      __              __     ____  _____
   / / / /___  ____ ___  ___     /   |  __________(_)____/ /_____ _____  / /_   / __ \/ ___/
  / /_/ / __ \/ __ `__ \/ _ \   / /| | / ___/ ___/ / ___/ __/ __ `/ __ \/ __/  / / / /\__ \
 / __  / /_/ / / / / / /  __/  / ___ |(__  |__  ) (__  ) /_/ /_/ / / / / /_   / /_/ /___/ /
/_/ /_/\____/_/ /_/ /_/\___/  /_/  |_/____/____/_/____/\__/\__,_/_/ /_/\__/   \____//____/

    _    _   _ ____  ____  _____ ____   ____    _    _        _      ____ _____ 
    / \  | \ | |  _ \|  _ \| ____/ ___| / ___|  / \  | |      / \    |  _ \_   _|
   / _ \ |  \| | | | | |_) |  _| \___ \| |     / _ \ | |     / _ \   | |_) || |  
  / ___ \| |\  | |_| |  _ <| |___ ___) | |___ / ___ \| |___ / ___ \ _|  __/ | |  
 /_/   \_\_| \_|____/|_| \_\_____|____/ \____/_/   \_\_____/_/   \_(_)_|    |_|  
                                                                                 

EOF
}
header_info
echo -e "\n A carregar..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)
VERSIONS=(stable beta dev)
for version in "${VERSIONS[@]}"; do
  eval "$version=$(curl -s https://raw.githubusercontent.com/home-assistant/version/master/$version.json | grep "ova" | cut -d '"' -f 4)"
done
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
HA=$(echo "\033[1;34m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
THIN="discard=on,ssd=1,"
set -Eeuo pipefail
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
if whiptail --title "HOME ASSISTANT OS VM" --yesno "Este script vai criar uma nova instalção do Home Assistant numa máquina virtual. Continuar?" 10 58; then
  :
else
  header_info && echo -e "⚠ Instalação interrompida pelo utilizador \n" && exit
fi

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function pve_check() {
  if [ $(pveversion | grep -c "pve-manager/7\.[2-9]") -eq 0 ]; then
    echo -e "${CROSS} Esta versão do Proxmox Virtual Environment não é suportada"
    echo -e "Requer a versão PVE 7.2 ou superior"
    echo -e "A sair..."
    sleep 2
    exit
  fi
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo -e "\n ${CROSS} Este script não funciona com PiMox! \n"
    echo -e "A sair..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --defaultno --title "SSH DETETADO" --yesno "Sugere-se usar o shell Proxmox em vez do SSH, pois o SSH pode criar problemas durante a leitura das variáveis. Deseja continuar com SSH?" 10 62; then
        echo "⚠ foste avisado ⚠"
      else
        clear
        exit
      fi
    fi
  fi
}

function exit-script() {
  clear
  echo -e "⚠  Instalação interrompida pelo utilizador \n"
  exit
}

function default_settings() {
  BRANCH="$stable"
  VMID="$NEXTID"
  FORMAT=",efitype=4m"
  MACHINE=""
  DISK_CACHE=""
  HN="haos$stable"
  CPU_TYPE=""
  CORE_COUNT="2"
  RAM_SIZE="4096"
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  START_VM="yes"
  echo -e "${DGN}A usar a versão HAOS: ${BGN}${BRANCH}${CL}"
  echo -e "${DGN}A usar Virtual Machine ID: ${BGN}${VMID}${CL}"
  echo -e "${DGN}A usar Machine Type: ${BGN}i440fx${CL}"
  echo -e "${DGN}A usar Disk Cache: ${BGN}Default${CL}"
  echo -e "${DGN}A usar Hostname: ${BGN}${HN}${CL}"
  echo -e "${DGN}A usar CPU Model: ${BGN}Default${CL}"
  echo -e "${DGN}Número de Cores alocados: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${DGN}Memória RAM alocada: ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DGN}A usar Bridge: ${BGN}${BRG}${CL}"
  echo -e "${DGN}A suar MAC Address: ${BGN}${MAC}${CL}"
  echo -e "${DGN}A usar VLAN: ${BGN}Default${CL}"
  echo -e "${DGN}A usar a interface MTU do tamanho: ${BGN}Default${CL}"
  echo -e "${DGN}Iniciar a VM depois da conclusão?: ${BGN}yes${CL}"
  echo -e "${BL}A criar HAOS VM usando das definições acima${CL}"
}

function advanced_settings() {
  if BRANCH=$(whiptail --title "VERSÃO DO HA" --radiolist "Escolha a versão" --cancel-button Exit-Script 10 58 3 \
    "$stable" "Estável  " ON \
    "$beta" "Beta  " OFF \
    "$dev" "Dev (em desenvolvimento)  " OFF \
    3>&1 1>&2 2>&3); then
    echo -e "${DGN}A usar a versão do HAOS: ${BGN}$BRANCH${CL}"
  else
    exit-script
  fi

  while true; do
    if VMID=$(whiptail --inputbox "Definir o ID para a Máquina Virtual" 8 58 $NEXTID --title "ID MÁQUINA VIRTUAL" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID já está em uso${CL}"
        sleep 2
        continue
      fi
      echo -e "${DGN}ID MÁQUINA VIRTUAL: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  if MACH=$(whiptail --title "TIPO DE MÁQUINA" --radiolist --cancel-button Exit-Script "Escolha o tipo" 10 58 2 \
    "i440fx" "Machine i440fx" ON \
    "q35" "Machine q35" OFF \
    3>&1 1>&2 2>&3); then
    if [ $MACH = q35 ]; then
      echo -e "${DGN}A usar o tipo de máquina: ${BGN}$MACH${CL}"
      FORMAT=""
      MACHINE=" -machine q35"
    else
      echo -e "${DGN}A usar o tipo de máquina: ${BGN}$MACH${CL}"
      FORMAT=",efitype=4m"
      MACHINE=""
    fi
  else
    exit-script
  fi

  if DISK_CACHE1=$(whiptail --title "CACHE DO DISCO" --radiolist "Escolher" --cancel-button Exit-Script 10 58 2 \
    "0" "Por defeito" ON \
    "1" "Escreva através" OFF \
    3>&1 1>&2 2>&3); then
    if [ $DISK_CACHE1 = "1" ]; then
      echo -e "${DGN}Using Disk Cache: ${BGN}Write Through${CL}"
      DISK_CACHE="cache=writethrough,"
    else
      echo -e "${DGN}Using Disk Cache: ${BGN}Default${CL}"
      DISK_CACHE=""
    fi
  else
    exit-script
  fi

  if VM_NAME=$(whiptail --inputbox "Definir nome do hostname" 8 58 haos${BRANCH} --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="haos${BRANCH}"
      echo -e "${DGN}A usar o Hostname: ${BGN}$HN${CL}"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
      echo -e "${DGN}A usar o Hostname: ${BGN}$HN${CL}"
    fi
  else
    exit-script
  fi

  if CPU_TYPE1=$(whiptail --title "MODELO DO CPU" --radiolist "Escolher" --cancel-button Exit-Script 10 58 2 \
    "0" "KVM64 (Default)" ON \
    "1" "Host" OFF \
    3>&1 1>&2 2>&3); then
    if [ $CPU_TYPE1 = "1" ]; then
      echo -e "${DGN}Using CPU Model: ${BGN}Host${CL}"
      CPU_TYPE=" -cpu host"
    else
      echo -e "${DGN}Using CPU Model: ${BGN}Default${CL}"
      CPU_TYPE=""
    fi
  else
    exit-script
  fi

  if CORE_COUNT=$(whiptail --inputbox "Alocar quantos Cores" 8 58 2 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORE_COUNT ]; then
      CORE_COUNT="2"
      echo -e "${DGN}Cores alocados: ${BGN}$CORE_COUNT${CL}"
    else
      echo -e "${DGN}Cores alocados: ${BGN}$CORE_COUNT${CL}"
    fi
  else
    exit-script
  fi

  if RAM_SIZE=$(whiptail --inputbox "Alocar número de RAM em MiB" 8 58 4096 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $RAM_SIZE ]; then
      RAM_SIZE="4096"
      echo -e "${DGN}Alocado RAM: ${BGN}$RAM_SIZE${CL}"
    else
      echo -e "${DGN}Alocado RAM: ${BGN}$RAM_SIZE${CL}"
    fi
  else
    exit-script
  fi

  if BRG=$(whiptail --inputbox "Definir a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $BRG ]; then
      BRG="vmbr0"
      echo -e "${DGN}A usar Bridge: ${BGN}$BRG${CL}"
    else
      echo -e "${DGN}A usar Bridge: ${BGN}$BRG${CL}"
    fi
  else
    exit-script
  fi

  if MAC1=$(whiptail --inputbox "Definir o MAC Address" 8 58 $GEN_MAC --title "MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC="$GEN_MAC"
      echo -e "${DGN}A usar o endereço MAC: ${BGN}$MAC${CL}"
    else
      MAC="$MAC1"
      echo -e "${DGN}A usar o endereço MAC: ${BGN}$MAC1${CL}"
    fi
  else
    exit-script
  fi

  if VLAN1=$(whiptail --inputbox "Definir a Vlan(deixe em branco para o padrão)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
      echo -e "${DGN}A usar Vlan: ${BGN}$VLAN1${CL}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${DGN}A usar Vlan: ${BGN}$VLAN1${CL}"
    fi
  else
    exit-script
  fi

  if MTU1=$(whiptail --inputbox "Defina o tamanho da interface MTU (deixe em branco para o padrão)" 8 58 --title "TAMANHO DA MTU" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
      echo -e "${DGN}A usar o Tamanho da Interface MTU: ${BGN}$MTU1${CL}"
    else
      MTU=",mtu=$MTU1"
      echo -e "${DGN}A usar o Tamanho da Interface MTU: ${BGN}$MTU1${CL}"
    fi
  else
    exit-script
  fi

  if (whiptail --title "INICIAR A MÁQUINA VIRTUAL" --yesno "Iniciar VM quando concluída?" 10 58); then
    echo -e "${DGN}Iniciar VM quando concluída: ${BGN}yes${CL}"
    START_VM="yes"
  else
    echo -e "${DGN}Iniciar VM quando concluída: ${BGN}no${CL}"
    START_VM="no"
  fi

  if (whiptail --title "CONFIGURAÇÕES AVANÇADAS COMPLETAS" --yesno "Pronto pra criar a VM HAOS ${BRANCH} VM?" --no-button Do-Over 10 58); then
    echo -e "${RD}A criar uma VM HAOS usando as configurações avançadas acima${CL}"
  else
    header_info
    echo -e "${RD}A usar as configurações avançadas${CL}"
    advanced_settings
  fi
}

function start_script() {
  if (whiptail --title "DEFINIÇÕES" --yesno "Usar as configurações padrão?" --no-button Avançadas 10 58); then
    header_info
    echo -e "${BL}A usar as configurações padrão${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}A usar as configurações avançadas${CL}"
    advanced_settings
  fi
}

arch_check
pve_check
ssh_check
start_script

msg_info "A validar armazenamento"
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  msg_error "Não foi possível detectar um local de armazenamento válido."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --title "Armazenamento" --radiolist \
      "Qual a localização de armazenamento gostaria de usar ${HN}?\nPara selecionar use a Barra de Espaço.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi
msg_ok "A usar ${CL}${BL}$STORAGE${CL} ${GN} para local de armazenamento."
msg_ok "O ID da Máquina Virtual é ${CL}${BL}$VMID${CL}."
msg_info "A obter o URL do Home Assistant ${BRANCH} Disk Image"
if [ "$BRANCH" == "$dev" ]; then
  URL=https://os-builds.home-assistant.io/${BRANCH}/haos_ova-${BRANCH}.qcow2.xz
else
  URL=https://github.com/home-assistant/operating-system/releases/download/${BRANCH}/haos_ova-${BRANCH}.qcow2.xz
fi
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
wget -q --show-progress $URL
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Download completo ${CL}${BL}haos_ova-${BRANCH}.qcow2.xz${CL}"
msg_info "A extrair KVM Disk Image"
unxz $FILE
STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  THIN=""
  ;;
btrfs)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  FORMAT=",efitype=4m"
  THIN=""
  ;;
esac
for i in {0,1}; do
  disk="DISK$i"
  eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
  eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done
msg_ok "Extraída KVM Disk Image"
msg_info "A criar HAOS VM"
qm create $VMID -agent 1${MACHINE} -tablet 0 -localtime 1 -bios ovmf${CPU_TYPE} -cores $CORE_COUNT -memory $RAM_SIZE \
  -name $HN -tags proxmox-helper-scripts -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
pvesm alloc $STORAGE $VMID $DISK0 4M 1>&/dev/null
qm importdisk $VMID ${FILE%.*} $STORAGE ${DISK_IMPORT:-} 1>&/dev/null
qm set $VMID \
  -efidisk0 ${DISK0_REF}${FORMAT} \
  -scsi0 ${DISK1_REF},${DISK_CACHE}${THIN}size=32G \
  -boot order=scsi0 \
  -description "# Home Assistant OS
### https://github.com/tteck/Proxmox
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/D1D7EP4GF)" >/dev/null
msg_ok "Criada HAOS VM ${CL}${BL}(${HN})"
if [ "$START_VM" == "yes" ]; then
  msg_info "Starting Home Assistant OS VM"
  qm start $VMID
  msg_ok "A iniciar o Assistant OS VM"
fi
msg_ok "Concluido com sucesso!\n"
