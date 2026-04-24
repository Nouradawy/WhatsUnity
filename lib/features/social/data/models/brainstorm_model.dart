import '../../domain/entities/brainstorm.dart';

String _idScalarToString(Object? v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

class BrainStormModel extends BrainStorm {
  const BrainStormModel({
    required super.id,
    required super.authorId,
    required super.createdAt,
    required super.compoundId,
    required super.channelId,
    required super.title,
    required super.image,
    required super.options,
    required super.comments,
    super.votes,
  });

  factory BrainStormModel.fromJson(Map<String, dynamic> json) {
    // Robustly handle 'Image' being either a List of Maps or a single Map
    List<Map<String, dynamic>> parseImage(dynamic imageJson) {
      if (imageJson == null) return [];
      if (imageJson is List) {
        return List<Map<String, dynamic>>.from(imageJson);
      }
      if (imageJson is Map) {
        return [Map<String, dynamic>.from(imageJson)];
      }
      return [];
    }

    return BrainStormModel(
      id: json['id'].toString(),
      authorId: json['author_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      compoundId: _idScalarToString(json['compound_id']),
      channelId: _idScalarToString(json['channel_id']),
      title: json['Title'] ?? json['title'] ?? '',
      image: parseImage(json['Image'] ?? json['image'] ?? json['imageSources']),
      options: List<Map<String, dynamic>>.from(json['Options'] ?? json['options'] ?? []),
      comments: List<Map<String, dynamic>>.from(json['comments'] ?? json['Comments'] ?? []),
      votes: (json['Votes'] ?? json['votes']) as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'created_at': createdAt.toIso8601String(),
      'compound_id': compoundId,
      'channel_id': channelId,
      'Title': title,
      'Image': image,
      'Options': options,
      'comments': comments,
      'Votes': votes,
    };
  }
}
