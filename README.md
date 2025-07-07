# 🛡️ Evaluación y Explotación de Vulnerabilidades en Infraestructura como Código (IaC)

![IaC Security Banner](https://img.shields.io/badge/IaC%20Security-TFM%20Project-blueviolet?style=for-the-badge&logo=terraform)
![Cloud Providers](https://img.shields.io/badge/Cloud%20Providers-AWS%20%7C%20Azure%20%7C%20GCP-orange?style=for-the-badge&logo=amazon&logoColor=white&labelColor=0078D4&color=0078D4)
![Security Tools](https://img.shields.io/badge/Security%20Tools-Checkov%20%7C%20TFSec%20%7C%20Terrascan-informational?style=for-the-badge&logo=python&logoColor=white)

Este repositorio forma parte de un Trabajo de Fin de Máster (TFM) centrado en la **evaluación y explotación de vulnerabilidades en entornos de Infraestructura como Código (IaC)**. Contiene una colección de escenarios Terraform diseñados intencionadamente para ser vulnerables, abarcando una amplia gama de configuraciones inseguras en los principales proveedores de nube: AWS, Azure y Google Cloud Platform (GCP).

## 🚀 Objetivos del Proyecto

El objetivo principal de este proyecto es:

* **Simular y Documentar** configuraciones de IaC comunes que introducen vulnerabilidades de seguridad.
* **Evaluar** la capacidad de detección de herramientas de análisis de seguridad de IaC líderes en la industria (Checkov, TFSec, Terrascan) frente a estos escenarios.
* **Proporcionar una Base de Conocimiento** práctica para comprender y mitigar riesgos en despliegues de infraestructura en la nube.
* **Servir como material de laboratorio** para la formación y la concienciación sobre la seguridad en la nube.

## 📁 Estructura del Repositorio

El repositorio está organizado de la siguiente manera:

.
├── scenarios/
│   ├── aws/
│   │   ├── scenario_01_insecure_storage_aws.tf
│   │   ├── ...
│   │   └── scenario_20_insecure_metadata_aws.tf
│   ├── azure/
│   │   ├── scenario_01_insecure_storage_azure.tf
│   │   ├── ...
│   │   └── scenario_20_insecure_metadata_azure.tf
│   └── gcp/
│       ├── scenario_01_insecure_storage_gcp.tf
│       ├── ...
│       └── scenario_20_insecure_metadata_gcp.tf
└── README.md

Cada carpeta de proveedor (`aws`, `azure`, `gcp`) contiene 20 archivos Terraform (`.tf`), uno para cada escenario de vulnerabilidad. Todas las configuraciones están diseñadas para ser desplegadas en regiones europeas.

## 📝 Escenarios de Vulnerabilidad Implementados

Cada escenario representa una configuración de IaC intencionalmente vulnerable. A continuación se detalla cada uno:

| Nº  | Tipo de Vulnerabilidad                                | Descripción Breve                                                                                               | Proveedores                               | Región Principal |
| :-- | :---------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------- | :---------------------------------------- | :--------------- |
| 1   | Almacenamiento No Cifrado y Acceso Público           | Recursos de almacenamiento (buckets, blobs) sin cifrado en reposo y/o acceso público.                             | AWS S3, Azure Blob, GCP Storage           | Europa           |
| 2   | Acceso a Red - Puertos Abiertos / Servicios Públicos | Grupos de seguridad/Reglas de red que exponen puertos críticos (ej. SSH, RDP, bases de datos) a Internet.        | AWS EC2/SG, Azure VM/NSG, GCP CE/Firewall | Europa           |
| 3   | Exposición de Credenciales Sensibles                  | Credenciales, claves API o secretos codificados directamente en el código Terraform o en variables de entorno.  | AWS IAM, Azure Key Vault, GCP Secret Mgr  | Europa           |
| 4   | Monitorización y Logging Insuficientes                | Falta de configuración de logs de auditoría, logs de flujo de red o monitorización de eventos de seguridad.     | AWS CloudTrail, Azure Log Analytics, GCP Logs | Europa           |
| 5   | Privilegios Excesivos / IAM Insegura                 | Roles/Políticas IAM que otorgan más permisos de los necesarios (principio del mínimo privilegio violado).      | AWS IAM, Azure AD, GCP IAM                | Europa           |
| 6   | Configuración Insegura de Contenedores                | Imágenes de contenedor sin escanear, credenciales en imágenes, puertos expuestos en Kubernetes.                  | AWS ECR/EKS, Azure ACR/AKS, GCP GCR/GKE   | Europa           |
| 7   | Falta de Actualizaciones y Parches / Componentes Obsoletos | Uso de AMIs/Imágenes de VM antiguas o versiones de software sin parches conocidos.                               | AWS EC2, Azure VM, GCP CE                 | Europa           |
| 8   | Falta de Redundancia y Recuperación ante Desastres    | Despliegues en una sola zona de disponibilidad, sin copias de seguridad o planes de recuperación.                  | AWS EC2/RDS, Azure VM/SQL, GCP CE/SQL     | Europa           |
| 9   | Exposición de Datos Sensibles en Outputs              | Datos sensibles (ej. IPs internas, nombres de usuario) expuestos en los `outputs` de Terraform.                 | Todos los proveedores (Outputs)           | Europa           |
| 10  | Falta de Validación de Entradas / Inyección de Código | (Simulado en la intención, más aplicativo, pero IaC que lo permite).                                            | N/A (Más allá del alcance directo de IaC) | Europa           |
| 11  | Configuración Insegura de Bases de Datos              | Bases de datos accesibles públicamente, sin cifrado, sin autenticación robusta o versiones obsoletas.           | AWS RDS, Azure SQL DB, GCP Cloud SQL      | Europa           |
| 12  | Exposición de Servicios de Gestión/APIs a Internet    | Endpoints de APIs o interfaces de gestión (ej. EC2, Web Apps) accesibles públicamente sin restricciones.        | AWS API Gateway, Azure App Service, GCP Cloud Run | Europa           |
| 13  | Configuración Insegura de Redes (ACLs, Rutas)        | Subredes sin aislamiento, tablas de ruteo que dirigen tráfico interno a Internet, Network ACLs permisivas.    | AWS VPC/NACLs, Azure VNet/NSG, GCP VPC/Firewall | Europa           |
| 14  | Uso Inseguro de Servicios Gestionados/PaaS            | Servicios PaaS (ej. App Service, Lambda) con configuraciones predeterminadas inseguras o acceso excesivo.      | AWS Lambda, Azure App Service, GCP Cloud Functions | Europa           |
| 15  | Falta de Gestión de Claves y Certificados             | Uso de certificados caducados, claves débilmente protegidas o ausencia de rotación de claves.                    | AWS ACM/KMS, Azure Key Vault, GCP KMS     | Europa           |
| 16  | Configuración Insegura de Identidades Externas        | Federated Identity con configuraciones que permiten la suplantación o acceso no autorizado.                       | AWS IAM Identity Center, Azure AD B2B/B2C, GCP Identity Platform | Europa           |
| 17  | Uso Inseguro de Servicios Compartidos / Multi-inquilino | Configuración de clústeres (EKS/AKS/GKE) o servicios compartidos que comprometen el aislamiento entre inquilinos. | AWS EKS, Azure AKS, GCP GKE               | Europa           |
| 18  | Configuración Insegura de Seguridad de Borde         | WAF ausente/mal configurado, CDN permitiendo HTTP, exposición de IPs de origen.                                 | AWS WAF/CloudFront, Azure App Gateway/CDN, GCP Cloud Armor/CDN | Europa           |
| 19  | Funciones Sin Servidor / Arquitecturas Basadas en Eventos Vulnerables | Permisos excesivos en funciones serverless, secretos en variables de entorno, triggers inseguros.            | AWS Lambda, Azure Functions, GCP Cloud Functions | Europa           |
| 20  | Exposición de Metadatos de Instancias o Servicios     | VMs exponiendo información sensible (credenciales, datos de usuario) a través de servicios de metadatos o scripts. | AWS EC2 (IMDS), Azure VM (Custom Data), GCP CE (Metadata) | Europa           |

## ⚠️ Advertencia de Seguridad

**¡IMPORTANTE!** Este repositorio contiene código Terraform diseñado **específicamente para ser vulnerable**. Su propósito es educativo y de prueba.

* **NUNCA despliegues estos recursos en un entorno de producción.**
* Utiliza siempre una cuenta de nube dedicada y aislada (sandbox) para tus pruebas.
* Asegúrate de destruir todos los recursos después de usarlos para evitar cargos inesperados y mitigar riesgos.

## 🛠️ Requisitos Previos

Antes de comenzar, asegúrate de tener instaladas y configuradas las siguientes herramientas:

* **Terraform:** [Instalación](https://developer.hashicorp.com/terraform/install) (versión 1.0.0 o superior recomendada).
* **CLI de los proveedores de nube:**
    * **AWS CLI:** [Instalación y Configuración](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    * **Azure CLI:** [Instalación y Configuración](https://learn.microsoft.com/es-es/cli/azure/install-azure-cli)
    * **Google Cloud SDK (gcloud CLI):** [Instalación y Configuración](https://cloud.google.com/sdk/docs/install)
* **Herramientas de análisis de seguridad IaC:**
    * **Checkov:** [Instalación](https://www.checkov.io/2.Concepts/Installation.html) (`pip install checkov`)
    * **TFSec:** [Instalación](https://aquasecurity.github.io/tfsec/latest/getting-started/#installation) (varias opciones disponibles)
    * **Terrascan:** [Instalación](https://terrascan.io/docs/terrascan-getting-started/install/)

Asegúrate de que tus credenciales de CLI para AWS, Azure y GCP estén configuradas correctamente y tengan los permisos necesarios para crear y destruir los recursos especificados.

## 🚀 Cómo Utilizar los Escenarios

Sigue estos pasos para probar y analizar cada escenario:

1.  **Clonar el Repositorio:**
    ```bash
    git clone [https://github.com/tu_usuario/tu_repositorio.git](https://github.com/tu_usuario/tu_repositorio.git)
    cd tu_repositorio
    ```
    *(Reemplaza `https://github.com/tu_usuario/tu_repositorio.git` con la URL real de tu repositorio.)*

2.  **Seleccionar un Escenario:**
    Navega a la carpeta del proveedor y el escenario que deseas probar. Por ejemplo, para el Escenario 1 de AWS:
    ```bash
    cd scenarios/aws/
    ```

3.  **Inicializar Terraform:**
    Una vez dentro de la carpeta del escenario (ej. `scenarios/aws`), inicializa Terraform:
    ```bash
    terraform init
    ```

4.  **Ejecutar Herramientas de Seguridad (¡RECOMENDADO ANTES DE DESPLEGAR!):**
    Ejecuta las herramientas de análisis de seguridad para identificar las vulnerabilidades en el código Terraform *antes* de desplegar la infraestructura.

    * **Checkov:**
        ```bash
        checkov -f scenario_01_insecure_storage_aws.tf
        # O para escanear todos los archivos en la carpeta actual:
        # checkov -d .
        ```
    * **TFSec:**
        ```bash
        tfsec .
        ```
    * **Terrascan:**
        ```bash
        terrascan scan -f scenario_01_insecure_storage_aws.tf -i terraform
        # O para escanear todos los archivos en la carpeta actual:
        # terrascan scan -i terraform -d .
        ```
    * **Nota:** Ajusta el nombre del archivo (`scenario_01_insecure_storage_aws.tf`) según el escenario que estés probando.

5.  **Revisar el Plan de Terraform (¡CRÍTICO!):**
    Siempre revisa el plan de ejecución de Terraform para entender qué recursos se crearán y si hay alguna alerta.
    ```bash
    terraform plan
    ```
    **¡Verifica cuidadosamente los `outputs` si están presentes, ya que podrían revelar información sensible!**

6.  **Aplicar el Escenario (Desplegar la Infraestructura Vulnerable):**
    Si estás seguro de entender los riesgos y deseas desplegar la infraestructura vulnerable para propósitos de prueba y explotación controlada, procede con:
    ```bash
    terraform apply --auto-approve
    ```
    **Recuerda:** Esto creará recursos en tu cuenta de nube que son intencionalmente inseguros.

7.  **Explorar y Explotar (Opcional, con precaución):**
    Una vez desplegado, puedes intentar acceder a los recursos o explotar las vulnerabilidades para entender mejor su impacto. Utiliza las IPs o nombres de host proporcionados en los `outputs` de Terraform.

8.  **Destruir los Recursos (¡MUY IMPORTANTE!):**
    Para evitar costos y riesgos de seguridad, **siempre destruye los recursos después de tus pruebas.**
    ```bash
    terraform destroy --auto-approve
    ```

9.  **Limpiar el Directorio:**
    Elimina los archivos de Terraform generados localmente:
    ```bash
    rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup .
    ```

## ⚠️ Consideraciones Adicionales

* **Sustituye Placeholders:** Algunos archivos Terraform (especialmente los de GCP) pueden contener placeholders como `"your-gcp-project-id"`. Asegúrate de reemplazarlos con tus valores reales antes de ejecutar `terraform init` o `terraform apply`.
* **Gestión de Costos:** Los recursos en la nube incurren en costos. La destrucción oportuna es crucial.
* **Ambiente de Pruebas:** Idealmente, realiza estas pruebas en una suscripción, proyecto o cuenta de nube completamente aislada y desechable.

---

Este proyecto es una contribución a la comunidad de seguridad en la nube y un punto de partida para una investigación más profunda en la detección y mitigación de vulnerabilidades de IaC.

**¡Felices pruebas y aprendizaje seguro!**

---