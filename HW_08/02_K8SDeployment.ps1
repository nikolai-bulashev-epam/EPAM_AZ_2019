kubectl apply -f .\kubernetes\Deployment.yaml --validate=false
kubectl apply -f .\kubernetes\Services.yaml --validate=false
kubectl get services
az aks browse --resource-group $env:RG_NAME --name $env:AKS_CLUSTERNAME 