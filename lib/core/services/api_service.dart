import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio de acceso a datos backend (Supabase).
///
/// Comentarios reescritos en estilo académico:
/// - Instanciación: la clase acepta un `SupabaseClient?` para permitir un modo
///   demo donde la persistencia es un no-op (útil en pruebas o UI demos).
/// - Persistencia de datos: cada método encapsula una operación CRUD mínima.
/// - Asincronismo: todos los métodos son `async` y devuelven valores por futuro.
class ApiService {
  final SupabaseClient? _client;

  ApiService([SupabaseClient? client]) : _client = client;

  /// Retorna estadísticas genéricas del personal registrado.
  /// Sustituye las referencias a "veterinarios" por un concepto neutro.
  Future<Map<String, int>> getStaffStats() async {
    if (_client == null) return {'total': 0, 'active': 0, 'inactive': 0};
    try {
      final totalRes = await _client!.from('staff').select();
      final activeRes = await _client!.from('staff').select().eq('active', true);
      final inactiveRes = await _client!.from('staff').select().eq('active', false);

      final total = (totalRes as List).length;
      final active = (activeRes as List).length;
      final inactive = (inactiveRes as List).length;

      return {'total': total, 'active': active, 'inactive': inactive};
    } catch (_) {
      return {'total': 0, 'active': 0, 'inactive': 0};
    }
  }

  /// Conteo de jornadas (ejemplo de colección 'jornada').
  Future<int> getJornadasCount() async {
    if (_client == null) return 0;
    try {
      final res = await _client!.from('jornada').select();
      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getJornadas() async {
    if (_client == null) return [];
    try {
      final res = await _client!.from('jornada').select('*');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  /// Stream realtime de la tabla `jornada` (supabase realtime)
  Stream<List<Map<String, dynamic>>> streamJornadas() {
    if (_client == null) return const Stream.empty();
    return _client!.from('jornada').stream(primaryKey: ['id']).order('fecha').map((e) => List<Map<String, dynamic>>.from(e as List));
  }

  /// Crea una jornada. Si existe una función SQL `create_jornada_tx` la
  /// invoca para asegurar transaccionalidad; en caso contrario realiza un
  /// insert directo y retorna la fila creada.
  Future<Map<String, dynamic>?> createJornada(Map<String, dynamic> data) async {
    if (_client == null) throw Exception('Supabase client not configured. Configure SUPABASE_URL and SUPABASE_ANON_KEY.');
    
    try {
      print('ApiService.createJornada: intentando crear jornada con datos: ${data.keys.toList()}');
      
      // Normalizar los datos para que coincidan con la estructura de la tabla
      final normalizedData = _normalizeJornadaData(data);
      print('ApiService.createJornada: datos normalizados: ${normalizedData.keys.toList()}');
      
      // Intentar función segura en DB
      try {
        final res = await _client!.rpc('create_jornada_tx', params: {'payload': normalizedData});
        if (res != null) {
          print('ApiService.createJornada: creación exitosa via RPC');
          return Map<String, dynamic>.from((res as List).first as Map);
        }
      } catch (e) {
        print('ApiService.createJornada: RPC falló, intentando insert directo: $e');
      }

      // Fallback: insert directo
      final res = await _client!.from('jornada').insert(normalizedData).select().maybeSingle();
      if (res == null) {
        print('ApiService.createJornada: insert returned null - posible problema de RLS/permisos');
        throw Exception('Error: La inserción devolvió null. Verifica permisos en la tabla jornada.');
      }
      
      print('ApiService.createJornada: creación exitosa via insert directo, id: ${res['id']}');
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      print('ApiService.createJornada PostgrestException: message=${e.message}, details=${e.details}, hint=${e.hint}, code=${e.code}');
      throw Exception('Error de base de datos: ${e.message}. Detalles: ${e.details}');
    } catch (e) {
      print('ApiService.createJornada error: $e');
      rethrow;
    }
  }

  /// Normaliza los datos de jornada para que coincidan con la estructura de la tabla
  Map<String, dynamic> _normalizeJornadaData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    
    // Convertir staff a staff_ids si es necesario
    if (data.containsKey('staff') && !data.containsKey('staff_ids')) {
      normalized['staff_ids'] = data['staff'];
      normalized.remove('staff');
    }
    
    // Asegurar que vacunas sea jsonb
    if (data.containsKey('vacunas') && data['vacunas'] is List) {
      normalized['vacunas'] = data['vacunas'];
    }
    
    // Convertir fecha a timestamptz si es string
    if (data['fecha'] is String) {
      try {
        final dateStr = data['fecha'] as String;
        if (dateStr.contains('T')) {
          normalized['fecha'] = dateStr; // Ya es ISO8601
        } else {
          normalized['fecha'] = '${dateStr}T00:00:00Z'; // Agregar tiempo
        }
      } catch (e) {
        print('ApiService._normalizeJornadaData: error procesando fecha: $e');
      }
    }
    
    return normalized;
  }

  Future<void> updateJornada(String id, Map<String, dynamic> data) async {
    if (_client == null) return;
    await _client!.from('jornada').update(data).eq('id', id);
  }

  Future<void> deleteJornada(String id) async {
    if (_client == null) return;
    await _client!.from('jornada').delete().eq('id', id);
  }

  /// Gestión de perfiles de personal — tabla 'staff' (neutro).
  Future<List<Map<String, dynamic>>> getStaffProfiles() async {
    if (_client == null) return [];
    try {
      final res = await _client!.from('staff').select('*');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  /// Stream realtime de la tabla `staff`.
  Stream<List<Map<String, dynamic>>> streamStaff() {
    if (_client == null) return const Stream.empty();
    return _client!.from('staff').stream(primaryKey: ['id']).map((e) => List<Map<String, dynamic>>.from(e as List));
  }

  /// Crea un perfil de staff y devuelve la fila creada (o null en error).
  Future<Map<String, dynamic>?> createStaffProfile(Map<String, dynamic> data) async {
    if (_client == null) throw Exception('Supabase client not configured. Configure SUPABASE_URL and SUPABASE_ANON_KEY.');
    
    try {
      // Debug: imprimir los datos que se van a insertar
      print('ApiService.createStaffProfile: intentando insertar datos: ${data.keys.toList()}');
      
      // Intentamos insert directo primero
      try {
        final res = await _client!.from('staff').insert(data).select().maybeSingle();
        if (res != null) {
          print('ApiService.createStaffProfile: insert exitoso');
          return Map<String, dynamic>.from(res as Map);
        }
        // Si res == null puede ser por RLS/permissions; intentaremos upsert
        print('ApiService.createStaffProfile: insert returned null (possible permission/RLS issue), trying upsert');
      } on PostgrestException catch (e) {
        // Mostrar detalle para diagnóstico y seguir intentando con upsert
        print('ApiService.createStaffProfile PostgrestException on insert: message=${e.message}, details=${e.details}, hint=${e.hint}, code=${e.code}');
      }

      // Intentar upsert (on conflict by id) — útil cuando ya hemos generado id desde Auth
      try {
        print('ApiService.createStaffProfile: intentando upsert con id: ${data['id']}');
        final up = await _client!.from('staff').upsert(data, onConflict: 'id').select().maybeSingle();
        if (up != null) {
          print('ApiService.createStaffProfile: upsert exitoso');
          return Map<String, dynamic>.from(up as Map);
        }
        print('ApiService.createStaffProfile: upsert returned null (possible RLS/permission issue)');
        return null;
      } on PostgrestException catch (e) {
        print('ApiService.createStaffProfile PostgrestException on upsert: message=${e.message}, details=${e.details}, hint=${e.hint}, code=${e.code}');
        throw Exception('Error de base de datos: ${e.message}. Detalles: ${e.details}');
      }
    } catch (e) {
      print('ApiService.createStaffProfile exception: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> updateStaffProfile(String id, Map<String, dynamic> data) async {
    if (_client == null) return null;
    try {
      final res = await _client!.from('staff').update(data).eq('id', id).select().maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      // ignore: avoid_print
      print('ApiService.updateStaffProfile error: $e');
      rethrow;
    }
  }

  Future<bool> deleteStaffProfile(String id) async {
    if (_client == null) return false;
    try {
      try {
        await _client!.from('perfil').delete().or('id.eq.$id,user_id.eq.$id');
      } catch (e) {
        print('ApiService.deleteStaffProfile: error deleting perfil: $e');
      }

      try {
        await _client!.from('device_authorizations').delete().eq('staff_id', id);
      } catch (e) {
        print('ApiService.deleteStaffProfile: error deleting device_authorizations: $e');
      }

      await _client!.from('staff').delete().eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      print('ApiService.deleteStaffProfile PostgrestException: message=${e.message}, details=${e.details}, hint=${e.hint}, code=${e.code}');
      return false;
    } catch (e) {
      print('ApiService.deleteStaffProfile error: $e');
      return false;
    }
  }

  Future<bool> deleteAuthUserAndData(String userId) async {
    if (_client == null) return false;
    try {
      final res = await _client!.functions.invoke('delete_user', body: {'user_id': userId});
      final data = res.data;
      if (data is Map && data['ok'] == true) return true;
      return false;
    } catch (e) {
      print('ApiService.deleteAuthUserAndData error: $e');
      return false;
    }
  }

  /// Inserta o actualiza un registro en la tabla `perfil` para asociar un
  /// rol (por ejemplo 'veterinario') a un staff identificado por `staffId`.
  /// Inserta o actualiza una fila en `perfil` asociando `rol` al `staffId`.
  /// Devuelve `true` si la operación fue exitosa, lanza excepción en fallo.
  Future<bool> assignRoleToStaff(String staffId, String role) async {
    if (_client == null) return false;
    try {
      final row = {'id': staffId, 'user_id': staffId, 'rol': role};
      try {
        final res = await _client!.from('perfil').upsert(row, onConflict: 'id').select().maybeSingle();
        if (res == null) {
          // ignore: avoid_print
          print('ApiService.assignRoleToStaff: upsert returned null (possible RLS/permission issue)');
          return false;
        }
        return true;
      } on PostgrestException catch (e) {
        // ignore: avoid_print
        print('ApiService.assignRoleToStaff PostgrestException: message=${e.message}, details=${e.details}, hint=${e.hint}, code=${e.code}');
        // Intentar insert como fallback
        try {
          final ins = await _client!.from('perfil').insert(row).select().maybeSingle();
          return ins != null;
        } catch (e2) {
          // ignore: avoid_print
          print('ApiService.assignRoleToStaff fallback insert error: $e2');
          return false;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('ApiService.assignRoleToStaff error: $e');
      rethrow;
    }
  }

  /// Envía un correo de restablecimiento de contraseña a `email`.
  /// Devuelve true si la llamada se realizó sin excepción.
  Future<bool> sendResetPasswordEmail(String email) async {
    if (_client == null) return false;
    try {
      // Llamada directa disponible en la mayoría de versiones de supabase_flutter.
      await _client!.auth.resetPasswordForEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Intenta actualizar la contraseña de un usuario usando las APIs "admin"
  /// disponibles en el cliente de Supabase. Esto solo funcionará si el
  /// `SupabaseClient` fue inicializado con una clave de servicio (service_role)
  /// o si la instancia tiene permisos para operar sobre usuarios.
  /// Devuelve `true` si la operación parecía exitosa, `false` en caso contrario.
  Future<bool> adminUpdateUserPassword(String userId, String newPassword) async {
    // Nota: la SDK cliente de Supabase en cliente (no-server) no expone de
    // forma portable una API admin para actualizar la contraseña de otro
    // usuario sin la clave `service_role`. Implementar esto requiere usar la
    // REST admin endpoint con la service_role key o un endpoint seguro en el
    // servidor. Aquí devolvemos `false` para indicar que no se pudo actualizar
    // localmente y forzar el fallback (envío de email de restablecimiento).
    return false;
  }

  /// Comprueba si el usuario autenticado actualmente es administrador.
  /// Busca la fila en `staff` por el `auth.currentUser.id` y revisa
  /// `is_admin` o `role`.
  Future<bool> currentUserIsAdmin() async {
    if (_client == null) return false;
    final user = _client!.auth.currentUser;
    if (user == null) return false;
    try {
      final sel = await _client!.from('staff').select().eq('id', user.id).limit(1).maybeSingle();
      if (sel == null) return false;
      final row = Map<String, dynamic>.from(sel as Map);
      if (row['is_admin'] == true) return true;
      final role = (row['role'] ?? '').toString().toLowerCase();
      return role == 'admin' || role == 'administrador';
    } catch (_) {
      return false;
    }
  }

  /// Obtiene el registro de `staff` para el id provisto (usualmente el uid de Auth).
  Future<Map<String, dynamic>?> getStaffById(String id) async {
    if (_client == null) return null;
    try {
      final sel = await _client!.from('staff').select().eq('id', id).limit(1).maybeSingle();
      if (sel == null) return null;
      return Map<String, dynamic>.from(sel as Map);
    } catch (e) {
      // ignore: avoid_print
      print('ApiService.getStaffById error: $e');
      return null;
    }
  }

  /// Crea un usuario de Auth en Supabase y devuelve su `user.id` o null.
  Future<String?> signUpAuthUser(String email, String password, {Map<String, dynamic>? userMetadata}) async {
    if (_client == null) throw Exception('Supabase client not configured. Configure SUPABASE_URL and SUPABASE_ANON_KEY.');
    try {
      final res = await _client!.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
      );

      var user = res.user;
      user ??= _client!.auth.currentUser;
      if (user == null) throw Exception('SignUp did not return a user.');
      return user.id;
    } on AuthException catch (e) {
      throw Exception('Auth error: ${e.message}');
    } catch (e) {
      throw Exception('Auth exception: $e');
    }
  }

  /// Indica si el `ApiService` tiene un `SupabaseClient` inicializado.
  bool get isConnected => _client != null;

  Future<void> deauthorizeDevice(String staffId, String deviceId) async {
    if (_client == null) return;
    await _client!.from('device_authorizations').delete().eq('staff_id', staffId).eq('device_id', deviceId);
  }

  /// Upload avatar bytes to Supabase Storage and return public URL (or null on failure)
  Future<String?> uploadAvatar(Uint8List bytes, String filename, {String bucket = 'avatars'}) async {
    if (_client == null) return null;
    try {
      final path = 'public/$filename';
      await _client!.storage.from(bucket).uploadBinary(path, bytes);
      final public = _client!.storage.from(bucket).getPublicUrl(path);
      return public;
    } catch (e) {
      return null;
    }
  }

  // Vacunas CRUD (se mantiene como ejemplo de otro recurso)
  Future<List<Map<String, dynamic>>> getVacunas() async {
    if (_client == null) return [];
    try {
      final res = await _client!.from('lotevacuna').select('*');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  /// Stream realtime de la tabla `lotevacuna`
  Stream<List<Map<String, dynamic>>> streamVacunas() {
    if (_client == null) return const Stream.empty();
    return _client!.from('lotevacuna').stream(primaryKey: ['id']).order('created_at').map((e) => List<Map<String, dynamic>>.from(e as List));
  }

  /// Inserta un lote y devuelve la fila creada o lanza excepción en error.
  Future<Map<String, dynamic>?> createVacuna(Map<String, dynamic> data) async {
    if (_client == null) throw Exception('Supabase client not configured. Configure SUPABASE_URL and SUPABASE_ANON_KEY.');
    
    try {
      final payload = _normalizeVacuna(data);
      print('ApiService.createVacuna: intentando insertar payload con campos: ${payload.keys.toList()}');
      
      final res = await _client!.from('lotevacuna').insert(payload).select().maybeSingle();
      if (res == null) {
        print('ApiService.createVacuna: insert returned null - posible problema de RLS/permisos');
        throw Exception('Error: La inserción devolvió null. Verifica permisos en la tabla lotevacuna.');
      }
      
      print('ApiService.createVacuna: inserción exitosa, id: ${res['id']}');
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      print('ApiService.createVacuna PostgrestException: message=${e.message}, details=${e.details}, hint=${e.hint}, code=${e.code}');
      throw Exception('Error de base de datos: ${e.message}. Detalles: ${e.details}');
    } catch (e) {
      print('ApiService.createVacuna error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> updateVacuna(String id, Map<String, dynamic> data) async {
    if (_client == null) return null;
    try {
      final payload = _normalizeVacuna(data);
      final res = await _client!.from('lotevacuna').update(payload).eq('id', id).select().maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      // ignore: avoid_print
      print('ApiService.updateVacuna error: $e');
      rethrow;
    }
  }

  Future<bool> deleteVacuna(String id) async {
    if (_client == null) return false;
    try {
      await _client!.from('lotevacuna').delete().eq('id', id);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('ApiService.deleteVacuna error: $e');
      return false;
    }
  }

  // Helper: map form keys to actual DB columns for `lotevacuna`.
  Map<String, dynamic> _normalizeVacuna(Map<String, dynamic> data) {
    final Map<String, dynamic> out = {};
    
    // Campos básicos
    if (data['nombre'] != null && data['nombre'].toString().isNotEmpty) out['nombre'] = data['nombre'];
    
    // descripcion: prefer explicit descripcion, fallback to laboratorio/proveedor
    if (data['descripcion'] != null && data['descripcion'].toString().isNotEmpty) {
      out['descripcion'] = data['descripcion'];
    } else {
      final parts = <String>[];
      if (data['laboratorio'] != null && data['laboratorio'].toString().isNotEmpty) parts.add('Lab: ${data['laboratorio']}');
      if (data['proveedor'] != null && data['proveedor'].toString().isNotEmpty) parts.add('Proveedor: ${data['proveedor']}');
      if (parts.isNotEmpty) out['descripcion'] = parts.join(' | ');
    }
    
    // cantidad: accept cantidad_frascos or cantidad
    try {
      if (data['cantidad'] != null && data['cantidad'].toString().isNotEmpty) {
        out['cantidad'] = int.tryParse(data['cantidad'].toString()) ?? 0;
      } else if (data['cantidad_frascos'] != null && data['cantidad_frascos'].toString().isNotEmpty) {
        out['cantidad'] = int.tryParse(data['cantidad_frascos'].toString()) ?? 0;
      }
    } catch (_) {}
    
    // lote: accept n_lote or lote
    if (data['lote'] != null && data['lote'].toString().isNotEmpty) {
      out['lote'] = data['lote'];
    } else if (data['n_lote'] != null && data['n_lote'].toString().isNotEmpty) {
      out['lote'] = data['n_lote'];
    }
    
    // fecha_vencimiento: accept fecha_venc or fecha_vencimiento
    if (data['fecha_venc'] != null && data['fecha_venc'].toString().isNotEmpty) {
      out['fecha_vencimiento'] = data['fecha_venc'];
    } else if (data['fecha_vencimiento'] != null && data['fecha_vencimiento'].toString().isNotEmpty) {
      out['fecha_vencimiento'] = data['fecha_vencimiento'];
    }
    
    // Campos adicionales que faltaban
    if (data['laboratorio'] != null && data['laboratorio'].toString().isNotEmpty) {
      out['laboratorio'] = data['laboratorio'];
    }
    
    if (data['fecha_ingreso'] != null && data['fecha_ingreso'].toString().isNotEmpty) {
      out['fecha_ingreso'] = data['fecha_ingreso'];
    }
    
    if (data['n_factura'] != null && data['n_factura'].toString().isNotEmpty) {
      out['n_factura'] = data['n_factura'];
    }
    
    if (data['proveedor'] != null && data['proveedor'].toString().isNotEmpty) {
      out['proveedor'] = data['proveedor'];
    }
    
    if (data['presentacion'] != null && data['presentacion'].toString().isNotEmpty) {
      out['presentacion'] = data['presentacion'];
    }
    
    if (data['dosis_por_frasco'] != null && data['dosis_por_frasco'].toString().isNotEmpty) {
      out['dosis_por_frasco'] = data['dosis_por_frasco'];
    }
    
    if (data['cantidad_frascos'] != null && data['cantidad_frascos'].toString().isNotEmpty) {
      out['cantidad_frascos'] = int.tryParse(data['cantidad_frascos'].toString()) ?? 0;
    }
    
    // Nuevos campos para veterinarios y lotes asignados
    if (data['veterinario_asignado_id'] != null && data['veterinario_asignado_id'].toString().isNotEmpty) {
      out['veterinario_asignado_id'] = data['veterinario_asignado_id'];
    }
    
    if (data['lote_vacuna_asignado_id'] != null && data['lote_vacuna_asignado_id'].toString().isNotEmpty) {
      out['lote_vacuna_asignado_id'] = data['lote_vacuna_asignado_id'];
    }
    
    // Debug: imprimir los campos mapeados
    print('ApiService._normalizeVacuna: input keys=${data.keys.toList()}, output keys=${out.keys.toList()}');
    
    return out;
  }

  /// Login usando email/password con Supabase y consulta la tabla 'perfil' para obtener rol
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (_client == null) {
      return {'error': 'No Supabase client available (demo mode)'};
    }

    try {
      final res = await _client!.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) return {'error': 'Invalid credentials'};

      // Intentamos leer el rol desde la tabla 'perfil'. Probamos por 'user_id' y por 'id'.
      String? role;
      try {
        final perfil = await _client!.from('perfil').select('rol').eq('user_id', user.id).maybeSingle();
        if (perfil != null) {
          role = perfil['rol']?.toString();
        }
      } catch (_) {}

      if (role == null) {
        try {
          final perfil2 = await _client!.from('perfil').select('rol').eq('id', user.id).maybeSingle();
          if (perfil2 != null) {
            role = perfil2['rol']?.toString();
          }
        } catch (_) {}
      }

      return {
        'user': user,
        'role': role,
        'isAdmin': role == 'admin',
        'isStaff': role == 'staff',
      };
    } on AuthException catch (e) {
      return {'error': e.message};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
