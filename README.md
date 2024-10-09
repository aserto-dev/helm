# Aserto Helm Charts

> [!NOTE]
> The documentation below discusses self-hosted deployment of the Aserto backend services.
> [See here](https://github.com/aserto-dev/helm/tree/main/charts/topaz) if you are
> looking to deploy a [topaz](https://www.topaz.sh) authorizer in your Kubernetes cluster.

[Aserto](https://www.aserto.com) is a cloud-native authorization service that provides
fine-grained access control for your applications.

An Aserto deployment consists of multiple services that can be deployed separately or together.
In addition to individual service charts, `aserto` is an umbrella chart that can be used to
configure and deploy all the services at once.

The charts are published to the `ghcr.io/aserto-dev/helm` OCI registry and
can be used directly from there or by adding them as dependencies to your own charts.


## Requirements

### Helm

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/intro/install) to get started.

Full OCI support is available starting from Helm v3.8.0. If you are using an older version,
follow Helm's [instructions](https://helm.sh/docs/topics/registries/) on how to enable OCI
registries.


### PostgreSQL

The Aserto directory service requires a PostgreSQL database to store its data.
You can deploy a PostgresSQL instance using the
[Bitnami chart](https://bitnami.com/stack/postgresql/helm) or use a managed PostgreSQL
from your cloud provider.


#### Databases and Roles

The directory service uses two database that can run on the same or different PostgreSQL
instances. The database are named `aserto-ds` and `aserto-root-ds` by default but the
names are configurable.

When both databases are on the same PostgreSQL instance, the service can be configured to
connect to both using the same role or different ones. In either case, each role must
be the owner of the database it connects to and have the `CREATEROLE` option.
Additionally, if the role has the `CREATEDB` option, the service can create the databases
automatically at startup if they don't already exist.

Without the `CREATEDB` option, you must create the databases manually before deploying the chart.
The following SQL commands can be used to create the roles and databases:

```sql
CREATE ROLE aserto_root CREATEROLE LOGIN PASSWORD '<password>';
CREATE ROLE aserto_tenant CREATEROLE LOGIN PASSWORD '<password>';

CREATE DATABASE "aserto-root-ds" OWNER = aserto_root TEMPLATE = template0;
CREATE DATABASE "aserto-ds" OWNER = aserto_tenant TEMPLATE = template0;
```

### Kubernetes Secrets

The Aserto services require several secrets to be created in the kubernetes namespace to
which the services are deployed. The examples in the sections below use `aseerto`.
To create the namespace, use:

```shell
kubectl create namespace aserto
```

#### Database Credentials

The database credentials must be stored in a Kubernetes secret in the same namespace as the
Aserto chart. The secret must have two keys: `username` and `password`.

For example, if deploying to the `aserto` namespace, a secret named `pg-ds-credentials`can be
created using:

```shell
kubectl create secret generic pg-ds-credentials \
  --namespace aserto \
  --from-literal=username=aserto \
  --from-literal=password=<password>
```

#### Image Pull Secret

The Aserto images are stored in a private registry and require an access token to be stored in
a kubernetes secret for the cluster to be able to pull them.
To create a token, log into your GitHub account that was granted acccess to the Aserto registry,
follow [these instructions](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
and include the `read:packages` scope.

The token must then be stored in a Kubernetes secret in the same namespace as the Aserto chart:

```shell
kubectl create secret docker-registry ghcr-creds \
  --namespace aserto \
  --docker-server=https://ghcr.io \
  --docker-username=<github username> \
  --docker-password=<access token>
```

#### Policy Registry Credentials

The discovery service requires read access to the container registry where your policies are stored.
This can be any OCI registry such as ghcr.io, DockerHub, or a private registry.

First, create a read-only access token in the registry you plan to use. The details differ from
one registry to another, so consult your registry's documentation.

The token must be stored in a Kuebernetes secret in the same namespace as the Aserto chart:

```shell
kubectl create secret generic discovery-ghcr-token \
    --namespace aserto \
    --from-literal=token=<access token>
```

### OpenID Connect

Authentication to the Aserto management console is done using OpenID Connect. Creating an OIDC
application differs from one identity provider to another. Consult your provider's documentation
to create an application with the users that need access to the Aserto console.


## Configuration

Configuring a deployment is done using a `values.yaml` file that can be passed as an argument to
`helm install`, or embedded in your own chart's `values.yaml` if you are using the Aserto chart
as a dependency.

The top-level sections in the `values.yaml` file are:

- `global`: configuration values shared by all Aserto services. These can also be overridden
  by individual service settings.
- `directory`: configuration values for the directory service.
- `authorizer`: configuration values for the multi-tenant authorizer service.
- `discovery`: configuration values for the discovery service.
- `console`: configuration values for the management console.
- `scim`: configuration values for the SCIM service.

The `aserto` umbrella chart's [values.yaml](charts/aserto/values.yaml) file documents the available
options.

To use the chart as a dependency in your own chart, add the following to the parent chart's `Chart.yaml`:
```yaml
dependencies:
  - name: aserto
    version: ~0.1.6
    repository: oci://ghcr.io/aserto-dev/helm

```
Then run `helm dep update` to download the chart and its dependencies.

When using the `aserto` chart as a dependency the parent's `values.yaml` file should
keep the `global` values in place but move the other values into the `aserto` section.
For example:
```yaml
global:
  aserto:
    ports:
      grpc: 8282
      https: 8383
      health: 8484
      mertics: 8585
    ...

aserto:
  directory:
    rootDirectory:
      database:
        port: 5432
        ...
```

### Directory Management Service

The directory service exposes a management endpoint that is used, among other things, to initialize
its internal database. The management endpoint authenticates using SSH keys.
In order to be able to connect, you must provide at least one public key in the `directory.sshAdminKeys`
value of the `values.yaml` file.

Example:
```yaml
...
directory:
  sshAdminKeys: |
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABg... admin@acme.com
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... another_admin@acme.com
...
```


## Deployment

To deploy the Aserto services, first create a `values.yaml` file with the desired configuration.
A good starting point is the default [values.yaml](charts/aserto/values.yaml). You must provide
values for several required fields:

- `global.aserto.oidc` holds the domain and client ID for your OpenID Connect application used
  to authenticate access to the management console.
- `global.aserto.https.allowed_origins` should include the ingress domain where the management console
  will be hosted.
- `diretcory.rootDirectory.database.host` and `directory.tenantDirectory.database.host` should be set
  to the hostname of the PostgreSQL instance(s) for the root and tenant directories.
- `discovery.registries` must include configuration for at least one policy registry with the Kubernetes
  secret that holds the access token.
- `console.authorizerURL` and `console.directoryURL` should be set to the ingress URLs of the authorizer
  and directory services.

Deploy the chart in a release called `aserto` using:

```shell
helm install aserto oci://ghcr.io/aserto-dev/helm/aserto -f values.yaml
```

### Directory Initialization

Once the services are deployed and running, you'll need to initialize the root directory used internally
to authorize access to all other services. This is done by connecting to the directory service's management
endpoint and running the `provision-root-keys` command.

To connect to the management endpoint, you must first port-forward the management service to your local machine:

```shell
kubectl --namespace <namespace> port-forward \
  $(kubectl get pods --namespace <namespace> \
    -l "app.kubernetes.io/name=directory,app.kubernetes.io/instance=<release>" \
    -o jsonpath="{.items[0].metadata.name}") 2222:2222
```

Substitute `<namespace>` with the Kubernetes namespace where the Aserto services are deployed and `<release>` with the
name of the Helm release (as listed in `helm list -n <namespace>`).

For example, if the namespace and release are both `aserto`:
```shell
kubectl --namespace aserto port-forward \
  $(kubectl get pods --namespace aserto \
    -l "app.kubernetes.io/name=directory,app.kubernetes.io/instance=aserto" \
    -o jsonpath="{.items[0].metadata.name}") 2222:2222
```

This forward port 2222 on your local machine to the directory service's management endpoint.

In another terminal, run the `provision-root-keys` command using one of the SSH keys provided in the `values.yaml` file
under `directory.sshAdminKeys`. For example:

```shell
ssh -p 2222 -i <private key path> localhost provision-root-keys
```

If you added your default SSH key (`~/.ssh/id_*.pub`) to `directory.sshAdminKeys`, you can omit the `-i` option:

```shell
ssh -p 2222 localhost provision-root-keys
```
