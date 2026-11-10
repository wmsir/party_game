import 'package:flutter/material.dart';
import '../models/post_moment_model.dart';
import '../services/moment_service.dart';

class MomentProvider extends ChangeNotifier {
  final MomentService _service = MomentService();

  List<PostMomentModel> get moments => _service.moments;

  void publishMoment({
    required String authorId,
    required String authorName,
    required String authorAvatar,
    required String content,
    String? gameTag,
    String? recordHighlight,
  }) {
    _service.publishMoment(
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      gameTag: gameTag,
      recordHighlight: recordHighlight,
    );
    notifyListeners();
  }

  void toggleLike(String momentId) {
    _service.toggleLike(momentId);
    notifyListeners();
  }

  void addComment(String momentId, String userName, String commentText) {
    _service.addComment(momentId, userName, commentText);
    notifyListeners();
  }
}
