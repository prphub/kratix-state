# ServiceNow Ticketing Integration Promise

This Promise provides ServiceNow ticketing integration for Kratix, enabling approval workflows for service provisioning through ServiceNow's ITSM platform. **This Promise follows the Ansible Job Launcher pattern** and leverages existing Kratix promises instead of creating deployments directly.

## Overview

The ServiceNow Promise implements a complete ticketing workflow that:

1. **Creates ServiceNow Tickets**: Automatically creates tickets in your ServiceNow instance when users request services
2. **Manages Approval Workflows**: Waits for approval in ServiceNow before proceeding with provisioning
3. **Provisions via Existing Promises**: Creates resource requests for existing Kratix promises (PostgreSQL, Redis, etc.) after approval
4. **Updates Ticket Status**: Keeps ServiceNow tickets updated with provisioning status

## Key Design: Leverage Existing Promises

**Instead of creating PostgreSQL/Redis deployments directly**, this promise:
- ✅ Creates resource requests for existing `postgresql`, `redis`, etc. promises
- ✅ Follows the **Compound Promise** pattern
- ✅ Reuses battle-tested promise implementations
- ✅ Maintains separation of concerns

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ ServiceNowRequest│───▶│ ServiceNow Ticket │───▶│ Promise Resource │
│    (CRD)        │    │   (Approval Gate) │    │    Request      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                          │
                              ▼                          ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │ ServiceNow ITSM  │    │  PostgreSQL     │
                       │  (Manual/Auto    │    │  Redis, etc.    │
                       │    Approval)     │    │   Promises      │
                       └──────────────────┘    └─────────────────┘
```

## Quick Start

### 1. Prerequisites

- Kratix installed and configured
- ServiceNow instance with access to REST API
- Custom table `u_kratix_ticket` created in ServiceNow (see [Setup](#setup))

### 2. Create ServiceNow Credentials

**Important**: Create the secret in the **kratix-platform-system** namespace (where Kratix platform runs):

```bash
kubectl create secret generic servicenow-credentials \
  --namespace kratix-platform-system \
  --from-literal=instance=your-pdi-instance \
  --from-literal=username=admin \
  --from-literal=password=your-admin-password
```

**Example with your ServiceNow PDI instance:**
```bash
kubectl create secret generic servicenow-credentials \
  --namespace kratix-platform-system \
  --from-literal=instance=dev12345 \
  --from-literal=username=admin \
  --from-literal=password=your-actual-password
```

**Note**: Replace `dev12345` with your actual ServiceNow PDI instance name (the part before `.service-now.com`)

### 3. Install the Promise

```bash
kubectl apply -f promise.yaml
```

### 4. Verify Setup

Test your ServiceNow connection:
```bash
# Get your credentials
INSTANCE=$(kubectl get secret servicenow-credentials -n kratix-platform-system -o jsonpath='{.data.instance}' | base64 -d)
USERNAME=$(kubectl get secret servicenow-credentials -n kratix-platform-system -o jsonpath='{.data.username}' | base64 -d)
PASSWORD=$(kubectl get secret servicenow-credentials -n kratix-platform-system -o jsonpath='{.data.password}' | base64 -d)

# Test API connection
curl -u "${USERNAME}:${PASSWORD}" \
  "https://${INSTANCE}.service-now.com/api/now/table/u_kratix_ticket?sysparm_limit=1"
```

Expected response: JSON with `result` array (may be empty)

### 5. Make a Service Request

```bash
kubectl apply -f resource-request.yaml
```

## Setup

### ServiceNow Table Configuration

Create a custom table `u_kratix_ticket` in ServiceNow with the following fields:

| Field Name | Type | Description |
|------------|------|-------------|
| `u_kratix_request_id` | String | Unique identifier for the Kratix request |
| `u_description` | String | Description of the requested service |
| `u_requested_by` | String | Email/username of requester |
| `u_service_type` | Choice | Type of service (PostgreSQL, Redis, etc.) |
| `u_status` | Choice | Status (new, open, complete, rejected) |
| `u_priority` | Choice | Priority level (low, medium, high, critical) |
| `u_requested_at` | Date/Time | Request timestamp |
| `u_auto_approve` | Boolean | Auto-approval flag |

### Default Values

Set the following default values in ServiceNow:

- `u_requested_at`: `gs.nowDateTime()`
- `u_status`: `new`
- `u_priority`: `medium`

## Usage Examples

### Basic PostgreSQL Request

```yaml
apiVersion: marketplace.kratix.io/v1
kind: ServiceNowRequest
metadata:
  name: postgres-dev-db
  namespace: default
spec:
  promise_name: postgresql
  description: "PostgreSQL database for development environment"
  requested_by: "developer@company.com"
  priority: medium
  resource_request:
    apiVersion: marketplace.kratix.io/v1alpha1
    kind: postgresql
    metadata:
      name: dev-app-db
      namespace: default
    spec:
      teamId: dev-team
      env: dev
      size: small
```

### Redis with Auto-Approval

```yaml
apiVersion: marketplace.kratix.io/v1
kind: ServiceNowRequest
metadata:
  name: redis-cache-prod
  namespace: default
spec:
  promise_name: redis
  description: "Redis cache for production application"
  requested_by: "ops@company.com"
  priority: high
  auto_approve: true  # Skip manual approval
  resource_request:
    apiVersion: marketplace.kratix.io/v1alpha1
    kind: redis
    metadata:
      name: session-cache
      namespace: default
    spec:
      teamId: ops-team
      env: prod
      size: medium
```

## How It Works with Existing Promises

### Prerequisites

You must have the target promises already installed:

```bash
# Install PostgreSQL Promise
kubectl apply -f https://raw.githubusercontent.com/syntasso/kratix-marketplace/main/postgresql/promise.yaml

# Install Redis Promise  
kubectl apply -f https://raw.githubusercontent.com/syntasso/kratix-marketplace/main/redis/promise.yaml
```

### The Flow

1. **User creates ServiceNowRequest** → specifies `promise_name: postgresql`
2. **ServiceNow ticket created** → awaits approval
3. **After approval** → Pipeline extracts `resource_request` and writes to `/kratix/output/`
4. **Kratix processes output** → Creates the actual PostgreSQL resource
5. **PostgreSQL Promise** → Handles the actual database provisioning

## Monitoring and Status

### Check Request Status

```bash
kubectl get servicenowrequests
kubectl describe servicenowrequest postgresql-example
```

### Status Fields

The Promise tracks several status fields:

- `approval_state`: pending, approved, rejected, provisioned
- `ticket_id`: ServiceNow ticket system ID
- `ticket_number`: Human-readable ticket number
- `ticket_url`: Direct link to ServiceNow ticket
- `provisioned_resource`: Name of the actual resource created

## Advantages of This Approach

### ✅ **Reuse Existing Promises**
- No need to reimplement PostgreSQL, Redis deployments
- Leverage community-tested promise implementations
- Automatic updates when underlying promises improve

### ✅ **Separation of Concerns**
- ServiceNow Promise handles approval workflow
- Database Promises handle actual provisioning
- Clean architectural boundaries

### ✅ **Extensibility**
- Easy to add support for new services
- Just reference existing promise names
- No code changes needed for new promise types

### ✅ **Following Kratix Patterns**
- Matches Ansible Job Launcher architecture
- Single pipeline with external system integration
- Standard Kratix output mechanism

## Troubleshooting

### Common Issues

1. **ServiceNow Connection Failed**
   ```bash
   # Check credentials in correct namespace
   kubectl get secret servicenow-credentials -n kratix-platform-system -o yaml
   
   # Test connection manually (replace with your actual values)
   curl -u admin:password https://dev12345.service-now.com/api/now/table/u_kratix_ticket
   ```

2. **Pipeline Permission Errors**
   - Ensure secret is in `kratix-platform-system` namespace
   - Verify ServiceNow custom table `u_kratix_ticket` exists
   - Check admin user has API access permissions

3. **Ticket Not Created**
   - Verify ServiceNow table exists with correct fields
   - Check user permissions in ServiceNow
   - Validate field mappings match your ServiceNow configuration

### Debug Commands

```bash
# Check pipeline logs
kubectl logs -l kratix.io/promise-name=servicenow-ticket

# View resource status
kubectl get servicenowtickets -o wide

# Check events
kubectl get events --field-selector involvedObject.kind=ServiceNowTicket
```

## Development

### Building Pipeline Images

```bash
# Build approval pipeline
cd internal/approval-pipeline
docker build -t servicenow-approval-pipeline:latest .

# Build provisioner pipeline  
cd internal/provisioner-pipeline
docker build -t servicenow-provisioner-pipeline:latest .
```

### Testing

```bash
# Test with auto-approval
kubectl apply -f - <<EOF
apiVersion: marketplace.kratix.io/v1
kind: ServiceNowTicket
metadata:
  name: test-auto-approve
spec:
  service_type: PostgreSQL
  description: "Test auto-approval"
  requested_by: "test@example.com"
  auto_approve: true
  service_config:
    database_name: "testdb"
EOF
```

## Security Considerations

- Store ServiceNow credentials securely using Kubernetes secrets
- Use ServiceNow service accounts with minimal required permissions
- Enable audit logging for all ticket operations
- Regularly rotate ServiceNow credentials

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This Promise is distributed under the Apache 2.0 License.
