FROM ghcr.io/ai-dock/comfyui:latest-cuda

# rcloneをインストール
RUN apt-get update && apt-get install -y \
    rclone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 起動スクリプトを作成
RUN echo '#!/bin/bash\n\
\n\
# rcloneの設定ファイルを作成\n\
mkdir -p /root/.config/rclone\n\
cat > /root/.config/rclone/rclone.conf << EOF\n\
[sakura]\n\
type = s3\n\
env_auth = false\n\
access_key_id = ${S3_ACCESS_KEY}\n\
secret_access_key = ${S3_SECRET_KEY}\n\
endpoint = https://${S3_ENDPOINT}\n\
region = \n\
location_constraint = \n\
EOF\n\
\n\
# 必要なディレクトリを作成\n\
mkdir -p /opt/ComfyUI/models\n\
mkdir -p /opt/ComfyUI/custom_nodes\n\
mkdir -p /opt/ComfyUI/workflows\n\
mkdir -p /opt/ComfyUI/output\n\
\n\
# オブジェクトストレージからデータを初期同期\n\
echo "初期同期: オブジェクトストレージからデータをダウンロード"\n\
# モデル\n\
rclone copy sakura:${S3_BUCKET}/models /opt/ComfyUI/models --progress\n\
# LoRA\n\
rclone copy sakura:${S3_BUCKET}/loras /opt/ComfyUI/models/loras --progress\n\
# カスタムノード\n\
rclone copy sakura:${S3_BUCKET}/custom_nodes /opt/ComfyUI/custom_nodes --progress\n\
# ワークフロー\n\
rclone copy sakura:${S3_BUCKET}/workflows /opt/ComfyUI/workflows --progress\n\
# 設定ファイル\n\
rclone copy sakura:${S3_BUCKET}/config /opt/ComfyUI/config --progress\n\
\n\
# バックグラウンドで定期的に同期\n\
(while true; do \n\
  sleep 300\n\
  echo "定期同期: $(date)"\n\
  # 出力を同期\n\
  rclone copy /opt/ComfyUI/output sakura:${S3_BUCKET}/output --progress --update\n\
  # ワークフローを同期\n\
  rclone copy /opt/ComfyUI/workflows sakura:${S3_BUCKET}/workflows --progress --update\n\
  # 設定ファイルを同期\n\
  rclone copy /opt/ComfyUI/config sakura:${S3_BUCKET}/config --progress --update\n\
done) &\n\
\n\
# オリジナルの起動スクリプトを実行\n\
exec /start.sh "$@"' > /opt/startup.sh

RUN chmod +x /opt/startup.sh

# 起動スクリプトを実行するように設定
ENTRYPOINT ["/opt/startup.sh"]
