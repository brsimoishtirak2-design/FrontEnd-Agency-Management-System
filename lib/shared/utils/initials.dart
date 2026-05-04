/// Compact initials derived from a full name.
///
/// Up to 2 letters, uppercase. Falls back to "?" for empty input,
/// or to the first letter / two letters of a single-word name.
///
/// Examples:
///   nameInitials('Alice Brown') == 'AB'
///   nameInitials('  alice  brown  carter ') == 'AC'   // first + last
///   nameInitials('alice') == 'AL'                     // first 2 letters
///   nameInitials('a') == 'A'                          // first letter
///   nameInitials('') == '?'
String nameInitials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final first = parts.first;
  if (parts.length == 1) {
    return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (first[0] + parts.last[0]).toUpperCase();
}
