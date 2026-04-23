# ExpressHub

ExpressHub is a comprehensive, full-stack food delivery platform built with Node.js and Express. It is designed for containerization with Docker, automated CI/CD with Jenkins, and infrastructure management using Terraform.

This project serves as a robust template for a modern web service, demonstrating a complete development, deployment, and infrastructure lifecycle.

---

## 1) Project Overview

### Tech Stack
- **Backend:** Node.js (CommonJS), Express.js
- **Frontend:** HTML, CSS, JavaScript (static)
- **Containerization:** Docker
- **CI/CD:** Jenkins (Declarative Pipeline)
- **Infrastructure as Code:** Terraform

### API Endpoints
The backend exposes a RESTful API for managing the platform's core features:
- `GET /api/status` → Health check and service status.
- `POST /api/status` → Test POST endpoint.
- `PUT /api/status` → Test PUT endpoint.
- `/api/menu` → Routes for managing menu items.
- `/api/orders` → Routes for handling customer orders.
- `/api/restaurants` → Routes for listing and managing restaurants.
- `/*` → Serves the frontend application for any non-API route.

### Repository Structure
- `index.js` → Main Express application entry point.
- `package.json` → Project dependencies and npm scripts.
- `Dockerfile` → Instructions for building the application's Docker image.
- `Jenkinsfile` → CI/CD pipeline definition for Jenkins.
- `backend/` → Contains backend route handlers.
- `frontend/` → Contains the static frontend application.
- `terraform/` → Terraform configurations for managing infrastructure across different environments (dev, stage, prod).

---

## 2) Prerequisites

Ensure these tools are installed on your local machine or Jenkins agent:
- **Git:** For source control.
- **Node.js & npm:** For running the application and managing dependencies.
- **Docker Engine:** For building and running the containerized application.
- **Terraform:** For managing infrastructure as code.
- **Jenkins:** For orchestrating the CI/CD pipeline.
- `libatomic1`: A system library required by Node.js binaries on some lean Linux distributions.

---

## 3) Local Development

### Step 1: Clone the Repository
```bash
git clone https://github.com/poVvisal/ExpressHub.git
cd ExpressHub
```

### Step 2: Install Dependencies
```bash
npm install
```

### Step 3: Run Tests
The current test script performs a basic syntax check.
```bash
npm test
```

### Step 4: Run the Application
This command starts the Express server locally on port 3000.
```bash
node index.js
```

### Step 5: Test the API
You can now access the application and its API endpoints:
- **Frontend:** Open your browser to `http://localhost:3000`
- **API:**
  ```bash
  # Check service status
  curl http://localhost:3000/api/status

  # Example: Get list of restaurants (assuming endpoint is implemented)
  curl http://localhost:3000/api/restaurants
  ```

---

## 4) Docker Deployment

### Step 1: Build the Docker Image
```bash
docker build -t expresshub-app .
```

### Step 2: Run the Docker Container
This command runs the application in a detached container and maps port 3000.
```bash
docker run -d --name expresshub-container -p 3000:3000 expresshub-app
```

### Step 3: Verify the Container
Check that the container is running and test the endpoint.
```bash
docker ps
curl http://localhost:3000/api/status
```

### Step 4: Stop and Remove the Container
```bash
docker stop expresshub-container
docker rm expresshub-container
```

---

## 5) Jenkins & CI/CD

The `Jenkinsfile` in this repository automates the build, test, and deployment process.

### Jenkins Configuration
1.  **Install Plugins:** Ensure the `NodeJS`, `Docker Pipeline`, and `Git` plugins are installed in Jenkins.
2.  **Configure NodeJS:** In **Manage Jenkins → Tools**, add a `NodeJS` installation. The name must match the one specified in the `Jenkinsfile` (`nodejs 'NodeJS-20'`).
3.  **Docker Permissions:** Allow the `jenkins` user to run Docker commands:
    ```bash
    sudo usermod -aG docker jenkins
    sudo systemctl restart jenkins
    ```

### Pipeline Stages
The pipeline executes the following stages:
1.  **Checkout:** Clones the source code from Git.
2.  **Install Dependencies:** Runs `npm install`.
3.  **Test:** Runs `npm test`.
4.  **Docker Build:** Builds the Docker image.
5.  **Deploy:** Stops any existing container and runs the new one.

---

## 6) Infrastructure with Terraform

The `terraform/` directory contains the code to provision and manage the infrastructure required to run this application.

- **`modules/`**: Contains reusable Terraform modules (e.g., for an EC2 instance).
- **`dev/`, `stage/`, `prod/`**: Environment-specific configurations that use the shared modules to create distinct infrastructure for development, staging, and production.

### Usage
1.  Navigate to an environment directory (e.g., `terraform/dev`).
2.  Initialize Terraform:
    ```bash
    terraform init
    ```
3.  Review the execution plan:
    ```bash
    terraform plan
    ```
4.  Apply the changes to provision the infrastructure:
    ```bash
    terraform apply
    ```

---

## 7) Troubleshooting

### `node: error while loading shared libraries: libatomic.so.1`
**Cause:** Missing `libatomic1` system library.
**Fix:** `sudo apt-get update && sudo apt-get install -y libatomic1`

### `npm: not found` in Jenkins Pipeline
**Cause:** Node.js is not available in the pipeline's environment.
**Fix:** Ensure the **NodeJS Plugin** is installed and configured in Jenkins and that the `tools` directive is present in your `Jenkinsfile`.

### Docker commands fail with `permission denied` in Jenkins
**Cause:** The `jenkins` user is not part of the `docker` group.
**Fix:** `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins`

