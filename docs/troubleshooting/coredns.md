# CoreDNS fix

`make fix-coredns` patches the cluster's CoreDNS ConfigMap to forward external
DNS queries to `8.8.8.8` / `8.8.4.4` instead of `/etc/resolv.conf`.

## When to run it

Right after `make kind-create`, before installing Argo CD. A fresh kind
cluster on this network can't resolve `github.com`, `ghcr.io`, or `quay.io`
until this runs — Argo CD's repo-server and image pulls will fail with
`server misbehaving` otherwise.

## Why it's needed

See `docs/troubleshooting/kind-cluster-issues.md#2` for the full incident
writeup. Short version: the local router returns `SERVFAIL` for external
domains when queried from the kind cluster's Docker network. Forwarding to
public DNS instead sidesteps it.

## Usage

\`\`\`bash
make fix-coredns
\`\`\`

Safe to run more than once — it checks the current Corefile first and does
nothing if the forward target is already `8.8.8.8 8.8.4.4`.
