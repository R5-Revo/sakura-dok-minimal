FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

# 環境変数の設定
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    git \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを設定
WORKDIR /workspace

# ComfyUIのクローン
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

# Python依存関係のインストール
# 互換性のあるPyTorchとtorchvisionのバージョンを指定
WORKDIR /workspace/ComfyUI
RUN pip3 install --no-cache-dir torch==2.0.1+cu118 torchvision==0.15.2+cu118 -f https://download.pytorch.org/whl/torch_stable.html
RUN pip3 install --no-cache-dir -r requirements.txt

# S3マウントツールのインストール
RUN apt-get update && apt-get install -y \
    s3fs \
    fuse \
    rclone \
    && rm -rf /var/lib/apt/lists/*

# 起動スクリプトの作成
RUN echo '#!/bin/bash\n\
\n\
# S3マウントの設定（環境変数が存在する場合）\n\
if [ -n "$S3_BUCKET" ] && [ -n "$S3_ENDPOINT" ] && [ -n "$S3_ACCESS_KEY" ] && [ -n "$S3_SECRET_KEY" ]; then\n\
  echo "Setting up S3 storage..."\n\
  mkdir -p /workspace/storage\n\
  \n\
  # S3FS接続情報の設定\n\
  echo "$S3_ACCESS_KEY:$S3_SECRET_KEY" > /etc/passwd-s3fs\n\
  chmod 600 /etc/passwd-s3fs\n\
  \n\
  # 完全なエンドポイントURLの確認\n\
  if [[ "$S3_ENDPOINT" != http* ]]; then\n\
    S3_ENDPOINT="https://$S3_ENDPOINT"\n\
    echo "Updated S3_ENDPOINT to include protocol: $S3_ENDPOINT"\n\
  fi\n\
  \n\
  echo "Mounting S3 bucket to /workspace/storage..."\n\
  s3fs "$S3_BUCKET" /workspace/storage \\\n\
    -o passwd_file=/etc/passwd-s3fs \\\n\
    -o url="$S3_ENDPOINT" \\\n\
    -o allow_other,use_path_request_style\n\
  \n\
  # S3FSマウントが失敗した場合、rcloneを使用\n\
  if [ $? -ne 0 ]; then\n\
    echo "WARNING: S3FS mount failed. Falling back to rclone."\n\
    \n\
    # rclone設定\n\
    mkdir -p /root/.config/rclone\n\
    cat > /root/.config/rclone/rclone.conf << EOF\n\
[s3]\n\
type = s3\n\
provider = Other\n\
access_key_id = $S3_ACCESS_KEY\n\
secret_access_key = $S3_SECRET_KEY\n\
endpoint = $S3_ENDPOINT\n\
acl = private\n\
EOF\n\
    \n\
    echo "Testing rclone connection..."\n\
    rclone lsd s3:$S3_BUCKET\n\
    \n\
    if [ $? -ne 0 ]; then\n\
      echo "ERROR: Both S3FS and rclone failed. Using local storage only."\n\
    else\n\
      echo "Mounting with rclone..."\n\
      rclone mount s3:$S3_BUCKET /workspace/storage --daemon\n\
    fi\n\
  fi\n\
else\n\
  echo "S3 environment variables not set. Using local storage only."\n\
fi\n\
\n\
# ComfyUIの起動\n\
cd /workspace/ComfyUI\n\
python3 main.py --listen 0.0.0.0 --port 8188\n\
' > /workspace/start.sh

RUN chmod +x /workspace/start.sh

# ComfyUIのポートを公開
EXPOSE 8188

# 起動コマンド
CMD ["/workspace/start.sh"]
