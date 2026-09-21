import 'dart:convert';

/// Validated endpoint with credentials separated from the request URL.
class HttpEndpoint {
  final Uri uri;
  final String? authorization;
  final String? username;

  const HttpEndpoint._(this.uri, this.authorization, this.username);

  factory HttpEndpoint.parse(String address) {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasFragment) {
      throw const FormatException(
        'Enter a valid HTTPS endpoint without a fragment.',
      );
    }
    if (uri.userInfo.isEmpty) return HttpEndpoint._(uri, null, null);
    final separator = uri.userInfo.indexOf(':');
    final username = Uri.decodeComponent(
      separator < 0 ? uri.userInfo : uri.userInfo.substring(0, separator),
    );
    final password = separator < 0
        ? ''
        : Uri.decodeComponent(uri.userInfo.substring(separator + 1));
    if (username.contains(':') ||
        username.contains('\r') ||
        username.contains('\n')) {
      throw const FormatException('Invalid endpoint username.');
    }
    return HttpEndpoint._(
      uri.replace(userInfo: ''),
      'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      username,
    );
  }
}
