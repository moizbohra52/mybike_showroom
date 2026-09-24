// admin-users — the user-administration steps that need the Auth admin API.
//
// Security model (docs/phase-06/README.md):
//   * The caller's JWT is verified with the Auth server (getUser); nothing in
//     the body is trusted.
//   * Every permission decision and every database write runs with the
//     CALLER's JWT, so RLS stays the authority (G1). The service role key is
//     used only for the Auth admin API: create user, set password, roll back.
//   * app_metadata.invited_by (writable only with the service role key)
//     records the creator, which lets the caller assign the new user.
//
// POST { action: 'create', email, password, full_name, showroom_id, role_id,
//        phone?, designation?, employee_code? }        → { user_id }
// POST { action: 'set_password', user_id, password }    → { ok: true }
// Errors: { error: { code, message } } with 400/401/403/409/500; messages are
// safe to show to the user.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.117.1';

export type HandlerConfig = {
  url?: string;
  anonKey?: string;
  serviceRoleKey?: string;
  /** Injected in tests. */
  fetch?: typeof fetch;
};

type Body = Record<string, unknown>;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export class HttpError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message);
  }
}

export function createHandler(config: HandlerConfig): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders });
    }
    try {
      if (req.method !== 'POST') {
        throw new HttpError(405, 'method_not_allowed', 'Use POST.');
      }
      const { url, anonKey, serviceRoleKey } = config;
      if (!url || !anonKey || !serviceRoleKey) {
        console.error('admin-users: SUPABASE_URL, SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY is missing');
        throw new HttpError(500, 'server_misconfigured', 'The server is not configured. Contact your administrator.');
      }
      const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
      if (!token) {
        throw new HttpError(401, 'unauthorized', 'Your session has expired. Please sign in again.');
      }

      const auth = { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false };
      const caller = createClient(url, anonKey, {
        auth,
        global: { headers: { Authorization: `Bearer ${token}` }, fetch: config.fetch },
      });
      const { data, error } = await caller.auth.getUser(token);
      if (error || !data.user) {
        throw new HttpError(401, 'unauthorized', 'Your session has expired. Please sign in again.');
      }
      const admin = createClient(url, serviceRoleKey, { auth, global: { fetch: config.fetch } });

      const body = (await req.json().catch(() => null)) as Body | null;
      switch (body?.action) {
        case 'create':
          return json(200, await createUser(caller, admin, data.user.id, body));
        case 'set_password':
          return json(200, await setPassword(caller, admin, body));
        default:
          throw new HttpError(400, 'invalid_action', 'Unknown action.');
      }
    } catch (e) {
      if (e instanceof HttpError) {
        return json(e.status, { error: { code: e.code, message: e.message } });
      }
      console.error('admin-users', e);
      return json(500, { error: { code: 'server_error', message: 'The request could not be completed. Please try again.' } });
    }
  };
}

async function createUser(caller: SupabaseClient, admin: SupabaseClient, callerId: string, body: Body) {
  const email = text(body.email).toLowerCase();
  const fullName = text(body.full_name);
  const showroomId = text(body.showroom_id);
  const roleId = text(body.role_id);
  const password = typeof body.password === 'string' ? body.password : '';
  if (email.length > 254 || !emailPattern.test(email)) {
    throw new HttpError(400, 'invalid_email', 'Enter a valid email address.');
  }
  if (fullName.length < 1 || fullName.length > 120) {
    throw new HttpError(400, 'invalid_name', 'Enter the full name (up to 120 characters).');
  }
  if (!uuidPattern.test(showroomId) || !uuidPattern.test(roleId)) {
    throw new HttpError(400, 'invalid_assignment', 'Choose a showroom and a role.');
  }
  checkPassword(password);

  // Checked as the caller before anything is created; RLS re-checks every
  // write below.
  await requireTrue(caller.rpc('has_permission_for', { p_module: 'users', p_action: 'create', p_showroom_id: showroomId }));
  await requireTrue(caller.rpc('can_assign_role', { p_role_id: roleId, p_showroom_id: showroomId }));

  const created = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
    app_metadata: { invited_by: callerId },
  });
  if (created.error || !created.data.user) {
    throw authAdminError(created.error);
  }
  const userId = created.data.user.id;
  try {
    await must(caller.from('user_showrooms').insert({ profile_id: userId, showroom_id: showroomId, is_default: true }));
    await must(caller.from('user_roles').insert({ profile_id: userId, role_id: roleId, showroom_id: showroomId }));
    await must(caller.rpc('rpc_admin_update_user', {
      p_profile_id: userId,
      p_full_name: fullName,
      p_phone: text(body.phone),
      p_designation: text(body.designation),
      p_employee_code: text(body.employee_code),
    }));
  } catch (e) {
    // Deleting the auth user cascades to the profile and its assignments.
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) {
      console.error('admin-users: rollback failed for', userId, error);
    }
    throw e;
  }
  return { user_id: userId };
}

async function setPassword(caller: SupabaseClient, admin: SupabaseClient, body: Body) {
  const userId = text(body.user_id);
  const password = typeof body.password === 'string' ? body.password : '';
  if (!uuidPattern.test(userId)) {
    throw new HttpError(400, 'invalid_user', 'Choose a user.');
  }
  checkPassword(password);
  await requireTrue(caller.rpc('can_manage_user', { p_profile_id: userId }));

  const { error } = await admin.auth.admin.updateUserById(userId, { password });
  if (error) {
    throw authAdminError(error);
  }
  return { ok: true };
}

/** Same rule as supabase/config.toml: 10+ characters, lower, upper, digit. */
export function checkPassword(password: string): void {
  if (password.length < 10 || password.length > 72 || !/[a-z]/.test(password) || !/[A-Z]/.test(password) ||
    !/[0-9]/.test(password)) {
    throw new HttpError(
      400,
      'weak_password',
      'Use 10–72 characters with at least one lowercase letter, one uppercase letter and one digit.',
    );
  }
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

async function requireTrue(call: PromiseLike<{ data: unknown; error: { code?: string } | null }>): Promise<void> {
  const { data, error } = await call;
  if (error) {
    throw databaseError(error);
  }
  if (data !== true) {
    throw new HttpError(403, 'forbidden', 'You do not have permission to perform this action.');
  }
}

async function must(call: PromiseLike<{ error: { code?: string } | null }>): Promise<void> {
  const { error } = await call;
  if (error) {
    throw databaseError(error);
  }
}

function databaseError(error: { code?: string }): Error {
  switch (error.code) {
    case '42501':
      return new HttpError(403, 'forbidden', 'You do not have permission to perform this action.');
    case '23505':
      return new HttpError(409, 'duplicate', 'This email or employee code is already in use.');
    case '23514':
    case '23502':
    case '22P02':
    case '22023':
      return new HttpError(400, 'invalid', 'Check the phone number, designation and employee code.');
    default:
      return new Error(`database error ${error.code ?? 'unknown'}`);
  }
}

function authAdminError(error: { code?: string; status?: number } | null): Error {
  if (error?.code === 'email_exists' || error?.code === 'user_already_exists') {
    return new HttpError(409, 'email_exists', 'A user with this email address already exists.');
  }
  if (error?.code === 'weak_password') {
    return new HttpError(400, 'weak_password', 'The password is too weak. Choose a stronger one.');
  }
  if (error?.code === 'user_not_found') {
    return new HttpError(404, 'not_found', 'The user could not be found.');
  }
  return new Error(`auth admin error ${error?.code ?? error?.status ?? 'unknown'}`);
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
