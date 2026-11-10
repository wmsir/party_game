package com.partygame.controller;

import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;

@RestController
@CrossOrigin(origins = "*")
public class AppDownloadController {

    private File getApkFile() {
        // 优先查找带版本号的正式安装包 party_game_app_v*.apk
        String[] dirs = new String[]{"/app/uploads", "/opt/party_game_server/uploads", "/opt/party_game_server", "."};
        for (String d : dirs) {
            File dir = new File(d);
            if (dir.exists() && dir.isDirectory()) {
                File[] list = dir.listFiles((dir1, name) -> name.startsWith("party_game_app_v") && name.endsWith(".apk"));
                if (list != null && list.length > 0) {
                    // 取修改时间最新的那个版本
                    File newest = list[0];
                    for (File f : list) {
                        if (f.lastModified() > newest.lastModified()) {
                            newest = f;
                        }
                    }
                    return newest;
                }
            }
        }
        File f1 = new File("/app/uploads/party_game_app_latest.apk");
        if (f1.exists()) return f1;
        File f2 = new File("/opt/party_game_server/uploads/party_game_app_latest.apk");
        if (f2.exists()) return f2;
        File f3 = new File("/opt/party_game_server/party_game_app_latest.apk");
        if (f3.exists()) return f3;
        File f4 = new File("party_game_app_latest.apk");
        if (f4.exists()) return f4;
        return f1;
    }

    @GetMapping(value = {"/download/app", "/party-game/download/app"}, produces = MediaType.TEXT_HTML_VALUE + ";charset=UTF-8")
    public ResponseEntity<String> downloadPage() {
        File file = getApkFile();
        boolean exists = file.exists();
        String apkFileName = exists ? file.getName() : "party_game_app_latest.apk";
        double sizeMb = exists ? (file.length() / (1024.0 * 1024.0)) : 0;
        String modTime = exists ? new SimpleDateFormat("yyyy-MM-dd HH:mm").format(new Date(file.lastModified())) : "暂未就绪";

        // 从文件名解析版本号，如 party_game_app_v1.0.12.apk -> v1.0.12
        String displayVersion = "最新正式版";
        if (apkFileName.contains("_v") && apkFileName.endsWith(".apk")) {
            displayVersion = apkFileName.substring(apkFileName.indexOf("_v") + 1, apkFileName.length() - 4);
        }

        String html = "<!DOCTYPE html><html lang='zh-CN'><head><meta charset='utf-8'>"
            + "<meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'>"
            + "<title>聚会桌游吧 - 官方最新客户端下载 (" + displayVersion + ")</title>"
            + "<style>"
            + "*{box-sizing:border-box;margin:0;padding:0;}"
            + "body{font-family:-apple-system,BlinkMacSystemFont,'PingFang SC','Hiragino Sans GB','Microsoft YaHei',sans-serif;"
            + "background:linear-gradient(135deg,#0f172a 0%,#1e1b4b 100%);color:#f8fafc;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:20px;}"
            + ".card{background:rgba(30,41,59,0.85);backdrop-filter:blur(16px);border:1px solid rgba(255,255,255,0.12);border-radius:24px;padding:32px 24px;width:100%;max-width:380px;text-align:center;box-shadow:0 20px 40px rgba(0,0,0,0.6);}"
            + ".logo-box{width:80px;height:80px;background:linear-gradient(135deg,#10b981,#059669);border-radius:20px;margin:0 auto 16px;display:flex;align-items:center;justify-content:center;font-size:42px;box-shadow:0 8px 24px rgba(16,185,129,0.35);}"
            + ".title{font-size:22px;font-weight:bold;margin-bottom:8px;color:#ffffff;}"
            + ".subtitle{font-size:13px;color:#94a3b8;margin-bottom:20px;}"
            + ".info-box{background:rgba(15,23,42,0.6);border-radius:14px;padding:12px 16px;margin-bottom:24px;text-align:left;font-size:12px;color:#cbd5e1;line-height:1.8;border:1px solid rgba(255,255,255,0.06);}"
            + ".info-row{display:flex;justify-content:space-between;}"
            + ".btn-download{display:block;background:linear-gradient(135deg,#10b981,#059669);color:#ffffff;text-decoration:none;font-size:16px;font-weight:bold;padding:14px;border-radius:14px;box-shadow:0 6px 20px rgba(16,185,129,0.4);transition:all 0.2s;}"
            + ".btn-download:active{transform:scale(0.98);opacity:0.9;}"
            + ".tip{font-size:11px;color:#64748b;margin-top:16px;line-height:1.5;}"
            + "</style></head><body><div class='card'>"
            + "<div class='logo-box'>🎲</div>"
            + "<div class='title'>聚会桌游吧</div>"
            + "<div class='subtitle'>腾讯级房间与大厅 · 极速云端直连</div>"
            + "<div class='info-box'>"
            + "<div class='info-row'><span>应用版本：</span><strong style='color:#10b981;'>" + displayVersion + " (带版本号安装包)</strong></div>"
            + "<div class='info-row'><span>安装包名称：</span><span style='color:#38bdf8;font-size:11px;'>" + apkFileName + "</span></div>"
            + "<div class='info-row'><span>安装包大小：</span><strong>" + String.format("%.2f MB", sizeMb) + "</strong></div>"
            + "<div class='info-row'><span>构建时间：</span><strong>" + modTime + "</strong></div>"
            + "<div class='info-row'><span>系统支持：</span><strong>Android 5.0+ (ARM/x86通用)</strong></div>"
            + "</div>"
            + "<a href='/party-game/download/" + apkFileName + "?t=" + System.currentTimeMillis() + "' class='btn-download'>🚀 立即高速下载 " + apkFileName + "</a>"
            + "<div class='tip'>💡 所有打包文件均自带清晰版本号。若手机曾安装过旧版，建议卸载后安装此最新版本！</div>"
            + "</div></body></html>";
        return ResponseEntity.ok(html);
    }

    @GetMapping(value = {
        "/download/party_game_app_latest.apk",
        "/party-game/download/party_game_app_latest.apk",
        "/download/{apkName:.+\\.apk}",
        "/party-game/download/{apkName:.+\\.apk}"
    })
    public ResponseEntity<Resource> downloadApk() {
        File file = getApkFile();
        if (!file.exists()) {
            return ResponseEntity.notFound().build();
        }
        Resource resource = new FileSystemResource(file);
        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + file.getName() + "\"")
            .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
            .header(HttpHeaders.PRAGMA, "no-cache")
            .header(HttpHeaders.EXPIRES, "0")
            .contentType(MediaType.APPLICATION_OCTET_STREAM)
            .body(resource);
    }
}
