# Setup Helm

```
export PILOT_POD_ID=$(kubectl get pods -n istio-system | grep pilot | awk '{print $1}')
kubectl get pod ${PILOT_POD_ID} -n istio-system -oyaml | grep image: | grep pilot
```

出力は以下のようになる。

```
    image: gke.gcr.io/istio/pilot:1.1.16-gke.0
    image: gke.gcr.io/istio/pilot:1.1.16-gke.0
```

バージョンは `1.1.16` なので、以下のリンクから該当のバージョンのチャートをダウンロードする。

[istio/istio](https://github.com/istio/istio/releases)

```
wget https://github.com/istio/istio/archive/1.1.16.zip
tar -xvf 1.1.16.zip
rm 1.1.16.zip
```

#### Create a secret

```
KIALI_USERNAME=$(read -p 'Kiali Username: ' uval && echo -n $uval | base64)
KIALI_PASSPHRASE=$(read -sp 'Kiali Passphrase: ' pval && echo -n $pval | base64)
```

```
NAMESPACE=istio-system
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: $NAMESPACE
  labels:
    app: kiali
type: Opaque
data:
  username: $KIALI_USERNAME
  passphrase: $KIALI_PASSPHRASE
EOF
```

#### Install via Helm

```
helm template --set kiali.enabled=true istio-1.1.16/install/kubernetes/helm/istio \
    --name istio --namespace istio-system > kiali.yaml

kubectl apply -f kiali.yaml
```

以下のようなエラーが出る場合がある

```
... Required value: must be specified when `operator` is 'In' or 'NotIn' ...
```

helm `2.15.1` で fix されたらしいのでアップデートするのがおすすめ。

see: [Can&#39;t install v1.3.3 with helm v2.15.0 · Issue #18095 · istio/istio](https://github.com/istio/istio/issues/18095)

ポートフォワーディングして UI にアクセスする。

```
kubectl -n istio-system port-forward $(kubectl \
  -n istio-system get pod -l app=kiali \
  -o jsonpath='{.items[0].metadata.name}') 20001:20001
```

`http://localhost:20001/kiali/console/` をブラウザで開く


