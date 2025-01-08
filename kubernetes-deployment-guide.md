# Руководство по развертыванию Kubernetes кластера

## 1. Подготовка к установке

### Системные требования

#### Master Node:
- CPU: минимум 2 ядра
- RAM: минимум 2 GB
- Диск: минимум 20 GB

#### Worker Node:
- CPU: минимум 1 ядро
- RAM: минимум 1 GB
- Диск: минимум 20 GB

### Требования к системе
- Ubuntu 20.04/22.04 LTS
- Отключенный swap
- Статические IP-адреса
- Полный доступ root
- Доступ в интернет

## 2. Подготовка файлов

1. Создайте все необходимые скрипты:
   - k8s-prerequisites.sh - предварительная настройка
   - open-ports.sh - настройка портов
   - master-init.sh - инициализация master ноды
   - worker-join.sh - присоединение worker ноды

2. Скопируйте скрипты на все ноды:
\`\`\`bash
scp *.sh root@<node-ip>:/root/
\`\`\`

3. Сделайте скрипты исполняемыми:
\`\`\`bash
chmod +x *.sh
\`\`\`

## 3. Установка на Master Node

1. Запустите скрипт предварительной настройки:
\`\`\`bash
./k8s-prerequisites.sh master
\`\`\`

2. Откройте необходимые порты:
\`\`\`bash
./open-ports.sh master
\`\`\`

3. Инициализируйте master-ноду:
\`\`\`bash
./master-init.sh
\`\`\`

4. После успешной инициализации сохраните команду присоединения:
\`\`\`bash
cat /root/join-command.txt
\`\`\`

5. Если вы хотите управлять кластером от имени обычного пользователя:
\`\`\`bash
# Только на master-ноде
./setup-kubectl-user.sh
source ~/.bashrc  # Применить изменения в текущей сессии
\`\`\`

## 4. Установка на Worker Nodes

Если worker-нода уже была частью кластера, сначала выполните полный сброс:
```bash
# На worker-ноде
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/*
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /var/lib/etcd/*
sudo rm -rf /etc/cni/net.d/*
sudo systemctl stop kubelet
sudo systemctl start kubelet
```

1. Запустите скрипт предварительной настройки:
\`\`\`bash
./k8s-prerequisites.sh worker
\`\`\`

2. Откройте необходимые порты:
\`\`\`bash
./open-ports.sh worker
\`\`\`

3. Присоедините ноду к кластеру:
\`\`\`bash
./worker-join.sh "<команда из join-command.txt>"
\`\`\`

## 5. Проверка кластера

На master-ноде выполните следующие команды:

1. Проверка статуса нод:
\`\`\`bash
kubectl get nodes -o wide
\`\`\`

2. Проверка системных подов:
\`\`\`bash
kubectl get pods -n kube-system
\`\`\`

3. Проверка сетевых компонентов:
\`\`\`bash
kubectl get pods -n kube-system | grep calico
\`\`\`

## 6. Открытые порты

### Master Node:
- 6443/tcp: Kubernetes API server
- 2379-2380/tcp: etcd server client API
- 10250/tcp: Kubelet API
- 10259/tcp: kube-scheduler
- 10257/tcp: kube-controller-manager

### Worker Node:
- 10250/tcp: Kubelet API
- 30000-32767/tcp: NodePort Services

### Сетевые плагины:
- 179/tcp: Calico BGP
- 8472/udp: Flannel VXLAN
- 6783-6784/tcp,udp: Weave Net

## 7. Возможные проблемы и решения

### Ошибка подключения к API-серверу
Если вы видите ошибку:
```
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

Решение:
1. Проверьте наличие конфигурационного файла:
```bash
ls -l $HOME/.kube/config
```

2. Если файл отсутствует или неправильно настроен, выполните:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

3. Проверьте переменную KUBECONFIG:
```bash
echo $KUBECONFIG
```

4. Если пусто, добавьте в ~/.bashrc:
```bash
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bashrc
source ~/.bashrc
```

5. Проверьте статус API-сервера:
```bash
sudo systemctl status kube-apiserver
```

### Нода в статусе NotReady
1. Проверьте статус kubelet:
\`\`\`bash
systemctl status kubelet
\`\`\`

2. Проверьте логи kubelet:
\`\`\`bash
journalctl -u kubelet
\`\`\`

### Проблемы с сетью
1. Проверьте статус сетевого плагина:
\`\`\`bash
kubectl get pods -n kube-system | grep calico
\`\`\`

2. Проверьте логи сетевых подов:
\`\`\`bash
kubectl logs -n kube-system <pod-name>
\`\`\`

### Worker нода не появляется в кластере
Если после присоединения worker-ноды вы видите только master при выполнении `kubectl get nodes`:

1. На worker-ноде проверьте статус kubelet:
```bash
systemctl status kubelet
journalctl -u kubelet -f
```

2. Проверьте, что команда присоединения выполнилась успешно:
```bash
# На worker-ноде
kubeadm token list
```

3. Проверьте сетевую связность:
```bash
# На worker-ноде проверьте доступность API-сервера
curl -k https://<master-ip>:6443

# Проверьте правильность открытия портов
ss -tulpn | grep -E '6443|10250'
```

4. Если нужно, пересоздайте токен на master-ноде:
```bash
# На master-ноде
kubeadm token create --print-join-command
```

5. Если нода была присоединена ранее, сначала выполните reset:
```bash
# На worker-ноде
kubeadm reset
rm -rf /etc/cni/net.d
```

6. Проверьте логи на обеих нодах:
```bash
# На master-ноде
kubectl describe node <worker-node-name>

# На worker-ноде
journalctl -u kubelet -f
```

## 8. Полезные команды

### Управление нодами
\`\`\`bash
# Список нод
kubectl get nodes -o wide

# Подробная информация о ноде
kubectl describe node <node-name>

# Вывод ноды из кластера для обслуживания
kubectl drain <node-name> --ignore-daemonsets

# Возврат ноды в работу
kubectl uncordon <node-name>
\`\`\`

### Управление подами
\`\`\`bash
# Список всех подов
kubectl get pods --all-namespaces

# Подробная информация о поде
kubectl describe pod <pod-name> -n <namespace>

# Логи пода
kubectl logs <pod-name> -n <namespace>
\`\`\`

## 9. Рекомендации по безопасности

1. Регулярно обновляйте компоненты кластера
2. Используйте RBAC для управления доступом
3. Ограничивайте доступ к API-серверу
4. Настройте Network Policies
5. Регулярно делайте резервные копии etcd

## 10. Дополнительные ресурсы

- [Официальная документация Kubernetes](https://kubernetes.io/docs/)
- [Документация kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [Документация Calico](https://docs.projectcalico.org/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
