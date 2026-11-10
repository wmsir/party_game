# -*- coding: utf-8 -*-
"""
================================================================================
聚会桌游微服务 (PartyGameServer-Java) - 远程服务器一键原生编译与部署脚本
================================================================================
"""

import os
import sys
import time
import tarfile
import paramiko
import urllib.request
import json

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

REMOTE_HOST = '39.97.158.22'
REMOTE_PORT = 22
REMOTE_USER = 'root'
REMOTE_PASS = os.environ.get('FWPT_SSH_PASSWORD', '')
REMOTE_DIR  = '/opt/party_game_server'

LOCAL_DIR = os.path.abspath(os.path.dirname(__file__))

def log(msg):
    print(f"[\033[92mPARTY-GAME-JAVA\033[0m] {msg}")

def create_ssh():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(REMOTE_HOST, port=REMOTE_PORT, username=REMOTE_USER, password=REMOTE_PASS, timeout=15)
    return ssh

def exec_ssh(ssh, cmd):
    log(f"远程执行: {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='ignore')
    err = stderr.read().decode('utf-8', errors='ignore')
    if out.strip():
        print(out.strip())
    if err.strip() and ('error' in err.lower() or 'failed' in err.lower()):
        print(f"[远程输出警告] {err.strip()[:300]}")
    return out.strip()

def main():
    log("==================================================================")
    log(">>> 开始部署聚会桌游 Java 生产后端 (Spring Boot 3 + JPA + MySQL)")
    log("==================================================================")

    ssh = create_ssh()
    sftp = ssh.open_sftp()

    # 1. 创建远程目录
    exec_ssh(ssh, f"mkdir -p {REMOTE_DIR}")

    # 2. 打包本地 Java 源码
    tar_path = os.path.join(LOCAL_DIR, 'java_src.tar.gz')
    if os.path.exists(tar_path):
        os.remove(tar_path)

    log("本地归档 Java 源码与配置文件...")
    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(os.path.join(LOCAL_DIR, 'src'), arcname='src')
        tar.add(os.path.join(LOCAL_DIR, 'pom.xml'), arcname='pom.xml')
        tar.add(os.path.join(LOCAL_DIR, 'Dockerfile'), arcname='Dockerfile')
        tar.add(os.path.join(LOCAL_DIR, 'docker-compose.yml'), arcname='docker-compose.yml')

    remote_tar = f"{REMOTE_DIR}/java_src.tar.gz"
    log(f"SFTP 同步源码包至云端: {remote_tar} ({os.path.getsize(tar_path)/1024:.1f} KB)...")
    sftp.put(tar_path, remote_tar)
    os.remove(tar_path)

    # 3. 解压并在云端原生 Linux 执行 Maven 编译
    log("云端解压源码并执行 Maven 原生极速编译 (mvn clean package -DskipTests)...")
    build_cmds = (
        f"cd {REMOTE_DIR} && "
        f"tar -xzf java_src.tar.gz && "
        "export LANG=en_US.UTF-8 && export LC_ALL=en_US.UTF-8 && "
        "mvn clean package -DskipTests -Dfile.encoding=UTF-8"
    )
    build_out = exec_ssh(ssh, build_cmds)
    if "BUILD SUCCESS" not in build_out:
        log("[ERROR] 云端 Maven 编译失败！")
        print(build_out[-1500:])
        ssh.close()
        sys.exit(1)

    log("✓ 云端 Maven 原生编译构建成功 (BUILD SUCCESS)！")

    # 4. 构建并启动 Docker 容器
    log("重新构建并拉起 party-game-server Docker 容器...")
    docker_cmds = (
        f"cd {REMOTE_DIR} && "
        "docker compose down || true && "
        "docker compose build --no-cache && "
        "docker compose up -d --force-recreate"
    )
    exec_ssh(ssh, docker_cmds)

    # 5. 等待容器完全启动并进行健康巡检
    log("等待 Spring Boot 容器启动并完成 MySQL 表结构自动更新 (10秒)...")
    time.sleep(10)

    health_check_cmd = "curl -s http://127.0.0.1:9001/health || echo 'FAIL'"
    health_resp = exec_ssh(ssh, health_check_cmd)
    log(f"云端本地健康检查响应: {health_resp}")

    # 6. 检查 RDS party_game_db 中是否已自动建立表结构
    table_check_cmd = "mysql -h $DB_HOST -u root -p$DB_PASSWORD -D party_game_db -e 'SHOW TABLES;' 2>&1"
    tables_out = exec_ssh(ssh, table_check_cmd)
    log(f"MySQL party_game_db 数据表状态:\n{tables_out}")

    sftp.close()
    ssh.close()

    log("==================================================================")
    log("🎉 聚会桌游 Java 生产后端微服务已成功构建并发布！")
    log("==================================================================")

if __name__ == '__main__':
    main()
