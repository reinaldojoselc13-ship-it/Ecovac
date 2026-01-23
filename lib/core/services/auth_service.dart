


import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
	final SupabaseClient _client;

	AuthService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

	// Devuelve null si es válido, o mensaje de error si no.
	static String? validateEmail(String? value) {
		if (value == null || value.trim().isEmpty) return 'Correo requerido';
		final email = value.trim();
		final emailExp = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
		return emailExp.hasMatch(email) ? null : 'Correo inválido';
	}

	static String? validateUser(String? value) {
		if (value == null || value.trim().isEmpty) return 'Ingrese usuario';
		return null;
	}

	static String? validatePassword(String? value) {
		if (value == null || value.isEmpty) return 'Ingrese contraseña';
		if (value.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
		return null;
	}

	/// Inicia sesión con correo y contraseña. Lanza [AuthException] en error.
	Future<void> signIn({required String email, required String password}) async {
		try {
			final res = await _client.auth.signInWithPassword(email: email, password: password);
			if (res.session == null) {
				throw AuthException('No se pudo iniciar sesión');
			}
		} on AuthException {
			rethrow;
		} catch (e) {
			throw AuthException(e.toString());
		}
	}
}

class AuthException implements Exception {
	final String message;
	AuthException(this.message);
	@override
	String toString() => message;
}


