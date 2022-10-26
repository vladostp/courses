# TP Kubernetes
Au cours de ce TP, vous allez commencer par installer un cluster K8S avec l'outil RKE (Rancher Kubernetes Engine). Ensuite, vous allez manipuler différents objets K8S (Workloads, Pods, Volumes etc). Vous finirez par déployer une application hautement disponible et auto-réparatrice composée de deux services distincts qui utilisent des volumes et des secrets.

**Attention!** Afin d'être évalué, vous devez rédiger un rapport où vous mettrez les réponses aux questions posées et la description de tous les objets créés au cours du TP. Veillez à bien utiliser les noms demandés pour les objets Kubernetes. 

--------

## Creation de l'infrastructure
Dans cette section, vous devez créer trois machines virtuelles dans OpenStack avec les caractéristiques suivantes:
- Image Ubuntu Server 22.04.1 LTS - Docker Ready
- 2 vCPU
- 4Go RAM
- 20Go d'espace disque

Une machine sera le *Master Node (Control Plane)* et deux autres seront des *Worker Nodes*. 

Ces machines doivent avoir des hostnames suivants :
- [num_etu]-master-node
- [num_etu]-worker1
- [num_etu]-worker2

Afin de créer une machine avec 20Go d'espace disque, vous allez commencer par créer trois **Volumes** dans l'OpenStack avec l'image **snap-tpkube-2022** comme **Volume Source**. Ensuite, vous allez créer trois machines avec 2 vCPU, 4 Go de RAM et avec les volumes précédemment créés comme sources de démarrage (**Boot Source**).

------

## Déploiement du cluster
Dans cette section, vous allez deployer un cluster Kubernetes avec l'outil RKE (Rancher Kubernetes Engine).

### Préparation de nœuds
#### SSH
Avant de commencer le déploiement avec RKE, vous devez vous assurer que la machine **Master** peut se connecter en **ssh** sur toutes les machines du cluster sans aucun mot de passe. 
**Pour cela :**
-   Créez une paire de clefs ssh **sans passphrase** sur le nœud Master (commande `ssh-keygen`) 
-   **Ajoutez** la clef publique (`.ssh/id_rsa.pub`) du **Master** au fichier des clefs autorisées (`.ssh/authorized_keys`) sur tous les nœuds (y compris sur le nœud Master).
	 - **Attention !** Conservez les clefs déjà présentes dans `.ssh/authorized_keys` (sinon vous ne pourrez plus vous connecter aux nœuds).
- Testez si le nœud **Master** arrive à se connecter en ssh sur tous les nœuds (**y compris sur lui-même**)

#### Proxy
- **Ajoutez la variable NO_PROXY dans les variables d'environnement sur toutes les machines**
    - Ajoutez la ligne à la fin du fichier `/etc/environment`
    ```bash
    NO_PROXY=univ-lyon1.fr,127.0.0.1,localhost,192.168.0.0/16
    ```
- **Redémarrez tous les machines**

### Déploiement de Kubernetes avec RKE
- Téléchargez la dernière version stable de RKE depuis le dépôt officiel [RKE](https://github.com/rancher/rke/releases/). 
	- **Attention !** Vous devez choisir une version stable (release) et non un pre-release !
- Rendez le fichier téléchargé exécutable (`chmod +x <NOM_DU_FICHIER>`) et lancez la configuration
	```bash
	$ ./rke config
	```
	- Créez un cluster de 3 machines. Avec un Master ayant les rôles  `control-plane` et `etcd` et les deux Workers ayant le rôle de `worker`.
	- Mettez les adresses IP de vos machines en tant que `SSH Address of host`.
	- Laissez toutes les autres valeurs par défaut
	- Cette commande va créer le fichier de configuration du cluster `cluster.yml` qui peut être changé à la main si vous souhaitez modifier la configuration du cluster.
- Démarrez le cluster Kubernetes avec RKE
	```bash
	$ ./rke up
	```
	- Cette commande lit le fichier de configuration `cluster.yml` et installe, démarre et configure tout ce qui est nécessaire pour avoir un cluster Kubernetes fonctionnel.
	- Si vous voyez "Finished building Kubernetes cluster successfully", le cluster a été déployé avec succès
		- Si ce n'est pas le cas, essayez de supprimer et de redéployer le cluster
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
- Copiez la configuration de `kubectl` crée par **RKE**
  ```bash
  $ mkdir -p $HOME/.kube
  $ sudo cp -i kube_config_cluster.yml $HOME/.kube/config
  $ sudo chown $(id -u):$(id -g) $HOME/.kube/config
  ```
- Vérifiez le fonctionnement de `kubectl` en récupérant les informations du nœud de cluster
  ```bash
  kubectl get nodes
  ```
  - Quel est l'état des nœuds ?

-------------

## Utilisation du cluster
Dans cette section, vous allez déployer quelques objets Kubernetes sur votre cluster. 
Pour cela, vous allez créer des fichiers **yml** contenant la description des objets K8s. Ensuite vous allez créer ces objets avec la commande :
```bash
$ kubectl apply -f nom_du_fichier.yaml
```

### Création d'un pod
Vous allez commencer par créer un Pod qui est la plus petite unité que vous pouvez déployer dans le cluster K8s.

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
	kubectl logs NOM_DU_POD
	```
	- Avec cette commande, vous pouvez consulter depuis le nœud Master les logs de tout Pod lancé sur le cluster K8s. 
    - Vous n'avez donc plus besoin de vous connecter en **ssh** au Worker exécutant le Pod.
	- Vous pouvez également exécuter une commande dans n'importe quel Pod du cluster avec `kubectl exec`.

### Création d'un deployment
Dans la section précédente, vous avez créé un Pod avec l'application **Nginx**. Dans la vraie vie, vous ne manipulez jamais directement les Pods. Vous passerez toujours par des objets contrôleurs (**Workload Resources**), qui créeront et géreront des Pods pour vous. Ces objets assurent la réplication, le déploiement et le self-healing automatique de vos Pods.

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
    - Vous pouvez utiliser la commande `kubectl describe` pour afficher une description détaillée des objets K8S
    ```bash
    $ kubectl describe deployment nginx-deployment
    ```
    - Que voyez-vous dans la liste des événements de déploiement ?

- **Vérifiez que votre déploiement a lancé un bon nombre des replicas**
    ```bash
    $ kubectl get deployments
    ```

- **Visualisez les pods lancées par le déploiement**
    ```bash
    $ kubectl get pods
    ```
    - Comment sont distribués les pods entre les nœuds Workers? (utilisez l'option `-o wide`)

Jusqu'à maintenant, vous avez créé un objet de type **Deployment** qui crée et maintient un nombre des Pods demandées. **Deployment** peut être vu comme un regroupement des Pods dont le nombre est garanti par K8s.

### Creation d'une service
Pour rendre votre **Deployment** accessible, vous allez créer un objet de type **Service**.
Le **Service** peut être vu comme un Load Balancer qui distribue le trafic vers un ensemble des **Pods**.
Le nom du **Service** peut être utilisé comme nom DNS pour contacter tous les Pods référencés par ce **Service** depuis n'importe quel **Pod** dans le même **namespace**.

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
    - Le service doit être accessible en utilisant son nom `nginx-service` comme un nom DNS depuis le **Pod** `nginx-pod`. 
    - Vous pouvez faire une requête avec `curl` sur `http://nginx-service` depuis le **Pod** `nginx-pod`
	- Pour exécuter une commande dans un **Pod**, vous pouvez utiliser `kubectl exec -it nginx-pod -- sh`.


### Rolling Updates
Imaginez que vous avez une nouvelle version de l'application à déployer et vous voulez le faire sans aucune interruption de service.
Pour simuler ce scénario et pouvoir suivre le processus de déploiement, nous allons changer la version de l'image **nginx** et ralentir le processus de déploiement. 

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
        $ kubectl apply -f nginx_deployment.yml
        ```

- **Inline (en utilisant uniquement la ligne de commande)**
    ```bash
    $ kubectl set image deployments/nginx-deployment nginx=nginx:1.16.0
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
Certaines applications ont besoin d'un stockage permanent. 
Dans cette section, vous allez manipuler le mécanisme des volumes persistants proposé par Kubernetes.

La création d'un volume et son attribution à un **Pod** se font en plusieurs étapes.
Tout d'abord, un objet "Persistent Volume" doit être créé. Cette tâche est généralement effectuée par l'administrateur du cluster.
Dans le cadre de ce TP, vous allez créer un volume de type `local` (un répertoire monté sur les nœuds workers) avec la capacité de stockage de 200Mi.

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
Cette abstraction permet de découpler les volumes mis à disposition par les administrateurs K8s et les demandes d'espace de stockage des développeurs pour leurs applications.

Nous allons demander un volume qui a au moins 100 Mi de stockage et qui peut être montée en lecture-écriture par un seul nœud.

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

- **Modifiez le secret** pour que les champs `username` et `password` soient 
`Lyon1`. Pour cela, vous devez convertir la chaîne en base64 (commande `base64`)
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

### Init containers
L'utilisation de conteneurs d'initialisation (initContainers) est utile lorsque vous souhaitez initialiser un **Pod** avant l'exécution du conteneur d'application. 
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
  - Que vous renvoie la commande `curl` ?


### Sondes de Liveness et Readiness
Par défaut, si un **Pod** est en cours d'exécution (Running), il est considéré comme opérationnel par Kubernetes. 
Cela peut créer un problème, car même si le **Pod** est en cours d'exécution, l'application peut être bloquée ou pas prête à recevoir les demandes des utilisateurs. 
Pour résoudre ce problème, Kubernetes propose trois mécanismes : sondes de **Liveness**, **Readiness** et **Startup**.

Dans cette section, vous allez déployer des Pods avec les sondes **Liveness** et **Readiness**.

#### Liveness probe
Kubernetes est capable de vérifier automatiquement si vos applications répondent aux demandes des utilisateurs avec des sondes **Liveness**. 
Si votre application est bloquée et ne répond pas, K8s la détecte et relance ou recrée le conteneur.

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
    $ kubectl apply -f liveness_pod.yml
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

  - **Surveillez la liste des endpoints du service**
    ```bash
    $ kubectl get endpoints
    ```
		- Que remarquez-vous?

- **Est-ce que le service répond aux requêtes?**
  ```bash
  $ kubectl get services # Trouvez sur quel port le service est exposé
  $ curl 127.0.0.1:<NODE_PORT>
  ```
  - Comment pouvez-vous expliquer un tel comportement?

- **Trouvez et corrigez l'erreur**
  - Utilisez la commande
    ```bash
    $ kubectl edit pod nginx-nogood
    ```

- **Surveillez l'état des pods et la liste des endpoints du service**
  ```bash
  $ kubectl get pods
  $ kubectl get endpoints
  ```
  - Que remarquez-vous?


### Création d'un Ingress
**Ingress** est un objet K8s qui gère l'accès externe (**HTTP** ou **HTTPS**) aux services. 
Ingress peut acheminer le trafic vers un seul service (Single Service Ingress), s'appuyer sur l'URI HTTP pour acheminer le trafic vers différents services (Simple Fanout) ou acheminer le trafic en fonction de différents noms d'hôte (Name based virtual hosting).

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

- **Visualisez la liste des Ingress
  ```
  $ kubectl get ingress
  ```
- Quelles adresses se trouvent dans le colonne `ADDRESS` ? Si vous n'avez rien dans cette colonne, attendez un peu et réexécutez la commande.
	
- Essayez d'accéder au **Service** en utilisant le nom DNS précédemment créé à parir de votre navigateur ou en executant la commande `curl`.
	- Que pouvez-vous constater ?

------

## Un déploiement plus complexe
Dans la section précédente, vous avez manipulé de nombreux objets et mécanismes de Kubernetes. Vous pouvez désormais effectuer un déploiement plus complexe avec Kubernetes.

Dans cette section, vous rassemblerez toutes les connaissances acquises précédemment pour déployer une application hautement disponible et auto-réparatrice composée de deux services distincts qui utilisent des volumes et des secrets.

### Architecture de déploiement
L'application sera composée des deux services :
- **Le premier service est la base de données Redis**
	- Il sera utilisé pour stocker un compteur utilisé et mis à jour par l'application
	- Il stockera ses données sur un volume persistant
	- Il sera configuré avec un **initContainer** pour demander une authentification avec un mot de passe qui sera fourni par un **Secret** K8s
	- Il sera configuré avec une sonde **Liveness** pour assurer son bon fonctionnement
	- Il sera accessible via un **Service**
- **Le deuxième service est une application simple Counter que nous avons développée pour ce TP**
	- Ce service va lire et incrémenter le compteur stocké dans la base de données Redis
	- Il sera initialisé en récupérant un code source depuis un dépôt Git avec **initContainer**
	- Le service aura 3 instances
	- Le `hostname` de Redis sera fourni par une variable d'environnement
	- Le mot de passe d'authentification **Redis** sera fourni en montant le secret **Redis** en tant que volume
	- Il sera configuré avec une sonde **Liveness** pour assurer son bon fonctionnement
	- Il sera accessible via un **Ingress**

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
	- Créez le **Secret** avec le nom `redis-secret` qui a un champ nommé `password`. Ce champ doit contenir le mot `redispassword` qui sera utilisé comme mot de passe d'authetification **Redis**. N'oubliez pas que les secrets doivent être encodés en `base64`.
- **Deployment**
	- Créez un déploiement avec le nom `redis-deployment` qui
		- Crée un seul replica du **Pod**
		- A le label `app: redis`
		- A deux volumes
			- Volume avec le nom `redis-config` de type `emptyDir` qui sera utilisé pour stocker la configuration **Redis**
			- Volume avec le nom `redis-data` de `PersistantVolumeClaim` crée précédemment qui sera utilisé pour stocker les données **Redis** 
		- A deux conteneurs : un d'initialisation et un principal
		-  Le conteneur d'initilisation `initContainer`
      - A le nom `redis-config-init`
			- Utilise l'image `busybox`
			- Execute la commande `["sh", "-c", "echo requirepass $PASSWORD > /etc/redis/redis.conf"]`
			- Expose le champ `password` du secret `redis-secret` comme variable d'enviromenet nommée `PASSWORD`
			- Monte le volume de configuration **Redis** dans le path `/etc/redis/`
		- Le conteneur principal
			- A le nom et utilise l'image  `redis`
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

Vous avez créé le service Redis, vous devez maintenant vérifier s'il fonctionne correctement. 
- Créez un deploiement `busybox` avec la commande `kubectl create`
	```bash
	$ kubectl create deployment --image=busybox busybox -- sleep 99999999
	```

- Récupérez le nom du Pod créé par le déploiement et lancez un terminal dans ce Pod
	```bash
	$ kubectl get pods 
	$ kubectl exec -it PODNAME -- sh
	```

- Connectez-vous avec `telnet` sur le **Redis** à partir de **Pod** `busybox` et testez si **Redis** fonctionne correctement
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
	- Si vous avez exécuté toutes les commandes et que vous voyez ces résultats, Redis et son authentification ont été correctement configurés

### Service Counter
Afin de créer le service Counter décrit dans l'architecture de déploiement, vous devez créer les objets K8S suivants :
- **Deployment**
	- Créez un déploiement avec le nom `counter-deployment` qui
		- Crée un trois replicas des **Pods**
		- A le label `app: counter`
		- A deux volumes
			- Volume avec le nom `counter-app` de type `emptyDir` qui sera utilisé pour stocker l'application PHP **Counter**
			- Volume avec le nom `redis-secret` de type **Secret**  qui va utiliser le Secret `redis-secret`
		- A deux conteneurs : un d'initialisation et un principal
		-  Le conteneur d'initilisation `initContainers`
      - A le nom `counter-app-init`
			- Utilise l'image `busybox`
			- Execute la commande `['wget', 'https://forge.univ-lyon1.fr/vladimir.ostapenco/counter-application/-/raw/main/index.php', '-O', '/var/www/html/index.php']`
			- Monte le volume de l'application PHP **Counter** dans le path `/var/www/html`
		- Le conteneur principal
      - A le nom `counter-app`
			- Utilise l'image  `vladost/php:7.2-apache-redis`
      - A une variable d'environement nomée `REDIS_HOST` contenant le nom du service Redis `redis-service`
			- Monte deux volumes
				- Volume de l'application PHP **Counter** dans le path `/var/www/html`
				- Volume de Secret `redis-secret` dans le path `/credentials`
			- A une sonde **Liveness** de type `httpGet` qui sonde le path `/` sur le port `80` pour vérifier si l'application fonctionne correctement

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
Pour vérifier le fonctionnement de l'application, vous pouvez accéder au service avec votre navigateur en utilisant le nom DNS créé précédemment.
Pour rappel, vous avez crée un nom DNS de la forme `votrenom.xxxxx.os.univ-lyon1.fr`.
Pour accéder au service `counter-service`, vous devez ajouter le préfixe `/counter` au nom DNS.
Si tout a été configuré correctement, vous devriez voir un compteur d'utilisation du service et le nom de l'instance de **Pod** que vous utilisez actuellement sur la page Web de l'application. 
Mettez à jour la page plusieurs fois pour voir l'incrémentation du compteur et le changement de nom de l'instance de **Pod**.

- **Surveillez la valeur du compteur, attendez une minute et mettez à jour la page.**
  - Que remarquez-vous ? Comment pouvez-vous l'expliquer?

Bravo! Vous avez terminé le TP!

--------

## Ce travail a été réalisé par

- [Vladimir Ostapenco](https://vladost.com/)
- [Fabien Rico](https://perso.univ-lyon1.fr/fabien.rico/site/)

----------
