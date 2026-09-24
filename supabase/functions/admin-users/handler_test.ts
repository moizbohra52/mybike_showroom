// deno test supabase/functions/admin-users/
// Runs the real handler and supabase-js against an in-memory fetch that plays
// Auth + PostgREST, and checks which key each call carries.
import { deepStrictEqual, ok, strictEqual } from 'node:assert/strict';
import { createHandler } from './handler.ts';

const CALLER = 'a0000000-0000-4000-8000-000000000003';
const NEW_USER = 'b6000000-0000-4000-8000-000000000001';
const SHOWROOM = '5a000000-0000-4000-8000-000000000001';
const ROLE = 'c0000000-0000-4000-8000-000000000001';

type Call = { method: string; path: string; authorization: string | null; body: Record<string, unknown> | null };
type Route = (call: Call) => Response;

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

function fakeSupabase(overrides: Record<string, Route> = {}) {
  const calls: Call[] = [];
  const routes: Record<string, Route> = {
    'GET /auth/v1/user': (c) =>
      c.authorization === 'Bearer caller-jwt'
        ? reply(200, { id: CALLER, aud: 'authenticated', role: 'authenticated' })
        : reply(401, { code: 401, error_code: 'bad_jwt', msg: 'invalid JWT' }),
    'POST /rest/v1/rpc/has_permission_for': () => reply(200, true),
    'POST /rest/v1/rpc/can_assign_role': () => reply(200, true),
    'POST /rest/v1/rpc/can_manage_user': () => reply(200, true),
    'POST /auth/v1/admin/users': () => reply(200, { id: NEW_USER, email: 'new.exec@mybike.test' }),
    'POST /rest/v1/user_showrooms': () => new Response(null, { status: 201 }),
    'POST /rest/v1/user_roles': () => new Response(null, { status: 201 }),
    'POST /rest/v1/rpc/rpc_admin_update_user': () => new Response(null, { status: 204 }),
    [`DELETE /auth/v1/admin/users/${NEW_USER}`]: () => reply(200, { id: NEW_USER }),
    [`PUT /auth/v1/admin/users/${NEW_USER}`]: () => reply(200, { id: NEW_USER }),
    ...overrides,
  };
  const fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const request = new Request(input, init);
    const raw = await request.text();
    const call: Call = {
      method: request.method,
      path: new URL(request.url).pathname,
      authorization: request.headers.get('Authorization'),
      body: raw ? JSON.parse(raw) : null,
    };
    calls.push(call);
    const route = routes[`${call.method} ${call.path}`];
    return route ? route(call) : reply(404, { message: `unexpected ${call.method} ${call.path}` });
  };
  const handler = createHandler({
    url: 'https://project.supabase.co',
    anonKey: 'anon-key',
    serviceRoleKey: 'service-key',
    fetch,
  });
  const find = (method: string, path: string) => calls.filter((c) => c.method === method && c.path === path);
  return { handler, calls, find };
}

function post(body: unknown, token: string | null = 'caller-jwt'): Request {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  return new Request('https://project.supabase.co/functions/v1/admin-users', {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
}

const newUser = {
  action: 'create',
  email: ' New.Exec@MyBike.test ',
  password: 'Welcome@2026',
  full_name: 'New Exec',
  showroom_id: SHOWROOM,
  role_id: ROLE,
  phone: '+919800000001',
};

async function errorCode(response: Response): Promise<string> {
  return ((await response.json()) as { error: { code: string } }).error.code;
}

Deno.test('answers the CORS preflight', async () => {
  const { handler } = fakeSupabase();
  const response = await handler(new Request('https://x/functions/v1/admin-users', { method: 'OPTIONS' }));
  strictEqual(response.status, 200);
  ok(response.headers.get('Access-Control-Allow-Headers')?.includes('authorization'));
  await response.body?.cancel();
});

Deno.test('rejects requests without a valid session before any privileged call', async () => {
  const { handler, calls } = fakeSupabase();
  const missing = await handler(post(newUser, null));
  strictEqual(missing.status, 401);
  await missing.body?.cancel();
  const forged = await handler(post(newUser, 'forged-jwt'));
  strictEqual(forged.status, 401);
  await forged.body?.cancel();
  ok(calls.every((c) => c.authorization !== 'Bearer service-key'));
});

Deno.test('validates the input before any privileged call', async () => {
  const { handler, find } = fakeSupabase();
  const weak = await handler(post({ ...newUser, password: 'short1A' }));
  strictEqual(weak.status, 400);
  strictEqual(await errorCode(weak), 'weak_password');
  const email = await handler(post({ ...newUser, email: 'not-an-email' }));
  strictEqual(await errorCode(email), 'invalid_email');
  const scope = await handler(post({ ...newUser, role_id: 'ADMIN' }));
  strictEqual(await errorCode(scope), 'invalid_assignment');
  strictEqual(find('POST', '/auth/v1/admin/users').length, 0);
});

Deno.test('refuses to create when the caller may not grant the role; nothing is created', async () => {
  const { handler, find } = fakeSupabase({ 'POST /rest/v1/rpc/can_assign_role': () => reply(200, false) });
  const response = await handler(post(newUser));
  strictEqual(response.status, 403);
  strictEqual(await errorCode(response), 'forbidden');
  strictEqual(find('POST', '/auth/v1/admin/users').length, 0);
});

Deno.test('creates with the service role, assigns with the caller JWT', async () => {
  const { handler, find, calls } = fakeSupabase();
  const response = await handler(post(newUser));
  strictEqual(response.status, 200);
  deepStrictEqual(await response.json(), { user_id: NEW_USER });

  const [create] = find('POST', '/auth/v1/admin/users');
  strictEqual(create.authorization, 'Bearer service-key');
  strictEqual(create.body?.email, 'new.exec@mybike.test');
  strictEqual(create.body?.email_confirm, true);
  deepStrictEqual(create.body?.app_metadata, { invited_by: CALLER });

  const [membership] = find('POST', '/rest/v1/user_showrooms');
  deepStrictEqual(membership.body, { profile_id: NEW_USER, showroom_id: SHOWROOM, is_default: true });
  const [role] = find('POST', '/rest/v1/user_roles');
  deepStrictEqual(role.body, { profile_id: NEW_USER, role_id: ROLE, showroom_id: SHOWROOM });
  const [profile] = find('POST', '/rest/v1/rpc/rpc_admin_update_user');
  strictEqual(profile.body?.p_phone, '+919800000001');

  // Database access never uses the service role key: RLS decides every write.
  ok(calls.filter((c) => c.path.startsWith('/rest/v1/')).every((c) => c.authorization === 'Bearer caller-jwt'));
});

Deno.test('rolls the auth user back when RLS refuses an assignment', async () => {
  const { handler, find } = fakeSupabase({
    'POST /rest/v1/user_roles': () =>
      reply(403, { code: '42501', message: 'new row violates row-level security policy for table "user_roles"' }),
  });
  const response = await handler(post(newUser));
  strictEqual(response.status, 403);
  strictEqual(await errorCode(response), 'forbidden');
  const deleted = find('DELETE', `/auth/v1/admin/users/${NEW_USER}`);
  strictEqual(deleted.length, 1);
  strictEqual(deleted[0].authorization, 'Bearer service-key');
});

Deno.test('reports an existing email as a conflict', async () => {
  const { handler } = fakeSupabase({
    'POST /auth/v1/admin/users': () =>
      reply(422, { code: 422, error_code: 'email_exists', msg: 'A user with this email address has already been registered' }),
  });
  const response = await handler(post(newUser));
  strictEqual(response.status, 409);
  strictEqual(await errorCode(response), 'email_exists');
});

Deno.test('set_password requires can_manage_user', async () => {
  const { handler, find } = fakeSupabase({ 'POST /rest/v1/rpc/can_manage_user': () => reply(200, false) });
  const response = await handler(post({ action: 'set_password', user_id: NEW_USER, password: 'Welcome@2026' }));
  strictEqual(response.status, 403);
  await response.body?.cancel();
  strictEqual(find('PUT', `/auth/v1/admin/users/${NEW_USER}`).length, 0);
});

Deno.test('set_password sets the new password with the service role', async () => {
  const { handler, find } = fakeSupabase();
  const response = await handler(post({ action: 'set_password', user_id: NEW_USER, password: 'Welcome@2026' }));
  strictEqual(response.status, 200);
  await response.body?.cancel();
  const [update] = find('PUT', `/auth/v1/admin/users/${NEW_USER}`);
  strictEqual(update.body?.password, 'Welcome@2026');
  strictEqual(update.authorization, 'Bearer service-key');
});

Deno.test('rejects unknown actions', async () => {
  const { handler } = fakeSupabase();
  const response = await handler(post({ action: 'delete_everyone' }));
  strictEqual(response.status, 400);
  strictEqual(await errorCode(response), 'invalid_action');
});
