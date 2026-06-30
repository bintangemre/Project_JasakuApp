import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<Map<String, dynamic>?> signInWithGoogle({
    String expectedRole = 'customer',
  }) async {
    try {
      // Inisialisasi
      await _googleSignIn.initialize(
        serverClientId:
            '1003990493678-rfv6vbej465gq8jd6sh5fk6ab3583je2.apps.googleusercontent.com',
      );

      // Login
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Ambil token
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return null;
      }

      return await sendTokenToBackend(idToken, expectedRole);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> sendTokenToBackend(
    String idToken,
    String expectedRole,
  ) async {
    final url = Uri.parse('http://10.244.34.20:3000/api/auth/login/google');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken, 'role': expectedRole}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
