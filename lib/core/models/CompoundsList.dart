/// Category and [Compound] document ids (`compound_categories` / `compounds` document `\$id`).
/// Values are normalized to non-null [String] for UI and repository calls.
String _idFromJson(Object? v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

class Compound {
  final String id;
  final String name;
  final String? developer;
  final String? city;
  final String? pictureUrl;

  Compound({
    required this.id,
    required this.name,
    this.developer,
    this.city,
    this.pictureUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'developer': developer,
      'city': city,
      'picture_url': pictureUrl,
    };
  }

  factory Compound.fromJson(Map<String, dynamic> json) {
    return Compound(
      id: _idFromJson(json['id']),
      name: json['name'] as String,
      developer: json['developer'] as String?,
      city: json['city'] as String?,
      pictureUrl: json['picture_url'] as String?,
    );
  }
}

class Category {
  final String id;
  final String name;
  final List<Compound> compounds;

  Category({
    required this.id,
    required this.name,
    required this.compounds,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'compounds': compounds.map((compound) => compound.toJson()).toList(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    final compoundsList = json['compounds'] as List;
    final List<Compound> parsedCompounds = compoundsList
        .map((compoundJson) => Compound.fromJson(compoundJson as Map<String, dynamic>))
        .toList();

    return Category(
      id: _idFromJson(json['id']),
      name: json['name'] as String,
      compounds: parsedCompounds,
    );
  }
}