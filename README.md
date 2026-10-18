# Project4 – End-to-End CI/CD (Jenkins + SonarQube + ZAP + Trivy + ArgoCD)

## Repo layout (copy into your repo)
```
Jenkinsfile                    <- repo root
argocd-application.yaml        <- repo root (applied once to the cluster)
project4/                      <- folder that has manage.py
  Dockerfile, entrypoint.sh, .dockerignore, requirements.txt
  sonar-project.properties
  k8s/ deployment.yaml service.yaml secret.yaml
```
If manage.py is at the repo root, set `APP_DIR = '.'` in the Jenkinsfile and
`path: k8s` in the ArgoCD app.

## 1. Django settings.py changes
```python
import os
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-only-key")
DEBUG = os.environ.get("DJANGO_DEBUG", "0") == "1"
ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1").split(",")

MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")  # right after SecurityMiddleware
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
```
Also run `pip freeze > requirements.txt` in your working venv. The wsgi path used is
`project4.wsgi:application` – change entrypoint.sh if your settings package is named differently.

## 2. Jenkins prerequisites
Credentials (Manage Jenkins -> Credentials):
| ID | Type | Used for |
|---|---|---|
| `sonar-token` | Secret text | SonarQube user token (My Account -> Security) |
| `dockerhub-creds` | Username/password | push image (use an access token) |
| `github-creds` | Username/password | GitOps commit (PAT with repo scope) |

The Jenkins container needs the Docker CLI and `/var/run/docker.sock` mounted
(already the case in your compose). Create the SonarQube project `project4` first.
Create a *Pipeline from SCM* job pointing at the repo; add a GitHub webhook.

Avoid a build loop: the GitOps commit contains `[skip ci]`; also consider ignoring
commits from user `jenkins` (SCM Skip plugin) or only trigger on non-`k8s/` paths.

## 3. Run it
1. Edit the `EDIT THESE` block in the Jenkinsfile and the Docker Hub / GitHub names in the YAMLs.
2. Build with `ENFORCE_GATES=false` -> first green run (findings are reported, not blocking).
3. Reports are archived: `bandit`, `pip-audit`, `trivy-fs`, `trivy-image`, `zap-report.html`; SonarQube dashboard for SAST.
4. Later switch `ENFORCE_GATES=true` to make the scans block the pipeline.

## 4. ArgoCD (GitOps)
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl port-forward svc/argocd-server -n argocd 8080:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl apply -f argocd-application.yaml
```
Each Jenkins run changes the image tag in `k8s/deployment.yaml`; ArgoCD detects the commit
and syncs. App: `http://<node-ip>:30080` (`minikube service project4 -n project4 --url` on Minikube).

## Screenshots to capture for the task
SonarQube dashboard, ZAP report, Trivy/pip-audit reports, green Jenkins stage view,
ArgoCD app Synced/Healthy, running app in browser.

## Notes
- SQLite inside the pod is ephemeral (fine for the task). For persistence add a PVC or move to Postgres.
- ZAP baseline is a passive scan; swap to `zap-full-scan.py` for an active scan (slower).