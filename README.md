## MobileCellCount

顕微鏡に写る細菌細胞数を自動測定するアプリケーション

アプリケーションの大枠の機能は
https://github.com/shu223/MLModelCamera 

こちらのレポジトリをcloneさせていただき作成しました。

## 使用モデル
YoloV5

/models/のconverted_best.mlmodelとconverted_best2.mlmodelがYoloV5のモデルで、

converted_best2.mlmodelが現状最も精度の高いモデルです。



##  追加機能
・不要な機能の削除

・物体検出数のリアルタイム表示

・タップアクションによる計測結果の停止、再生機能

## 課題
まだまだモデルのブラッシュアップは必要です
