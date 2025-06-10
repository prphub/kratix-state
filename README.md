# Kratix Set Up - Minikube

## Error: Windows version of the flux CLI is having trouble resolving relative paths across different drives or path contexts
```
PS D:\ws\k8s\kratix-state> flux install
✚ generating manifests
✗ install failed: Rel: can't make C:\Users\prp36\AppData\Local\Temp\flux-system3891206159 relative to D:\ws\k8s\kratix-state
```

### ✅ Fix: Set `TEMP` and `TMP` to a directory on D: drive

#### 📌 Step-by-step in PowerShell (VS Code):

1.  Create a temporary folder on your D: drive (if it doesn't exist):
    
    powershell
    
    CopyEdit
    
    `mkdir D:\Temp`
    
2.  Set the environment variables for the current session:
    
    powershell
    
    CopyEdit
    
    `$env:TEMP = "D:\Temp" $env:TMP = "D:\Temp"`
    
3.  Run the Flux install:
    
    powershell
    
    CopyEdit
    
    `flux install`

flux bootstrap github |
  --owner=prphub |
  --repository=kratix-state |
  --branch=main |
  --path=clusters/prp |
  --personal