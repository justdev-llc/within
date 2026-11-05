/// How faithfully [Teaching.text] follows the source passage.
enum ContentType {
  /// Wording taken from a published translation (record it in `attribution`).
  translationExcerpt('translation_excerpt'),

  /// Our own plain-English rendering that preserves the verse's meaning.
  paraphrase('paraphrase');

  const ContentType(this.jsonValue);

  final String jsonValue;

  static ContentType fromJson(String value) => values.firstWhere(
    (type) => type.jsonValue == value,
    orElse: () => throw FormatException('Unknown contentType: $value'),
  );
}

/// A single teaching from any tradition. Tradition-agnostic by design so the
/// Gita, Quran and Bible libraries can reuse it later.
class Teaching {
  const Teaching({
    required this.id,
    required this.tradition,
    required this.scripture,
    required this.reference,
    required this.text,
    required this.shortText,
    required this.contentType,
    required this.language,
    this.attribution,
  });

  factory Teaching.fromJson(Map<String, dynamic> json) => Teaching(
    id: json['id'] as String,
    tradition: json['tradition'] as String,
    scripture: json['scripture'] as String,
    reference: json['reference'] as String,
    text: json['text'] as String,
    shortText: json['shortText'] as String,
    contentType: ContentType.fromJson(json['contentType'] as String),
    language: json['language'] as String,
    attribution: json['attribution'] as String?,
  );

  final String id;
  final String tradition;
  final String scripture;
  final String reference;

  /// Full text shown in the app and medium widget.
  final String text;

  /// Widget-friendly version for the lock screen and small widget.
  final String shortText;

  final ContentType contentType;
  final String language;

  /// Translator or source edition, when [contentType] is a translation excerpt.
  final String? attribution;

  bool get isParaphrase => contentType == ContentType.paraphrase;
}
