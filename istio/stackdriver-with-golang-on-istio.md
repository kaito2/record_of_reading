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


