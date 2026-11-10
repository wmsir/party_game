import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/post_moment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moment_provider.dart';

class MomentsSquareView extends StatefulWidget {
  const MomentsSquareView({super.key});

  @override
  State<MomentsSquareView> createState() => _MomentsSquareViewState();
}

class _MomentsSquareViewState extends State<MomentsSquareView> {
  final TextEditingController _contentCtrl = TextEditingController();
  String _selectedTag = '大话骰';

  final List<String> _tags = ['大话骰', '谁是牛头王', '聚会大冒险', '谁是卧底', '聚会日常'];

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  void _showPublishDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('发布聚会高光动态', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 游戏标签选择
              Wrap(
                spacing: 8,
                children: _tags.map((tag) {
                  final isSelected = tag == _selectedTag;
                  return ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.bgElevated,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setSheetState(() => _selectedTag = tag);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentCtrl,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '分享你的神级反杀、爆笑整蛊或开黑瞬间...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final text = _contentCtrl.text.trim();
                    if (text.isEmpty) return;
                    final momentProv = Provider.of<MomentProvider>(context, listen: false);
                    momentProv.publishMoment(
                      authorId: user.id,
                      authorName: user.nickname,
                      authorAvatar: user.avatar,
                      content: text,
                      gameTag: _selectedTag,
                      recordHighlight: '✨ 玩家【${user.nickname}】的 $_selectedTag 专属动态',
                    );
                    _contentCtrl.clear();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🎉 动态发布成功！')),
                    );
                  },
                  child: const Text('立即发布', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentDialog(PostMomentModel moment) {
    final commentCtrl = TextEditingController();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('评论 ${moment.authorName} 的动态', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '写下你的神评...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.bgDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    final text = commentCtrl.text.trim();
                    if (text.isEmpty) return;
                    Provider.of<MomentProvider>(context, listen: false).addComment(
                      moment.id,
                      user.nickname,
                      text,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final momentProv = Provider.of<MomentProvider>(context);
    final moments = momentProv.moments;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.cardSurface,
        elevation: 0,
        title: const Text('✨ 聚会潮友圈', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: '发动态',
            icon: const Icon(Icons.add_photo_alternate, color: AppColors.primary),
            onPressed: _showPublishDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text('晒高光', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showPublishDialog,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: moments.length,
        itemBuilder: (context, idx) {
          final m = moments[idx];
          return _buildMomentCard(m);
        },
      ),
    );
  }

  Widget _buildMomentCard(PostMomentModel m) {
    final momentProv = Provider.of<MomentProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部作者
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withAlpha(25),
                child: Text(m.authorAvatar, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.authorName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (m.gameTag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withAlpha(60)),
                  ),
                  child: Text(
                    m.gameTag!,
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // 高光卡片
          if (m.recordHighlight != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: AppColors.accent, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.recordHighlight!,
                      style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // 动态正文
          Text(
            m.content,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
          ),

          const SizedBox(height: 12),

          // 互动按钮 (点赞、评论)
          Row(
            children: [
              InkWell(
                onTap: () => momentProv.toggleLike(m.id),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        m.likedByMe ? Icons.favorite : Icons.favorite_border,
                        color: m.likedByMe ? AppColors.secondary : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${m.likeCount}',
                        style: TextStyle(
                          color: m.likedByMe ? AppColors.secondary : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              InkWell(
                onTap: () => _showCommentDialog(m),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${m.comments.length}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 评论列表
          if (m.comments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: m.comments.map((c) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      c,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
