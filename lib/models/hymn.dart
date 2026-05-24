// Lightweight Hymn model that maps assets/json/tenzi.json into a stable
// runtime representation used across the app. This file intentionally
// provides both fields and helper methods that the UI and services expect
// (id, songNumber, number, title, subtitle, firstLine, stanzas, chorus,
// lyrics, toJson(), fromJson(), getFirstLine()).

class Hymn {
  final String id; // string identifier (song number as string)
  final int songNumber;
  final String number; // string version of song number
  final String title;
  final String subtitle;
  final List<List<String>> stanzas; // list of stanza lines
  final List<String>? chorus;
  final String category;

  Hymn({
    required this.id,
    required this.songNumber,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.stanzas,
    this.chorus,
    this.category = '',
  });

  /// Create a Hymn from the JSON structure used in assets/json/tenzi.json
  factory Hymn.fromJson(Map<String, dynamic> json) {
    // song number may be under 'song_number' or 'number' or 'songNumber'
    final dynamic snRaw =
        json['song_number'] ?? json['songNumber'] ?? json['number'];
    final songNumber = int.tryParse(snRaw?.toString() ?? '') ?? 0;
    final number = songNumber.toString();

    final title = (json['title'] as String?)?.trim() ?? '';
    final subtitle = (json['subtitle'] as String?)?.trim() ?? '';

    // Collect stanza keys like stanza_1, stanza_2, stanza1, stanzaA etc.
    final stanzaEntries = <_StanzaEntry>[];
    json.forEach((k, v) {
      final key = k.toString();
      if (key.toLowerCase().startsWith('stanza')) {
        // try to extract an index to sort; fallback to 0
        final parts = key.split(RegExp(r'[_\s]'));
        int idx = 0;
        if (parts.length > 1) {
          idx = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        } else {
          // stanza and maybe number directly after 'stanza'
          final match = RegExp(r'stanza(\d+)').firstMatch(key.toLowerCase());
          if (match != null) {
            idx = int.tryParse(match.group(1) ?? '0') ?? 0;
          }
        }

        if (v is List) {
          final lines = v
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          stanzaEntries.add(_StanzaEntry(index: idx, lines: lines));
        }
      }
    });

    // Sort stanzas by extracted index
    stanzaEntries.sort((a, b) => a.index.compareTo(b.index));
    final stanzas = stanzaEntries.map((e) => e.lines).toList();

    // Chorus may be present as a list under key 'chorus'
    List<String>? chorus;
    String category = (json['category'] as String?)?.trim() ?? '';
    if (json['chorus'] is List) {
      chorus = (json['chorus'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return Hymn(
      id: number,
      songNumber: songNumber,
      number: number,
      title: title,
      subtitle: subtitle,
      stanzas: stanzas,
      chorus: chorus == null || chorus.isEmpty ? null : chorus,
      category: category,
    );
  }

  /// Convenience empty hymn used by some UI code when no hymn is found.
  static Hymn empty() => Hymn(
        id: '0',
        songNumber: 0,
        number: '0',
        title: '',
        subtitle: '',
        stanzas: const [],
        chorus: null,
        category: '',
      );

  /// Build a plain text lyrics string from stanzas and chorus
  String get lyrics {
    final buffer = StringBuffer();
    for (var i = 0; i < stanzas.length; i++) {
      final stanza = stanzas[i];
      if (stanza.isEmpty) continue;
      // Optionally prefix stanza number
      buffer.writeln(stanza.join('\n'));
      buffer.writeln();
    }
    if (chorus != null && chorus!.isNotEmpty) {
      buffer.writeln('Chorus:');
      buffer.writeln(chorus!.join('\n'));
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// First non-empty line from the first stanza
  String get firstLine {
    for (final stanza in stanzas) {
      if (stanza.isNotEmpty) return stanza.first;
    }
    return '';
  }

  /// Backwards-compatible method seen in some parts of the codebase
  String getFirstLine() => firstLine;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'song_number': songNumber,
      'title': title,
      'subtitle': subtitle,
      'category': category,
    };

    for (var i = 0; i < stanzas.length; i++) {
      data['stanza_${i + 1}'] = stanzas[i];
    }

    if (chorus != null) data['chorus'] = chorus;
    return data;
  }
}

class _StanzaEntry {
  final int index;
  final List<String> lines;
  _StanzaEntry({required this.index, required this.lines});
}
