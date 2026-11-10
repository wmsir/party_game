import 'dart:async';
import '../models/post_moment_model.dart';
import 'api_service.dart';

class MomentService {
  static final MomentService _instance = MomentService._internal();
  factory MomentService() => _instance;
  MomentService._internal() {
    refreshMoments();
  }

  final List<PostMomentModel> _moments = [];
  List<PostMomentModel> get moments => List.unmodifiable(_moments);

  Future<void> refreshMoments() async {
    try {
      final remote = await ApiService().fetchMoments();
      if (remote.isNotEmpty) {
        _moments.clear();
        _moments.addAll(remote);
      }
    } catch (_) {}
  }

  void publishMoment({
    required String authorId,
    required String authorName,
    required String authorAvatar,
    required String content,
    String? gameTag,
    String? recordHighlight,
  }) {
    final local = PostMomentModel(
      id: 'M-${DateTime.now().millisecondsSinceEpoch}',
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      gameTag: gameTag,
      recordHighlight: recordHighlight,
      likeCount: 1,
      likedByMe: true,
    );
    _moments.insert(0, local);

    // 同步到云端
    ApiService().publishMoment(
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      gameTag: gameTag,
      recordHighlight: recordHighlight,
    );
  }

  void toggleLike(String momentId) {
    final idx = _moments.indexWhere((m) => m.id == momentId);
    if (idx != -1) {
      final m = _moments[idx];
      m.likedByMe = !m.likedByMe;
      m.likeCount += m.likedByMe ? 1 : -1;
      ApiService().likeMoment(momentId);
    }
  }

  void addComment(String momentId, String userName, String commentText) {
    final idx = _moments.indexWhere((m) => m.id == momentId);
    if (idx != -1) {
      _moments[idx].comments.add('$userName: $commentText');
    }
  }
}
