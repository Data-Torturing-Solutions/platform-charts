# platform-charts

Shared deployment platform for small apps on the `rosetraviss-lon1` DOKS cluster — the deployment counterpart to [`meta`](https://github.com/Data-Torturing-Solutions/meta)'s monitoring role.

## What's here

- **`charts/app-base`** — one Helm chart every app instantiates via its own `deploy/values.yaml`. Covers Deployment (+ optional sidecar containers), Service, Ingress (with per-path-group annotations, e.g. basic-auth on an admin path), PVC, ConfigMap, and CronJobs.
- **`.github/workflows/deploy.yml`** — a reusable `workflow_call` workflow every app repo calls: build → push to GHCR → `helm upgrade --install --atomic`.

## Onboarding a new app

1. Containerize it (Dockerfile in the app repo).
2. Write `deploy/values.yaml` in the app repo, overriding `charts/app-base/values.yaml`'s defaults.
   **If you set `persistence.enabled: true`, do not also declare `volumeMounts` for
   `persistence.mountPath`.** The chart already mounts the PVC there in the primary
   container and in every cronjob, then appends `.Values.volumeMounts` on top;
   declaring it again gives duplicate entries and server-side apply rejects the whole
   release with `duplicate entries for key [mountPath=...]`.
3. Add a workflow to the app repo that calls this repo's `deploy.yml` with `secrets: inherit`:

   ```yaml
   name: Deploy
   on:
     push:
       branches: [main, master]
   jobs:
     deploy:
       uses: Data-Torturing-Solutions/platform-charts/.github/workflows/deploy.yml@master
       with:
         app_name: my-app
         namespace: app-my-app
       secrets: inherit
   ```

4. Bootstrap the namespace's Secret once by hand (`kubectl create secret generic <app>-secrets -n app-<x> --from-env-file=...`) — GitHub Actions never sees secret values, only RBAC over workload resources.

## Releasing a new chart version

```bash
helm lint charts/app-base
helm package charts/app-base
helm push app-base-X.Y.Z.tgz oci://ghcr.io/data-torturing-solutions/charts
```

Bump `version` in `charts/app-base/Chart.yaml` first, and the `chart_version` input in whichever app workflows should pick it up.
