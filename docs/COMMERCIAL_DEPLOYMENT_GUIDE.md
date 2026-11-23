# PartyGame Club — Commercial Production Deployment Guide

This guide covers deploying **PartyGame Club** (`party_game_server_java` + `party_game_app`) in a hardened commercial production environment using Docker Compose, Nginx TLS, MySQL 8.0, SMS/payment providers, and signed Android builds.

---

## 1. Prerequisites
- Linux server (Ubuntu 22.04+ / Debian 12+, 2 vCPU / 4 GB RAM recommended)
- Docker Engine & Docker Compose plugin (`docker compose version`)
- A registered domain name pointed to your server's public IP (required for HTTPS + `wss://`)

---

## 2. Configure Production Environment
1. Copy the template environment file:
   ```bash
   cd party_game_server_java
   cp .env.example .env
   ```
2. Generate a BCrypt hash for the Operations Admin Console (`/admin`) password:
   ```bash
   python3 -c 'import bcrypt; print(bcrypt.hashpw(b"ReplaceWithStrongAdminPassword!", bcrypt.gensalt()).decode())'
   ```
   Paste the resulting `$2b$...` hash into `PARTY_ADMIN_PASSWORD_HASH` in `.env` (or leave empty only if using an allowlisted account in `PARTY_ADMIN_USERNAMES`).
3. Set production security flags in `.env`:
   - `PARTY_ALLOW_PASSWORDLESS_PHONE=false`
   - `PARTY_SMS_SANDBOX=false`
   - `PARTY_PAYMENT_SANDBOX=false`
   - `PARTY_PUBLIC_BASE_URL=https://play.yourdomain.com`
   - `PARTY_CORS_ALLOWED_ORIGINS=https://play.yourdomain.com`
   - `PARTY_WS_ALLOWED_ORIGINS=https://play.yourdomain.com`

---

## 3. Start Docker Compose Stack
```bash
cd party_game_server_java
mkdir -p uploads deploy/ssl
docker compose up -d --build
```
Verify container health:
```bash
docker compose ps
curl -fsS http://127.0.0.1:9001/health
curl -fsS http://127.0.0.1:9001/actuator/health
```

---

## 4. Enable HTTPS & WebSocket (`wss://`)
1. Provision TLS certificates (e.g., via Certbot on the host or ACME webroot) and place `fullchain.pem` and `privkey.pem` inside `party_game_server_java/deploy/ssl/`.
2. Open `party_game_server_java/deploy/nginx.conf`, uncomment the `server { listen 443 ssl http2; ... }` block, and update `server_name` to your domain.
3. Reload Nginx:
   ```bash
   docker compose exec nginx nginx -t && docker compose exec nginx nginx -s reload
   ```

---

## 5. SMS & Payment Integration
- **SMS Gateway**: Log into `https://play.yourdomain.com/admin`, open the **短信网关** tab, choose `ALIYUN` or `TENCENT`, fill your AccessKey/SecretId/SignName/TemplateCode, and save. Secrets are masked on read (`********`) and preserved when updating non-secret fields.
- **Payment Orders**:
  - Client creates a `PENDING` order via `POST /api/shop/order/create`.
  - When your WeChat Pay / Alipay server-side notify webhook verifies the payment signature, call `ShopService.confirmOrder(orderId, tradeNo)` (or `POST /api/shop/order/confirm` from your internal payment gateway) to credit diamonds, coins, and VIP EXP idempotently.
  - Because `PARTY_PAYMENT_SANDBOX=false`, direct sandbox recharge calls to `/api/shop/pay` and `/api/shop/first-recharge` are blocked in production.

---

## 6. Android Release Keystore Signing (CI)
To ship Google Play `.aab` and production `.apk` builds from `.github/workflows/build-multiplatform.yml`, add these repository secrets in GitHub Settings → Secrets and variables → Actions:
- `ANDROID_KEYSTORE_BASE64`: Base64-encoded `.jks` keystore (`base64 -w 0 upload-keystore.jks`)
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias
- `ANDROID_KEY_PASSWORD`: Key password

---

## 7. Backup & Operations Monitoring
- **MySQL Automated Daily Backup** (cron):
  ```bash
  0 3 * * * docker exec party-game-mysql mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" party_game_db | gzip > /opt/backups/party_game_$(date +\%F).sql.gz
  ```
- **Live Monitoring**:
  - Health probe: `GET /health` & `GET /actuator/health`
  - Operations Dashboard (`/admin`): real-time KPIs, live active rooms, active WebSocket count, payment order ledger (`GET /api/admin/orders`), and 24-hour player activity heatmap.
