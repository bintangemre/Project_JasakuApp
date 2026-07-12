import '../constants/api_endpoints.dart';

/// Constructs a full image URL from a path or returns the URL as-is if already absolute.
/// Handles both old relative paths (e.g. "uploads/xxx.jpg") and new Supabase Storage URLs.
String imageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final normalized = path.replaceAll('\\', '/');
  final clean = normalized.startsWith('/') ? normalized.substring(1) : normalized;
  return '${ApiEndpoints.baseUrl}/$clean';
}
