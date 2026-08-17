# infra

One-time cluster bootstrap, applied by hand (not CI) — `ingress-nginx` and `cert-manager` are already installed on `rosetraviss-lon1`. What's left needs live credentials I shouldn't be the one entering, so these are for you to run directly.

## 1. Cloudflare API token → cert-manager

Create a token at [Cloudflare → My Profile → API Tokens](https://dash.cloudflare.com/profile/api-tokens) scoped to **Zone : DNS : Edit** for the zones this cluster will issue certs for (`makersmap.co.uk`, `cornwallhairdressers.co.uk`, and whatever domain jpmc-tech eventually gets). You may already have a suitable one at `~/.kiln_cf_token` — check its scope covers DNS edit on all three zones before reusing it; mint a fresh one scoped to exactly these zones if not.

```bash
kubectl create secret generic cloudflare-api-token \
  -n cert-manager \
  --from-literal=api-token=<paste-token-here>

kubectl apply -f infra/cluster-issuer.yaml

# Confirm it's ready (should flip to True within a few seconds — no
# certificate has been requested yet, this just checks the issuer itself
# can reach Cloudflare's API):
kubectl get clusterissuer letsencrypt-cloudflare -o wide
```

The `email:` in `cluster-issuer.yaml` is currently a placeholder (`admin@rosetraviss.uk`) — change it to whatever address should receive Let's Encrypt expiry notices before applying, if different.

## 2. DIGITALOCEAN_ACCESS_TOKEN → GitHub Actions

Every app's deploy workflow calls into this repo's reusable `deploy.yml`, which needs a DO API token to push images and run `helm upgrade`. I don't have org-admin on `Data-Torturing-Solutions` (confirmed — `gh secret list --org` 403s), and this isn't something to hand off through me either way.

Reuse your existing doctl token, or mint a fresh one scoped for CI at [DigitalOcean → API → Tokens](https://cloud.digitalocean.com/account/api/tokens):

```bash
# Org-level — covers vertical-kiln, vertical-pasty, platform-charts
gh secret set DIGITALOCEAN_ACCESS_TOKEN --org Data-Torturing-Solutions

# Personal account has no org-level secrets — set it on jpmc-tech directly
gh secret set DIGITALOCEAN_ACCESS_TOKEN --repo rosetraviss/jpmc-tech
```

Both prompt for the value on stdin (or pipe it in) rather than taking it as a visible argument.

## Reference

- Load balancer external IP (what DNS records will eventually point at): `143.198.242.24`
- `ingress-nginx-values.yaml` — PROXY protocol + Cloudflare real-IP trust + Server header stripping
- `cluster-issuer.yaml` — the shared ACME issuer every app's Ingress references via `cert-manager.io/cluster-issuer`
