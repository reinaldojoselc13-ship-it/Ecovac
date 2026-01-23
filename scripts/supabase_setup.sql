-- Idempotent SQL for Supabase: add expected columns and temporary permissive RLS for diagnostics
-- Run this in Supabase SQL editor. Review before applying in production.

-- 1) Create app_users if missing
CREATE TABLE IF NOT EXISTS public.app_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id uuid,
  email text,
  meta jsonb,
  created_at timestamptz DEFAULT now()
);

-- 2) Ensure perfil has expected columns used by client
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='perfil' AND column_name='id') THEN
    ALTER TABLE public.perfil ADD COLUMN id uuid DEFAULT gen_random_uuid();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='perfil' AND column_name='auth_id') THEN
    ALTER TABLE public.perfil ADD COLUMN auth_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='perfil' AND column_name='nombres') THEN
    ALTER TABLE public.perfil ADD COLUMN nombres text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='perfil' AND column_name='apellidos') THEN
    ALTER TABLE public.perfil ADD COLUMN apellidos text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='perfil' AND column_name='telefono') THEN
    ALTER TABLE public.perfil ADD COLUMN telefono text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='perfil' AND column_name='direccion') THEN
    ALTER TABLE public.perfil ADD COLUMN direccion text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='perfil' AND column_name='created_at') THEN
    ALTER TABLE public.perfil ADD COLUMN created_at timestamptz DEFAULT now();
  END IF;
END$$;

-- 3) Ensure lotevacuna.cantidad exists
ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS cantidad integer DEFAULT 0;

-- 4) Ensure staff.email exists
ALTER TABLE public.staff
  ADD COLUMN IF NOT EXISTS email text;

-- 5) Temporary permissive RLS policies for diagnosis (REMOVE after tests)
-- Enable RLS if not enabled
ALTER TABLE public.perfil ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;

-- Drop any existing permissive policy to re-create idempotently
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='perfil' AND policyname='allow_all') THEN
    PERFORM pg_catalog.pg_reload_conf();
  END IF;
END$$;

DROP POLICY IF EXISTS allow_all ON public.perfil;
CREATE POLICY allow_all ON public.perfil FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS allow_all_staff ON public.staff;
CREATE POLICY allow_all_staff ON public.staff FOR ALL USING (true) WITH CHECK (true);

-- 6) Helpful diagnostics queries you can run after applying
-- List policies:
-- SELECT * FROM pg_policies WHERE schemaname='public' AND tablename IN ('perfil','staff');
-- List columns:
-- SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='perfil';
-- List constraints for perfil:
-- SELECT conname, contype, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'public.perfil'::regclass;

-- IMPORTANT:
-- After you verify client INSERT/UPSERT works with temporary policies, replace the permissive policies
-- with secure ones granting only the minimum necessary permissions (e.g., allow users to SELECT their own perfil,
-- and use an RPC or server-side function for admin-only operations that requires the service_role key).

-- Example secure policy (for later):
-- CREATE POLICY select_own ON public.perfil FOR SELECT USING (auth.uid() = auth_id::text);

-- End of file

Future<void> _register() async {
  final supabase = Supabase.instance.client;
  final email = emailController.text.trim();
  final password = passwordController.text;
  final nombres = nombreController.text.trim();
  final apellidos = apellidoController.text.trim();
  final cedula = cedulaController.text.trim();
  final telefono = telefonoController.text.trim();
  final direccion = direccionController.text.trim();
  final sector = sectorSeleccionado; // 'Público' o 'Privado'
  final role = 'veterinario'; // o toma del selector si aplica

  try {
    final authRes = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'nombres': nombres,
        'apellidos': apellidos,
        'cedula': cedula,
        'telefono': telefono,
        'direccion': direccion,
        'sector': sector,
      },
    );

    final user = authRes.user;
    if (user == null) throw Exception('Registro fallido: usuario no creado');

    // Crear fila en staff (usamos el mismo uuid del auth para id)
    final staffInsert = await supabase.from('staff').insert({
      'id': user.id,
      'email': email,
      'nombres': nombres,
      'apellidos': apellidos,
      'cedula': cedula,
      'telefono': telefono,
      'direccion': direccion,
      'numero_colegio': null,
      'role': role,
      'is_admin': false,
      'active': true,
      'created_at': DateTime.now().toIso8601String(),
    }).execute();

    if (staffInsert.error != null) {
      throw Exception('Error insertando staff: ${staffInsert.error!.message}');
    }

    // Crear perfil mínimo ligado al staff
    final perfilInsert = await supabase.from('perfil').insert({
      // si tu perfil usa user_id que apunta a staff.id:
      'user_id': user.id,
      'auth_id': user.id,
      'nombres': nombres,
      'apellidos': apellidos,
      'telefono': telefono,
      'direccion': direccion,
      'rol': role,
      'email': email,
      'created_at': DateTime.now().toIso8601String(),
      'meta': {'created_via': 'app'},
    }).execute();

    if (perfilInsert.error != null) {
      throw Exception('Error insertando perfil: ${perfilInsert.error!.message}');
    }

    // Navegar / informar éxito
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/vet'); // o la ruta que corresponda
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro correcto')),
      );
    }
  } catch (e) {
    final msg = e is PostgrestException ? e.message : e.toString();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
