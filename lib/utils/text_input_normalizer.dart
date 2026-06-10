String normalizeSmartPunctuation(String value) {
  return value
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u201A', "'")
      .replaceAll('\u201B', "'")
      .replaceAll('\u2032', "'")
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"')
      .replaceAll('\u201E', '"')
      .replaceAll('\u201F', '"')
      .replaceAll('\u2033', '"')
      .replaceAll('\u00AB', '"')
      .replaceAll('\u00BB', '"')
      .replaceAll('\u2010', '-')
      .replaceAll('\u2011', '-')
      .replaceAll('\u2012', '-')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll('\u2212', '-')
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u202F', ' ');
}

String normalizeSearchInput(String value) =>
    normalizeSmartPunctuation(value).trim();
