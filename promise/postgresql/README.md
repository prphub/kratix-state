# PostgreSQL Promise for Kratix

This Promise provides a PostgreSQL database service on Kratix, allowing teams to easily provision PostgreSQL instances with various configurations.

## Features

- **Multiple PostgreSQL versions**: Support for versions 13, 14, 15, and 16
- **Flexible sizing**: Small, medium, and large deployment options
- **Persistent storage**: Optional persistent storage with configurable sizes
- **Automated backups**: Daily backup functionality (requires persistence)
- **Monitoring**: Prometheus metrics integration
- **SSL support**: Optional SSL/TLS encryption
- **Health checks**: Built-in liveness and readiness probes

## Installation

### Prerequisites
- Access to a container registry (Docker Hub, GitHub Container Registry, or private registry)
- Docker installed and logged into your registry
- Kratix platform cluster with kubectl access

### Steps

1. **Build and push the configure pipeline image**:

   You MUST build and push the pipeline image first since it doesn't exist yet.
   
   ```bash
   # Navigate to pipeline directory
   cd postgresql/pipeline
   
   # Login to your container registry (example for Docker Hub)
   docker login
   
   # Build the image (replace YOUR_USERNAME with your actual username)
   docker build -t docker.io/YOUR_USERNAME/postgresql-configure-pipeline:v0.1.0 .
   
   # Push the image
   docker push docker.io/YOUR_USERNAME/postgresql-configure-pipeline:v0.1.0
   ```

2. **Update the Promise with your image reference**:

   Edit `promise.yaml` and replace `YOUR_REGISTRY` with your actual image:
   ```yaml
   containers:
     - image: docker.io/YOUR_USERNAME/postgresql-configure-pipeline:v0.1.0
       name: postgresql-configure-pipeline
   ```

3. **Apply the Promise to your Kratix platform cluster**:
   ```bash
   kubectl apply -f promise.yaml
   ```

**📝 Note**: See `BUILD_AND_DEPLOY.md` for detailed build instructions and registry options.

## Usage

### Basic PostgreSQL Instance

```yaml
apiVersion: marketplace.kratix.io/v1alpha1
kind: postgresql
metadata:
  name: my-database
  namespace: default
spec:
  size: small
  version: "15"
  database: "myapp"
  username: "postgres"
```

### Production PostgreSQL with Full Features

```yaml
apiVersion: marketplace.kratix.io/v1alpha1
kind: postgresql
metadata:
  name: production-db
  namespace: production
spec:
  size: large
  version: "15"
  database: "production_app"
  username: "app_user"
  persistence: true
  backup: true
  monitoring: true
  ssl: true
```

## Password Security

**Important**: Users do NOT provide passwords in the PostgreSQL request. Here's how password security is handled:

1. **Auto-Generation**: A secure random password is generated using `openssl rand -base64 32`
2. **Secure Storage**: The password is stored in a Kubernetes Secret (`{name}-postgresql-secret`)
3. **Access Control**: Applications retrieve the password via secret references
4. **No Plain Text**: Passwords never appear in YAML files or logs

### Retrieving the Password

```bash
# Get the auto-generated password
kubectl get secret {name}-postgresql-secret -o jsonpath='{.data.postgres-password}' | base64 -d
```

## Configuration Options

### `spec.size`
- **Type**: string
- **Default**: `small`
- **Options**: `small`, `medium`, `large`
- **Description**: Determines the resource allocation and storage size

| Size | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage | Replicas |
|------|-------------|-----------|----------------|--------------|---------|----------|
| small | 100m | 500m | 256Mi | 512Mi | 1Gi | 1 |
| medium | 250m | 1000m | 512Mi | 1Gi | 5Gi | 1 |
| large | 500m | 2000m | 1Gi | 2Gi | 10Gi | 2 |

### `spec.version`
- **Type**: string
- **Default**: `15`
- **Options**: `13`, `14`, `15`, `16`
- **Description**: PostgreSQL version to deploy

### `spec.database`
- **Type**: string
- **Default**: `app`
- **Description**: Name of the initial database to create

### `spec.username`
- **Type**: string
- **Default**: `postgres`
- **Description**: Username for the PostgreSQL superuser
- **Note**: Password is auto-generated and stored in a Kubernetes Secret for security

### `spec.persistence`
- **Type**: boolean
- **Default**: `true`
- **Description**: Enable persistent storage for PostgreSQL data

### `spec.backup`
- **Type**: boolean
- **Default**: `false`
- **Description**: Enable automated daily backups (requires persistence)

### `spec.monitoring`
- **Type**: boolean
- **Default**: `false`
- **Description**: Enable Prometheus metrics collection

### `spec.ssl`
- **Type**: boolean
- **Default**: `false`
- **Description**: Enable SSL/TLS encryption for connections

## Generated Resources

When you create a PostgreSQL request, the following Kubernetes resources are created:

### Core Resources
- **Secret**: `{name}-postgresql-secret` - Contains database credentials
- **ConfigMap**: `{name}-postgresql-config` - PostgreSQL configuration
- **Service**: `{name}-postgresql` - Database service endpoint
- **StatefulSet**: `{name}-postgresql` - PostgreSQL deployment

### Optional Resources
- **PersistentVolumeClaim**: `{name}-postgresql-data` - Data storage (if persistence enabled)
- **CronJob**: `{name}-postgresql-backup` - Backup scheduler (if backup enabled)
- **PersistentVolumeClaim**: `{name}-postgresql-backup` - Backup storage (if backup enabled)
- **Deployment**: `{name}-postgresql-exporter` - Metrics exporter (if monitoring enabled)
- **Service**: `{name}-postgresql-metrics` - Metrics service (if monitoring enabled)

### Connection Information
- **ConfigMap**: `{name}-postgresql-connection` - Connection details for applications

## Connecting to PostgreSQL

### From within the cluster

Applications can connect using the service name:
```
Host: {name}-postgresql
Port: 5432
Database: {spec.database}
Username: {spec.username}
Password: Retrieved from {name}-postgresql-secret
```

### Connection String Format
```
postgresql://{username}:{password}@{name}-postgresql:5432/{database}
```

### Getting Credentials
```bash
# Get username
kubectl get secret {name}-postgresql-secret -o jsonpath='{.data.postgres-username}' | base64 -d

# Get password
kubectl get secret {name}-postgresql-secret -o jsonpath='{.data.postgres-password}' | base64 -d

# Get database name
kubectl get secret {name}-postgresql-secret -o jsonpath='{.data.postgres-database}' | base64 -d
```

## Monitoring

When monitoring is enabled, PostgreSQL metrics are exposed via prometheus-postgres-exporter at port 9187. Common metrics include:

- `pg_up` - PostgreSQL server availability
- `pg_database_size_bytes` - Database size in bytes
- `pg_stat_database_tup_inserted` - Number of rows inserted
- `pg_stat_database_tup_updated` - Number of rows updated
- `pg_stat_database_tup_deleted` - Number of rows deleted
- `pg_stat_database_numbackends` - Number of active connections

## Backup and Recovery

When backup is enabled, a CronJob runs daily at 2 AM to create SQL dumps. Backups are stored in a persistent volume.

### Manual Backup
```bash
kubectl exec -it {name}-postgresql-0 -- pg_dump -U {username} -d {database} > backup.sql
```

### Restore from Backup
```bash
kubectl exec -i {name}-postgresql-0 -- psql -U {username} -d {database} < backup.sql
```

## Troubleshooting

### Check PostgreSQL Status
```bash
kubectl get statefulset {name}-postgresql
kubectl get pods -l app={name}-postgresql
```

### View Logs
```bash
kubectl logs -f {name}-postgresql-0
```

### Test Database Connection
```bash
kubectl exec -it {name}-postgresql-0 -- psql -U {username} -d {database} -c "SELECT version();"
```

### Check Resources
```bash
kubectl describe postgresql {name}
kubectl get events --field-selector involvedObject.name={name}-postgresql
```

## Security Considerations

1. **Passwords**: Automatically generated random passwords are stored in Kubernetes secrets
2. **SSL**: Enable SSL for production workloads
3. **Network Policies**: Consider implementing network policies to restrict access
4. **RBAC**: Ensure proper RBAC is configured for the service account

## Limitations

- Single master setup (no built-in high availability)
- Backup retention is not automatically managed
- SSL certificates need to be managed separately
- No built-in connection pooling

## Version History

- **v0.1.0**: Initial release with basic PostgreSQL functionality

## Contributing

To modify this Promise:
1. Update the Promise definition in `promise.yaml`
2. Modify the configure script in `configure.sh`
3. Rebuild and push the pipeline image
4. Test with sample requests

## Support

For issues and questions:
- Check the Kratix documentation
- Review the generated resource events
- Examine the pipeline logs