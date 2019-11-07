# Using Stackdriver* with golang on Istio

[Using Stackdriver* with golang on Istio](https://medium.com/google-cloud/using-stackdriver-with-golang-on-istio-2ccbe00bbcd8) を読んだメモ

## 概要

## 本編

Istio, GKE, Stackdriver ファミリーの関連性を明らかにしていく

`observing` と `controlling` に焦点を当てる。(アプリケーション自体は2層の Hello World App)

シンプルな frontend->backend の構成のアプリを作り、 Stackdriver の top-level capability と istio の主要な機能を組み込む。

サンプルアプリ: [salrashid123/istio_helloworld](https://github.com/salrashid123/istio_helloworld)

このレポジトリでは以下のことを検討する。

- Stackdriver Logging
- Stackdriver Monitoring
- Stackdriver Trace
- Stackdriver Error Reporting
- Stackdriver Profiler
- Stackdriver Debugger*
- Opencensus Exporter for Stackdriver

同時に以下もカバーする

- Istio Traffic Management
- Istio Fault Injection

### Testing endpoints

なにをデプロイするのか??

以下のような IF のアプリをデプロイする。

Frontend (`fe`):

```
http.Handle("/", rootHandler)   // does nothing
http.Handle("/hostname", hostnameHander)  // emits back the hostname of the pod that got the request
http.Handle("/tracer", traceHandler)  // starts tracing requests to gcs and makes a call to the backend /tracer endpoint
http.Handle("/backend", backendHandler)  // just makes an http call to the backend
http.Handle("/log", logHandler)  // logs stuff
http.Handle("/delay", delayHandler) // adds in an artifical delay of 3s by default.  Accepts ?delay=2000 to daly 2s,etc
http.Handle("/error", errorHandler)  // emits a custom error
http.Handle("/debug", debugHandler)  // debug endpoint where you can setup a breakpoint (well, you can set one anywhere...)
http.Handle("/measure", trackVistHandler(measureHandler))  // emits a custom metric to opencensus-->stackdriver
```

Backend (`be`):

```
http.HandleFunc("/tracer", tracer)  // accepts an inbound trace context from frontend, used context to make a gcs call and then return
http.HandleFunc("/backend", backend) // just responds, ok
```

もっとしっかり見たい場合は [salrashid123/istio_helloworld](https://github.com/salrashid123/istio_helloworld)(再掲) を参照

### Setup

```
export PROJECT_ID=`gcloud config get-value core/project`
export PROJECT_NUMBER=`gcloud projects describe $PROJECT_ID --format="value(projectNumber)"`
```

### Configure Project

#### Enable Services

```
gcloud services enable cloudtrace.googleapis.com \
                       compute.googleapis.com \
                       container.googleapis.com \
                       logging.googleapis.com \
                       monitoring.googleapis.com \
                       sourcerepo.googleapis.com \
                       stackdriver.googleapis.com \
                       clouddebugger.googleapis.com \
                       clouderrorreporting.googleapis.com \
                       cloudprofiler.googleapis.com
```

#### Add IAM Permissions

TODO: create service account

シェルにしました。(permission への強い執念)

```bash:add-permission.sh
roles=( roles/clouddebugger.agent \
        roles/cloudprofiler.agent \
        roles/cloudtrace.agent \
        roles/container.admin \
        roles/errorreporting.writer \
        roles/logging.logWriter \
        roles/monitoring.metricWriter \
        roles/monitoring.editor )

for role in ${roles[@]}
do
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
           --member serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
           --role ${role}
done
```

### Create GCS bucket

```
gsutil mb gs://sdtest-${PROJECT_NUMBER}

echo foo > some_file.txt
gsutil cp some_file.txt gs://sdtest-${PROJECT_NUMBER}

gsutil acl ch -r -u ${PROJECT_NUMBER}-compute@developer.gserviceaccount.com:R gs://sdtest-${PROJECT_NUMBER}
```

### Install GKE + Istio

```
export GKE_ISTIO_VERSION=1.1.16

gcloud beta container  clusters create gcp-demo \
    --machine-type "n1-standard-1" --zone us-central1-a  \
    --num-nodes 3 --enable-ip-alias  --enable-stackdriver-kubernetes \
    --scopes "https://www.googleapis.com/auth/cloud-platform","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append,https://www.googleapis.com/auth/cloud_debugger","https://www.googleapis.com/auth/monitoring.write" \
    --addons=Istio --istio-config=auth=MTLS_PERMISSIVE --cluster-version=1.14.7

gcloud container clusters get-credentials gcp-demo --zone us-central1-a

kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)
```

### Add Kiali

[salrashid123/stackdriver_istio_helloworld](https://github.com/salrashid123/stackdriver_istio_helloworld)

トポロジーグラフを描画するためにインストールする。(デフォルトではインストールされていない)

上のレポジトリだと既存の yaml を適用するだけで内容がわからないのでひとまず heml でインストールしてから中身を見る

see: [Visualizing Your Mesh](https://istio.io/docs/tasks/telemetry/kiali/)

[別途まとめた](./setup-helm.md)

### Add Stackdriver Trace

以下のコマンドでルールの編集画面を開く。

```
kubectl edit -n istio-system rule stackdriver-tracing-rule
```

`match: "false"` の `"false"` を以下の条件に置き換える。

```
(context.protocol == "http" || context.protocol == "grpc") && (context.reporter.kind | "inbound" == "inbound")
```

### Register GCE Metadataserver and Service

**公式に言及がないため割愛**

### Build and Push images

```
git clone https://github.com/salrashid123/stackdriver_istio_helloworld.git
cd stackdriver_istio_helloworld/minimal_gcp/
cd fe
docker build  --build-arg VER=1 -f Dockerfile.prod \ 
    -t gcr.io/$PROJECT_ID/fe_min:1 .
docker build  --build-arg VER=2 -f Dockerfile.prod \ 
    -t gcr.io/$PROJECT_ID/fe_min:2 .
docker push gcr.io/$PROJECT_ID/fe_min:1
docker push gcr.io/$PROJECT_ID/fe_min:2

docker build  --build-arg VER=1 -f Dockerfile.debug \
    -t gcr.io/$PROJECT_ID/fe_min:debug1 .
docker build  --build-arg VER=2 -f Dockerfile.debug \
    -t gcr.io/$PROJECT_ID/fe_min:debug2 .
docker push gcr.io/$PROJECT_ID/fe_min:debug1
docker push gcr.io/$PROJECT_ID/fe_min:debug2
```

```
cd ../be
docker build  --build-arg VER=1 -f Dockerfile -t \
    gcr.io/$PROJECT_ID/be_min:1 .
docker build  --build-arg VER=2 -f Dockerfile -t \
    gcr.io/$PROJECT_ID/be_min:2 .
docker push  gcr.io/$PROJECT_ID/be_min:1
docker push  gcr.io/$PROJECT_ID/be_min:2
```

### Deploy Application

first get the `GATEWAY_IP`

```
export GATEWAY_IP=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $GATEWAY_IP 
```

#### Edit configmap.yaml(, debug-configmap.yaml)

以下の値を修正して apply する。

```yaml:configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: settings
data:
  GOOGLE_CLOUD_PROJECT: "your_project"
  BUCKET_NAME: "sdtest-your_project_number"
  GKE_CLUSTER_NAME: "gcp-demo"
```

```
kubectl apply -f configmap.yaml
```

#### Prepare istio for ingress

sidecar injection を有効化

```
kubectl label namespace default istio-injection=enabled

kubectl apply -f istio-lb-certs.yaml

# wait a couple seconds

kubectl apply -f istio-ingress-gateway.yaml
kubectl apply -f istio-services.yaml
kubectl apply -f configmap.yaml
kubectl apply -f debug-configmap.yaml

# replace 'your_project' => 'kaito2'
kubectl apply -f istio-deployment.yaml
```

##### 1. Deploy fev1->bev1

```
kubectl apply -f istio-fev1-bev1.yaml
```

アクセスしてみる

```
for i in {1..10}; do curl -sk -w "\n" -s http://$GATEWAY_IP/hostname &&  sleep 1; done

hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
hello from myapp-v1-7969cccc78-zwghg, i'm running version 1
```

**外部サービスを登録していないのでトポロジにログの送信が表示されていない**

