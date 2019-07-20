docker build .\application -t="$env:AKR_HOST/samples/helloapp"
docker login $env:AKR_HOST -u $env:AKR_USERNAME -p $env:AKR_PASSWORD
docker push "$env:AKR_HOST/samples/helloapp"
