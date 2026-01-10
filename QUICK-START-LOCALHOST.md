# Quick Start: Jenkins Pipeline for Localhost

## Setup (5 minutes)

1. **Prerequisites**: Docker, Docker Compose, Maven, Java 11+

2. **Create Jenkins Pipeline Job**:
   - New Item → Pipeline
   - Pipeline script from SCM
   - Repository: Your repo URL
   - Script Path: `jenkins/Jenkinsfile-localhost`

3. **Run**: Click "Build Now"

## What It Does

1. ✅ Builds all services with Maven
2. ✅ Runs unit tests
3. ✅ Builds Docker images
4. ✅ Deploys to localhost via Docker Compose
5. ✅ Verifies health checks
6. ✅ Runs integration tests

## After Successful Build

Services available at:
- API Gateway: http://localhost:8080
- User Service: http://localhost:8081
- Order Service: http://localhost:8082
- Payment Service: http://localhost:8083
- Notification Service: http://localhost:8084

## Cleanup

```bash
docker-compose down        # Stop services
docker-compose down -v     # Stop and remove data
```

## Troubleshooting

- **Port conflicts**: `docker-compose down` first
- **Health checks fail**: Check logs with `docker-compose logs`
- **Build fails**: Ensure Docker, Maven, Java are installed

For detailed documentation, see [README-LOCALHOST-PIPELINE.md](README-LOCALHOST-PIPELINE.md)

