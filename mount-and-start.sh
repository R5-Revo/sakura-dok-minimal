#!/bin/bash

echo "Starting S3 mount process and ComfyUI..."

# 環境変数の確認
echo "Environment variables:"
echo "S3_BUCKET: ${S3_BUCKET:-not set}"
echo "S3_ENDPOINT: ${S3_ENDPOINT:-not set}"
echo "S3_ACCESS_KEY: ${S3_ACCESS_KEY:0:3}... (masked for security)"
echo "S3_SECRET_KEY: ${S3_SECRET_KEY:0:3}... (masked for security)"

# 必要な環境変数がセットされているか確認
if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ] || [ -z "$S3_BUCKET" ] || [ -z "$S3_ENDPOINT" ]; then
  echo "WARNING: S3 environment variables not fully set. Storage mounting will be skipped."
else
  # S3マウントプロセスを開始
  echo "Setting up S3 storage..."
  
  # 認証情報をファイルに保存
  echo "$S3_ACCESS_KEY:$S3_SECRET_KEY" > /etc/passwd-s3fs
  chmod 600 /etc/passwd-s3fs
  
  # ストレージディレクトリを作成
  mkdir -p /workspace/storage
  
  echo "Mounting S3 bucket to /workspace/storage..."
  # s3fsでマウント
  s3fs "$S3_BUCKET" /workspace/storage \
    -o passwd_file=/etc/passwd-s3fs \
    -o url="$S3_ENDPOINT" \
    -o allow_other,use_path_request_style,nomultipart \
    -f &
  
  S3FS_PID=$!
  sleep 5
  
  # マウントが成功したか確認
  if kill -0 $S3FS_PID 2>/dev/null; then
    echo "S3FS mounted successfully with PID $S3FS_PID"
    
    # マウント状態を表示
    echo "Mount points:"
    mount | grep s3fs
    
    echo "Storage directory contents:"
    ls -la /workspace/storage/
    
    # 必要なディレクトリ構造を作成
    mkdir -p /workspace/storage/models
    mkdir -p /workspace/storage/output
    mkdir -p /workspace/storage/input
    
    # ComfyUIのディレクトリをシンボリックリンク
    echo "Setting up ComfyUI directory symlinks..."
    
    # モデルディレクトリのリンク
    if [ -d "/workspace/ComfyUI/models" ]; then
      mv /workspace/ComfyUI/models/* /workspace/storage/models/ 2>/dev/null || true
      rm -rf /workspace/ComfyUI/models
    fi
    ln -sfn /workspace/storage/models /workspace/ComfyUI/models
    echo "Models directory linked: $(readlink -f /workspace/ComfyUI/models)"
    
    # 出力ディレクトリのリンク
    if [ -d "/workspace/ComfyUI/output" ]; then
      mv /workspace/ComfyUI/output/* /workspace/storage/output/ 2>/dev/null || true
      rm -rf /workspace/ComfyUI/output
    fi
    ln -sfn /workspace/storage/output /workspace/ComfyUI/output
    echo "Output directory linked: $(readlink -f /workspace/ComfyUI/output)"
    
    # 入力ディレクトリのリンク
    if [ -d "/workspace/ComfyUI/input" ]; then
      mv /workspace/ComfyUI/input/* /workspace/storage/input/ 2>/dev/null || true
      rm -rf /workspace/ComfyUI/input
    fi
    ln -sfn /workspace/storage/input /workspace/ComfyUI/input
    echo "Input directory linked: $(readlink -f /workspace/ComfyUI/input)"
    
  else
    echo "WARNING: S3FS mount failed. Falling back to rclone."
    
    # rcloneでの代替アプローチを試みる
    mkdir -p /root/.config/rclone
    cat > /root/.config/rclone/rclone.conf <<EOF
[sakura]
type = s3
env_auth = false
access_key_id = $S3_ACCESS_KEY
secret_access_key = $S3_SECRET_KEY
endpoint = $S3_ENDPOINT
region = 
location_constraint = 
EOF
    
    # rcloneでの接続テスト
    echo "Testing rclone connection..."
    rclone lsd sakura:$S3_BUCKET
    
    if [ $? -eq 0 ]; then
      echo "Rclone connection successful. Setting up sync..."
      mkdir -p /workspace/storage
      
      # 初期同期
      rclone copy sakura:$S3_BUCKET /workspace/storage --progress
      
      # バックグラウンドで定期的に同期を実行
      (while true; do 
        sleep 300
        echo "Running periodic sync at $(date)"
        rclone copy /workspace/storage sakura:$S3_BUCKET --progress --update
        echo "Sync completed at $(date)"
      done) &
      
      # 必要なディレクトリと同じくシンボリックリンクを設定
      mkdir -p /workspace/storage/models
      mkdir -p /workspace/storage/output
      mkdir -p /workspace/storage/input
      
      # リンクを設定
      ln -sfn /workspace/storage/models /workspace/ComfyUI/models
      ln -sfn /workspace/storage/output /workspace/ComfyUI/output
      ln -sfn /workspace/storage/input /workspace/ComfyUI/input
    else
      echo "ERROR: Both S3FS and rclone failed. Using local storage only."
    fi
  fi
fi

# ComfyUIの実行
echo "Starting ComfyUI..."
cd /workspace/ComfyUI
python3 main.py --listen --port 8188
