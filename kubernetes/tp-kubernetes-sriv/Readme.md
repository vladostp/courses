# TP Kubernetes 2022
Au cours de ce TP, vous allez installer, configurer et administrer un cluster K8S. Puis, vous allez manipuler différents objets K8S (Workloads, Pods, Volumes etc).

--------

## Creation de l'infrastructure
Dans cette section, vous devez créer trois machines virtuelles dans OpenStack avec les caractéristiques suivantes:
- Image Ubuntu Server 22.04.1 LTS - Docker Ready
- 2 vCPU
- 4GB RAM
- 10GB d'espace disque

Une machine sera le *Master Node (Control Plane)* et deux autres seront des *Worker Nodes*. 

Ces machines doivent avoir des hostnames suivants :
- [num_etu]-master-node
- [num_etu]-worker1
- [num_etu]-worker2

------

## Installation, validation et la mise à jour (M2 SRIV)
Dans cette section, vous allez installer et valider le fonctionnement du cluster Kubernetes. 
Dans les nouvelles versions, Kubernetes ne prend plus en charge Container Runtime Docker par défaut. Pour pouvoir utiliser Docker avec Kubernetes, il faut installer et configurer un composant shim **[cri-dockerd](https://github.com/Mirantis/cri-dockerd)**.

Pour des raisons de simplicité, dans cette section du laboratoire, vous allez manipuler une version de Kubernetes qui prend en charge Docker par défaut.


### Installation

#### Sur tous les VMs

- **Ajoutez la clé GPG et le repository Kubernetes**
  ```bash
  $ sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
  $ echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  $ sudo apt update
  ```

- **Installez les packages Kubernetes**
  ```bash
  $ sudo apt install -y kubelet=1.22.0-00 kubeadm=1.22.0-00 kubectl=1.22.0-00
  ```
Dans cette section, vous installez la version 1.22.0 du Kubernetes. Dans la section suivante, vous verrez comment mettre à jour K8S.

- **Bloquez la mise à jour automatique des packages installés précédemment**
  ```bash
  $ sudo apt-mark hold kubelet kubeadm kubectl
  ```
    - La mise à jour automatique de ces packages peut casser votre cluster.

### Configuration du proxy
- **Ajoutez la variable NO_PROXY dans les variables d'environnement**
    - Ajoutez la ligne dans `/etc/environment`
  ```bash
  NO_PROXY=univ-lyon1.fr,127.0.0.1,localhost,10.244.0.0/16,10.96.0.0/12,192.168.0.0/16
  ```
        - `10.244.0.0/16` - la plage des adresses des PODS dans votre cluster
        - `10.96.0.0/12` - la plage des adresses système de Kubernetes

- **Testez si Docker peut télécharger et lancer un conteneur**
  ```bash
  $ sudo docker run hello-world
  ```

- **Redémarrez tous les machines**


### Initialisation du Cluster
Une fois les packages Kubernetes installés, vous pouvez initialiser le cluster et installer un CNI (Container Network Interface). 

Le processus d'initialisation du cluster est très simple. Vous allez utiliser **kubeadm** pour initialiser votre cluster et **flannel** comme le CNI.


#### Sur le nœud master
- **Initialisez votre cluster**
  ```bash
  $ sudo kubeadm init --pod-network-cidr=10.244.0.0/16
  ```
    - **Attention !** Mémorisez bien le token donné par cette commande, ce token sera utilisé par vos nœuds workers pour rejoindre le cluster.
    - Qu'est-ce que l'option `--pod-network-cidr` permet de faire ?
    - Suivez les étapes d'initialisation du cluster Kubernetes.

- **Configurez l'outil d'administration kubectl**
  ```bash
  $ mkdir -p $HOME/.kube
  $ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  $ sudo chown $(id -u):$(id -g) $HOME/.kube/config
  ```
    - Que fait cet outil ?

#### Sur les nœuds worker
- **Ajoutez les Workers dans cluster**
  ```bash
  $ sudo kubeadm join [join_token]
  ```
    - Le token a été donné par la commande **kubeadm init**, lors de l'initialisation du cluster.

#### Sur le noeud Master
- **Verifiez l'etat des nodes**
  ```bash
  $ kubectl get nodes
  $ kubectl describe nodes
  ```
    - Vérifiez l'état des nœuds
    - Pourquoi l'état des nœuds est "NotReady"?

- **Installez CNI (Container network interface)**
  ```bash
  $ kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
  $ kubectl get pods -n kube-flannel
  ```
    - Pour initialiser Flannel, Kubernetes crée un objet de type "DaemonSet". Pourquoi un objet de type "DaemonSet" est-il créé ?
    - Attendez que les Pods Flannel soient en état "Running".

- **Re-vérifiez l'état des nœuds**
    - Qu'avez-vous remarqués?

### Validation de l'installation
- **Créez un deployment nginx**
  ```bash
  $ kubectl create deployment --image=nginx nginx
  ```

- **Vérifiez que le pod est bien lancé et que le déploiement a été bien créé**
  ```bash
  $ kubectl get pods
  $ kubectl get deployments
  ```

- **Créez un port forward sur le pod et vérifiez son fonctionnement**
  ```bash
  $ kubectl port-forward PODNAME 8081:80 &
  $ curl 127.0.0.1:8081
  ```
    - **Attention**! Vous devez remplacer **PODNAME** par le nom du pod créé par deploy,ent.
    - Que permet de faire un port-forward?

- **Visualisez des logs du Pod**
  ```bash
  $ kubectl logs PODNAME
  ```

- Trouver sur quel nœud le pod a été lancé. Vous pouvez utiliser l'option `-o wide` de la commande `kubectl get pods`.


### La mise à jour du cluster
Dans cette section, vous allez mettre à jour votre cluster K8s. 
Pour effectuer cela, vous allez utiliser l'outil **kubeadm**. 

### Préparation de la mise à jour
Avant de commencer la mise à jour du cluster, il faut vérifier la version actuelle des éléments de votre cluster. Ensuite, vous devez trouver quelle est la dernière version stable de K8S.

- **Vérifiez la version de kubelet sur les noeuds**
  ```bash
  $ kubectl get nodes
  ```

- **Vérifiez la version d'API du client et serveur**
  ```bash
  $ kubectl version --short
  ```

- **Vérifiez la version de kubeadm**
  ```bash
  $ kubeadm version
  ```

Vous mettrez à jour le cluster vers la dernière version stable prenant en charge Docker par défaut (1.23.13). 

### La mise à jour du cluster
Vous allez commencer par mettre à jour le nœud principal.

- **Exportez les variables d'environnement suivantes**
  ```bash
  $ export VERSION=v1.23.13
  $ export ARCH=amd64
  ```

- **Récupérez et installez de la nouvelle version de kubeadm**
  ```bash
  $ curl -sSL https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubeadm > kubeadm
  $ sudo install -o root -g root -m 0755 ./kubeadm /usr/bin/kubeadm
  $ sudo kubeadm version
  ```

- **Exécutez la commande de planification de la mise à jour**
  ```
  $ sudo kubeadm upgrade plan
  ```
    - Que fait cette commande ?
    - Si toute l'information affichée vous semble correcte, vous pouvez effectuer la mise à jour du cluster

- **Mettez à jour le cluster**
  ```bash
  $ sudo kubeadm upgrade apply v1.23.13
  ```

- **Vérifiez les versions de kubelet sur les nœuds**
  ```
  $ kubectl get nodes
  ```
    - Que pouvez-vous cconstater ?

- **Mettez à jour le kubelet**
    - **Exportez les variables d'environnement suivantes**
	```bash
	$ export VERSION=v1.23.13
	$ export ARCH=amd64
	```

    - **Installez la nouvelle version de kubelet**
        ```bash
        $ curl -sSL https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubelet > kubelet
        $ sudo install -o root -g root -m 0755 ./kubelet /usr/bin/kubelet
        $ sudo systemctl restart kubelet.service
        ```
    - **Vérifiez la mise à jour de kubelet**
        ```bash
        $ kubectl get nodes
        ```

- **Vérifiez la version du kubectl**
    ```bash
    $ kubectl version
    ```
    - Que pouvez-vous constater ?

- **Mettez à jour le kubectl**
    ```bash
    $ curl -sSL https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubectl > kubectl
    $ sudo install -o root -g root -m 0755 ./kubectl /usr/bin/kubectl
    $ kubectl version
    ```

- **Mettez à jour les nœuds workers**
    - Quel composant doit être mis à jour sur les nœuds workers afin de finaliser la mise à jour de votre cluster ? 
    
- **VVérifiez à partir du nœud master que tous les workers ont été mis à jour**
        ```bash
        $ kubectl get nodes
        ```

Bravo! Vous avez mis à jour votre cluster sans aucune interruption de service!

### Nettoyage
Dans la section suivante, vous allez installer Kubernetes avec RKE (Rancher Kubernetes Engine).
Pour que l'installation avec RKE se passe bien, vous devez d'abord supprimer le cluster créé avec **kubedm** et supprimer toutes les images docker.
- **Supprimez le cluster avec kubadm** 
  ```bash
  sudo kubeadm reset
  ```
- **Supprimez tous les images docker**
  ```bash
  sudo docker rmi -f $(sudo docker images -q)
  ```

Vous devez exécuter ces commandes sur tous les nœuds du cluster.

------

## RKE Installation et validation

### Préparation de nœuds
#### SSH
Avant de commencer le déploiement avec RKE, vous devez vous assurer que la machine **Master** peut se connecter en **ssh** sur toutes les machines du cluster sans aucun mot de passe. 
**Pour cela :**
-   Créez une paire de clefs ssh **sans passphrase** sur le nœud Master (commande `ssh-keygen`) 
-   **Ajoutez** la clef publique (`.ssh/id_rsa.pub`) du **Master** au fichier des clefs autorisées (`.ssh/authorized_keys`) sur tous les nœuds (y compris sur le nœud Master).
	 - **Attention !** Conservez les clefs déjà présentes dans `.ssh/authorized_keys` (sinon vous ne pourrez plus vous connecter aux nœuds).
- Testez si le nœud **Master** arrive à se connecter en ssh sur tous les nœuds (**y compris sur lui-même**)
#### Proxy
- **Si ce n'est pas encore fait, ajoutez la variable NO_PROXY dans les variables d'environnement sur tous les nœuds**
    - Ajoutez la ligne dans `/etc/environment`
    ```bash
    NO_PROXY=univ-lyon1.fr,127.0.0.1,localhost,192.168.0.0/16
    ```
  - **Si vous avez modifié le fichier `/etc/environment`, redémarrez les nœuds**

### Installation et configuration de RKE
- Téléchargez la dernière version stable de RKE depuis le dépôt officiel [RKE](https://github.com/rancher/rke/releases/). 
	- **Attention !** Vous devez choisir une version stable (release) et non pre-release !
- Rendez le fichier téléchargé exécutable et lancer la configuration
	```bash
	$ ./rke config
	```
	- Créez un cluster de 3 machines. Avec Master ayant les rôles  `control-plane` et `etcd`, les deux travailleurs ayant le rôle de `worker`.
	- Mettez les adresses IP de vos machines en tant que `SSH Address of host`.
	- Laissez toutes les autres valeurs par défaut
	- Cette commande va créer le fichier de configuration du cluster `cluster.yml` qui peut être modifié à la main si vous souhaitez modifier la configuration du cluster.
- Démarrez le cluster Kubernetes avec RKE
	```bash
	$ ./rke up
	```
	- Cette commande va lire le fichier de configuration du cluster `cluster.yml` et va installer, démarrer et configurer tout ce qui est nécessaire pour un cluster Kubernetes.
	- Si vous voyez "Fini de créer le cluster Kubernetes avec succès", le cluster a été démarré avec succès
		- Sinon, essayez de supprimer et de redémarrer le cluster
		```bash
		./rke remove
		./rke up
		```


### Installation et configuration de kubectl
- Téléchargez et installez la dernière version de **kubectl**
  ```bash
  $ curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  $ sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  ```
- Copiez la configuration de kubectl crée par **RKE**
  ```bash
  $ mkdir -p $HOME/.kube
  $ sudo cp -i kube_config_cluster.yml $HOME/.kube/config
  $ sudo chown $(id -u):$(id -g) $HOME/.kube/config
  ```
- Vérifiez le fonctionnement de **kubectl** en récupérant les informations du nœud de cluster
  ```bash
  kubectl get nodes
  ```

-------------

## Utilisation du cluster
Dans cette section, vous allez déployer des objets Kubernetes sur votre cluster. 
Pour cela, vous allez créer des fichiers **yml** contenant la description des objets K8S. Ensuite vous allez créer ces objets avec la commande :
```bash
$ kubectl apply -f nom_du_fichier.yaml
```

### Création d'un pod
Vous commencerez par créer un Pod qui est un objet de base de K8S. 

Créez le fichier `nginx_pod.yml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    service: web
spec:
   containers:
   - name: nginx
     image: nginx
     ports:
        - containerPort: 80
          hostPort: 8080
```

Ce fichier décrit un Pod qui a les caractéristiques suivantes :
- **Nom**: nginx-pod
- **Label**: service = web
- **Image et nom du conteneur**: nginx
- **Le port du conteneur**: 80
- **Le port exposé sur le hôte**: 8080

- **Créez cet objet dans le cluster**
    ```bash
    $ kubectl apply -f nginx_pod.yml
    ```

- **Vérifiez si le pod a été bien créé**
    ```bash
    $ kubectl get pods
    ```
    - Utilisez l'option `-o wide` pour voir plus d'information sur les objets K8s
    - Sur quel nœud le Pod a-t-il été lancé ?
    - Vérifiez l'accessibilité du pod en interrogeant le port 8080 de tous les nœuds. Que pouvez-vous conclure ?
- Visualisez les logs du pod avec la commande 
	```bash
	kubectl logs NOM_DU_POD
	```
	- Avec cette commande, vous pouvez consulter depuis le nœud Master les logs de tout Pod lancé sur le cluster K8s. Vous n'avez donc plus besoin de vous connecter en **ssh** au Worker exécutant le Pod.
	- Vous pouvez également exécuter une commande dans chaque pod du cluster avec `kubectl exec`.

### Création d'un deployment
Dans la section précédente, vous avez créé un Pod avec l'application **Nginx**. Dans la vraie vie, vous ne manipulez jamais directement les Pods. Vous passerez toujours par des objets de contrôleur (workload resources), qui créeront et géreront des Pods pour vous. Ces objets assurent la réplication, le déploiement et le self-healing automatique de vos Pods.

Dans cette section, vous allez déployer une application hautement disponible et vous allez essayer les mécanismes de mises à jour déclaratives et rollbacks.

Pour commencer, vous allez créer un objet de type "Deployment". 

Créez le fichier `nginx_deployment.yml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: web
  replicas: 3
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
          - containerPort: 80
```

- **Créez cet objet dans le cluster**
    ```bash
    $ kubectl apply -f nginx_deployment.yml
    ```
    - Quels rôles jouent les labels et les sélecteurs ? 
    - Sur quelle image seront basés les conteneurs créés ?

- **Vous pouvez suivre le processus de déploiement et visualiser l'état des déploiements avec les commandes**
    ```bash
    $ kubectl rollout status deployments nginx-deployment
    $ kubectl get deployments
    $ kubectl get replicasets
    ```
    - Combien de replicas ont été créés par le déploiement ?

- **Mettez à l'échelle votre déploiement pour avoir 6 replicas**
    ```bash
    $ kubectl scale deployment nginx-deployment --replicas=6
    ```
    - Vous pouvez utiliser la commande `kubectl describe` pour afficher une description détaillée d'un objet K8S

- **Vérifiez que votre déploiement a lancé un bon nombre des replicas**
    ```bash
    $ kubectl get deployments
    ```

- **Visualisez les pods lancées par le déploiement**
    ```bash
    $ kubectl get pods
    ```
    - Comment sont distribués les pods entre les nœuds workers? (option `-o wide`)

Jusqu'à maintenant, vous avez créé un objet de type "Deployment" qui crée et maintient un nombre des Pods demandées. "Deployment" peut être vu comme un regroupement des Pods dont le nombre est garanti par K8S.

### Creation d'une service
Pour rendre le "Deployment" accessible, vous allez créer un objet de type "Service".
Le service peut être vu comme un Load Balancer qui distribue le trafic vers un ensemble des **Pods**.
Le nom du **Service** peut être utilisé comme nom de domaine pour contacter tous les Pods référencés par ce **Service** depuis n'importe quel **Pod** dans le même **namespace**.

Créez le fichier `nginx_service.yml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```
- Quel est l'intérêt de la section `selector` dans le fichier yaml?
- Que permet de faire un **Service** de type `NodePort`?

- **Créez le service dans le cluster**
    ```bash
    $ kubectl apply -f nginx_service.yml
    ```

- **Détectez quel port est exposé sur les nœuds pour atteindre le service**
    ```bash
    $ kubectl get services
    ```

- **Affichez des endpoints du service**
    ```bash
    $ kubectl get endpoints
    ```
    - Quelles adresses sont affichées dans la liste des ENDPOINTS?

- **Vérifiez que le déploiement est bien accessible depuis n'importe quel nœud du cluster**
    ```bash
    $ curl -I 127.0.0.1:[node_port]
    ```

- **Vérifier que le service est accessible depuis le Pod `nginx-pod` créé précédemment  
    - Le service doit être accessible en utilisant son nom `nginx-service` comme un nom de domaine depuis le **Pod** `nginx-pod`. 
    - Vous pouvez faire une requête avec `curl` sur `http://nginx-service` depuis le **Pod** `nginx-pod`
	- Pour exécuter une commande dans un **Pod**, vous pouvez utiliser `kubectl exec`.


### Rolling Updates
Imaginez que vous avez une nouvelle version de l'application à déployer. Vous voulez le faire sans aucune interruption de service.

Pour simuler ce scénario et pouvoir suivre le processus de déploiement, nous allons changer la version de l'image **Nginx** et ralentir le processus de déploiement. 

Nous allons modifier les paramètres de déploiement pour faire une pause de 10 secondes après le déploiement de chaque nouveau **Pod**
```bash
$ kubectl patch deployment nginx-deployment -p '{"spec": {"minReadySeconds": 10}}' 
```

Pour déployer la nouvelle version de l'application, vous mettrez à jour le **Déploiement**.

**Vous avez deux moyens pour faire cela :**
- **En modifiant le fichier `yaml` du Deployment `nginx_deployment.yml`**
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deployment
    spec:
      selector:
        matchLabels:
          app: web
      replicas: 3
      template:
        metadata:
          labels:
            app: web
        spec:
          containers:
          - name: nginx
            image: nginx:1.16.0
            ports:
              - containerPort: 80
    ```
    - **Et en appliquant les changements**
        ```bash
        $ kubectl apply -f deployment.yaml
        ```

- **Inline (en utilisant uniquement la ligne de commande)**
    ```bash
    $ kubectl set image deployments/nginx-deployment nginx=nginx:1.16.0 --v 6
    ```

- **Mettez-à-jour le déploiement et suivez le processus de déploiement**
    ```bash
    $ kubectl get services # Pour récupérer le NodePort
    $ watch -n 1 curl -I 127.0.0.1:[node_port]
    ```
    - Comme nous avons ralenti le processus de déploiement, vous pouvez suivre le déploiement de la nouvelle version en temps réel

Comme vous pouvez le constater, la mise à jour s'est déroulée de manière progressive et sans aucune interruption de service.

### Rollbacks
Imaginez que la mise à jour de l'application ne se soit pas déroulée comme prévu. L'application ne fonctionne plus ou la nouvelle version n'est plus compatible avec d'autres éléments de la pile applicative. 

Kubernetes vous donne la possibilité de revenir en arrière avec le mécanisme de Rollback.

- **Effectuez le Rollback de déploiement `nginx-deployment`**
    ```bash
    $ kubectl rollout undo deployments nginx-deployment
    ```

- **Suivez le processus de Rollback**
    ```bash
    $ watch -n 1 curl -I 127.0.0.1:[node_port]
    ```

Avec Kubernetes, vous pouvez spécifier la version de déploiement à laquelle vous souhaitez revenir. 
Pour cela, vous devez récupérer l'historique de déploiement et choisir la révision à laquelle vous souhaitez revenir.

- **Récupérez l'historique du déploiement**
    ```bash
    $ kubectl rollout history deployment nginx-deployment
    ```
    - Affichez les détails de la révision 2 du **Deployment**. Quelle commande utiliserez-vous ?
    
Vous pouvez revenir à une révision particulière du déploiement en utilisant l'option `--to-revision` de la commande `kubectl rollout undo`.

- **Revenez à la révision 2 du déploiement**
    - Quelle commande avez-vous utilisée ?


### Volumes
Certaines applications ont besoin d'un stockage permanent. Dans cette section, vous allez créer et manipuler le mécanisme des volumes persistants proposé par Kubernetes.

La création d'un volume et son attribution à un **Pod** se font en plusieurs étapes.

Tout d'abord, un objet "Persistent Volume" doit être créé. Cette tâche est généralement effectuée par l'administrateur du cluster.

Dans le cadre de ce TP, vous allez créer un volume de type `local` (un répertoire monté sur les nœuds workers) avec la capacité de stockage de 10 Giga.

Créez le fichier `pv.yml`
```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
```

- **Créez le Persistent Volume dans le cluster**
    ```bash
    $ kubectl apply -f pv.yaml
    ```
    - Que signifie l'accès mode "ReadWriteOnce"?

- **Visualisez les volumes persistants**
    ```bash
    $ kubectl get pv
    ```
    - Quel est son statut après la création?
    - Quelle est la stratégie de rétention de volume persistant créée et que signifie-t-elle ?


Vous ne pouvez pas attacher directement un volume persistant à votre **Pod**. Kubernetes ajoute une couche d'abstraction - l'objet **PersistentVolumeClaim**. Cet objet peut être vu comme une demande de stockage et peut être attaché à un **Pod**. Cette abstraction permet de découpler les volumes mis à disposition par les administrateurs K8S et les demandes d'espace de stockage des développeurs pour leurs applications.

Nous allons demander un volume qui a au moins 3 Giga de stockage et qui peut être montée en lecture-écriture par un seul nœud.

Créez le fichier `pvc.yml`
```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: task-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
```

- **Créez cet objet dans le cluster**
    ```bash
    $ kubectl apply -f pvc.yaml
    ```

- **Visualisez l'état des Persistant Volumes et Persistant Volume Claims**
    ```bash
    $ kubectl get pv
    $ kubectl get pvc
    ```
	- Quel est le statut du volume persistant et du PVC après la création de la claim ?
	
- **Est-ce que deux claims peuvent utiliser le même volume persistant ?**
    - Vous pouvez tester cela en créant une autre **Persistent Volume Claim** avec les mêmes caractéristiques mais un nom différent et voir si cette claim sera **Bound**.

Maintenant, vous pouvez attacher le `PersistantVolumeClaim` à un **Pod**.

Créez le fichier `pvc_pod.yml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mongodb-pvc
spec:
  containers:
    - image: mongo
      name: mongodb
      volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
      ports:
        - containerPort: 27017
          protocol: TCP
  volumes:
    - name: mongodb-data
      persistentVolumeClaim:
        claimName: task-pv-claim
```

- **Créez cet objet dans le cluster**
    ```bash
    $ kubectl apply -f pvc_pod.yml
    ```

- **Vérifiez que votre pod est lancé**
    ```bash
    $ kubectl get pods
    ```

    - **Trouvez un moyen de vérifier que le volume persistent fonctionne correctement**
        - Comment l'avez-vous vérifié ?


### Secrets
Les secrets sont utilisés pour sécuriser les données sensibles qui peuvent être mises à disposition dans vos Pods. Les secrets peuvent être fournis à vos pods de deux manières différentes : en tant que variables d'environnement ou en tant que volumes contenant les secrets.

Dans cette section, vous allez créer un secret et l'utiliser dans un pod de deux manières différentes.

Créez le fichier `secret.yml`
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: 42-secret
data:
  username: NDI=
  password: NDI=
```

- **Modifiez le secret** pour que les champs `username` et `password` soient 
`SRIV`. Pour cela, vous devez convertir la chaîne en base64 (commande `base64`)
    - Quel est le contenu du fichier secret.yaml après les modifications?
    - N'hésitez pas à utiliser la [documentation officielle](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/).
- **Créez le secret dans le cluster**
    ```bash
    $ kubectl apply -f secret.yml
    ```

Créez le fichier `pod_with_secret.yml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-secret
spec:
   containers:
   - name: busybox
     image: busybox
     command: ['sh', '-c', 'ls -al /secret && echo "Username: $SECRET_USERNAME" && sleep 99999']
```

- Modifiez la description du **Pod** afin que le répertoire `/secret` soit monté en tant que volume du secret et que la variable d'environement `SECRET_USERNAME` contienne la valeur `username` du secret.
    - N'hésitez pas à utiliser la [documentation officielle](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/).
- Quelle sera la nouvelle description du Pod avec des secrets?

- **Créez le Pod dans le cluster**
    ```bash
    $ kubectl apply -f pod_with_secret.yml
    ```

- **Visualisez les logs du pod**
    ```
    $ kubectl get pods
    $ kubectl logs NOM_DU_POD
    ```
    - Que voyez-vous dans les logs du Pod?

### Sondes de Liveness et Readiness

Par défaut, si un **Pod** est en cours d'exécution (Running), il est considéré comme opérationnel par Kubernetes. Cela peut créer un problème, car même si le **Pod** est en cours d'exécution, l'application peut être bloquée ou pas prête à recevoir les demandes des utilisateurs. Pour résoudre ce problème, Kubernetes propose trois mécanismes : sondes de **Liveness**, **Readiness** et **Startup**.

Kubernetes est capable de vérifier automatiquement si vos applications répondent aux demandes des utilisateurs avec des sondes **Liveness**. Si votre application est bloquée et ne répond pas, K8S la détecte et relance ou recrée le conteneur.

Kubernetes peut également retenir le trafic entrant jusqu'à ce que votre service soit en mesure de recevoir les demandes des utilisateurs avec des sondes **Readiness**.

Les sondes **Startup** sont utiles dans le contexte des sondes **Liveness** et des conteneurs à démarrage lent, les empêchant d'être tués par le K8S avant qu'ils ne soient opérationnels. 

Dans cette section, vous allez déployer des Pods avec les sondes **Liveness** et **Readiness**.

#### Liveness probe

Créez le fichier `liveness_pod.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-pod
spec:
  containers:
  - image: nginx
    name: nginx
    livenessProbe:
       httpGet:
         path: /
         port: 80
```

- **Créez cet objet dans le cluster**
    ```bash
    $ kubectl apply -f liveness-pod.yml
    ```

- **Supprimez le répertoire `/usr/share/nginx` à l'intérieur du Pod `liveness-pod`**
	```bash
	kubectl exec -it liveness-pod -- rm -r /usr/share/nginx
	```
	- Cette commande fait échouer la sonde Liveness du **Pod** car le serveur `nginx` ne trouve plus la page d'index et répond avec une erreur 404.

- **Surveillez les événements et le comportement du Pod `liveness-pod`**
    ```bash
    $ kubectl describe pod liveness-pod
    $ kubectl get pods
    ```
	- **Que fait Kubernetes en cas d'échec de la liveness probe?**


#### Readiness probe
Les sondes **Readiness** permettent de vérifier si un conteneur peut recevoir les demandes des utilisateurs. Si la vérification échoue, le trafic ne sera pas dirigé vers ce Pod.

Créez le fichier `nginx_readiness.yml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-readiness
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx-readiness
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-good
  labels:
    app: nginx-readiness
spec:
  containers:
  - name: nginx
    image: nginx
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-nogood
  labels:
    app: nginx-readiness
spec:
  containers:
  - name: nginx
    image: nginx:1.222
    readinessProbe:
      httpGet:
          path: /
          port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
```

- **Créez ces objets dans le cluster**
    ```bash
    $ kubectl apply -f nginx_readiness.yml
    ```

- **Etudiez le comportement des Pods avec une sonde Readiness**
	- Surveillez les pods
	```bash
	$ kubectl get pods -o wide
	```
		       - Que remarquez-vous?
	- Surveillez la liste des endpoints du service
	```bash
	$ kubectl get endpoints
	```
		    - Que remarquez-vous?

- **Est-ce que le service répond aux requêtes?**
    - Comment pouvez-vous expliquer un tel comportement?

- **Trouvez et corrigez l'erreur**
    - Utilisez la commande
        ```bash
        $ kubectl edit pod nginx-nogood
        ```

- **Surveillez l'état des pods et la liste des endpoints du service**
    - Que remarquez-vous?


### Création d'un Ingress
**Ingress** est un objet K8S qui gère l'accès externe (**HTTP** ou **HTTPS**) aux services. Ingress peut acheminer le trafic vers un seul service (Single Service Ingress), s'appuyer sur l'URI HTTP pour acheminer le trafic vers différents services (Simple Fanout) ou acheminer le trafic en fonction de différents noms d'hôte (Name based virtual hosting).

Pour qu'un **Ingress** soit fonctionel, un nom DNS doit être ajouté sur la plate-forme **OpenStack**. L'**OpenStack** de l'université dispose d'un service qui vous permet de générer un nom DNS fonctionnel sur le réseau de l'université. 
- Sur l'interface **Horizon** d'**OpenStack**, trouvez l'onglet **DNS** et allez à la page **Zones**
- Sur cette page, vous devez trouver une **Zone** cree auparavant avec un nom `xxxx.os.univ-lyon1.fr`. Cliquez sur **Create Record Set**.
- Creez un **Record Set** de type `A` avec le nom `votrenom.xxxx.os.univ-lyon1.fr.` (remplacez  `xxxx.os.univ-lyon1.fr.` par le nom de la **Zone** et `votrenom` par votre nom de famille et n'oubliez un `.` à la fin) et deux **Records** contenant les adresses IP des vos noeuds **Workers**.
- Si votre **Record Set** à été créé correctement, vous devriez pouvoir faire un `ping` sur le nom DNS et recevoir une réponse de l'un des **Workers**.

Une fois le nom DNS correctement configuré, vous pouvez créer l'objet **Ingress** qui redirigera le trafic vers le service `nginx-service` créé précédemment.

Créez le fichier `nginx_ingress.yml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  defaultBackend:
    service:
      name: nginx-service
      port:
        number: 80
```

- **Créez cet objet dans le cluster**
    ```bash
    $ kubectl apply -f nginx_ingress.yml
    ```

- **Visualisez la liste des Ingress
    ```
    $ kubectl get ingress
    ```
	- Quelles adresses se trouvent dans le colonne `ADDRESS` ?
	
- Essayez d'accéder au **Service** avec votre navigateur en utilisant le nom DNS créé précédemment.
	- Que pouvez-vous constater ?


