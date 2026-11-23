package com.partygame.game;

import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

/**
 * 聚会大冒险大转盘 - 权威分场景题库与转盘扇区配置
 */
public final class PartyWheelPromptBank {

    private PartyWheelPromptBank() {}

    public static final List<Map<String, String>> SEGMENTS = List.of(
            Map.of("label", "喝半杯", "type", "DRINK"),
            Map.of("label", "真心话", "type", "TRUTH"),
            Map.of("label", "左边喝", "type", "DRINK"),
            Map.of("label", "大冒险", "type", "DARE"),
            Map.of("label", "右边喝", "type", "DRINK"),
            Map.of("label", "免罚金牌", "type", "LUCKY"),
            Map.of("label", "全场干杯", "type", "DRINK"),
            Map.of("label", "指定一人", "type", "DRINK")
    );

    private static final Map<String, List<String>> TRUTH_BY_PACK = Map.of(
            "icebreaker", List.of(
                    "全场你对谁的第一印象最好？为什么？",
                    "最近一次社死或尴尬经历是什么？",
                    "手机里最近一张自拍是什么时候拍的？",
                    "如果中了 500 万，你会立刻辞职还是继续上班？",
                    "你最拿手的一道菜或隐藏才艺是什么？",
                    "大学或工作以来最疯狂的一次熬夜在干嘛？"
            ),
            "friends", List.of(
                    "现场谁看起来最像“喝醉了会哭或发疯”的人？",
                    "你手机里最不舍得删的一张朋友黑照是谁的？",
                    "做过最疯狂、从来没告诉过家人的事情是什么？",
                    "上次悄悄买单或送朋友礼物最肉痛的一次花了多少？",
                    "在场谁借钱最可能忘还（纯玩笑）？",
                    "说出你和现场某位好友之间最难忘的一件糗事！"
            ),
            "couple", List.of(
                    "谈过几次恋爱？最心动的一瞬间是什么？",
                    "对方哪个小习惯让你觉得超级可爱？",
                    "如果可以和在场某位交换一天人生，你想选谁？",
                    "你最看重伴侣的哪三个特质？",
                    "收到过最浪漫或最离谱的礼物是什么？",
                    "异地/忙碌时最希望另一半为你做哪件小事？"
            ),
            "talent", List.of(
                    "如果上台参加才艺选秀，你会表演什么绝活？",
                    "你最喜欢的一首歌是什么，为什么有故事？",
                    "小时候最想成为的职业是什么？现在实现几分？",
                    "最拿手的模仿对象是谁？",
                    "人生中最有成就感的一次高光时刻是什么？",
                    "如果拍一部关于你的电影，片名会叫什么？"
            )
    );

    private static final Map<String, List<String>> DARE_BY_PACK = Map.of(
            "icebreaker", List.of(
                    "模仿一种动物的叫声和动作，持续 10 秒！",
                    "用播音腔念一句：“今晚全场的消费由我买单”！",
                    "给左手边第一位玩家认真夸赞 3 个优点！",
                    "现场给大家分享一个手机相册里最近拍的风景/美食图！",
                    "站起来摆一个超级英雄出场 Pose 保持 5 秒！",
                    "用方言念一段绕口令“四是四，十是十”！"
            ),
            "friends", List.of(
                    "给微信置顶或最近联系人发一句“今晚风好大，好想吃夜宵”！",
                    "做 8 个俯卧撑或 10 个深蹲，节奏不能乱！",
                    "和右边玩家深情对视 8 秒，谁先笑谁喝半杯！",
                    "让右边桌友用你手机发一条仅大家可见的搞笑文案！",
                    "模仿现场某位好友的经典口头禅和神态！",
                    "用最深情的语气对着水杯/酒杯念一首情诗！"
            ),
            "couple", List.of(
                    "对右手边或指定好友深情表白 10 秒钟！",
                    "现场比心并说出一句土味情话，不能卡壳！",
                    "让对面玩家指定一个表情，连续做三连拍！",
                    "闭眼猜出右边好友手里拿的小物件是什么！",
                    "大声说出你对在场某位的心动第一眼印象！",
                    "和指定好友击掌十次并同时喊出彼此昵称！"
            ),
            "talent", List.of(
                    "清唱你最拿手的一首歌的高潮部分（至少 4 句）！",
                    "30 秒内说出一个冷笑话，逗笑至少一人算过关！",
                    "用三种不同情绪（开心/委屈/霸道总裁）念“你好呀”！",
                    "即兴跳一段 10 秒钟节奏舞步或手指舞！",
                    "现场表演一段电影经典台词配音！",
                    "单脚金鸡独立坚持 15 秒并背出 7 的乘法口诀！"
            )
    );

    public static Map<String, Object> buildSpinPayload(
            int requestedIdx,
            String scenePack,
            String spinnerName,
            Set<String> usedPrompts) {
        int idx = (requestedIdx >= 0 && requestedIdx < SEGMENTS.size())
                ? requestedIdx
                : ThreadLocalRandom.current().nextInt(SEGMENTS.size());
        Map<String, String> seg = SEGMENTS.get(idx);
        String label = seg.get("label");
        String type = seg.get("type");
        String pack = (scenePack != null && TRUTH_BY_PACK.containsKey(scenePack)) ? scenePack : "icebreaker";

        String promptTitle;
        String promptContent;

        if ("TRUTH".equals(type)) {
            promptTitle = "💬 真心话考验";
            promptContent = pickNonRepeating(TRUTH_BY_PACK.get(pack), usedPrompts, "TRUTH:" + pack + ":");
        } else if ("DARE".equals(type)) {
            promptTitle = "🎭 大冒险挑战";
            promptContent = pickNonRepeating(DARE_BY_PACK.get(pack), usedPrompts, "DARE:" + pack + ":");
        } else if ("LUCKY".equals(type)) {
            promptTitle = "🛡️ 免罚金牌";
            promptContent = "恭喜获得【免罚金牌】1 枚，可抵消本轮或下一轮任意饮酒/惩罚！";
        } else {
            promptTitle = "🍻 酒桌指令";
            promptContent = switch (label) {
                case "喝半杯" -> "爽快干掉半杯，气氛直接拉满！";
                case "左边喝" -> "左手边相邻玩家饮半杯（可用免罚金牌抵消）！";
                case "右边喝" -> "右手边相邻玩家饮半杯（可用免罚金牌抵消）！";
                case "全场干杯" -> "全体碰杯！祝大家玩得开心，干杯！";
                case "指定一人" -> "由转动者指定全场任意一位玩家接受干杯挑战！";
                default -> label;
            };
        }

        Map<String, Object> payload = new HashMap<>();
        payload.put("targetIdx", idx);
        payload.put("segmentLabel", label);
        payload.put("segmentType", type);
        payload.put("scenePack", pack);
        payload.put("promptTitle", promptTitle);
        payload.put("promptContent", promptContent);
        payload.put("spinnerName", spinnerName != null ? spinnerName : "玩家");
        return payload;
    }

    private static String pickNonRepeating(List<String> pool, Set<String> usedPrompts, String prefix) {
        if (pool == null || pool.isEmpty()) return "现场真心分享一个有趣的小故事！";
        List<String> unused = new ArrayList<>();
        for (String item : pool) {
            if (usedPrompts == null || !usedPrompts.contains(prefix + item)) {
                unused.add(item);
            }
        }
        if (unused.isEmpty() && usedPrompts != null) {
            usedPrompts.removeIf(k -> k.startsWith(prefix));
            unused.addAll(pool);
        }
        String chosen = unused.get(ThreadLocalRandom.current().nextInt(unused.size()));
        if (usedPrompts != null) usedPrompts.add(prefix + chosen);
        return chosen;
    }
}
