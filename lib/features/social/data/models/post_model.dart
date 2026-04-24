import '../../domain/entities/post.dart';

/// Legacy Supabase may send int; Appwrite and JSON often use [String] — always normalize to [String].
String _compoundIdFromJson(Object? v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

class PostModel extends Post {
  const PostModel({
    required super.id,
    required super.compoundId,
    required super.authorId,
    required super.postHead,
    required super.sourceUrl,
    required super.getCalls,
    required super.comments,
    super.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'].toString(),
      compoundId: _compoundIdFromJson(json['compound_id']),
      authorId: json['author_id'] as String,
      postHead: json['post_head'] as String,
      sourceUrl: List<Map<String, dynamic>>.from(json['source_url'] ?? []),
      getCalls: json['getCalls'] as bool? ?? false,
      comments: List<Map<String, dynamic>>.from(json['Comments'] ?? []),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'compound_id': compoundId,
      'author_id': authorId,
      'post_head': postHead,
      'source_url': sourceUrl,
      'getCalls': getCalls,
      'Comments': comments,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
