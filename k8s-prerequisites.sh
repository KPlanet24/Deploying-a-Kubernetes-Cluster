#!/bin/bash

# Функция для вывода ошибок
error_exit() {
    echo "Ошибка: $1" >&2
    exit 1
}

# Проверяем, запущен ли скрипт от root
if [ "$(id -u)" != "0" ]; then
    error_exit "Этот скрипт должен быть запущен от пользователя root"
fi

# Отключаем swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# Загружаем необходимые модули ядра
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Настраиваем параметры сети
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Устанавливаем containerd
apt-get update
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# Устанавливаем kubernetes компоненты
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

# Добавляем GPG ключ Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Добавляем репозиторий Kubernetes
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Обновляем индекс пакетов и устанавливаем компоненты kubernetes
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Проверяем установку
echo "Проверка установленных компонентов:"
kubeadm version || error_exit "kubeadm не установлен"
kubectl version --client || error_exit "kubectl не установлен"

# Отключаем автозапуск kubelet до инициализации кластера
systemctl disable kubelet
systemctl stop kubelet

# Открываем необходимые порты
./open-ports.sh $1 || error_exit "Ошибка при открытии портов"

echo "Предварительная настройка завершена успешно!" 