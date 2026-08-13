import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse({ error: "Brakuje ustawień Supabase w Edge Function." }, 500);
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization) {
      return jsonResponse({ error: "Brak zalogowanego użytkownika." }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return jsonResponse({ error: "Sesja wygasła. Zaloguj się ponownie." }, 401);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { data: manager, error: managerError } = await admin
      .from("profiles")
      .select("id, role, active")
      .eq("id", userData.user.id)
      .single();

    if (managerError || !manager) {
      console.error("MANAGER PROFILE ERROR:", managerError);
      return jsonResponse({ error: "Nie znaleziono Twojego profilu w bazie." }, 403);
    }

    if (manager.role !== "manager" || manager.active !== true) {
      return jsonResponse({ error: "Nie masz uprawnień managera." }, 403);
    }

    const body = await req.json();
    const full_name = String(body.full_name || "").trim();
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const position = String(body.position || "Początkujący kelner").trim();
    const role = body.role === "manager" ? "manager" : "employee";

    if (!full_name) return jsonResponse({ error: "Podaj imię i nazwisko pracownika." }, 400);
    if (!email) return jsonResponse({ error: "Podaj adres e-mail." }, 400);
    if (password.length < 8) return jsonResponse({ error: "Hasło musi mieć minimum 8 znaków." }, 400);

    const { data: newUserData, error: createUserError } =
      await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name },
      });

    if (createUserError || !newUserData.user) {
      console.error("CREATE USER ERROR:", createUserError);
      return jsonResponse({
        error: createUserError?.message || "Nie udało się utworzyć konta.",
      }, 400);
    }

    const newUserId = newUserData.user.id;

    // profiles NIE musi mieć kolumny email.
    const { error: profileError } = await admin.from("profiles").insert({
      id: newUserId,
      full_name,
      position,
      role,
      active: true,
    });

    if (profileError) {
      console.error("PROFILE ERROR:", profileError);
      await admin.auth.admin.deleteUser(newUserId);
      return jsonResponse({
        error: "Nie udało się utworzyć profilu: " + profileError.message,
      }, 400);
    }

    return jsonResponse({
      success: true,
      message: "Pracownik został utworzony.",
      user_id: newUserId,
    });
  } catch (error) {
    console.error("FUNCTION ERROR:", error);
    return jsonResponse({
      error: error instanceof Error ? error.message : "Nieznany błąd.",
    }, 500);
  }
});
