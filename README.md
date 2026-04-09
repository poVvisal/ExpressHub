# FoodExpress

FoodExpress is a minimal Node.js + Express service packaged with Docker and deployed through a Jenkins Pipeline.

This project is designed to demonstrate a complete CI/CD flow:
- Checkout source from GitHub
- Install dependencies
- Run tests
- Build Docker image
- Deploy container

---

## 1) Project Overview

### Tech Stack
- Node.js (CommonJS)
- Express
- Docker
- Jenkins Declarative Pipeline

### Current API
- `GET /` → returns a text response
- `POST /` → returns a text response

### Repository Structure
- `index.js` → Express application entry point
- `package.json` → dependencies and npm scripts
- `Dockerfile` → image build instructions
- `Jenkinsfile` → CI/CD pipeline definition

---

## 2) Prerequisites

Install these tools on your Linux machine (or Jenkins agent):
- Git
- Node.js and npm
- Docker Engine
- Jenkins
- `libatomic1` system library *(required by Node.js binaries on lean Linux installs)*

Official references:
- Node.js: https://nodejs.org/en/download
- Git: https://git-scm.com/downloads/linux
- Docker Engine on Linux: https://docs.docker.com/engine/install/
- Jenkins on Linux (official): https://www.jenkins.io/doc/book/installing/linux/

---

## 3) Local Setup (Step by Step)

### Step 1: Install system dependencies
```bash
sudo apt-get update
sudo apt-get install -y git docker.io libatomic1
```

> ⚠️ `libatomic1` is required by Node.js v12+ binaries. Without it, `node` and `npm` will fail with:
> `error while loading shared libraries: libatomic.so.1: cannot open shared object file`

### Step 2: Clone the repository
```bash
git clone https://github.com/poVvisal/FoodExpress.git
cd FoodExpress
```

### Step 3: Install dependencies
```bash
npm install
```

### Step 4: Run tests
```bash
npm test
```

Expected behavior: syntax check passes using:
```bash
node --check index.js
```

### Step 5: Run the app locally
```bash
node index.js
```

Test endpoints:
```bash
curl http://localhost:3000/
curl -X POST http://localhost:3000/
```

---

## 4) Docker Setup (Step by Step)

### Step 1: Build image
```bash
docker build -t foodexpress-js .
```

### Step 2: Run container
```bash
docker run -d --name foodexpress-js -p 3000:3000 foodexpress-js
```

### Step 3: Verify container
```bash
docker ps
curl http://localhost:3000/
```

### Step 4: Stop and remove container
```bash
docker stop foodexpress-js
docker rm foodexpress-js
```

---

## 5) Jenkins Setup on Linux (Step by Step)

### Step 1: Install system dependencies
Before installing Jenkins, ensure required system libraries are present:
```bash
sudo apt-get update
sudo apt-get install -y libatomic1 docker.io
```

### Step 2: Install Jenkins
Follow the official Jenkins Linux installation guide:
- https://www.jenkins.io/doc/book/installing/linux/

### Step 3: Start and enable Jenkins
```bash
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins
```

### Step 4: Install suggested plugins
During first-time setup, choose **Install suggested plugins**.

### Step 5: Install required plugins for this project
In Jenkins: **Manage Jenkins → Plugins → Available Plugins**

Install (or verify) these plugins:
- Pipeline
- Git
- **NodeJS** ← *required: auto-installs Node/npm into pipeline PATH*
- **Docker Pipeline** ← *required: enables docker commands in Jenkinsfile*
- Credentials Binding

Optional but helpful:
- Blue Ocean
- Timestamper

Official plugin index: https://plugins.jenkins.io/

### Step 6: Configure NodeJS Tool
In Jenkins: **Manage Jenkins → Tools → NodeJS installations → Add NodeJS**

| Field | Value |
|---|---|
| Name | `NodeJS-20` |
| Install automatically | ✅ checked |
| Version | `20.x` (or latest LTS) |

> ⚠️ The name `NodeJS-20` must exactly match what's in your `Jenkinsfile` under `tools { nodejs 'NodeJS-20' }`.

### Step 7: Allow Jenkins to use Docker
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

Verify Docker access:
```bash
# Check jenkins user is in docker group
groups jenkins
# Expected output includes: jenkins docker
```

---

## 6) Jenkinsfile

The pipeline uses the `tools` block to inject Node.js automatically — no manual PATH setup needed:

```groovy
pipeline {
    agent any

    tools {
        nodejs 'NodeJS-20'   // must match name set in Manage Jenkins → Tools
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/poVvisal/FoodExpress.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }

        stage('Test') {
            steps {
                sh 'npm test'
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t foodexpress-js .'
            }
        }

        stage('Deploy') {
            steps {
                sh 'docker stop foodexpress-js || true'
                sh 'docker rm foodexpress-js || true'
                sh 'docker run -d --name foodexpress-js -p 3000:3000 foodexpress-js'
            }
        }
    }
}
```

---

## 7) Create the Jenkins Pipeline Job

### Step 1: New Item
- Create a **Pipeline** job (example: `FoodExpress-Pipeline`)

### Step 2: Pipeline Definition
- Choose **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/poVvisal/FoodExpress.git`
- Branch: `*/main`
- Script Path: `Jenkinsfile`

### Step 3: Save and Build
- Click **Build Now**

Pipeline stages executed:
1. Checkout
2. Install Dependencies (`npm install`)
3. Test (`npm test`)
4. Docker Build (`docker build -t foodexpress-js .`)
5. Deploy (`docker run -d --name foodexpress-js -p 3000:3000 foodexpress-js`)

---

## 8) Optional: Auto Build with GitHub Webhook

### Jenkins side
- Enable trigger: **GitHub hook trigger for GITScm polling**

### GitHub side
- Repository Settings → Webhooks → Add webhook
- Payload URL: `http://<jenkins-host>:8080/github-webhook/`
- Content type: `application/json`

Official docs:
- https://www.jenkins.io/doc/book/pipeline/
- https://docs.github.com/en/webhooks

---

## 9) Troubleshooting

### `node: error while loading shared libraries: libatomic.so.1`
Cause: Missing system library required by Node.js binaries.

Fix:
```bash
sudo apt-get install -y libatomic1
```

### `npm: not found` in Jenkins pipeline
Cause: Node.js is not on the Jenkins agent PATH.

Fix:
- Install the **NodeJS** Jenkins plugin
- Configure a NodeJS installation under **Manage Jenkins → Tools**
- Add `tools { nodejs 'NodeJS-20' }` to your Jenkinsfile

### `npm test` fails with `Error: no test specified`
Cause: old placeholder test script in `package.json`.

Fix:
```bash
git pull
npm install
npm test
```

### Jenkins shows `Selected Git installation does not exist`
Cause: Jenkins tool configuration missing a named Git installation.

Fix:
- Manage Jenkins → Tools → add/verify Git installation

### Docker build/deploy stage fails with permission denied
Cause: Jenkins user is not in Docker group.

Fix:
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

---

## 10) Useful Official References

- Jenkins User Documentation: https://www.jenkins.io/doc/
- Jenkins Pipeline Book: https://www.jenkins.io/doc/book/pipeline/
- Jenkins Linux Installation: https://www.jenkins.io/doc/book/installing/linux/
- Jenkins Plugins Index: https://plugins.jenkins.io/
- Docker Documentation: https://docs.docker.com/
- Node.js Documentation: https://nodejs.org/docs/latest/api/
- Express Documentation: https://expressjs.com/

---

## 11) Quick Command Summary

```bash
# System prereqs (run once on fresh server)
sudo apt-get install -y libatomic1 docker.io
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Local
npm install
npm test
node index.js

# Docker
docker build -t foodexpress-js .
docker run -d --name foodexpress-js -p 3000:3000 foodexpress-js

# Jenkins service checks (Linux)
sudo systemctl status jenkins
```
