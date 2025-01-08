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

# Проверяем наличие аргумента с командой присоединения
if [ "$#" -lt 1 ]; then
    error_exit "Использование: $0 \"<команда присоединения>\""
fi

# Собираем команду присоединения из всех аргументов
JOIN_COMMAND="$*"

# Проверяем, что команда начинается с kubeadm join
if [[ ! $JOIN_COMMAND =~ ^kubeadm[[:space:]]join ]]; then
    error_exit "Неверный формат команды присоединения. Команда должна начинаться с 'kubeadm join'"
fi

# Выполняем полный сброс перед присоединением
echo "Выполняем сброс предыдущей конфигурации..."
kubeadm reset -f
rm -rf /etc/kubernetes/*
rm -rf /var/lib/kubelet/*
rm -rf /var/lib/etcd/*
rm -rf /etc/cni/net.d/*

# Останавливаем и перезапускаем kubelet
systemctl stop kubelet
systemctl start kubelet

# Выполняем команду присоединения
echo "Присоединение к кластеру..."
eval "$JOIN_COMMAND"

if [ $? -ne 0 ]; then
    error_exit "Ошибка при присоединении к кластеру"
fi

# Перезапускаем kubelet для уверенности
systemctl restart kubelet

# Проверяем статус kubelet
echo "Проверка статуса kubelet..."
systemctl status kubelet || error_exit "Kubelet не запущен"

# Ждем некоторое время для инициализации
echo "Ожидание инициализации ноды..."
sleep 30

# Проверяем логи kubelet на наличие ошибок
echo "Проверка логов kubelet..."
journalctl -u kubelet --no-pager | tail -n 50

echo "Нода успешно присоединена к кластеру!"
echo "Проверьте статус ноды на master-узле командой: kubectl get nodes" 