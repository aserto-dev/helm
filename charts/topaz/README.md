# Topaz Helm Chart

[Topaz](https://www.topaz.sh) is an open source authorization service providing fine grained, real-time,
policy based access control for applications and APIs.

The topaz chart is used to deploy instances of the topaz authorizer to a Kubernetes cluster.
A topaz instance can run standalone or connect to a control plane hosted by Aserto or self-hosted
in your own cluster.
Use the [aserto chart](https://github.com/aserto-dev/helm/blob/main/README.md) to deploy a self-hosted
control plane.


## Requirements

### Helm

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/intro/install) to get started.

Full OCI support is available starting from Helm v3.8.0. If you are using an older version,
follow Helm's [instructions](https://helm.sh/docs/topics/registries/) on how to enable OCI
registries.


## Usage

Create a `values.yaml` file with your configuration. The [default values](https://github.com/aserto-dev/helm/blob/main/charts/topaz/values.yaml)
provide a good starting point. A minimal configuration that deploys a Topaz instance using a policy from a publicly
accessible OCI repository is shown below:

```yaml
opa:
  policy:
    oci:
      registry: https://ghcr.io
      image: ghcr.io/aserto-policies/policy-rebac:latest
```

To deploy the chart to a `topaz` namespace in your Kubernetes cluster creating the namespace if it doesn't exist, run:

```shell
helm install topaz oci://ghcr.io/aserto-dev/helm/topaz -f values.yaml --namespace topaz --create-namespace
```

To use the Topaz chart as a subchart within your own parent chart, add it as a dependency in your `Chart.yaml`:

```yaml
dependencies:
  - name: topaz
    version: ~0.1.0
    repository: oci://ghcr.io/aserto-dev/helm
```

Configuring Topaz in the parent chart's `values.yaml` is similar to standalone configuration with one difference:
all configuration elements are nested under the `topaz` key:

```yaml
topaz:
  opa:
    policy:
      oci:
        registry: https://ghcr.io
        image: ghcr.io/aserto-policies/policy-rebac:latest
```


## Configuration

The default [values.yaml](https://github.com/aserto-dev/helm/blob/main/charts/topaz/values.yaml)
is a good starting point for configuring topaz.

The following sections describe the various configuration options available in the chart.

* [Policy Configuration](#policy-configuration)
  * [Policy Image](#policy-image)
  * [Discovery](#discovery)
  * [Persistence](#persistence)
* [Directory](#directory)
  * [Edge Directory](#edge-directory)
  * [Edge Sync](#edge-sync)
  * [Remote Directory](#remote-directory)
* [Controller](#controller)
* [Decision Logs](#decision-logs)
  * [Local File](#local-file)
  * [Remote](#remote)
* [Service Ports](#service-ports)
* [Authentication](#authentication)


## Policy Configuration

Topaz is built on top of the [Open Policy Agent](https://www.openpolicyagent.org) (OPA) and uses
it to evaluate authorization poicies. The `opa` section of `values.yaml` is used to configure OPA.
There are two ways to specify the poilcy to use:
1. By configuring topaz with a policy image stored in an OCI registry.
2. By pointing topaz to a discovery service that provides it with the necessary configuration options.
   When using discovery, topaz periodically polls the service for updates to the policy and/or OPA
   plugins.

> [!IMPORTANT]
> Explicitly specifying a policy image and using a discovery service are mutually exclusive. If discovery
> configuration is provided, the `oci` section is ignored.

### Policy Image

You can configure topaz to use a policy image stored in an OCI registry using the `opa.policy.oci` section.
At a minimum, you must specify the registry URL and full URI of the policy image to use.

```yaml
opa:
  policy:
    oci:
      registry: https://ghcr.io
      image: ghcr.io/aserto-policies/policy-rebac:latest
```

If the image is stored in a private repository, you must also provide credentials to access it.
An API key or token is always required and, depending on the registry, you may also need to provide
a user name.
There are three ways to provide an API key:

1. Plain text in `values.yaml`:
```yaml
opa:
  policy:
    oci:
      registry: https://ghcr.io
      image: ghcr.io/aserto-policies/policy-rebac:latest
      apiKey: "<api key or token>"
```

2. Using the `--set` option when installing/upgrading the chart:
```shell
helm install ... --set opa.policy.oci.apiKey="<api key or token>"
```

3. Using a kubernetes secret:
```yaml
opa:
  policy:
    oci:
      registry: https://ghcr.io
      image: ghcr.io/aserto-policies/policy-rebac:latest
      apiKeySecret:
        name: "<name of the kubernetes secret>"
        key: "<key within the secret (default: 'api-key')>"
```

### Discovery

Configuration for a discovery service is done in the `opa.policy.discovery` section.
The discovery service requires an API key which can be provided in the same ways as for an OCI registry:
within `values.yaml`, using the `--set` option, or in a kubernetes secret.

```yaml
opa:
  policy:
    discovery:
      url: https://discovery.prod.aserto.com/api/v2/discovery
      policyName: my-policy
      tenantID: df61e407-cb84-491d-8a0c-942a68ba9f26
      apiKey: "<discovery api key>"
```

> [!TIP]
> When using the hosted Aserto control plane, the discovery service URL and API key can be found in the
> [Aserto console](https://console.aserto.com) by navigating to the _Connections_ page and expanding
> the _Aserto Discovery_ connection.

### Persistence

For higher availability and faster restart times, you can configure topaz to store discovery responses
and downloaded policy images in a persistent volume.

```yaml
opa:
  persistence:
    enabled: true
```

A 10MB volume is created by default but you can optionally specify the size and storage class:
```yaml
opa:
  persistence:
    enabled: true
    storage: 20Mi
    storageClassName: "<name of storage class>"
```

See [here](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims) for
more information on persisten volume claims.


## Directory

The `directory` section of `values.yaml` is used to configure the directory service that topaz uses to
store and manage its data.
By default, topaz run a local (edge) directory which can optionally be configured to sync data from a
central directory. Alternately, you can configure topaz to not run a local directory at all and instead
connect to a remote directory.

> [!IMPORTANT]
> If configuration is provided for both edge and remote directories, topaz will use the remote directory.
> Configuration of the edge directory is ignored in this case.

### Edge Directory

The edge directory is a set of data-access services that run as part of topaz. The `model` and `reader`
services are always enabled when running an edge directory. The `writer`, `importer`, and `exporter` are
enabled by default but can be disabled if not needed.
For example, to only enable the `importer` service:

```yaml
directory:
  edge:
    services:
      - importer
```

Data is stored in a 1GB persistent volume by default. You can configure the size and storage class similar
to the OPA persistent volume configuration [above](#persistence).

```yaml
directory:
  edge:
    persistence:
      enabled: true
      storage: 2Gi
      storageClassName: "<name of storage class>"
```

### Edge Sync

The edge directory can be configured to sync data from a central directory. This is done by setting the
`directory.edge.sync` section in `values.yaml`.

```yaml
directory:
  edge:
    sync:
      address: directory.prod.aserto.com:8443
      tenantID: df61e407-cb84-491d-8a0c-942a68ba9f26
      apiKey: "<directory (read-only) API key>"
      # Skip verification of remote TLS certificate
      skipTLSVerification: false
      # The frequency of syncs in minutes.
      intervalMinutes: 1
```

> [!TIP]
> When using the hosted Aserto control plane, the directory API key can be found in the
> [Aserto console](https://console.aserto.com) by navigating to the _Connections_ page and expanding
> the _Aserto Directory_ connection.


### Remote Directory

An alternative to syncing a local edge directory from a remote, is to directly call the remote directory
when topaz needs to access data. This is done by setting the `directory.remote` section in `values.yaml`.

```yaml
directory:
  remote:
    address: directory.prod.aserto.com:8443
    tenantID: df61e407-cb84-491d-8a0c-942a68ba9f26
    apiKey: "<directory (read-only) API key>"
```


## Controller

Topaz can optionally connect to a control plane allowing administrators to remotely force policy updates
and trigger directory syncs. The `controller` section of `values.yaml` is used to configure the connection
to the control plane.

> [!NOTE]
> Before configuring the controller, you must create an _Edge Authorizer_ connection in the Aserto console
> and obtain the connection's mutual-TLS certificate and private key.
> See [here](https://docs.aserto.com/docs/edge-authorizers/security-and-management) for detailed instructions.

```yaml
controller:
  enabled: true
  address: relay.prod.aserto.com:8443
  mtlsCert: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  mtlsKey: |
    -----BEGIN RSA PRIVATE KEY-----
    ...
    -----END RSA PRIVATE KEY-----
  # [Optional] Kubernetes secret containing the mTLS client certificate and private key.
  # Must be a secret of type kubernetes.io/tls.
  mtlsCertSecretName: ""
```

Similar to other sensitive information, the mTLS certificate and private key can also be provided
in a kubernetes secret of type `kubernetes.io/tls`.


## Decision Logs

Topaz can be configured to record a log of all authorization decisions it makes.
Decision logs can be written to a local file or shipped to a remote service.

> [!IMPORTANT]
> If configuration is provided for both local and remote decision logging, topaz will use the remote configuration.
> Local file configuration is ignored in this case.

### Local File

To log decisions to a local file, set the `decisionLogs.enabled` section in `values.yaml`.

```yaml
decisionLogs:
  enabled: true
```

Logs are written to the `/decisions` directory in the topaz pod. The directory is backed by a
100MB persistent volume by default. You can configure the size and storage class similar to the
OPA persistent volume configuration [above](#persistence).

```yaml
decisionLogs:
  persistence:
    enabled: true
    storage: 200Mi
    storageClassName: "<name of storage class>"
```

You can also configure the maximus size of a single log file and the number of log files to keep.

```yaml
decisionLogs:
  file:
    maxFileSizeMB: 10
    maxFileCount: 10
```

### Remote

When a remote decision log service is used, topaz accumulates decisions in local files and periodically
ships them to the remote service in batches. In that case, the local `/decisions` directory is used as
the spool space for decisions waiting to be shipped. It is backed by a 100MB persistent volume by default
but the size and storage class can be configured similar to the OPA persistent volume configuration
[above](#persistence).

Authentication to the remote service is done using mutual-TLS, similar to the [controller](#controller).
The same certificate and private key can be used for both services.

```yaml
decisionLogs:
  remote:
    scribe:
      address: ems.prod.aserto.com:8443
      tenantID: df61e407-cb84-491d-8a0c-942a68ba9f26
      mtlsCert: |
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
      mtlsKey: |
        -----BEGIN RSA PRIVATE KEY-----
        ...
        -----END RSA PRIVATE KEY-----
      # [Optional] Kubernetes secret containing the mTLS client certificate and private key.
      # Must be a secret of type kubernetes.io/tls.
      mtlsCertSecretName: ""
      # [Optional] Duration (in seconds) to wait for a batch of decisions to be acknowledged by the server.
      # If the server does not acknowledge the batch within this time, the batch is resent.
      ackWaitSec: 60
```

## Service Ports

Topaz pods expose the following ports:

| Protocol | Default Port | Description |
|----------|--------------|-------------|
| gRPC     | 8282         | gRPC services |
| HTTPS    | 8383         | REST endpoints and web console |
| Health   | 8484         | gRPC [health service](https://github.com/grpc/grpc/blob/master/doc/health-checking.md) |
| Metrics  | 8585         | Prometheus metrics [optional, enabled by default] |
| Profiler | 8686         | Profiler service [optional, disabled by default] |

The default ports can be overridden in `values.yaml`:

```yaml
ports:
  grpc: 8282
  https: 8383
  health: 8484
  metrics: 8585
  profiler: 8686
```

The metrics service can be disabled if not needed:

```yaml
metrics:
  enabled: false
```

The profiler service can be enabled using:
```yaml
profiler:
  enabled: true
```

## Authentication

By default, anyone with access to the topaz pod can use the gRPC and REST endpoints. That means that any
service or job running in the same kubernetes cluster can access topaz.
To restrict access, you can configure topaz to require an API key for all service endpoints.
Multiple API keys can be configured making it possible to rotate keys without service interruption and to
provide separate keys for different clients.

API keys are configured in the `auth` section of `values.yaml` and can be provided explicitly or using
Kubernetes secrets.

```yaml
auth:
  apiKeys:
    - key: "<plaintext API key>"
    - secretName: "<name of a kubernetes secret>"
      secretKey: "<key within the secret>"
```

When one or more API keys are configured, clients must provide a key in the `Authorization` header of
all requests using the `Basic` scheme. For example, if port 8383 is forwarded from the topaz pod, you
can list all policy modules using:

```shell
curl -k -H "Authorization: Basic <api-key>" https://localhost:8383/api/v2/policies
```

## TLS

By default, the topaz gRPC and HTTP services run without TLS. To enable TLS you must provide certificates
for the services.
Certificates are read from Kubernetes secrets of type `kubernetes.io/tls` defined in the `tls` section
of `values.yaml`:

```yaml
tls:
  grpc: "<name of secret with gRPC certificate>"
  https: "<name of secret with HTTPS certificate>"
```
