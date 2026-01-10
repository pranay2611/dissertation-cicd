# Jenkins CI/CD Pipeline for Localhost Deployment

This guide explains how to set up and use the Jenkins CI/CD pipeline for deploying microservices to localhost using Docker Compose.

## Overview

The `Jenkinsfile-localhost` pipeline builds, tests, and deploys all microservices to your local machine using Docker Compose. This is ideal for:
- Local development and testing
- CI/CD testing without AWS resources
- Development environment validation
- Integration testing

## Prerequisites

Before using this pipeline, ensure you have the following installed on your Jenkins server (or the machine running Jenkins):

1. **Jenkins** (2.0 or higher)
2. **Docker** (20.10 or higher) - Required for building and running services, as well as Maven builds
3. **Docker Compose** (v2.0 or higher recommended, or docker-compose v1.29+ as fallback)
   - The pipeline automatically detects whether `docker compose` (v2) or `docker-compose` (v1) is available
   - Docker Compose v2 is recommended and uses the `docker compose` command (no hyphen)
   - Docker Compose v1 uses the `docker-compose` command (with hyphen)
4. **curl** (for health checks)

**Notes**: 
- **Maven and Java JDK are NOT required** to be installed directly on the Jenkins server. The pipeline uses Docker containers with Maven pre-installed (`maven:3.9-eclipse-temurin-11`) for building services. This ensures consistent build environments without requiring manual Maven installation.
- The pipeline automatically detects and uses the appropriate Docker Compose command (`docker compose` or `docker-compose`) based on what's available in your environment.

### Verify Prerequisites

```bash
# Check Docker
docker --version

# Check Docker Compose (try v2 first, then v1)
docker compose version || docker-compose --version

# Verify Docker can pull the Maven image (will be pulled automatically if needed)
docker pull maven:3.9-eclipse-temurin-11

# Check curl
curl --version
```

**Note**: The pipeline will automatically detect which Docker Compose command is available. If you have Docker Compose v2, it will use `docker compose`. If you only have v1, it will use `docker-compose`.

## Pipeline Features

The pipeline includes the following stages:

1. **Checkout**: Checks out the source code from the repository
2. **Build All Services**: Builds all microservices in parallel using Maven
3. **Run Unit Tests**: Runs unit tests for all services in parallel
4. **Build Docker Images**: Builds Docker images for all services
5. **Stop Existing Containers**: Cleans up any existing containers
6. **Start Infrastructure Services**: Starts databases, Redis, Kafka, and Zookeeper
7. **Start Microservices**: Starts all microservices
8. **Wait for Services to be Healthy**: Waits for all services to pass health checks
9. **Health Check**: Performs final health checks on all services
10. **Run Integration Tests**: Runs integration tests (if available)
11. **Display Service Status**: Shows the status of all services

## Setup Instructions

### Option 1: Pipeline as Code (Recommended)

1. **Create a Jenkins Pipeline Job**:
   - Go to Jenkins Dashboard
   - Click "New Item"
   - Enter a name (e.g., "Microservices Localhost Pipeline")
   - Select "Pipeline" and click "OK"

2. **Configure the Pipeline**:
   - Under "Pipeline Definition", select "Pipeline script from SCM"
   - Choose your SCM (Git, etc.)
   - Set the Repository URL
   - Set the Script Path to: `jenkins/Jenkinsfile-localhost`
   - Save the configuration

3. **Run the Pipeline**:
   - Click "Build Now" to run the pipeline
   - Monitor the build progress in the console output

### Option 2: Direct Pipeline Script

1. **Create a Jenkins Pipeline Job**:
   - Go to Jenkins Dashboard
   - Click "New Item"
   - Enter a name (e.g., "Microservices Localhost Pipeline")
   - Select "Pipeline" and click "OK"

2. **Copy the Pipeline Script**:
   - In the pipeline configuration, select "Pipeline script"
   - Copy the contents of `jenkins/Jenkinsfile-localhost`
   - Paste into the script text area
   - Save the configuration

3. **Run the Pipeline**:
   - Click "Build Now" to run the pipeline

## Service Endpoints

After a successful pipeline run, the following services will be available on localhost:

- **API Gateway**: http://localhost:8080
  - Health: http://localhost:8080/actuator/health
- **User Service**: http://localhost:8081
  - Health: http://localhost:8081/api/auth/health
- **Order Service**: http://localhost:8082
  - Health: http://localhost:8082/api/orders/health
- **Payment Service**: http://localhost:8083
  - Health: http://localhost:8083/api/payments/health
- **Notification Service**: http://localhost:8084
  - Health: http://localhost:8084/api/notifications/health

## Pipeline Configuration

### Environment Variables

The pipeline uses the following environment variables (configurable in Jenkins):

- `COMPOSE_PROJECT_NAME`: Docker Compose project name (default: `dissertation`)
- `DOCKER_COMPOSE_FILE`: Path to docker-compose.yml (default: `docker-compose.yml`)

### Customizing the Pipeline

You can customize the pipeline by modifying `Jenkinsfile-localhost`:

1. **Change Ports**: Modify the health check URLs in the "Health Check" stage
2. **Add Stages**: Add additional stages for custom testing or deployment steps
3. **Modify Build Options**: Change Maven build parameters (e.g., profiles, skip tests)
4. **Adjust Timeouts**: Modify sleep durations and retry counts for health checks

### Keeping Containers Running

By default, the pipeline keeps containers running after completion. To stop containers automatically:

1. Uncomment the line in the `post.always` block:
   ```groovy
   sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} down'
   ```

## Troubleshooting

### Pipeline Fails at Health Check

If health checks fail:

1. **Check Container Logs**:
   ```bash
   docker-compose logs
   docker-compose logs [service-name]
   ```

2. **Check Container Status**:
   ```bash
   docker-compose ps
   ```

3. **Increase Health Check Timeout**: Modify the `max_attempts` variable in the "Wait for Services to be Healthy" stage

### Docker Compose Command Not Found

If you see errors like `docker-compose: command not found`:

1. **Check Docker Compose Installation**:
   ```bash
   # Try Docker Compose v2 (recommended)
   docker compose version
   
   # Or try Docker Compose v1 (legacy)
   docker-compose --version
   ```

2. **Install Docker Compose if Missing**:
   - **For Docker Compose v2** (recommended): Usually included with Docker Desktop or Docker Engine 20.10+
   - **For Docker Compose v1**: Install via package manager or download from [Docker Compose releases](https://github.com/docker/compose/releases)

3. **The Pipeline Auto-Detects**: The pipeline automatically detects which command is available, but you need at least one installed.

### Port Conflicts

If you get port conflict errors:

1. **Stop Existing Containers**:
   ```bash
   # Use the command detected by the pipeline
   docker compose down || docker-compose down
   ```

2. **Check for Running Containers**:
   ```bash
   docker ps
   docker compose ps || docker-compose ps
   ```

3. **Kill Conflicting Processes**: Identify and stop processes using the required ports

### Docker Build Failures

If Docker builds fail:

1. **Check Disk Space**:
   ```bash
   df -h
   docker system df
   ```

2. **Clean Docker Resources**:
   ```bash
   docker system prune -a
   ```

3. **Check Docker Logs**:
   ```bash
   docker-compose build --no-cache [service-name]
   ```

### Maven Build Failures

If Maven builds fail:

1. **Check Docker Maven Image**: Ensure the Maven Docker image can be pulled:
   ```bash
   docker pull maven:3.9-eclipse-temurin-11
   ```
2. **Check Maven Cache**: The pipeline caches Maven dependencies in `${HOME}/.m2`. If you encounter dependency issues:
   ```bash
   # On Jenkins server, clear Maven cache if needed
   rm -rf ~/.m2/repository
   ```
3. **Check Network**: Ensure Jenkins/Docker can access Maven Central repository
4. **Check Disk Space**: Maven Docker containers need disk space for dependencies:
   ```bash
   docker system df
   df -h
   ```
5. **Verify Docker Volume Mounts**: Ensure Docker has permission to mount volumes from the Jenkins workspace

## Manual Testing After Pipeline

Once the pipeline completes successfully, you can manually test the services:

### 1. Register a User

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john",
    "email": "john@example.com",
    "password": "password123",
    "role": "USER"
  }'
```

### 2. Login

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john",
    "password": "password123"
  }'
```

Save the token from the response.

### 3. Create an Order

```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john",
    "productName": "Laptop",
    "quantity": 1,
    "unitPrice": 999.99
  }'
```

## Stopping Services

To stop all services after testing:

```bash
docker-compose down
```

To stop and remove volumes (deletes database data):

```bash
docker-compose down -v
```

## Best Practices

1. **Use Pipeline as Code**: Store the Jenkinsfile in your repository for version control
2. **Run Tests First**: The pipeline runs unit tests before building Docker images
3. **Monitor Resource Usage**: Ensure your Jenkins server has enough resources (CPU, memory, disk)
4. **Clean Up Regularly**: Clean up Docker resources periodically to free disk space
5. **Use Separate Jenkins Agents**: Consider using dedicated agents for Docker builds
6. **Enable Notifications**: Configure email/Slack notifications for build results

## Differences from AWS Pipeline

This localhost pipeline differs from the AWS pipeline (`Jenkinsfile-api-gateway`, `Jenkinsfile-multi-service`) in the following ways:

- **No ECR**: Uses local Docker images instead of AWS ECR
- **No ECS**: Uses Docker Compose instead of AWS ECS
- **Local Deployment**: Services run on localhost instead of AWS infrastructure
- **Simpler Setup**: No AWS credentials or configuration required
- **Faster Iterations**: No need to push images to remote registry

## Additional Resources

- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Project README](../README.md) - For more information about the microservices architecture

