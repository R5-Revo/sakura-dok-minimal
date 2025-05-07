# ComfyUI with S3 Storage

このDockerイメージは、NVIDIAのGPUを活用したComfyUIと、さくらのオブジェクトストレージ（S3互換）を連携させるためのものです。

## 機能

- NVIDIA GPU対応（CUDA 12.1）
- PyTorchとxformersによる高速推論
- さくらのオブジェクトストレージとの連携
- モデル、入出力データの永続化

## 使用方法

```bash
docker run --gpus all -p 8188:8188 \
  -e S3_ACCESS_KEY="あなたのアクセスキー" \
  -e S3_SECRET_KEY="あなたのシークレットキー" \
  -e S3_BUCKET="バケット名" \
  -e S3_ENDPOINT="https://s3.isk01.sakurastorage.jp" \
  ghcr.io/r5-revo/comfyui-s3:latest
