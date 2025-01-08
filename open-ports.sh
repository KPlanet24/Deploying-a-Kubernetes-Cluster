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

# Проверяем наличие firewall-cmd
if ! command -v firewall-cmd &> /dev/null; then
    echo "Установка firewalld..."
    apt-get update && apt-get install -y firewalld
    systemctl enable firewalld
    systemctl start firewalld
fi

# Функция для открытия портов
open_ports() {
    local node_type=$1
    
    # Общие порты для всех нод
    firewall-cmd --permanent --add-port=10250/tcp # Kubelet API
    
    if [ "$node_type" == "master" ]; then
        # Порты для master ноды
        firewall-cmd --permanent --add-port=6443/tcp      # Kubernetes API server
        firewall-cmd --permanent --add-port=2379-2380/tcp # etcd server client API
        firewall-cmd --permanent --add-port=10259/tcp     # kube-scheduler
        firewall-cmd --permanent --add-port=10257/tcp     # kube-controller-manager
    fi
    
    if [ "$node_type" == "worker" ]; then
        # Порты для worker ноды
        firewall-cmd --permanent --add-port=30000-32767/tcp # NodePort Services
    fi
    
    # Порты для сетевых плагинов (раскомментируйте нужные)
    firewall-cmd --permanent --add-port=179/tcp       # Calico BGP
    firewall-cmd --permanent --add-port=8472/udp      # Flannel VXLAN
    firewall-cmd --permanent --add-port=6783-6784/tcp # Weave Net
    firewall-cmd --permanent --add-port=6783-6784/udp # Weave Net
}

# Проверяем аргументы
if [ "$#" -ne 1 ]; then
    echo "Использование: $0 [master|worker]"
    exit 1
fi

if [ "$1" != "master" ] && [ "$1" != "worker" ]; then
    error_exit "Неверный аргумент. Используйте 'master' или 'worker'"
fi

# Открываем порты
echo "Открываем порты для $1 ноды..."
open_ports "$1"

# Перезагружаем firewall
echo "Перезагружаем firewall..."
firewall-cmd --reload

echo "Порты успешно открыты для $1 ноды!"

# Показываем открытые порты
echo "Список открытых портов:"
firewall-cmd --list-ports 