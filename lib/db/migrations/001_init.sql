-- Migration 001: initial schema for AppEcovac

-- Enable extension for UUID generation (Postgres)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Users table (app_users)
CREATE TABLE IF NOT EXISTS public.app_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_uid uuid UNIQUE,
  email text UNIQUE NOT NULL,
  role text NOT NULL CHECK (role IN ('veterinario','administrador')),
  is_admin boolean DEFAULT false,
  nombre text,
  apellidos text,
  telefono text,
  direccion text,
  avatar_url text,
  numero_colegio text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_app_users_role ON public.app_users(role);

-- Vacunas table
CREATE TABLE IF NOT EXISTS public.vacunas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  descripcion text,
  cantidad integer DEFAULT 0 CHECK (cantidad >= 0),
  lote text,
  fecha_vencimiento date,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_vacunas_nombre ON public.vacunas(nombre);

-- Jornadas table
CREATE TABLE IF NOT EXISTS public.jornadas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  fecha timestamptz NOT NULL,
  ubicacion text,
  descripcion text,
  estado text DEFAULT 'pendiente',
  organizador_id uuid REFERENCES public.app_users(id) ON DELETE SET NULL,
  vacunas jsonb DEFAULT '[]'::jsonb,
  staff_ids uuid[] DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_jornadas_fecha ON public.jornadas(fecha);
CREATE INDEX IF NOT EXISTS idx_jornadas_vacunas_gin ON public.jornadas USING GIN (vacunas);

-- Audit log
CREATE TABLE IF NOT EXISTS public.audit_log (
  id bigserial PRIMARY KEY,
  entity text,
  entity_id uuid,
  action text,
  actor_id uuid,
  payload jsonb,
  created_at timestamptz DEFAULT now()
);

-- Example RLS policies (basic). Adjust role names according to your Supabase setup.
-- Enable RLS
ALTER TABLE public.jornadas ENABLE ROW LEVEL SECURITY;

-- Allow authenticated inserts (must be adjusted for stricter control)
CREATE POLICY jornadas_insert ON public.jornadas FOR INSERT TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- Allow update/delete only to organizer or admins
CREATE POLICY jornadas_modify ON public.jornadas FOR UPDATE, DELETE TO authenticated USING (
  organizador_id::text = auth.uid() OR EXISTS (SELECT 1 FROM public.app_users u WHERE u.auth_uid::text = auth.uid() AND u.is_admin)
) WITH CHECK (
  organizador_id::text = auth.uid() OR EXISTS (SELECT 1 FROM public.app_users u WHERE u.auth_uid::text = auth.uid() AND u.is_admin)
);

-- Provide a safe server-side function to create jornada within a transaction
-- SECURITY DEFINER is required and should be owned by a db role with sufficient privileges
CREATE OR REPLACE FUNCTION public.create_jornada_tx(payload jsonb)
RETURNS TABLE(id uuid) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
  v_item jsonb;
BEGIN
  -- Insert jornada
  INSERT INTO public.jornadas (nombre, fecha, ubicacion, descripcion, vacunas, staff_ids, organizador_id)
  VALUES (
    payload->>'nombre',
    (payload->>'fecha')::timestamptz,
    payload->>'ubicacion',
    payload->>'descripcion',
    COALESCE(payload->'vacunas','[]'::jsonb),
    (SELECT array_agg(x) FROM jsonb_array_elements_text(payload->'staff_ids') x),
    (payload->>'organizador_id')::uuid
  ) RETURNING id INTO v_id;

  -- Optional: decrement stock for each vacuna (if payload contains vacuna_id and cantidad)
  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(payload->'vacunas','[]'::jsonb)) LOOP
    BEGIN
      UPDATE public.vacunas SET cantidad = cantidad - (v_item->>'cantidad')::int
      WHERE id = (v_item->>'vacuna_id')::uuid;
    EXCEPTION WHEN OTHERS THEN
      -- ignore stock errors here; prefer stricter handling in production
      NULL;
    END;
  END LOOP;

  -- Audit
  INSERT INTO public.audit_log(entity, entity_id, action, actor_id, payload) VALUES ('jornada', v_id, 'create', (payload->>'actor_id')::uuid, payload);

  RETURN QUERY SELECT v_id;
END; $$;

-- Grant execute on the function to authenticated (or manage via edge function)
GRANT EXECUTE ON FUNCTION public.create_jornada_tx(jsonb) TO authenticated;

-- Legacy-compatible tables used by the app: `staff`, `perfil`, `lotevacuna`.
-- `staff` mirrors user profiles used across the codebase (keeps compatibility).
CREATE TABLE IF NOT EXISTS public.staff (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE,
  nombres text,
  apellidos text,
  cedula text,
  telefono text,
  direccion text,
  numero_colegio text,
  sector text,
  avatar_path text,
  role text DEFAULT 'veterinario',
  is_admin boolean DEFAULT false,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_staff_role ON public.staff(role);

-- Tabla perfil (puede contener roles/atributos adicionales)
CREATE TABLE IF NOT EXISTS public.perfil (
  id uuid PRIMARY KEY,
  user_id uuid,
  rol text,
  meta jsonb DEFAULT '{}'::jsonb
);

-- Tabla lotevacuna (nombre usado por el código actual)
CREATE TABLE IF NOT EXISTS public.lotevacuna (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  descripcion text,
  cantidad integer DEFAULT 0 CHECK (cantidad >= 0),
  lote text,
  fecha_vencimiento date,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lotevacuna_nombre ON public.lotevacuna(nombre);

-- Functions

import 'package:supabase_flutter/supabase_flutter.dart';

/// Crea un usuario en Auth y guarda la fila en la tabla `perfil`.
/// Retorna la fila insertada (Map) en caso de éxito.
///
/// Lanza excepciones con mensajes claros en caso de fallo.
Future<Map<String, dynamic>> registrarUsuario({
  required SupabaseClient client,
  required String email,
  required String password,
  required String nombres,
  required String apellidos,
  required String cedulaIdentidad,
  required String numColegioVeterinario,
  required String rol, // 'administrador' o 'veterinario'
  required String sectorEjercicio,
}) async {
  if (client == null) throw Exception('SupabaseClient no proporcionado.');

  // Validaciones básicas
  email = email.trim().toLowerCase();
  if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.[A-Za-z]{2,}$').hasMatch(email)) {
    throw Exception('Correo electrónico con formato inválido.');
  }
  if (password.isEmpty || password.length < 6) {
    throw Exception('Contraseña inválida (mínimo 6 caracteres).');
  }
  if (rol != 'administrador' && rol != 'veterinario') {
    throw Exception('Rol inválido. Use \"administrador\" o \"veterinario\".');
  }

  try {
    // 1) Crear usuario en Auth
    final res = await client.auth.signUp(email: email, password: password);
    final user = res.user ?? client.auth.currentUser;
    print('signUp res: $res');
    print('user id: ${user?.id}');

    // Normalización: algunos SDKs retornan user en res.user, si no, comprobar currentUser
    final authId = user.id;

    // 2) Preparar payload exactamente con los nombres de columna requeridos
    final Map<String, dynamic> payload = {
      'auth_id': authId,
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'cedula_identidad': cedulaIdentidad.trim(),
      'num_colegio_veterinario': numColegioVeterinario.trim(),
      'rol': rol,
      'sector_ejercicio': sectorEjercicio.trim(),
      'estado_usuario': 'activo',
    };

    // 3) Insertar en la tabla 'perfil' y devolver la fila creada
    try {
      final insert = await client.from('perfil').insert(payload).select().maybeSingle();
      print('insert result: $insert');
    } on PostgrestException catch (e) {
      print('PG error: message=${e.message}, details=${e.details}, hint=${e.hint}, code=${e.code}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DB error: ${e.message ?? e.details ?? e.toString()}')));
    } catch (e, st) {
      print('unexpected error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    }

    return Map<String, dynamic>.from(insert as Map);
  } on AuthException catch (e) {
    // Errores de autenticación supabase
    throw Exception('Auth error: ${e.message}');
  } catch (e) {
    // Re-lanzar con mensaje claro
    throw Exception('Error al registrar usuario: $e');
  }
}

final stream = supabase
  .from('perfil')
  .stream(primaryKey: ['auth_id'])
  .eq('rol', 'veterinario')
  .order('created_at', ascending: false);

stream.listen((rows) {
  // actualizar provider/state con rows
});

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>?> registrarVacuna({
  required BuildContext context,
  required SupabaseClient client,
  required String nombre,
  String? descripcion,
  required int cantidad,
  int? cantidadDosis,
  String? lote,
  DateTime? fechaVencimiento, // puede ser null
}) async {
  try {
    final payload = <String, dynamic>{
      'nombre': nombre.trim(),
      'descripcion': descripcion?.trim(),
      'cantidad': cantidad,
      'cantidad_dosis': cantidadDosis ?? 0,
      'lote': lote?.trim(),
      // Supabase acepta ISO8601 para date/timestamptz; Postgres hará cast
      if (fechaVencimiento != null) 'fecha_vencimiento': fechaVencimiento.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    final res = await client.from('lotevacuna').insert(payload).select().maybeSingle();

    if (res == null) {
      final msg = 'Inserción devolvió null. Revise políticas RLS/permissions en Supabase.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando vacuna: $msg')));
      return null;
    }

    // Éxito: devolver fila creada (Map)
    return Map<String, dynamic>.from(res as Map);
  } on PostgrestException catch (e) {
    final err = e.message ?? e.details ?? e.toString();
    final msg = err.isNotEmpty ? err : 'Error PostgREST desconocido';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permiso/DB error: $msg')));
    return null;
  } catch (e) {
    final msg = e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando vacuna: $msg')));
    return null;
  }
}

Future<Map<String, dynamic>?> registrarJornada({
  required BuildContext context,
  required SupabaseClient client,
  required String nombre,
  required DateTime fecha,
  String? ubicacion,
  String? descripcion,
  String estado = 'pendiente',
  List<Map<String, dynamic>>? vacunas, // lista de {vacuna_id: '...', cantidad: 1, ...}
}) async {
  try {
    // intentar obtener organizador desde auth (puede ser null si no logueado)
    final user = client.auth.currentUser;
    final organizadorId = user?.id;

    final payload = <String, dynamic>{
      'nombre': nombre.trim(),
      'fecha': fecha.toIso8601String(),
      if (ubicacion != null) 'ubicacion': ubicacion.trim(),
      if (descripcion != null) 'descripcion': descripcion.trim(),
      'estado': estado,
      if (organizadorId != null) 'organizador_id': organizadorId,
      'vacunas': vacunas ?? [],
      'created_at': DateTime.now().toIso8601String(),
    };

    final res = await client.from('jornadas').insert(payload).select().maybeSingle();

    if (res == null) {
      final msg = 'Inserción devolvió null. Revise políticas RLS/permissions en Supabase.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando jornada: $msg')));
      return null;
    }

    return Map<String, dynamic>.from(res as Map);
  } on PostgrestException catch (e) {
    final err = e.message ?? e.details ?? e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permiso/DB error al crear jornada: $err')));
    return null;
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando jornada: ${e.toString()}')));
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';

Future<Map<String, dynamic>?> registrarPerfil({
  required BuildContext context,
  required SupabaseClient client,
  required String email,
  required String password,
  required String nombres,
  required String apellidos,
  required String cedulaIdentidad,
  required String numColegioVeterinario,
  required String rol, // 'veterinario' o 'administrador'
  required String sectorEjercicio, // 'Público' o 'Privado'
  String? telefono,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  // Validaciones mínimas
  final rolNorm = rol.trim().toLowerCase();
  if (!(rolNorm == 'veterinario' || rolNorm == 'administrador')) {
    messenger.showSnackBar(const SnackBar(content: Text('Rol inválido. Use \"veterinario\" o \"administrador\".')));
    return null;
  }
  final sectorNorm = sectorEjercicio.trim();
  if (!(sectorNorm.toLowerCase() == 'público' || sectorNorm.toLowerCase() == 'publico' || sectorNorm.toLowerCase() == 'privado')) {
    messenger.showSnackBar(const SnackBar(content: Text('Sector inválido. Use \"Público\" o \"Privado\".')));
    return null;
  }

  try {
    // 1) Crear usuario en Auth
    final res = await client.auth.signUp(email: email.trim(), password: password);
    final user = res.user ?? client.auth.currentUser;
    if (user == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo crear el usuario en Auth.')));
      return null;
    }
    final authId = user.id;

    // 2) Preparar payload EXACTO con nombres de columna solicitados
    final Map<String, dynamic> payload = {
      'auth_id': authId,
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'cedula_identidad': cedulaIdentidad.trim(),
      'num_colegio_veterinario': numColegioVeterinario.trim(),
      'rol': rolNorm, // guardamos en minúscula
      'sector_ejercicio': sectorNorm,
      'estado_usuario': 'activo',
      'email': email.trim(),
      if (telefono != null && telefono.trim().isNotEmpty) 'telefono': telefono.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    // 3) Insertar en la tabla 'perfil'
    try {
      final insert = await client.from('perfil').insert(payload).select().maybeSingle();

      if (insert == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Error creando perfil. Revise permisos/registro del servidor.')));
        // adicional: imprimir payload para diagnóstico
        // ignore: avoid_print
        print('registrarPerfil payload returned null: $payload');
        return null;
      }

      // Éxito
      messenger.showSnackBar(const SnackBar(content: Text('Perfil creado correctamente.')));
      return Map<String, dynamic>.from(insert as Map);
    } on PostgrestException catch (e) {
      // Mostrar y loggear detalle de Postgrest (permiso/constraint/etc)
      // ignore: avoid_print
      print('Error detalle: ${e.message}');
      // Opcional más info:
      // ignore: avoid_print
      print('Postgrest details: details=${e.details}, hint=${e.hint}, code=${e.code}');
      messenger.showSnackBar(SnackBar(content: Text('DB error: ${e.message ?? 'ver consola'}')));
      return null;
    } catch (e, st) {
      // ignore: avoid_print
      print('Error inesperado al insertar perfil: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      return null;
    }
  } on AuthException catch (e) {
    // Errores claros de Auth
    // ignore: avoid_print
    print('Auth error: ${e.message}');
    messenger.showSnackBar(SnackBar(content: Text('Auth error: ${e.message}')));
    return null;
  } catch (e, st) {
    // ignore: avoid_print
    print('Error general en registrarPerfil: $e\n$st');
    messenger.showSnackBar(SnackBar(content: Text('Error al registrar perfil: $e')));
    return null;
  }
}
