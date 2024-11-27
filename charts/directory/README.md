# Directory Helm Chart

This chart installs the Aserto multi-tenant Directory service. It is backed by a Postgres database
and provides central management of authorization models and data.
Topaz instances can be configured to sync data from a specific tenant or to evaluate requests
in the central directory itself, without a local copy.


## Requirements

### Helm

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/intro/install) to get started.

Full OCI support is available starting from Helm v3.8.0. If you are using an older version,
follow Helm's [instructions](https://helm.sh/docs/topics/registries/) on how to enable OCI


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

The directory service require several secrets to be created in the kubernetes namespace to
which the service is deployed. The examples in the sections below use the `aserto` namespace.
To create the namespace, use:

```shell
kubectl create namespace aserto
```

#### Database Credentials

The database credentials must be stored in a Kubernetes secret in the same namespace as the
directory deployment. The secret must have two keys: `username` and `password`.

For example, if deploying to the `aserto` namespace, a secret named `pg-ds-credentials`can be
created using:

```shell
kubectl create secret generic pg-ds-credentials \
  --namespace aserto \
  --from-literal=username=<username> \
  --from-literal=password=<password>
```

Where `<username>` and `<password>` are database role credentials.


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

### SSH Keys

The directory service exposes a management endpoint over SSH. The management endpoint is used,
among other things, to initialize the root directory database.
The directory chart can be configured with one or more SSH public keys to be granted access to
the management endpoint.

If you don't already have an SSH key, you can follow [these instructions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key)
to create one.


## Configuration

Configuring a deployment is done using a `values.yaml` file that can be passed as an argument to
`helm install`, or embedded in your own chart's `values.yaml` if you are using the Aserto chart
as a dependency.

The main configuration options are discussed below. Take a look at [values.yaml](https://github.com/aserto-dev/helm/blob/main/charts/directory/values.yaml)
for a full view of available options.


### Image

The directory service is a part of Aserto's commercial offering and the service container image
is not available publicly.
If your GitHub account has been granted access to the image you can proceed in one of two ways.

If you have a private OCI registry that your Kubernetes cluster can access, you can pull the
directory image using your GitHub credentials, push it your registry, and use it from there.
In your `values.yaml` file, point the `image.repository` to your local registry. For example:
```yaml
image:
  repository: my.registry.com/my-repo/directory
  # Optionally override the image tag. The default is the chart appVersion.
  # tag: x.y.z
```

If you'd prefer to pull the Aserto image directly from your Kubernetes cluster you can create an
[Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic)
with the `read:packages` scope. Store the token in a Kubernetes secret of type `docker-registry`
in the same namespace you plan to deploy the directory into. For example, if you are deploying to
the `aserto` namespace, you can create a secret named `ghcr-creds` by replacing `<username>` and
`<access_token>` below with your GitHub user and access token.

```sh
kubectl create secret docker-registry ghcr-creds \
    --docker-server=https://ghcr.io --docker-username=<username> --docker-password=<access_token> -n directory
```

In your `values.yaml` file add the secret name to `imagePullSecrets`:
```yaml
imagePullSecrets:
  - name: ghcr-creds
```

### SSH Keys

At least one admin key must be configured under `sshAdminKeys`:
```yaml
sshAdminKeys: |
  ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABg... admin@acme.com
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... another_admin@acme.com
```

### Database

The directory service uses two Postgres databases, an internal "root" directory used to authorize access to the
directory itself and other Aserto services, and a "tenant" directory where data owned by directory tenants
are stored. The two database can run on the same Postgres instance or on separate ones.

[See above](#databases-and-roles) on how to set up the databases and create Kubernetes secrets with
credentials.

Then configure the databases in `rootDirectory.database` and `tenantDirectory.database`:

```yaml
rootDirectory:
  database:
    host: <hostname>  # hostname of the Postgres instance to be used for the root directory.
    sslMode: require  # set to 'disable' if the database doesn't use TLS.
    admin:
      credentialsSecret: <secret-name>  # name of k8s secret with the db credentials

tenantDirectory:
  database:
    host: <hostname>  # hostname of the Postgres instance to be used for the tenant directory.
    sslMode: require  # set to 'disable' if the database doesn't use TLS.
    admin:
      credentialsSecret: <secret-name>  # name of k8s secret with the db credentials
```
