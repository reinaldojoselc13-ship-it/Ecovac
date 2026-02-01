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

-- 5) Add missing columns to lotevacuna table
ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS descripcion text;

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS laboratorio text;

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS fecha_ingreso date;

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS n_lote text;

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS n_factura text;

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS proveedor text;

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS presentacion text;

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS dosis_por_frasco text;

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS cantidad_frascos integer;

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS veterinario_asignado_id uuid REFERENCES public.staff(id);

ALTER TABLE public.lotevacuna
  ADD COLUMN IF NOT EXISTS lote_vacuna_asignado_id uuid REFERENCES public.lotevacuna(id);

-- 5) Temporary permissive RLS policies for diagnosis (REMOVE after tests)
-- Enable RLS if not enabled
ALTER TABLE public.perfil ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;

-- Also enable RLS for main entities
ALTER TABLE public.lotevacuna ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jornadas ENABLE ROW LEVEL SECURITY;

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

DROP POLICY IF EXISTS allow_all_lotevacuna ON public.lotevacuna;
CREATE POLICY allow_all_lotevacuna ON public.lotevacuna FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS allow_all_jornadas ON public.jornadas;
CREATE POLICY allow_all_jornadas ON public.jornadas FOR ALL USING (true) WITH CHECK (true);

-- 5b) SECURE RLS POLICIES (recommended for production)
-- NOTE: These policies assume `staff.id` == `auth.uid()`.

-- Helper: check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS(
    SELECT 1
    FROM public.staff s
    WHERE s.id = auth.uid()
      AND (s.is_admin = true OR lower(coalesce(s.role, '')) IN ('admin','administrador'))
  );
$$;

-- Replace permissive policies with secure ones (idempotent)

-- PERFIL: leave as-is for now (depends on your app), but remove allow_all in production.

-- STAFF
DROP POLICY IF EXISTS staff_select_all ON public.staff;
CREATE POLICY staff_select_all ON public.staff
FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS staff_modify_admin ON public.staff;
CREATE POLICY staff_modify_admin ON public.staff
FOR INSERT, UPDATE, DELETE TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

-- LOTEVACUNA
DROP POLICY IF EXISTS lotevacuna_select_all ON public.lotevacuna;
CREATE POLICY lotevacuna_select_all ON public.lotevacuna
FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS lotevacuna_modify_admin ON public.lotevacuna;
CREATE POLICY lotevacuna_modify_admin ON public.lotevacuna
FOR INSERT, UPDATE, DELETE TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

-- JORNADAS
DROP POLICY IF EXISTS jornadas_select_all ON public.jornadas;
CREATE POLICY jornadas_select_all ON public.jornadas
FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS jornadas_modify_admin ON public.jornadas;
CREATE POLICY jornadas_modify_admin ON public.jornadas
FOR INSERT, UPDATE, DELETE TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

-- IMPORTANT:
-- Once you apply the secure policies, REMOVE the permissive allow_all_* policies below.

-- 6) Helpful diagnostics queries you can run after applying
-- List policies:
-- SELECT * FROM pg_policies WHERE schemaname='public' AND tablename IN ('perfil','staff','lotevacuna','jornadas');
-- List columns:
-- SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='jornadas';
-- List constraints for jornadas:
-- SELECT conname, contype, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'public.jornadas'::regclass;

-- IMPORTANT:
-- After you verify client INSERT/UPSERT works with temporary policies, replace the permissive policies
-- with secure ones granting only the minimum necessary permissions (e.g., allow users to SELECT their own perfil,
-- and use an RPC or server-side function for admin-only operations that requires the service_role key).

-- Example secure policy (for later):
-- CREATE POLICY select_own ON public.perfil FOR SELECT USING (auth.uid() = auth_id::text);

-- End of file
