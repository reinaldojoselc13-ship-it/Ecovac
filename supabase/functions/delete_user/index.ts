import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "method_not_allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!url || !anonKey || !serviceRoleKey) {
      return new Response(JSON.stringify({ error: "missing_env" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("Authorization") ?? "";

    const callerClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const adminClient = createClient(url, serviceRoleKey);

    const { data: callerAuth, error: callerAuthErr } = await callerClient.auth.getUser();
    if (callerAuthErr || !callerAuth?.user) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const callerId = callerAuth.user.id;

    const { data: callerStaff, error: staffErr } = await adminClient
      .from("staff")
      .select("id,is_admin,role")
      .eq("id", callerId)
      .maybeSingle();

    if (staffErr || !callerStaff) {
      return new Response(JSON.stringify({ error: "caller_not_found" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }

    const role = String(callerStaff.role ?? "").toLowerCase();
    const isAdmin = callerStaff.is_admin === true || role === "admin" || role === "administrador";

    if (!isAdmin) {
      return new Response(JSON.stringify({ error: "forbidden" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));
    const targetUserId = String(body?.user_id ?? "");

    if (!targetUserId) {
      return new Response(JSON.stringify({ error: "missing_user_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    await adminClient.from("perfil").delete().or(`id.eq.${targetUserId},user_id.eq.${targetUserId}`);
    await adminClient.from("device_authorizations").delete().eq("staff_id", targetUserId);
    await adminClient.from("staff").delete().eq("id", targetUserId);

    const { error: delAuthErr } = await adminClient.auth.admin.deleteUser(targetUserId);
    if (delAuthErr) {
      return new Response(JSON.stringify({ ok: false, error: "auth_delete_failed", details: delAuthErr.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: "unexpected", details: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
