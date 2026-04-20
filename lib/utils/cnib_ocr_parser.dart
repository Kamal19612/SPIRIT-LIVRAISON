/// Extraction des champs d'une **Carte Nationale d'Identité Burkinabè** (CNIB)
/// à partir du texte renvoyé par l'OCR (libellés français usuels).
///
/// Mise en page usuelle (recto) :
/// - `Né(e) le : JJ/MM/AAAA À LIEU` (lieu souvent **sur la même ligne** que la date)
/// - Plus bas : `Délivrée le : JJ/MM/AAAA` puis `Expire le : JJ/MM/AAAA`
///   (délivrance **toujours avant** expiration dans le temps).
class CnibBurkinaParseResult {
  final String? lastName;
  final String? firstNames;
  /// Numéro d'identifiant national (souvent 17 chiffres en haut à droite)
  final String? nationalIdNumber;
  /// Numéro de série de la carte (ex. B11127698)
  final String? cardSerial;
  final String? birthDate;
  final String? birthPlace;
  final String? gender;
  final String? profession;
  final String? issueDate;
  final String? expiryDate;

  const CnibBurkinaParseResult({
    this.lastName,
    this.firstNames,
    this.nationalIdNumber,
    this.cardSerial,
    this.birthDate,
    this.birthPlace,
    this.gender,
    this.profession,
    this.issueDate,
    this.expiryDate,
  });
}

class CnibOcrParser {
  CnibOcrParser._();

  static final _reDate = RegExp(r'\b(\d{2}/\d{2}/\d{4})\b');

  /// Compatibilité : extrait au moins nom / prénoms (ancien appel).
  static ({String? lastName, String? firstName}) parseNames(String raw) {
    final r = parseBurkinaCnib(raw);
    return (lastName: r.lastName, firstName: r.firstNames);
  }

  /// Parse complet pour CNIB Burkina Faso.
  static CnibBurkinaParseResult parseBurkinaCnib(String raw) {
    final text = _normalize(raw);
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final nationalId = _extractNationalId(text);
    final cardSerial = _extractCardSerial(text);
    final datesInOrder = _extractAllDates(text);
    final birthDate = _extractBirthDate(text);
    final birthPlace = _extractBirthPlaceBurkina(text, lines, birthDate);
    final gender = _extractGender(text);
    final profession = _extractProfession(text);
    final nom = _extractNom(lines, text);
    final prenoms = _extractPrenoms(lines, text);

    var issueDate = _extractIssueDate(text);
    var expiryDate = _extractExpiryDate(text);
    issueDate ??= _issueDateFromLineScan(lines, text);
    expiryDate ??= _expiryDateFromLineScan(lines, text);

    final fixed = _finalizeIssueAndExpiry(
      birthDate: birthDate,
      issueDate: issueDate,
      expiryDate: expiryDate,
      datesInOrder: datesInOrder,
      lines: lines,
    );

    return CnibBurkinaParseResult(
      lastName: _clean(nom),
      firstNames: _clean(prenoms),
      nationalIdNumber: nationalId,
      cardSerial: cardSerial,
      birthDate: birthDate,
      birthPlace: birthPlace,
      gender: gender,
      profession: profession,
      issueDate: fixed.$1,
      expiryDate: fixed.$2,
    );
  }

  static String _normalize(String raw) {
    var t = raw.replaceAll('\r', '\n');
    t = t.replaceAll(RegExp(r'[\u00A0]+'), ' ');
    t = t.replaceAll(RegExp(r' +'), ' ');
    return t.trim();
  }

  static String? _clean(String? s) {
    if (s == null) return null;
    var t = s.trim();
    if (t.length > 120) t = t.substring(0, 120);
    return t.isEmpty ? null : t;
  }

  static List<String> _extractAllDates(String text) {
    return _reDate.allMatches(text).map((m) => m.group(1)!).toList();
  }

  /// Après extraction OCR : éviter doublons incorrects, inversions, et compléter depuis les dates restantes.
  static (String?, String?) _finalizeIssueAndExpiry({
    required String? birthDate,
    required String? issueDate,
    required String? expiryDate,
    required List<String> datesInOrder,
    required List<String> lines,
  }) {
    // 1) Priorité absolue : une date par ligne contenant les libellés distincts
    String? lineDeliv;
    String? lineExp;
    for (final line in lines) {
      final low = line.toLowerCase();
      final hasDelivr = RegExp(r'delivr', caseSensitive: false).hasMatch(low);
      final hasExpir = RegExp(r'expir', caseSensitive: false).hasMatch(low);
      if (hasDelivr && RegExp(r'\ble\b', caseSensitive: false).hasMatch(low) && !hasExpir) {
        final d = _reDate.firstMatch(line);
        if (d != null) lineDeliv = d.group(1);
      }
      if (hasExpir &&
          !RegExp(r'n[ée]\s*\(?e\)?\s*le', caseSensitive: false).hasMatch(low)) {
        final d = _reDate.firstMatch(line);
        if (d != null) lineExp = d.group(1);
      }
    }
    if (lineDeliv != null) issueDate = lineDeliv;
    if (lineExp != null) expiryDate = lineExp;

    // 2) Retirer la date de naissance du pool
    final pool = <String>[];
    for (final d in datesInOrder) {
      if (birthDate != null && d == birthDate) continue;
      pool.add(d);
    }
    final uniquePool = _uniquePreserveOrder(pool);

    // 3) Compléter les manquants (ordre d'apparition dans le texte = souvent délivrance puis expiration)
    if (issueDate == null && uniquePool.isNotEmpty) {
      issueDate = uniquePool.first;
    }
    if (expiryDate == null && uniquePool.length >= 2) {
      expiryDate = uniquePool.length > 1
          ? uniquePool.firstWhere((d) => d != issueDate, orElse: () => uniquePool.last)
          : null;
    }
    if (expiryDate == null && uniquePool.isNotEmpty && issueDate != null) {
      for (final d in uniquePool) {
        if (d != issueDate) {
          expiryDate = d;
          break;
        }
      }
    }

    // 4) Si les deux sont identiques alors qu'il existe 2 dates « hors naissance » distinctes
    if (issueDate != null &&
        expiryDate != null &&
        issueDate == expiryDate &&
        uniquePool.length >= 2) {
      final distinct = uniquePool.toSet().toList();
      if (distinct.length >= 2) {
        final sorted = distinct.map(_parseEuropean).whereType<DateTime>().toList()..sort();
        if (sorted.length >= 2) {
          issueDate = _formatEuropean(sorted.first);
          expiryDate = _formatEuropean(sorted.last);
        }
      }
    }

    // 5) Dernière chance : exactement 2 dates hors naissance → plus ancienne = délivrance
    if ((issueDate == null || expiryDate == null || issueDate == expiryDate) &&
        birthDate != null &&
        uniquePool.length >= 2) {
      final rest = uniquePool.where((d) => d != birthDate).toList();
      if (rest.length >= 2) {
        final parsed = rest.map(_parseEuropean).whereType<DateTime>().toList()..sort();
        if (parsed.length >= 2) {
          issueDate = _formatEuropean(parsed.first);
          expiryDate = _formatEuropean(parsed.last);
        }
      }
    }

    // 6) Inversion : sur une carte, délivrance ≤ expiration
    if (issueDate != null && expiryDate != null) {
      final di = _parseEuropean(issueDate);
      final de = _parseEuropean(expiryDate);
      if (di != null && de != null && di.isAfter(de)) {
        final t = issueDate;
        issueDate = expiryDate;
        expiryDate = t;
      }
    }

    return (issueDate, expiryDate);
  }

  static List<String> _uniquePreserveOrder(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final x in items) {
      if (seen.add(x)) out.add(x);
    }
    return out;
  }

  static DateTime? _parseEuropean(String? ddMmYyyy) {
    if (ddMmYyyy == null) return null;
    final p = ddMmYyyy.split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  static String _formatEuropean(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }

  /// Lieu après **À** sur la ligne de naissance (`Né(e) le … À OUAGADOUGOU`), ou `…/AAAA A VILLE` (OCR sans accent).
  static String? _extractBirthPlaceBurkina(
    String text,
    List<String> lines,
    String? birthDateStr,
  ) {
    for (final line in lines) {
      if (!RegExp(r'N[ée]', caseSensitive: false).hasMatch(line)) continue;
      if (!_reDate.hasMatch(line)) continue;

      final m1 = RegExp(
        r'N[ée]\s*\(?e\)?\s*le\s*[:.]?\s*\d{2}/\d{2}/\d{4}\s+(?:À|A)\s+(.+?)(?=\s+(?:Sexe|SEXE|Taille|Profession)|$)',
        caseSensitive: false,
      ).firstMatch(line);
      if (m1 != null) {
        final p = _trimPlace(m1.group(1));
        if (p != null) return p;
      }

      final m2 = RegExp(
        r"(?:À|A)\s+([A-Za-zÉÈÀÂÊÔÙÇ][A-Za-zéèêàùôç\s\-']{2,45})",
        caseSensitive: false,
      ).firstMatch(line);
      if (m2 != null) {
        final p = _trimPlace(m2.group(1));
        if (p != null && !_looksLikeDateOrNoise(p)) return p;
      }
    }

    if (birthDateStr != null) {
      final esc = RegExp.escape(birthDateStr);
      final m3 = RegExp(
        '$esc\\s+(?:À|A)\\s+([A-Za-zÉÈÀÂÊÔÙÇ][A-Za-zéèêàùôç\\s\\-]{2,45})',
        caseSensitive: false,
      ).firstMatch(text);
      if (m3 != null) return _trimPlace(m3.group(1));
    }

    // Ligne sans le mot « Né » (OCR a parfois coupé la ligne au-dessus)
    for (final line in lines) {
      if (birthDateStr != null && !line.contains(birthDateStr)) continue;
      if (!RegExp(r'(?:À|A)\s+[A-Za-z]', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      if (RegExp(r'Delivr|Expir|Profession', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      final m4 = RegExp(
        r"(?:À|A)\s+([A-Za-zÉÈÀÂÊÔÙÇ][A-Za-zéèêàùôç\s\-']{2,45})",
        caseSensitive: false,
      ).firstMatch(line);
      if (m4 != null) {
        final p = _trimPlace(m4.group(1));
        if (p != null && !_looksLikeDateOrNoise(p)) return p;
      }
    }

    return null;
  }

  static bool _looksLikeDateOrNoise(String s) {
    return RegExp(r'^\d').hasMatch(s.trim()) || s.length < 3;
  }

  static String? _trimPlace(String? raw) {
    if (raw == null) return null;
    var work = raw.trim();
    for (final stop in ['Sexe', 'SEXE', 'Taille', 'Profession', 'Délivr', 'Delivr', 'Expir']) {
      final i = work.toUpperCase().indexOf(stop.toUpperCase());
      if (i > 0) work = work.substring(0, i).trim();
    }
    if (work.length > 60) work = work.substring(0, 60);
    return work.isEmpty ? null : work;
  }

  static String? _extractNationalId(String text) {
    final compact = text.replaceAll(RegExp(r'\s'), '');
    final m = RegExp(r'(\d{15,20})').firstMatch(compact);
    if (m != null) return m.group(1);
    return RegExp(r'\b(\d{15,20})\b').firstMatch(text)?.group(1);
  }

  static String? _extractCardSerial(String text) {
    final m = RegExp(r'\b([A-Z]\d{6,12})\b').firstMatch(text.toUpperCase());
    return m?.group(1);
  }

  static String? _extractBirthDate(String text) {
    final m = RegExp(
      r'N[ée]\s*\(?e\)?\s*le\s*[:.]?\s*(\d{2}/\d{2}/\d{4})',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1);
  }

  static String? _extractIssueDate(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'D[ée]livr[ée]e\s+le\s*[:.]?\s*(\d{2}/\d{2}/\d{4})',
        caseSensitive: false,
      ),
      RegExp(
        r'Delivr[ée]?e?\s+le\s*[:.]?\s*(\d{2}/\d{2}/\d{4})',
        caseSensitive: false,
      ),
      RegExp(
        r'D[ée]livr[ée]e\s*[:.]?\s*(\d{2}/\d{2}/\d{4})',
        caseSensitive: false,
      ),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static String? _issueDateFromLineScan(List<String> lines, String text) {
    for (final line in lines) {
      final l = line.trim();
      if (!RegExp(r'Delivr', caseSensitive: false).hasMatch(l)) continue;
      if (!RegExp(r'\ble\b', caseSensitive: false).hasMatch(l)) continue;
      if (RegExp(r'Expir', caseSensitive: false).hasMatch(l)) continue;
      final d = _reDate.firstMatch(l);
      if (d != null) return d.group(1);
    }
    return _dateNearKeywords(text, const ['delivr', 'délivr']);
  }

  static String? _extractExpiryDate(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'Expir[ée]?\s+le\s*[:.]?\s*(\d{2}/\d{2}/\d{4})',
        caseSensitive: false,
      ),
      RegExp(
        r'Expire\s*[:.]?\s*(\d{2}/\d{2}/\d{4})',
        caseSensitive: false,
      ),
      RegExp(
        r'Expir[^\n]{0,12}le\s*[:.]?\s*(\d{2}/\d{2}/\d{4})',
        caseSensitive: false,
      ),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static String? _expiryDateFromLineScan(List<String> lines, String text) {
    for (final line in lines) {
      final l = line.trim();
      if (!RegExp(r'Expir', caseSensitive: false).hasMatch(l)) continue;
      final d = _reDate.firstMatch(l);
      if (d != null) return d.group(1);
    }
    return _dateNearKeywords(text, const ['expir']);
  }

  static String? _dateNearKeywords(String text, List<String> keywordFragments) {
    for (final line in text.split('\n')) {
      final low = line.toLowerCase();
      final ok = keywordFragments.any(low.contains);
      if (!ok) continue;
      final d = _reDate.firstMatch(line);
      if (d != null) return d.group(1);
    }
    return null;
  }

  static String? _extractGender(String text) {
    final m = RegExp(
      r'Sexe\s*[:.]?\s*([MF])\b',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.toUpperCase();
  }

  static String? _extractProfession(String text) {
    final m = RegExp(
      r'Profession\s*[:.]?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.trim();
  }

  static String? _extractNom(List<String> lines, String fullText) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().toUpperCase() == 'NOM' && i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (_looksLikeName(next) &&
            !next.toUpperCase().contains('PRÉNOM') &&
            !next.toUpperCase().contains('PRENOM')) {
          return next;
        }
      }
    }

    final fromRegex = RegExp(
      r'(?:^|\n)\s*NOM\s*[:.]?\s*([^\n]+?)(?=\n|PR[ÉE]NOM|Pr[ée]nom|\Z)',
      caseSensitive: false,
    ).firstMatch(fullText);
    var v = fromRegex?.group(1)?.trim();
    if (v != null && _looksLikeName(v) && !v.toUpperCase().contains('PRÉNOM')) {
      return v;
    }

    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final low = l.toUpperCase();
      if (low == 'NOM' || low.startsWith('NOM ') || low.startsWith('NOM:')) {
        if (RegExp(r'NOM\s*[:.]?\s*(.+)', caseSensitive: false).hasMatch(l)) {
          final m = RegExp(r'NOM\s*[:.]?\s*(.+)', caseSensitive: false).firstMatch(l);
          final part = m?.group(1)?.trim();
          if (part != null && part.isNotEmpty && !part.toUpperCase().contains('PRÉNOM')) {
            return part;
          }
        }
        if (i + 1 < lines.length) {
          final next = lines[i + 1];
          if (_looksLikeName(next) && !next.toUpperCase().contains('PRÉNOM')) {
            return next;
          }
        }
      }
    }
    return null;
  }

  static String? _extractPrenoms(List<String> lines, String fullText) {
    for (var i = 0; i < lines.length; i++) {
      final u = lines[i].trim().toUpperCase();
      if ((u == 'PRÉNOMS' || u == 'PRENOMS' || u == 'PRÉNOM' || u == 'PRENOM') &&
          i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (next.isNotEmpty && next.length < 120) return next;
      }
    }

    final fromRegex = RegExp(
      r'PR[ÉE]NOMS?\s*[:.]?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(fullText);
    var v = fromRegex?.group(1)?.trim();
    if (v != null && v.isNotEmpty) return v;

    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (RegExp(r'PR[ÉE]NOMS?', caseSensitive: false).hasMatch(l)) {
        final m = RegExp(r'PR[ÉE]NOMS?\s*[:.]?\s*(.*)', caseSensitive: false).firstMatch(l);
        final part = m?.group(1)?.trim();
        if (part != null && part.isNotEmpty) return part;
        if (i + 1 < lines.length) return lines[i + 1];
      }
    }
    return null;
  }

  static bool _looksLikeName(String s) {
    final t = s.trim();
    if (t.length < 2 || t.length > 80) return false;
    if (RegExp(r'^\d').hasMatch(t)) return false;
    return true;
  }
}
