# istio: Up and Running 1
#istio_up_and_running

## The Istio Service Mesh

豆:
Istio（ギリシャ語のアルファベット、ιστίο）はギリシャ語で「帆」を意味する。

### The Origin of Istio
- Google, IBM, Lyft によって作成されたOSS

- サービスメッシュ上で動作するアプリケーションはサービスメッシュの上で動作していることを意識する必要はない
- トラフィックをインターセプトしてマネージメントする
- Envoyをデータプレーンとして用いている
	- アプリケーションにサイドカーとしてデプロイする
- コントロールプレーンはいくつかのコンポーネントから構成されており以下の管理を行う
	- data-plane proxies
	- API for operators
	- security settings
	- policy ckecks
	- etc.
- Istio の設計はプラットフォームに依存しない
	- OpenShift, Mesos, Cloud Foundry
	- MVやベアメタルなどの伝統的な環境にもデプロイ可能

> No technology is a panacea. 

**ごたくはかつあい**