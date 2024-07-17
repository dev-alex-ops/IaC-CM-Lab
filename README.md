# Práctica 2. 
## Creación de un clúster AKS con persistencia de datos y un WebServer en VM con Podman.
Este proyecto es la entrega del último Caso Práctico para el programa **Experto en Cloud Computing y DevOps** de la **UNIR**
Lo que se busca en esta práctica es desarrollar un proyecto que abarque la automatización de infraestructura y la administración de la configuración de los servicios que se desplegarán en esta.
Basaremos esta práctica en herramientas de IaC (Terraform) como CM (Ansible). El objetivo es desplegar dichas plantillas de configuración y automatización de la infraestructura con Azure Pipelines (esto último como reto personal extra).

La VM alojará simplemente un servidor web accesible desde el puerto 8080, con la plantilla default de Nginx, mientras que en el clúster AKS he dedicido implementar una aplicación de backend sencilla en NestJS, diseñada por mi en conjunto con mi compañero Antonio Sánchez (https://github.com/aerodinamicat)

El código que despliega la infraestructura está alojado en la carpeta **terraform**, mientras que el CM se encuentra en la carpeta **Ansible**. 

---

### Terraform
He dividido el proyecto en 4 principales ficheros:
- **Main.tf**: En este se declara el provider requerido, así como se *lockea* la versión de este a la **3.111.0**. También se declara el provider como tal, pasando como parámetros **SubscriptionId** y **TenantId**
- **Resources.tf**: En este fichero se definen todos los recursos que se van a crear en Azure, siendo estos:
    - Grupo de recursos
    - Red virtual
    - Subred de dicha vnet
    - Security group y security rules para la VM
    - Ip Pública
    - Interfaz de red que conecta la VM a la subnet y la IP pública
    - Asociación de la NIC al Security Group
    - Clave SSH gestionada por Azure
    - Máquina virtual con toda la configuración de red, instancias, almacenamiento y conexión.
    - Azure Container Registry
    - Clúster AKS
    - Permisos para hacer pull de imágenes de ACR para AKS
- **Vars.tf**: En este fichero se establecen todas las variables que se emplean en la creación de la infraestuctura. Algunos tienen un valor predeterminado (como location, resourcegroupName, sku...) y otras deben declararse en el momento de lanzar el terraform plan/apply.
    - En local yo he decidido hacerlo con el argumento **-var-file *variables.tfvars***, pero para poder lanzarlo desde una pipeline, puede emplearse el uso de el argumento **-var *nombre_variable=valor*** para referenciar desde un Vault como puede ser Azure KeyVault.  
    - El motivo de no subir el fichero **tfvars** es por no exponer la información sensible, como pueden ser contraseñas, IPs, o Ids de suscripciones o tenants 

- **Outputs.tf**: En este fichero se declaran los campos que debe devolver Terraform en el momento de la creación de la infraestuctura. Algo a tener en cuenta es que aquí podemos establecer que dicho output es información sensible, por lo que no mostrará por pantalla dichos valores, teniendo que acceder a ellos con el comando
```
terraform output -raw <nombre_variable>
```

Una vez desplegada la infraestructura con Terraform, se instancian 7 outputs:
- **acr_login_url**: URL del Registry creado
- **acr_username**: Usuario administrador
- **acr_password**: Contraseña del administrador
- **kube_config**: Fichero con la configuración del clúster AKS para exportar al kubectl local
- **ssh-private-key**: Clave privada generada por Azure para poder conectar a la máquina virtual
- **vm-admin-username**: Usuario de conexión a la máquina virtual
- **vm-public-ip**: IP de la máquina virtual

Dichos argumentos nos servirán para poder realizar la configuración del entorno de trabajo de Ansible.


### Ansible
He repartido el playbook en 3 roles: **ACR para todo lo que conlleva el pull, tag y push de imágenes desde Docker al ACR**, **AKS para todo lo relacionado con el despliegue y la creación de la aplicación en el Clúster de Kubernetes** y **VM para todo lo relacionado con la configuración y despliegue del servidor web en la Máquina Virtual**

Los ficheros contenidos en el proyecto son:
- **Roles**: En este directorio se incluyen los 3 roles a los que se llamarán desde el playbook principal.
- **Ansible.cfg**: Aquí se guarda la configuración por defecto que empleará Ansible para la conexión por SSH con la máquina que se encuentra en Azure
- **Hosts.ini**: En este fichero se declara otro host del inventario que realizará las funciones más securizadas, que se llevarán a cabo en la máquina local.
- **Playbook.yml**: Este es el playbook al que llamará Ansible y que realizará las llamadas a su vez a los roles.
- **Secrets.yaml**: En este fichero se guardarán los datos sensibles, ya que se securizarán con **Ansible-Vault**, estableciendo una contraseña para este, que se le pasará por comando en el momento de despliegue del playbook.

En la creación de estas tareas, se han empleado diversos módulos, tanto propios del **ansible.builtin** como módulos de terceros, como pueden ser **azure.azcollection**, **community.docker** o **kubernetes.core**, que se instalarán con el comando:

```
ansible-galaxy collection install <nombre del módulo>
```

#### Inventario de hosts:
- **Localhost**: Se empleará para los roles de **ACR y AKS**, ya que tiene instalado Docker y se ha configurado con el cliente de Azure (Az-CLI) además de que, con las variables de salida de Terraform, puede conectarse al ACR y por kubectl al nodo de control del AKS (esto último exportando la variable KUBECONFIG e igualándola al fichero donde hemos mandado la salida del comando terraform output -raw del kubeconfig de AKS)
```
terraform output -raw kube_config > ruta_al_fichero

export KUBECONFIG=ruta_al_fichero
``` 

Importante también tener en cuenta que esta máquina también tenemos la clave privada de la máquina virtual de Azure para poder loguear por ssh contra ella. Esto es posible siguiendo el mismo procedimiento que con la configuración del clúster: leyendo la salida de terraform y mandando esta a un fichero.
```
terraform output -raw ssh_private_key_file > ruta_a_la_clave
```
Esta ruta es referenciada en el fichero **ansible.cfg** dentro de los [defaults], así como el usuario de acceso a la máquina, de modo que cuando se encuentre la máquina virtual en el inventario dinámico que lee de Azure, pueda conectar correctamente con esta.

- **Webserver**: este host es el que se declara en el inventario dinámico de Ansible, y es donde se instalará Podman y se realizarán los pasos del rol VM

A continuación se resumen los pasos de cada uno de los roles:

##### Rol ACR
- Se conecta en primera instancia al ACR creado por Terraform, usando como variables la URL, el usuario y la contraseña. 
- Pullea una imágen nueva de Nginx del registry de Docker 
- Crea una nueva imágen, renombrándola con el nombre del registry
- Clona la imágen del repositorio donde se aloja el código custom que se desplegará en AKS
- Buildea el Dockerfile alojado en este repositorio, dándole el nombre y la tag oportuna para subirla a ACR
- Por último pushea ambas imágenes a ACR

##### Rol VM
- Actualiza los repositorios (con permisos de administrador)
- Instala Podman (con permisos de administrador)
- Pullea la imágen desde ACR
- Arranca el servicio con la imágen descargada

##### Rol AKS
- Crea el secreto para poder conectar con ACR (Leyendo de localhost el dockerconfig, donde se aloja el registry y el token de acceso)
- Crea el template para desplegar la aplicación.
- Crea el Volumen Persistente que se conectará al pod
- Crea el Servicio de Load Balancer que escuchará las peticiones desde el exterior al pod

---

## Explicación del Proyecto entregado e hitos en el proceso
A lo largo del ejercicio, he ido encontrando algunos problemas para llegar al punto al que quería llegar, que era la integración de este proyecto con el repositorio de Azure DevOps, para integrar este de manera sencilla con el CI/CD de Pipelines/Releases de esta misma plataforma, y con esta desplegar a los propios servicios de Azure, extendiendo así el rango de expansión de la práctica. 

El primero, que ha sido el que más impedimento me ha supuesto, es que para poder lanzar un Agent en Azure DevOps, este debe tener acceso al AZ-CLI, y para ello necesitaría crear un service principal, pero la licencia de estudiante brindada no permite esto, por lo que lo único posible es automatizarlo con un script ejecutado en local que automatiza todos los pasos a realizar para que la infraestructura pase de 0 a desplegada en un solo click y de manera interactiva.

Para poder desplegar esta práctica desde un equipo local cualquiera, se requieren una serie de dependencias:
- Acceso a una cuenta de Azure con una Suscripción Activa y un Tenant
- Dependencias de software necesarias:
    - Az-cli
    - Terraform
    - Ansible (+módulos mencionados anteriormente)
    - Docker / Podman (El proyecto usa ambas tecnologías, pero el host que lanza la aplicación emplea Docker. Pueden hacerse las modificaciones sencillas en los correspondientes ficheros de configuración de Ansible --***Main.yml del rol AKS y el rol ACR***-- y en el script ejecutable de bash)
    - Kubectl, ya que lo emplearemos para conectar con el cluster AKS
- Darle permisos de ejecución al 



