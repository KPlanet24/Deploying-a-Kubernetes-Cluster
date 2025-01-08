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

# Получаем IP-адрес для API-сервера
IP_ADDR=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
if [ -z "$IP_ADDR" ]; then
    error_exit "Не удалось определить IP-адрес"
fi

# Инициализируем кластер
echo "Инициализация кластера Kubernetes..."
kubeadm init --apiserver-advertise-address="$IP_ADDR" --pod-network-cidr=10.244.0.0/16 | tee /root/kubeadm-init.log

# Проверяем успешность инициализации
if [ $? -ne 0 ]; then
    error_exit "Ошибка при инициализации кластера"
fi

# Создаем конфигурацию kubectl для root
echo "Настройка конфигурации kubectl..."
mkdir -p "$HOME/.kube"
cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Настраиваем kubectl для обычного пользователя, если указан
if [ -n "$SUDO_USER" ]; then
    echo "Настройка конфигурации kubectl для пользователя $SUDO_USER..."
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    mkdir -p "$user_home/.kube"
    cp -i /etc/kubernetes/admin.conf "$user_home/.kube/config"
    chown -R "$SUDO_USER:$(id -gn $SUDO_USER)" "$user_home/.kube"
    echo "export KUBECONFIG=$user_home/.kube/config" >> "$user_home/.bashrc"
fi

# Настраиваем KUBECONFIG
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> "$HOME/.bashrc"
export KUBECONFIG=/etc/kubernetes/admin.conf

# Проверяем подключение к API-серверу
echo "Проверка подключения к API-серверу..."
until kubectl get nodes &>/dev/null; do
    echo "Ожидание доступности API-сервера..."
    sleep 5
done

# Устанавливаем сетевой плагин (Calico)
echo "Установка сетевого плагина Calico..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Ожидаем готовности системных подов
echo "Ожидание готовности системных подов..."
kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s

# Выводим статус кластера
echo "Проверка статуса кластера..."
kubectl get nodes
kubectl get pods --all-namespaces

# Сохраняем команду присоединения в файл
grep -A 2 "kubeadm join" /root/kubeadm-init.log > /root/join-command.txt
chmod 600 /root/join-command.txt

echo "Кластер успешно инициализирован!"
echo "Команда для присоединения worker нод сохранена в файле /root/join-command.txt"
echo "Для просмотра команды выполните: cat /root/join-command.txt" 