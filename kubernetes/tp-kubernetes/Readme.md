# TP Kubernetes
Au cours de ce TP, vous allez commencer par installer un cluster K8S avec l'outil RKE (Rancher Kubernetes Engine). Ensuite, vous allez manipuler différents objets K8S (Workloads, Pods, Volumes etc). Vous finirez par déployer une application hautement disponible et auto-réparatrice composée de deux services distincts qui utilisent des volumes et des secrets.

**Attention!** Afin d'être évalué, vous devez rédiger un rapport où vous mettrez les réponses aux questions posées et la description de tous les objets créés au cours du TP. Veillez à bien utiliser les noms demandés pour les objets Kubernetes. 

--------

## Creation de l'infrastructure
Dans cette section, vous devez créer trois machines virtuelles dans OpenStack avec les caractéristiques suivantes:
- 2 vCPU
- 4Go RAM
- 20Go d'espace disque
- Réseau `vlan1372` ou `vlan1368` (Assurez-vous que toutes les machines virtuelles font partie du même réseau!)

Une machine sera le *Control Plane* et deux autres seront des *Worker Nodes*.

Afin de créer des machines avec 20Go d'espace disque, vous allez commencer par créer trois **Volumes** dans l'OpenStack avec l'image **Ubuntu Server 22.04.3 LTS - Docker Ready** comme **Volume Source**. Ensuite, vous allez créer trois machines avec 2 vCPU, 4 Go de RAM, réseau `vlan1372` ou `vlan1368` et avec les volumes précédemment créés comme sources de démarrage (**Boot Source**).

------

## Déploiement du cluster
Dans cette section, vous allez deployer un cluster Kubernetes avec l'outil RKE (Rancher Kubernetes Engine).

### Préparation de nœuds
#### SSH
Avant de commencer le déploiement avec RKE, vous devez vous assurer que la machine **Control Plane** peut se connecter en **ssh** sur toutes les machines du cluster sans aucun mot de passe. 
**Pour cela :**
-   Créez une paire de clés ssh **sans passphrase** sur le nœud Control Plane (commande `ssh-keygen`) 
-   **Ajoutez** la clé publique (`.ssh/id_rsa.pub`) du **Control Plane** au fichier des clés autorisées (`.ssh/authorized_keys`) sur tous les nœuds (y compris sur le nœud Control Plane).
	 - **Attention !** Conservez les clés déjà présentes dans `.ssh/authorized_keys` (sinon vous ne pourrez plus vous connecter aux nœuds).
- Testez si le nœud **Control Plane** arrive à se connecter en ssh sur tous les nœuds (**y compris sur lui-même**)

#### Proxy
- **Ajoutez la variable NO_PROXY dans les variables d'environnement sur toutes les machines**
    - Ajoutez la ligne **à la fin** du fichier `/etc/environment`
    ```bash
    NO_PROXY=univ-lyon1.fr,127.0.0.1,localhost,192.168.0.0/16
    ```
    - De cette façon, le trafic destiné aux adresses du sous-réseau `192.168.0.0/16` ne passera pas par le proxy de l'université et l'outil **RKE** pourra atteindre directement toutes les machines du cluster.
- **Redémarrez toutes les machines!**

### Déploiement de Kubernetes avec RKE (Depuis le noeud Control Plane)
- Téléchargez la dernière version stable de RKE depuis le dépôt officiel [RKE](https://github.com/rancher/rke/releases/). 
	- **Attention !** Vous devez choisir une version stable (release) et non une pre-release !
- Rendez le fichier téléchargé exécutable (`chmod +x <NOM_DU_FICHIER>`), renommez le fichier en `rke` et lancez la configuration
	```bash
	$ ./rke config
	```
	- Créez un cluster de 3 machines avec la machine Control Plane ayant les rôles `control-plane` et `etcd` et les deux Worker nodes ayant le rôle de `worker`.
	- Mettez les adresses IP de vos machines en tant que `SSH Address of host`.
	- Laissez toutes les autres paramètres aux valeurs par défaut
	- Cette commande va créer le fichier de configuration du cluster `cluster.yml` qui peut être changé à la main si vous souhaitez modifier la configuration du cluster.
- Déployez le cluster Kubernetes avec **RKE**
	```bash
	$ ./rke up
	```
	- Cette commande lit le fichier de configuration `cluster.yml` et installe, démarre et configure tout ce qui est nécessaire sur tous les nœuds pour avoir un cluster Kubernetes fonctionnel.
	- Si vous voyez "Finished building Kubernetes cluster successfully", le cluster a été déployé avec succès
		- Si ce n'est pas le cas, essayez de supprimer et de redéployer le cluster
		```bash
		$ ./rke remove
		$ ./rke up
		```
- Après avoir déployé le cluster avec **RKE**, un fichier `kube_config_cluster.yml` est créé, ce fichier contient les détails de connexion et d'authentification pour interagir avec le cluster déployé.

### Installation et configuration de kubectl
Afin de manipuler les objets de votre cluster dans ce TP, vous utiliserez **kubectl**.
**kubectl** un outil de ligne de commande permettant de communiquer avec le Control Plane d'un cluster Kubernetes via l'API Kubernetes.

- Téléchargez et installez la version `1.26.8` de **kubectl**
  ```bash
  $ curl -LO "https://dl.k8s.io/release/v1.26.8/bin/linux/amd64/kubectl"
  $ sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  ```
- Copiez la configuration de `kubectl` crée par **RKE**
  ```bash
  $ mkdir -p $HOME/.kube
  $ sudo cp -i kube_config_cluster.yml $HOME/.kube/config
  $ sudo chown $(id -u):$(id -g) $HOME/.kube/config
  ```
- Vérifiez le fonctionnement de `kubectl` en récupérant les informations du nœud de cluster
  ```bash
  $ kubectl get nodes
  ```
  - Quel est l'état des nœuds ?

-------------

## Utilisation du cluster
Dans cette section, vous allez déployer quelques objets Kubernetes sur votre cluster. 
Pour cela, vous allez créer des fichiers **yml** contenant la description des objets K8s. Ensuite vous allez créer ces objets avec la commande :
```bash
$ kubectl apply -f nom_du_fichier.yml
```

### Création d'un pod
Vous allez commencer par créer un Pod qui est la plus petite unité que vous pouvez déployer dans un cluster K8s.

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
    - Utilisez l'option `-o wide` pour voir plus d'informations sur les objets K8s
    - Sur quel nœud le Pod a-t-il été lancé ?
    - Vérifiez l'accessibilité du Pod en interrogeant le port 8080 de tous les nœuds. Que pouvez-vous conclure ?
  
- **Visualisez les logs du pod**
	```bash
	$ kubectl logs NOM_DU_POD
	```
	- Avec cette commande, vous pouvez consulter depuis le nœud Control Plane les logs de tout Pod lancé sur le cluster K8s. 
    - Vous n'avez donc plus besoin de vous connecter en **ssh** au Worker exécutant le Pod.
	- Vous pouvez également exécuter une commande dans n'importe quel Pod du cluster avec `kubectl exec`.

### Création d'un deployment
Dans la section précédente, vous avez créé un Pod avec l'application **Nginx**. Dans la vraie vie, vous ne manipulez jamais directement les Pods. Vous passez toujours par des objets contrôleurs (**Workload Resources**), qui créent et gérent les Pods pour vous. Ces objets assurent la réplication, le déploiement et le self-healing automatique de vos Pods.

Dans cette section, vous allez déployer une application hautement disponible et vous allez manipuler les mécanismes de mises à jour déclaratives et de rollback.

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

- **Vous pouvez suivre le processus de déploiement et visualiser l'état des déploiements avec les commandes suivantes**
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
    - Vous pouvez utiliser la commande `kubectl describe` pour afficher une description détaillée des objets K8S
    ```bash
    $ kubectl describe deployment nginx-deployment
    ```
    - Que voyez-vous dans la liste des événements du déploiement ?

- **Vérifiez que votre déploiement a lancé un bon nombre des replicas**
    ```bash
    $ kubectl get deployments
    ```

- **Visualisez les pods lancées par le déploiement**
    ```bash
    $ kubectl get pods
    ```
    - Comment sont distribués les pods entre les nœuds Workers? (utilisez l'option `-o wide`)

Jusqu'à présent, vous avez créé un objet de type **Deployment** qui crée et maintient un nombre des Pods demandées. 
**Deployment** peut être vu comme un regroupement des Pods dont le nombre est garanti par K8s.

### Creation d'une service
Pour rendre votre **Deployment** accessible, vous allez créer un objet de type **Service**.
Le **Service** peut être vu comme un Load Balancer qui distribue le trafic vers un ensemble des **Pods**.
Le nom du **Service** peut être utilisé comme nom DNS pour contacter tous les Pods référencés par ce **Service** depuis n'importe quel **Pod** du même **namespace**.

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
- Quel est l'intérêt de la section `selector` dans la description du service?
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

- **Vérifiez si le service est accessible depuis le Pod `nginx-pod` créé précédemment**
    - Le service doit être accessible en utilisant son nom `nginx-service` comme un nom DNS depuis le **Pod** `nginx-pod` 
    - Vous pouvez faire une requête HTTP avec `curl` sur `http://nginx-service` depuis le **Pod** `nginx-pod`
	  - Pour exécuter une commande dans le **Pod** `nginx-pod`, vous pouvez utiliser `kubectl exec`
    - Quelle commande avez-vous utilisée pour effectuer la requête HTTP avec `curl ` à partir du **Pod** `nginx-pod`? Que pouvez-vous conclure?

### Rolling Updates
Imaginez que vous avez une nouvelle version de l'application à déployer et vous voulez le faire sans aucune interruption de service.
Pour simuler ce scénario et pouvoir suivre le processus de déploiement, nous allons d'abord ralentir le processus de déploiement puis changer la version de l'image **nginx** du déploiement.


Nous allons commencer par modifier les paramètres de déploiement afin d'attendre 10 secondes après le déploiement de chaque nouveau **Pod** avant de déployer le suivant.
```bash
$ kubectl patch deployment nginx-deployment -p '{"spec": {"minReadySeconds": 10}}' 
```

Pour déployer la nouvelle version de l'application, vous allez mettre à jour le **Déploiement**.

**Vous avez trois moyens pour faire cela :**
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
        $ kubectl apply -f nginx_deployment.yml
        ```

- **Inline (en utilisant uniquement la ligne de commande)**
    ```bash
    $ kubectl set image deployments/nginx-deployment nginx=nginx:1.16.0
    ```

- **Édition interactive**
    ```bash
    $ kubectl edit deployment nginx-deployment
    ```

- **Mettez-à-jour le déploiement et suivez le processus de déploiement**
    ```bash
    $ kubectl get services # Pour récupérer le NodePort
    $ watch -n 1 curl -I 127.0.0.1:[node_port]
    ```
    - Comme nous avons ralenti le processus de déploiement, vous pouvez suivre le déploiement de la nouvelle version en temps réel.

Comme vous pouvez le constater, la mise à jour s'est déroulée de manière progressive et sans aucune interruption de service.

### Rollbacks
Imaginez que la mise à jour de l'application ne se soit pas déroulée comme prévu. 
L'application ne fonctionne plus ou la nouvelle version n'est plus compatible avec d'autres éléments de la pile applicative. 
Kubernetes vous donne la possibilité de revenir en arrière avec le mécanisme de Rollback.

- **Effectuez le Rollback de déploiement `nginx-deployment`**
    ```bash
    $ kubectl rollout undo deployments nginx-deployment
    ```

- **Suivez le processus de Rollback**
    ```bash
    $ watch -n 1 curl -I 127.0.0.1:[node_port]
    ```

- Que pouvez-vous conclure?

Avec Kubernetes, vous pouvez spécifier la version de déploiement vers laquelle vous souhaitez revenir. 
Pour cela, vous devez récupérer l'historique du déploiement et choisir la révision vers laquelle vous souhaitez revenir.

- **Récupérez l'historique du déploiement**
    ```bash
    $ kubectl rollout history deployment nginx-deployment
    ```
    - Affichez les détails de la révision 2 du **Deployment**. Quelle commande utiliserez-vous ?
    
Vous pouvez revenir à une révision particulière du déploiement en utilisant l'option `--to-revision` de la commande `kubectl rollout undo`.

- **Revenez à la révision 2 du déploiement**
    - Quelle commande avez-vous utilisé ?
    
- **Récupérez l’historique du déploiement avec la commande vue précédemment**
    - Expliquez comment les numéros de révision ont changé une fois que vous êtes revenu à la version 2 du déploiement.

### Volumes
Certaines applications ont besoin d'un stockage permanent. 
Dans cette section, vous allez manipuler le mécanisme des volumes persistants proposé par Kubernetes.

La création d'un volume et son attribution à un **Pod** se font en plusieurs étapes.
Tout d'abord, un objet `Persistent Volume` doit être créé. Cette tâche est généralement effectuée par l'administrateur du cluster.
Dans le cadre de ce TP, vous allez créer un volume persistant de type `local` (un répertoire monté sur les nœuds workers) avec la capacité de stockage de 200Mi.

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
    storage: 200Mi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
```

- **Créez le Persistent Volume dans le cluster**
    ```bash
    $ kubectl apply -f pv.yml
    ```
    - Que signifie l'accès mode "ReadWriteOnce"?

- **Visualisez les volumes persistants**
    ```bash
    $ kubectl get pv
    ```
    - Quel est le statut du PV après création ?
    - Quelle est la stratégie de rétention de volume persistant créée et que signifie-t-elle ?


Vous ne pouvez pas attacher directement un volume persistant à votre **Pod**. 
Kubernetes ajoute une couche d'abstraction - l'objet **PersistentVolumeClaim**. 
Cet objet peut être vu comme une demande de stockage et peut être attaché à un **Pod**. 
Cette abstraction permet de découpler les volumes mis à disposition par les administrateurs K8s et les demandes d'espace de stockage faites par les développeurs pour leurs applications.

Vous allez demander 100 Mi de stockage qui peut être monté en lecture-écriture par un seul nœud en créant un objet **PersistentVolumeClaim**.

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
      storage: 100Mi
```

- **Créez cet objet dans le cluster**
    ```bash
    $ kubectl apply -f pvc.yml
    ```

- **Visualisez l'état des Persistant Volumes et Persistant Volume Claims**
    ```bash
    $ kubectl get pv
    $ kubectl get pvc
    ```
	- Quel est le statut du PV et du PVC après la création de la claim ?
	
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


### Variables d'environnement
L'utilisation de variables d'environnement est le moyen le plus simple d'injecter des données dans vos applications.
Dans cette section, vous allez créer un **Pod** qui utilise une variable d'environnement et affiche sa valeur au démarrage.

Créez le fichier `env_var_pod.yml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-var-pod
spec:
   containers:
   - name: env-busybox
     image: busybox
     command: ['sh', '-c', 'echo "Username: $USERNAME" && sleep 99999']
     env: 
     - name: USERNAME
       value: administrator
```

- **Créez le Pod dans le cluster**
    ```bash
    $ kubectl apply -f env_var_pod.yml
    ```

- **Visualisez les logs du pod**
    ```
    $ kubectl get pods
    $ kubectl logs NOM_DU_POD
    ```
    - Que voyez-vous dans les logs du Pod?

### Secrets
Les secrets sont utilisés pour sécuriser les données sensibles qui peuvent être mises à disposition dans vos Pods. 
Les secrets peuvent être fournis à vos pods de deux manières différentes : en tant que variables d'environnement ou en tant que volumes contenant les secrets.

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

- **Modifiez le secret** pour que les champs `username` et `password` contiennent `Lyon1`. Pour cela, vous devez convertir la chaîne en base64 (commande `base64`)
    - Quel est le contenu du fichier `secret.yml` après les modifications?
    - N'hésitez pas à utiliser la [documentation officielle](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/).
- **Créez le secret dans le cluster**
    ```bash
    $ kubectl apply -f secret.yml
    $ kubectl get secrets
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
- Quelle sera la description du Pod avec des secrets?

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
    - Que contiennent les fichiers du répertoire `/secret`?

### Init containers
L'utilisation de conteneurs d'initialisation (initContainers) est utile lorsque vous souhaitez initialiser un **Pod** avant l'exécution du conteneur principal. 
Ces conteneurs peuvent être utilisés pour télécharger du code, effectuer une configuration ou initialiser une base de données avant le démarrage de l'application principale. 
Dans cette section, vous allez déployer un **Pod** `nginx` avec un `initContainer` basé sur l'image `busybox` qui modifie la page d'accueil `index.html` avant le démarrage du conteneur principal. 
Comme le `initContainer` et le conteneur principal sont deux conteneurs distincts, il faudra créer un volume partagé par les deux conteneurs. 
Grâce à ce volume le `initContainer` pourra modifier la page d'accueil du conteneur principal. Vous allez utiliser un volume de type `emptyDir`.

Créez le fichier `nginx_pod_with_init.yml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod-with-init
  labels:
    service: web-with-init
spec:
  volumes:  
  - name: www 
    emptyDir: {}  
  containers:
   - name: nginx
     image: nginx
     ports:
        - containerPort: 80
          hostPort: 8081
     volumeMounts:  
     - mountPath: /usr/share/nginx/html 
       name: www
  initContainers:
  - name: init-nginx
    image: busybox
    command: ["sh", "-c", "echo 'Kubernetes' > /usr/share/nginx/html/index.html"]
    volumeMounts:  
    - mountPath: /usr/share/nginx/html  
      name: www
```

- **Créez cet objet dans le cluster**
  ```bash
  $ kubectl apply -f nginx_pod_with_init.yml
  ```

- **Surveillez le déploiement du Pod**
  ```bash
  $ kubectl get pods
  ```
  - Exécutez la commande plusieurs fois pour voir toutes les étapes de création du **Pod**.
  - Sur quel nœud **Worker** le **Pod** a-t-il été lancé (utilisez l'option `-o wide` ou la commande `kubectl describe pods <NOM_DU_POD>`) ?

- **Testez le Pod deploye precedement avec la commande `curl` depuis le nœud Worker**
  ```bash
  $ curl 127.0.0.1:8081
  ```
  - Que pouvez-vous constater?


### Sondes de Liveness et Readiness
Par défaut, si un **Pod** est en cours d'exécution (Running), il est considéré comme opérationnel par Kubernetes. 
Cela peut être problématique dans le cas où le **Pod** est en cours d'exécution mais l'application est bloquée ou n'est pas prête à recevoir les demandes des utilisateurs. 
Pour pallier à ce problème, Kubernetes propose trois mécanismes des sondes: **Liveness**, **Readiness** et **Startup**.

Dans cette section, vous allez déployer des Pods avec les sondes **Liveness** et **Readiness**.

#### Liveness probe
Kubernetes est capable de vérifier automatiquement si vos applications répondent aux demandes des utilisateurs avec des sondes **Liveness**. 
Si votre application est bloquée et ne répond pas, K8s le détecte et redémarre ou recrée le conteneur.

Créez le fichier `liveness_pod.yml`
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
    $ kubectl apply -f liveness_pod.yml
    ```

- **Provoquez une erreur d'application en supprimant le répertoire `/usr/share/nginx` dans le Pod `liveness-pod`**
	```bash
	$ kubectl exec -it liveness-pod -- rm -r /usr/share/nginx
	```
	- Après avoir exécuté cette commande, la sonde Liveness du **Pod** échouera car le serveur `nginx` ne peut plus trouver la page d'index et répond par une erreur 404.

- **Surveillez les événements et le comportement du Pod `liveness-pod`**
  ```bash
  $ kubectl describe pod liveness-pod
  $ kubectl get pods
  ```
	- Que fait Kubernetes en cas d'échec de la Liveness probe?


#### Readiness probe
Kubernetes peut également retenir le trafic entrant jusqu'à ce que votre service soit en mesure de recevoir les demandes des utilisateurs avec des sondes **Readiness**.
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
  name: nginx-slow
  labels:
    app: nginx-readiness
spec:
  containers:
  - name: nginx
    image: nginx
    command: ["sh", "-c", "sleep 300 && nginx -g 'daemon off;'"]
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
  - **Surveillez les pods déployés**
    ```bash
    $ kubectl get pods -o wide
    ```
    - Que remarquez-vous?

  - **Surveillez la liste des endpoints du service**
    ```bash
    $ kubectl get endpoints
    ```
    - Que remarquez-vous?

- **Le service répond-il aux requêtes?**
  ```bash
  $ kubectl get services # Trouvez sur quel port le service est exposé
  $ curl 127.0.0.1:<NODE_PORT>
  ```
  - Comment pouvez-vous expliquer un tel comportement?

- **Attendez 5 minutes et réétudiez le comportement des Pods et la liste des endpoints du service**
  ```bash
  $ kubectl get pods
  $ kubectl get endpoints
  ```
  - Que remarquez-vous? Comment pouvez-vous expliquer un tel comportement?

### Création d'un Ingress
**Ingress** est un objet K8s qui gère l'accès externe (**HTTP** ou **HTTPS**) aux services. 
Ingress peut acheminer le trafic vers un seul service (`Single Service Ingress`), s'appuyer sur l'URI HTTP pour acheminer le trafic vers différents services (`Simple Fanout`) ou acheminer le trafic en fonction de différents noms d'hôte (`Name based virtual hosting`).

Pour qu'un **Ingress** soit fonctionel, un nom DNS doit être ajouté sur la plate-forme **OpenStack**. 
L'**OpenStack** de l'université dispose d'un service qui vous permet de générer un nom DNS fonctionnel sur le réseau de l'université. 
- Sur l'interface **Horizon** d'**OpenStack**, trouvez l'onglet **DNS** et allez à la page **Zones**
- Sur cette page, vous devez trouver une **Zone** avec un nom de forme `xxxx.os.univ-lyon1.fr`. Cliquez sur **Create Record Set**.
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

- **Visualisez la liste des Ingress**
  ```
  $ kubectl get ingress
  ```
  - Quelles adresses se trouvent dans le colonne `ADDRESS` ? Si vous n'avez rien dans cette colonne, attendez un peu et réexécutez la commande.
	
- **Essayez d'accéder au **Service** en utilisant le nom DNS précédemment créé à parir de votre navigateur ou en executant la commande `curl`**
	- Que pouvez-vous constater ?

------

## Un déploiement plus complexe
Dans la section précédente, vous avez manipulé de nombreux objets et mécanismes de Kubernetes. Vous pouvez désormais créer des déploiements plus complexes.
Dans cette section, vous rassemblerez toutes les connaissances acquises précédemment pour déployer une application hautement disponible et auto-réparatrice composée de deux services distincts qui utilisent des volumes et des secrets.

### Architecture de déploiement
L'application sera composée des deux services :
- **Le premier service est la base de données clé-valeur Redis**
	- Il sera utilisé pour stocker un compteur utilisé et mis à jour par l'application
	- Il stockera ses données sur un volume persistant
	- Il sera configuré avec un **initContainer** pour demander une authentification avec un mot de passe qui sera fourni par un **Secret**
	- Il sera configuré avec une sonde **Liveness** pour assurer son bon fonctionnement
	- Il sera accessible via un **Service**
- **Le deuxième service est une application simple Counter que nous avons développé pour ce TP**. Cette application lit et incrémente le compteur stocké dans la base de données Redis.
	- Le service sera initialisé en récupérant un code source depuis un dépôt Git avec **initContainer**
	- Il aura 3 instances
	- Le `hostname` de Redis sera fourni par une variable d'environnement
	- Le mot de passe d'authentification **Redis** sera fourni en montant le Secret **Redis** en tant que volume
	- Il sera configuré avec une sonde **Liveness** pour assurer son bon fonctionnement
	- Il sera accessible de l'exterieur via un **Ingress**

### Service Redis
Afin de créer le service Redis décrit dans l'architecture de déploiement, vous devez créer les objets K8s suivants :
- **PersistantVolume**
	- Créez un volume persistant avec le nom `redis-pv` , de type `hostPath`,  avec une capacité de stockage de `500Mi` , le mode d'accès `ReadWriteOnce` et un point de montage `/mnt/redis`. Vous pouvez vous inspirer du volume persistant créé précédemment et de la documentation officielle de Kubernetes.

- **PersistantVolumeClaim**
	- Créez un **PersistantVolumeClaim** avec le nom `redis-pvc` qui demande un stockage avec une capacité de `500Mi` et le mode d'accès `ReadWriteOnce`.
	- Verifiez que les états de **PersistantVolume** et **PersistantVolumeClaim** sont `Bound`
    ```bash
    $ kubectl get pv
    $ kubectl get pvc
	  ```
  
- **Secret**
	- Créez le **Secret** avec le nom `redis-secret` qui a un champ nommé `password`. Ce champ doit contenir le mot `redispassword` qui sera utilisé comme mot de passe d'authentification **Redis**. N'oubliez pas que les secrets doivent être encodés en `base64`.

- **Deployment**
	- Créez un déploiement portant le nom `redis-deployment` qui crée un seul replica du **Pod** avec
		- Le label `app: redis`
		- Deux volumes
			- Volume `redis-config` de type `emptyDir` qui sera utilisé pour stocker la configuration **Redis**
			- Volume `redis-data` qui utilisera `PersistantVolumeClaim` crée précédemment et qui servira à stocker les données **Redis** 
		- Deux conteneurs: un d'initialisation et un principal
      - Le conteneur d'initilisation `initContainer` qui
        - A le nom `redis-config-init`
        - Utilise l'image `busybox`
        - Execute la commande `["sh", "-c", "echo requirepass $PASSWORD > /etc/redis/redis.conf"]`
        - Expose le champ `password` du secret `redis-secret` comme variable d'enviromenet nommée `PASSWORD`
        - Monte le volume de configuration **Redis** dans le path `/etc/redis/`
      - Le conteneur principal qui
        - A le nom `redis` et utilise l'image `redis:7.0.2`
        - Execute la commande `["redis-server", "/etc/redis/redis.conf"]`
        - Monte deux volumes
          - Volume de configuration **Redis** dans le path `/etc/redis/`
          - Volume des données **Redis** dans le path `/data`
        - A une sonde **Liveness** de type `exec` qui exécute la commande `["redis-cli", "ping"]` pour vérifier si l'application fonctionne correctement
	- Verifiez le Deployement et le Pod crée
    ```bash
    $ kubectl get deployments
    $ kubectl get pods
    ```

- **Service**
	- Créez un service de type `ClusterIP` avec le nom `redis-service`  qui
		- Utilise un selector sur le label `app: redis`
		- Transfére le trafic envoyé au port TCP `6379` du **Service** sur le port `6379` du **Pod** 
	 - Verifiez le **Service** et les **Endpoints**
    ```bash
    $ kubectl get services
    $ kubectl get endpoints
    ```

Vous avez créé le service Redis, vous devez maintenant vérifier s'il fonctionne correctement. Pour cela :
- Créez un deploiement `busybox` avec la commande `kubectl create`
	```bash
	$ kubectl create deployment --image=busybox busybox -- sleep 99999999
	```

- Récupérez le nom du Pod créé par le déploiement et lancez un terminal dans ce Pod
	```bash
	$ kubectl get pods 
	$ kubectl exec -it PODNAME -- sh
	```

- Connectez-vous avec `telnet` au **Redis** à partir de **Pod** `busybox` et testez si **Redis** fonctionne correctement
	```bash
	$ telnet redis-service 6379
	$ GET counter
	-NOAUTH Authentication required.
	$ AUTH redispassword
	+OK
	$ MGET *
	*1  
	$-1
	$ QUIT
	```
	- Si vous avez exécuté toutes les commandes et que vous voyez ces résultats, **Redis** et son authentification ont été correctement configurés

### Service Counter
Afin de créer le service Counter décrit dans l'architecture de déploiement, vous devez créer les objets K8S suivants :

- **Deployment**
	- Créez un déploiement avec le nom `counter-deployment` qui crée un trois replicas des **Pods** avec
		- Le label `app: counter`
		- Deux volumes
			- Volume `counter-app` de type `emptyDir` qui sera utilisé pour stocker l'application PHP **Counter**
			- Volume `redis-secret` de type **Secret**  qui va utiliser le Secret `redis-secret`
		- Deux conteneurs : un d'initialisation et un principal
      - Le conteneur d'initilisation `initContainers` qui
        - A le nom `counter-app-init`
        - Utilise l'image `alpine`
        - Execute la commande `['wget', 'https://forge.univ-lyon1.fr/vladimir.ostapenco/counter-application/-/raw/main/index.php', '-O', '/var/www/html/index.php']`
        - Monte le volume de l'application PHP **Counter** dans le path `/var/www/html`
      - Le conteneur principal qui
        - A le nom `counter-app`
        - Utilise l'image `vladost/php:7.2-apache-redis`
        - A une variable d'environement nomée `REDIS_HOST` contenant le nom du service Redis `redis-service`
        - Monte deux volumes
          - Volume de l'application PHP **Counter** dans le path `/var/www/html`
          - Volume du Secret `redis-secret` dans le path `/credentials`
        - A une sonde **Liveness** de type `httpGet` qui sonde le chemin `/` sur le port `80` pour vérifier si l'application fonctionne correctement

	- Verifiez le Deployement et les Pods crées
    ```bash
    $ kubectl get deployments
    $ kubectl get pods
    ```

- **Service**
	- Créez un **Service** avec le nom `counter-service`  qui
		- Utilise un selector sur le label `app: counter`
		- Transfére le trafic envoyé au port TCP `80` du **Service** sur le port `80` des **Pods** 
	 - Verifiez le **Service** et les **Endpoints**
     ```bash
     $ kubectl get services
     $ kubectl get endpoints
     ```

- **Ingress**
	- Créez un **Ingress** avec le nom `counter-ingress` qui
    - A l'annotation `nginx.ingress.kubernetes.io/rewrite-target: /` (Section `annotations` dans `metadata`)
		- Redirige les requêtes HTTP envoyées au au path `/counter` vers le port `80` de **Service** `counter-service`
    - Vous pouvez vous inspirer de l'exemple Ingress `simple-fanout-example` qui est donné dans le cours
  - Verifiez l'**Ingress**
    ```bash
    $ kubectl get ingress
    ```

### Verification de l'application
Pour vérifier le fonctionnement de l'application, vous pouvez essayer d'y accéder avec votre navigateur en utilisant le nom DNS créé précédemment et le préfixe `/counter`.
  - Pour rappel, vous avez créé précédemment un nom DNS de la forme `votrenom.xxxxx.os.univ-lyon1.fr`.

Pour accéder au service `counter-service`, vous devez ajouter le préfixe `/counter` au nom DNS.
Si tout a été configuré correctement, vous devriez voir un compteur d'utilisation du service et le nom de **Pod** qui vous repond sur la page Web de l'application. 
Mettez à jour la page plusieurs fois pour voir l'incrémentation du compteur et le changement de nom de l'instance de **Pod**.

- **Surveillez la valeur du compteur, attendez une minute et mettez à jour la page.**
  - Que remarquez-vous ? Comment pouvez-vous l'expliquer?

- **Mettez à l'échelle le déploiement `counter-deployment` pour avoir 6 replicas**
  - Quelle commande avez-vous utilisé ?

------

## BONUS: Déploiement du cluster Kubernetes avec `kubeadm`
Si vous avez terminé le TP et s'il vous reste du temps, vous pouvez déployer le cluster Kubernetes avec l'outil `kubeadm`. 

`kubeadm` est un outil officiel qui vous permet de créer et de gérer des clusters Kubernetes. Cet outil effectue les actions nécessaires pour qu'un cluster minimum viable soit opérationnel.

- **Avant de commencer**, supprimez le cluster déployé avec **RKE**
```bash
$ ./rke remove
```

- Votre nouveau cluster va utiliser Docker Engine comme CRI (Container Runtime Interface)
  - Pour ce faire, vous devez installer le service `cri-dockerd` sur toutes les machines du cluster 
    - https://github.com/Mirantis/cri-dockerd
    - **N.B.**: N'hésitez pas à utiliser le package `.deb` pour installer le `cri-dockerd`

- Installez `kubeadm`, `kubelet` et `kubectl` sur tous les noeuds à l'aide du tutoriel suivant
  - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
  - Quels sont les rôles de chaque composant installé ?

- Ajoutez la variable `NO_PROXY` dans les variables d'environnement sur toutes les machines.
    - Ajoutez la ligne **à la fin** du fichier `/etc/environment`
      ```bash
      NO_PROXY=univ-lyon1.fr,127.0.0.1,localhost,10.244.0.0/16,10.96.0.0/12,192.168.0.0/16
      ```
      - `10.244.0.0/16`​ correspond à la plage d'adresses qui sera utilisée pour les **Pods** dans votre cluster
      - `10.96.0.0/12`​ correspond à la plage d'adresses système de Kubernetes
    - Redémarrez tous les nœuds

- Creez le cluster Kubernetes avec `kubeadm` à l'aide du tutoriel suivant
  - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
  - Tout d'abord, vous devez initialiser le nœud Control Plane avec la commande `kubeadm init`.
    - N'oubliez pas de spécifier le socket CRI avec l'option  `--cri-socket` sur le socket `cri-dockerd` `unix:///var/run/cri-dockerd.sock` 
    - Le réseau utilisé par les Pods doit être `10.244.0.0/16`. Pour le spécifier, utilisez l'option `--pod-network-cidr`
    - Quelle commande avez-vous utilisée pour initialiser le nœud Control Plane ?
  - Ensuite, faites en sorte que les deux nœuds Worker rejoignent le cluster
    - La commande pour ce faire sera affichée dans la sortie de la commande `kubeadm init`
    - N'oubliez pas d'ajouter l'option `--cri-socket` à la commande `kubeadm join` pour spécifier le CRI
    - Quelle commande avez-vous utilisée sur chaque nœud Worker pour rejoindre le cluster ?

- Configurez l'outil `kubectl` comme expliqué dans le résultat de la commande `kubeadm init`

- Déployez le CNI (Container Network Interface) `flannel`, comme expliqué dans
  - https://github.com/flannel-io/flannel

- Verifiez l'etat du cluser avec la commande `kubectl get nodes`
  - Si tout a été déployé correctement, tous les nœuds doivent être dans l'état `Ready`

- Déployez les objets `nginx-deployment` et `nginx-service` vus précédemment et vérifiez s'ils fonctionnent correctement.

--------

**Bravo! Vous avez fini le TP! :tada:**

--------

Ce TP a été créé par: 

- [Vladimir Ostapenco](https://vladost.com/)
- [Fabien Rico](https://perso.univ-lyon1.fr/fabien.rico/site/)

----------
