FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

# 環境変数の設定
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PATH="/root/.local/bin:$PATH" \
    WORKSPACE=/workspace

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    s3fs \
    fuse \
    rclone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ComfyUIをクローン
WORKDIR /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

# 依存パッケージのインストール
WORKDIR /workspace/ComfyUI
RUN pip3 install --upgrade pip && \
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install -r requirements.txt && \
    pip3 install xformers

# オブジェクトストレージ初期化とComfyUI起動用のスクリプト作成
COPY mount-and-start.sh /workspace/
RUN chmod +x /workspace/mount-and-start.sh

# ポート公開
EXPOSE 8188

# コンテナ起動時のコマンド
CMD ["/workspace/mount-and-start.sh"]
