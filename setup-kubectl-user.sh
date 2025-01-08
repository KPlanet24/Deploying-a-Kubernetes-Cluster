#!/bin/bash

# Функция для вывода ошибок
error_exit() {
    echo "Ошибка: $1" >&2
    exit 1
}

# Проверяем наличие sudo прав
if ! sudo -v; then
    error_exit "Требуются права sudo"
fi

# Создаем конфигурацию kubectl
echo "Настройка конфигурации kubectl..."
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Добавляем KUBECONFIG в .bashrc, если его там нет
if ! grep -q "KUBECONFIG.*\.kube/config" "$HOME/.bashrc"; then
    echo "export KUBECONFIG=$HOME/.kube/config" >> "$HOME/.bashrc"
fi

# Устанавливаем переменную окружения
export KUBECONFIG=$HOME/.kube/config

echo "Настройка kubectl завершена успешно!"
echo "Выполните 'source ~/.bashrc' или перезайдите в систему"

# Проверяем работу kubectl
kubectl get nodes 