# Open
[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/epitaph-04/concourse-helm-resource)

# Helm Resource for Concourse

![Docker Build Status](https://img.shields.io/docker/build/epitaph/concourse-helm-resource.svg?style=popout)

Install a [Helm chart](https://github.com/kubernetes/helm) to a generic Kubernetes cluster from [Concourse](https://concourse.ci/)

cluster
- Native Helm `--wait` flag is used to determine the job's status
- Support for TLS-authenticated Tiller via `ca_cert`, `client_cert`, `client_key`

### Components

| Component | Version |
| --- | --- |
| `helm` | 3.2.4 |
| `kubectl` | 1.18.3 |

## Add resource type to pipeline

Add the resource type to your pipeline:

```yaml
resource_types:
- name: helm
  type: docker-image
  source:
    repository: epitaph/concourse-helm-resource
    tag: latest
```


## Source Configuration

### Authentication

Authentication can be done either through a kubeconfig file or using GCP service account key:

* `kubeconfig`: *Required

### Optional values

* `release`: *Optional if provided in parameter section.* Name of the release (not a file, a string).
* `namespace`: *Optional.* Kubernetes namespace the chart will be installed into. (Default: release name)
* `repos`: *Optional.* Array of Helm repositories to initialize, each repository is defined as an object with `name` and `url` properties.
* `ca_cert`: *Optional* Cert to verify Tiller's server certificate.
* `client_cert`: *Optional* Helm's client certificate for authenticating to Tiller.
* `client_key`: *Optional* Helm's private key for authenticating to Tiller.

## Behavior

### `check`: Check for new releases

Any new revisions to the release are returned, no matter their current state. The release must be specified in the
source for `check` to work.

### `in`

Not Supported

### `out`: Deploy the helm chart

Deploys a Helm chart onto the Kubernetes cluster. Tiller must be already installed
on the cluster.

#### Parameters

* `chart`: *Required.* Either the file containing the helm chart to deploy (ends with .tgz) or the name of the chart (e.g. `stable/mysql`).
* `release`: *Required.* File containing the name of the release. (Default: taken from source configuration).
* `values`: *Optional.* File containing the values.yaml for the deployment. Supports setting multiple value files using an array.
* `override_values`: *Optional.* Array of values that can override those defined in values.yaml. Each entry in
  the array is a map containing a key and a value or path. Value is set directly while path reads the contents of
  the file in that path. A `hide: true` parameter ensures that the value is not logged and instead replaced with `***HIDDEN***`
* `version`: *Optional* Chart version to deploy. Only applies if `chart` is not a file.
* `delete`: *Optional.* Deletes the release instead of installing it. Requires the `name`. (Default: false)
* `replace`: *Optional.* Replace deleted release with same name. (Default: false)
* `devel`: *Optional.* Allow development versions of chart to be installed. This is useful when wanting to install pre-release
  charts (i.e. 1.0.2-rc1) without having to specify a version. (Default: false)
* `wait_until_ready`: *Optional.* Set to the number of seconds it should wait until all the resources in
    the chart are ready. (Default: `0` which means don't wait).
* `force`: *Optional.* This flag will cause all pods to be recreated when upgrading. (Default: false)


## Example

Full example pipeline: <https://github.com/ilyasotkov/concourse-pipelines/blob/master/pipelines/gitlab-flow-semver.yml>

### Out

Define the resource:

```yaml
resources:
- name: helm-release
  type: helm
  source:
    kubeconfig: |
      apiVersion: v1
      kind: Config
      preferences: {}
      contexts:
      - context:
          cluster: development
          namespace: ramp
          user: developer
        name: dev-ramp-up
    repos:
      - name: some_repo
        url: https://somerepo.github.io/charts
```
Add to job:

```yaml
jobs:
  # ...
  plan:
  - put: release-app
    params:
      chart: source-repo/chart-0.0.1.tgz
      values: source-repo/values.yaml
      release: test
      override_values:
      - key: replicas
        value: 2
      - key: version
        path: version/number
      - key: secret
        value: ((my-top-secret-value))
        hide: true # Hides value in output
```
