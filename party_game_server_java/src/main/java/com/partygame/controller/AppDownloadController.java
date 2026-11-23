package com.partygame.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StreamUtils;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
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

    @GetMapping(value = {"/download/app", "/party-game/download/app", "/landing", "/party-game/landing"}, produces = MediaType.TEXT_HTML_VALUE + ";charset=UTF-8")
    public ResponseEntity<String> downloadPage(HttpServletRequest request) {
        File file = getApkFile();
        boolean exists = file.exists();
        String apkFileName = exists ? file.getName() : "party_game_app_latest.apk";
        String sizeMbText = exists ? String.format("%.2f MB", file.length() / (1024.0 * 1024.0)) : "约 45 MB (待部署上传)";
        String modTime = exists ? new SimpleDateFormat("yyyy-MM-dd HH:mm").format(new Date(file.lastModified())) : "随版本构建自动更新";

        // 从文件名解析版本号，如 party_game_app_v1.0.12.apk -> v1.0.12
        String displayVersion = "最新正式版";
        if (apkFileName.contains("_v") && apkFileName.endsWith(".apk")) {
            displayVersion = apkFileName.substring(apkFileName.indexOf("_v") + 1, apkFileName.length() - 4);
        }

        String uri = request != null && request.getRequestURI() != null ? request.getRequestURI() : "";
        String prefix = uri.startsWith("/party-game") ? "/party-game" : "";
        String downloadUrl = prefix + "/download/" + apkFileName + "?t=" + System.currentTimeMillis();
        String webPlayUrl = prefix + "/play";
        String statusBadge = exists ? "官方正式签发包 · 可直接安装" : "当前环境尚未上传 APK · 可立即体验网页版";

        try {
            ClassPathResource tpl = new ClassPathResource("static/download.html");
            String html = StreamUtils.copyToString(tpl.getInputStream(), StandardCharsets.UTF_8)
                    .replace("{{VERSION}}", displayVersion)
                    .replace("{{APK_NAME}}", apkFileName)
                    .replace("{{SIZE_MB}}", sizeMbText)
                    .replace("{{MOD_TIME}}", modTime)
                    .replace("{{DOWNLOAD_URL}}", downloadUrl)
                    .replace("{{WEB_PLAY_URL}}", webPlayUrl)
                    .replace("{{STATUS_BADGE}}", statusBadge);
            return ResponseEntity.ok(html);
        } catch (IOException e) {
            String fallbackHtml = "<!DOCTYPE html><html lang='zh-CN'><head><meta charset='utf-8'>"
                    + "<meta name='viewport' content='width=device-width, initial-scale=1.0'>"
                    + "<title>聚会桌游吧下载 (" + displayVersion + ")</title></head>"
                    + "<body style='font-family:sans-serif;background:#0f172a;color:#f8fafc;text-align:center;padding:48px 20px;'>"
                    + "<h1>🎲 聚会桌游吧 (" + displayVersion + ")</h1>"
                    + "<p style='color:#94a3b8;margin:12px 0 24px;'>" + statusBadge + "</p>"
                    + "<p><a href='" + downloadUrl + "' style='display:inline-block;padding:12px 24px;background:#10b981;color:#fff;border-radius:12px;text-decoration:none;font-weight:bold;'>立即下载 " + apkFileName + "</a></p>"
                    + "<p style='margin-top:16px;'><a href='" + webPlayUrl + "' style='color:#38bdf8;'>进入官方网页版</a></p>"
                    + "</body></html>";
            return ResponseEntity.ok(fallbackHtml);
        }
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
