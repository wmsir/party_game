package com.partygame.game;

import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

/**
 * 谁是卧底权威双词词库 (60组跨主题精选词对 + 拟人化线索库)
 */
public final class UndercoverWordBank {

    private UndercoverWordBank() {}

    public static final List<List<String>> WORD_PAIRS = List.of(
            // 1. 美食小吃
            List.of("汉堡包", "肉夹馍"),
            List.of("小龙虾", "大闸蟹"),
            List.of("烤冷面", "手抓饼"),
            List.of("鸭脖", "鸡爪"),
            List.of("包子", "饺子"),
            List.of("烤肉", "火锅"),
            List.of("面条", "米线"),
            List.of("油条", "麻花"),
            List.of("汤圆", "元宵"),
            List.of("煎饼果子", "鸡蛋灌饼"),
            List.of("臭豆腐", "螺蛳粉"),
            List.of("披萨", "烙饼"),

            // 2. 饮品甜点
            List.of("可口可乐", "百事可乐"),
            List.of("牛奶", "豆浆"),
            List.of("咖啡", "奶茶"),
            List.of("雪糕", "冰棍"),
            List.of("酸奶", "养乐多"),
            List.of("绿茶", "乌龙茶"),
            List.of("西瓜", "哈密瓜"),
            List.of("橙子", "橘子"),
            List.of("草莓", "樱桃"),
            List.of("蛋挞", "泡芙"),

            // 3. 日常生活
            List.of("秋裤", "毛裤"),
            List.of("雨伞", "雨衣"),
            List.of("口红", "唇膏"),
            List.of("枕头", "抱枕"),
            List.of("毛巾", "浴巾"),
            List.of("拖鞋", "凉鞋"),
            List.of("镜子", "玻璃"),
            List.of("风扇", "空调"),
            List.of("铅笔", "钢笔"),
            List.of("牙刷", "牙线"),
            List.of("眼镜", "墨镜"),
            List.of("背包", "行李箱"),

            // 4. 娱乐运动
            List.of("跳绳", "拔河"),
            List.of("象棋", "围棋"),
            List.of("吉他", "尤克里里"),
            List.of("乒乓球", "羽毛球"),
            List.of("扑克", "麻将"),
            List.of("KTV", "演唱会"),
            List.of("电影院", "话剧院"),
            List.of("过山车", "摩天轮"),

            // 5. 自然地理
            List.of("森林", "树林"),
            List.of("瀑布", "喷泉"),
            List.of("日出", "晚霞"),
            List.of("雪花", "冰雹"),
            List.of("湖泊", "海洋"),
            List.of("玫瑰", "月季"),
            List.of("向日葵", "菊花"),
            List.of("蝴蝶", "蜜蜂"),

            // 6. 科技潮流
            List.of("微信", "QQ"),
            List.of("手机", "平板"),
            List.of("自行车", "电动车"),
            List.of("高铁", "地铁"),
            List.of("耳机", "音箱"),
            List.of("相机", "手机支架"),
            List.of("朋友圈", "微博"),
            List.of("笔记本", "台式机"),
            List.of("浏览器", "搜索引擎"),
            List.of("快递", "外卖")
    );

    private static final Map<String, List<String>> CLUE_MAP = new HashMap<>();

    static {
        addClues("汉堡包", "两片面包夹着馅料", "快餐店很常见的主食", "通常配炸鸡可乐一起吃");
        addClues("肉夹馍", "外皮烤得酥脆里面夹肉", "陕西街头特别有名的碳水", "咬一口汁水很香");
        addClues("可口可乐", "红色包装的碳酸饮料", "加冰块喝特别带劲", "快乐肥宅水代表之一");
        addClues("百事可乐", "蓝色罐子装的气泡水", "甜度略高一点的碳酸饮品", "很多快餐套餐会配这个");
        addClues("小龙虾", "夜宵摊的绝对C位", "戴着手套剥壳才过瘾", "麻辣和蒜蓉口味最经典");
        addClues("大闸蟹", "秋天肥美膏黄特别多", "吃的时候需要配姜醋", "绑着绳子蒸熟变红");
        addClues("牛奶", "早上补充蛋白质的饮品", "白色液体奶香浓郁", "睡前喝一杯挺助眠");
        addClues("豆浆", "早餐店配油条的绝佳搭档", "植物蛋白磨出来的热饮", "有甜口也有咸口喝法");
        addClues("咖啡", "打工人早起续命神器", "微苦回甘提神醒脑", "可以做成拿铁或美式");
        addClues("奶茶", "逛街人手一杯的快乐水", "可以加珍珠椰果和小料", "选几分糖经常纠结很久");
        addClues("烤肉", "铁板上滋滋冒油特别香", "要用生菜包着蘸料吃", "和朋友围着炉子自己动手");
        addClues("火锅", "一群人聚餐最热闹的选择", "中间有鸳鸯锅分清汤红油", "下毛肚和肥牛讲究七上八下");
        addClues("微信", "现在每天打开频率最高的软件", "发红包和视频通话都靠它", "上面能刷朋友动态也能扫码支付");
        addClues("QQ", "企鹅图标承载很多青春回忆", "以前流行挂等级和踩空间", "群文件传大文件特别好用");
        addClues("手机", "出门忘带会非常焦虑的设备", "每天电量低于20%就慌", "揣在兜里能刷视频也能付款");
        addClues("平板", "屏幕比掌机大但比电脑轻便", "买前生产力买后爱奇艺", "窝在沙发上追剧看漫画超爽");
        addClues("吉他", "弹唱民谣最常用的六弦乐器", "抱着扫弦很有氛围感", "新手入门经常练按和弦手疼");
        addClues("尤克里里", "个头小小四根弦很好携带", "海边弹奏声音清脆欢快", "看起来像迷你版弹拨乐器");
        addClues("自行车", "靠双腿踩踏前进的环保工具", "车筐里可以放随身物品", "景区和校园里骑着很惬意");
        addClues("电动车", "拧一下把手就能轻松代步", "记得戴头盔和定期充电", "短途通勤比开车还不怕堵");
        addClues("秋裤", "降温后妈妈总会提醒穿上的单品", "贴身穿在长裤里面的保暖层", "北方人过冬的基础装备");
        addClues("毛裤", "比普通内搭更厚实绒毛多", "寒潮来袭时的终极御寒裤", "穿在里面裤腿会显厚一点");
        addClues("雨伞", "下雨天单手撑开挡水", "有折叠款也有长柄款", "偶尔太阳大也能拿来遮阳");
        addClues("雨衣", "穿在身上能解放双手骑车", "大雨天风再大也不怕吹翻", "透明或者亮色款式很常见");
        addClues("口红", "女生化妆包里必备的提气色单品", "色号多到直男分不清", "吃完饭后需要补涂一下");
        addClues("唇膏", "主要作用是滋润嘴唇防干裂", "秋冬风大时男女都会涂", "通常没有太浓的颜色");
        addClues("包子", "早点铺笼屉里冒热气的发酵面食", "里面包着肉馅或菜馅", "边走边吃很方便顶饱");
        addClues("饺子", "过年北方家庭团圆必吃美食", "皮薄馅大煮完蘸醋吃", "自己在家包还能包出元宝形状");
        addClues("高铁", "跨省出行速度超快的地面交通", "车厢安静平稳还能吃盒饭", "买票都要刷身份证进站");
        addClues("地铁", "城市地下穿梭最准时的通勤工具", "早高峰经常挤得水泄不通", "进出站刷乘车码就行");
    }

    private static void addClues(String word, String... clues) {
        CLUE_MAP.put(word, Arrays.asList(clues));
    }

    public static List<String> pickRandomPair() {
        return WORD_PAIRS.get(ThreadLocalRandom.current().nextInt(WORD_PAIRS.size()));
    }

    public static String pickClue(String word, Set<String> usedClues) {
        if (word == null || word.isBlank()) {
            // 白板 AI 发言：模糊试探
            List<String> blankClues = List.of(
                    "这个东西在生活里其实蛮常见的，就是用途看人习惯~",
                    "跟大家描述的挺贴近的，我平时偶尔也会接触到！",
                    "不算太冷门吧，说得再具体就太明显了~"
            );
            return blankClues.get(ThreadLocalRandom.current().nextInt(blankClues.size()));
        }

        List<String> specific = CLUE_MAP.get(word);
        if (specific != null && !specific.isEmpty()) {
            List<String> unused = new ArrayList<>();
            for (String c : specific) {
                if (usedClues == null || !usedClues.contains(c)) {
                    unused.add(c);
                }
            }
            List<String> pool = unused.isEmpty() ? specific : unused;
            String chosen = pool.get(ThreadLocalRandom.current().nextInt(pool.size()));
            if (usedClues != null) usedClues.add(chosen);
            return chosen;
        }

        List<String> generic = List.of(
                "这东西大家平时多少都见过或用过，挺生活化的~",
                "它的特点蛮鲜明的，但跟另一个相似词很容易混淆！",
                "第一反应就能想到它的画面，跟吃喝玩乐或日常有关！",
                "我先保留一点细节，听听后面几位的描述再说~"
        );
        return generic.get(ThreadLocalRandom.current().nextInt(generic.size()));
    }
}
