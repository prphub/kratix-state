# File: postgresql/docs/troubleshooting.md

# PostgreSQL Promise Troubleshooting Guide

## Common Issues and Solutions

### 1. PostgreSQL Pod Not Starting

**Symptoms:**
- Pod stuck in `Pending` or `CrashLoopBackOff` state
- Error messages about storage or permissions

**Diagnosis:**
```bash
kubectl describe pod {name}-postgresql-0
kubectl logs {name}-postgresql-0
```

**Common Causes:**
- **Storage Issues**: PVC not bound
- **Resource Limits**: Insufficient CPU/memory
- **Image Pull Issues**: Wrong PostgreSQL version

**Solutions:**
```bash
# Check PVC status
kubectl get pvc {name}-postgresql-data

# Check node resources
kubectl describe nodes

# Verify image exists
docker pull postgres:{version}
```

### 2. Cannot Connect to Database

**Symptoms:**
- Applications cannot connect to PostgreSQL
- Connection timeout errors

**Diagnosis:**
```bash
# Test internal connectivity
kubectl exec -it {name}-postgresql-0 -- psql -U {username} -d {database} -c "SELECT version();"

# Check service
kubectl get svc {name}-postgresql
```

**Common Causes:**
- **Wrong credentials**: Check secret values
- **Network policies**: Blocking connections
- **Service not ready**: Pod not fully started

**Solutions:**
```bash
# Get correct credentials
kubectl get secret {name}-postgresql-secret -o jsonpath='{.data.postgres-username}' | base64 -d
kubectl get secret {name}-postgresql-secret -o jsonpath='{.data.postgres-password}' | base64 -d

# Test from another pod
kubectl run -it --rm debug --image=postgres:{version} -- psql -h {name}-postgresql -U {username} -d {database}
```

### 3. Backup Job Failing

**Symptoms:**
- CronJob not creating successful jobs
- Backup files not being created

**Diagnosis:**
```bash
kubectl get cronjob {name}-postgresql-backup
kubectl describe job {name}-postgresql-backup-{timestamp}
```

**Common Causes:**
- **Backup storage full**: PVC at capacity
- **Database access issues**: Wrong credentials
- **Permissions**: Backup directory not writable

**Solutions:**
```bash
# Check backup storage
kubectl get pvc {name}-postgresql-backup

# Manual backup test
kubectl exec -it {name}-postgresql-0 -- pg_dump -U {username} -d {database}
```

### 4. Monitoring Not Working

**Symptoms:**
- No metrics appearing in Prometheus
- Exporter pod not running

**Diagnosis:**
```bash
kubectl get pods -l app={name}-postgresql-exporter
kubectl logs -l app={name}-postgresql-exporter
```

**Common Causes:**
- **Connection issues**: Exporter can't reach PostgreSQL
- **Wrong credentials**: Invalid database connection
- **Firewall**: Metrics port blocked

**Solutions:**
```bash
# Test exporter connectivity
kubectl port-forward svc/{name}-postgresql-metrics 9187:9187
curl http://localhost:9187/metrics
```

### 5. High Resource Usage

**Symptoms:**
- Pod being killed due to OOMKilled
- High CPU usage
- Slow query performance

**Diagnosis:**
```bash
kubectl top pods {name}-postgresql-0
kubectl exec -it {name}-postgresql-0 -- ps aux
```

**Solutions:**
- **Increase resources**: Change size from small to medium/large
- **Optimize queries**: Check slow query logs
- **Tune configuration**: Modify postgresql.conf settings

### 6. SSL Connection Issues

**Symptoms:**
- SSL handshake failures
- Certificate verification errors

**Diagnosis:**
```bash
kubectl exec -it {name}-postgresql-0 -- psql -U {username} -d {database} -c "SHOW ssl;"
```

**Solutions:**
- **Certificate management**: Ensure proper SSL certificates
- **Client configuration**: Update connection strings
- **Disable SSL**: Set `ssl: false` for testing

## Getting Help

### Log Collection
```bash
# PostgreSQL logs
kubectl logs {name}-postgresql-0 > postgresql.log

# Pipeline logs
kubectl logs -l app=kratix-pipeline-{name} > pipeline.log

# Events
kubectl get events --field-selector involvedObject.name={name}-postgresql > events.log
```

### Resource Status
```bash
# All related resources
kubectl get all -l app={name}-postgresql

# Promise status
kubectl describe postgresql {name}

# Secret verification
kubectl get secret {name}-postgresql-secret -o yaml
```

### Performance Analysis
```bash
# Resource usage
kubectl top pods {name}-postgresql-0

# Storage usage
kubectl exec -it {name}-postgresql-0 -- df -h

# Database size
kubectl exec -it {name}-postgresql-0 -- psql -U {username} -d {database} -c "SELECT pg_size_pretty(pg_database_size('{database}'));"
```

## Best Practices

1. **Always enable persistence** for production databases
2. **Use appropriate sizing** based on workload requirements
3. **Enable monitoring** to track performance
4. **Regular backups** for data protection
5. **SSL encryption** for production environments
6. **Resource quotas** to prevent resource exhaustion
7. **Health checks** to ensure availability

## Emergency Procedures

### Database Recovery
```bash
# Stop PostgreSQL
kubectl scale statefulset {name}-postgresql --replicas=0

# Restore from backup
kubectl exec -it {name}-postgresql-0 -- psql -U {username} -d {database} < /backup/latest.sql

# Restart PostgreSQL
kubectl scale statefulset {name}-postgresql --replicas=1
```

### Password Reset
```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update secret
kubectl patch secret {name}-postgresql-secret -p '{"data":{"postgres-password":"'$(echo -n $NEW_PASSWORD | base64)'"}}'

# Restart PostgreSQL
kubectl rollout restart statefulset {name}-postgresql
```