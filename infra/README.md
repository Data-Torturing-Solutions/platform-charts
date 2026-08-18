# infra

One-time cluster bootstrap for `rosetraviss-lon1`, applied by hand (not CI). `ingress-nginx`, `cert-manager`, and `external-dns` are installed and live.

## Status

- ✅ Cloudflare API token (`cloudflare-api-token` secret in `cert-manager`) — `ClusterIssuer letsencrypt-cloudflare` confirmed `Ready=True`, issuing real certs.
- ✅ `DIGITALOCEAN_ACCESS_TOKEN` — set at the `Data-Torturing-Solutions` org level (visibility: private repos). jpmc-tech was transferred into the org, so it inherits this too — no separate per-repo secret needed anymore.
- ✅ `external-dns` — reconciles Cloudflare DNS from Ingress hostnames automatically. See below.

## external-dns

Watches every Ingress in the cluster and creates/updates the matching Cloudflare A record — no more manually adding DNS records per app. **upsert-only policy, deliberately**: this Cloudflare account holds DNS for ~50 other properties outside this cluster, so it never deletes anything, even when a host is removed from an app's `values.yaml`. Scoped with `domainFilters` to only the zones actually in play; add a domain there when a new app gets a real hostname.

Reuses the same Cloudflare token already in `cert-manager`, copied into its own namespace:
```bash
kubectl get secret cloudflare-api-token -n cert-manager -o jsonpath='{.data.api-token}' | base64 -d > /tmp/cf-token.tmp
kubectl create secret generic cloudflare-api-token -n external-dns --from-file=api-token=/tmp/cf-token.tmp
rm /tmp/cf-token.tmp
```
**Don't use `--from-file=api-token=/dev/stdin` on this machine** — under Git Bash, MSYS path-conversion mangles `/dev/stdin` before it reaches `kubectl.exe` and silently corrupts the copied value (confirmed: produced a 44-byte UTF-16-flavored garbage token instead of the real 53-byte one, which then made `kubectl.exe` reject it outright as invalid). A real temp file sidesteps the path-conversion entirely.

```bash
helm upgrade --install external-dns external-dns/external-dns \
  -n external-dns -f infra/external-dns-values.yaml
```

## DOKS Load Balancer: REGIONAL vs REGIONAL_NETWORK

**This one cost real debugging time and will bite again on any from-scratch reinstall.** Since DOKS 1.33.1-do.0, the default LB type is `REGIONAL_NETWORK`, which **silently ignores** `service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol` — the annotation sits on the Service with no error, but the actual DO Load Balancer object never gets `enable_proxy_protocol: true`. Symptom: every direct HTTPS connection to the LB resets mid-handshake (nginx expects a PROXY protocol preamble that never arrives, fails to parse the raw TLS ClientHello as one, resets). Cloudflare surfaces this as a 525.

Fix is in `ingress-nginx-values.yaml`: `service.beta.kubernetes.io/do-loadbalancer-type: "REGIONAL"` alongside the proxy-protocol annotation. On an existing cluster, DigitalOcean's cloud-controller-manager already owns that annotation field (it auto-set the `REGIONAL_NETWORK` default), so a `helm upgrade` hits a server-side-apply field-manager conflict. Work around it with a direct patch, which the CCM then reconciles onto the real LB (takes 30-60s):
```bash
kubectl annotate svc ingress-nginx-controller -n ingress-nginx \
  service.beta.kubernetes.io/do-loadbalancer-type=REGIONAL --overwrite
```
Verify with `doctl compute load-balancer get <id> -o json` — look for `"type": "REGIONAL"` and `"enable_proxy_protocol": true`, not just that the annotation is set on the Service (which proved nothing here).

## Cloudflare API token → cert-manager (already done, kept for reference)

Token needs **Zone : DNS : Edit** for the zones this cluster issues certs for (`makersmap.co.uk`, `cornwallhairdressers.co.uk`, and whatever domain jpmc-tech eventually gets).
```bash
kubectl create secret generic cloudflare-api-token \
  -n cert-manager \
  --from-literal=api-token=<paste-token-here>
kubectl apply -f infra/cluster-issuer.yaml
kubectl get clusterissuer letsencrypt-cloudflare -o wide
```

## Reference

- Load balancer external IP: `129.212.161.57` (`enable_proxy_protocol` must read `true` via `doctl`, not just be present as a Service annotation — this IP changed once already when the LB had to be recreated to fix exactly that, and external-dns corrected every Ingress-derived DNS record automatically within its normal reconcile cycle when it did)
- `ingress-nginx-values.yaml` — LB type/PROXY protocol + Cloudflare real-IP trust + Server header stripping
- `cluster-issuer.yaml` — the shared ACME issuer every app's Ingress references via `cert-manager.io/cluster-issuer`
- `external-dns-values.yaml` — Cloudflare DNS reconciliation from Ingress hostnames
