-- ============================================================
-- Stuck Monitoring: database user (jalankan di Supabase > SQL Editor)
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

-- 1. Tabel user (password disimpan dalam bentuk hash bcrypt)
create table if not exists public.app_users (
  id            uuid primary key default gen_random_uuid(),
  username      text not null unique,
  name          text not null,
  password_hash text not null,
  level         text not null check (level in ('Admin','SuperAdmin')),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- Kunci tabel: tidak ada akses langsung dari browser (anon/authenticated)
alter table public.app_users enable row level security;
revoke all on public.app_users from anon, authenticated;

-- 2. Fungsi cek SuperAdmin (dipakai fungsi lain)
create or replace function public.app_require_superadmin(p_username text, p_password text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not exists (
    select 1 from public.app_users
    where username = p_username
      and is_active
      and level = 'SuperAdmin'
      and password_hash = extensions.crypt(p_password, password_hash)
  ) then
    raise exception 'Akses ditolak: hanya SuperAdmin yang dapat melakukan ini';
  end if;
end;
$$;

-- 3. Login: mengembalikan data user (tanpa password)
create or replace function public.app_login(p_username text, p_password text)
returns table(username text, name text, level text)
language sql
security definer
set search_path = public, extensions
as $$
  select u.username, u.name, u.level
  from public.app_users u
  where u.username = p_username
    and u.is_active
    and u.password_hash = extensions.crypt(p_password, u.password_hash);
$$;

-- 4. Daftar pengguna (hanya SuperAdmin)
create or replace function public.list_users(p_username text, p_password text)
returns table(username text, name text, level text, is_active boolean)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform public.app_require_superadmin(p_username, p_password);
  return query
    select u.username, u.name, u.level, u.is_active
    from public.app_users u
    order by u.created_at, u.username;
end;
$$;

-- 5. Tambah pengguna (hanya SuperAdmin)
create or replace function public.create_user(
  p_actor_username text, p_actor_password text,
  p_username text, p_name text, p_password text, p_level text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform public.app_require_superadmin(p_actor_username, p_actor_password);
  if length(coalesce(p_password,'')) < 6 then
    raise exception 'Password minimal 6 karakter';
  end if;
  if exists (select 1 from public.app_users where username = p_username) then
    raise exception 'Username sudah dipakai';
  end if;
  insert into public.app_users (username, name, password_hash, level)
  values (p_username, p_name, extensions.crypt(p_password, extensions.gen_salt('bf')), p_level);
end;
$$;

-- 6. Hapus pengguna (hanya SuperAdmin; tidak bisa hapus diri sendiri atau SuperAdmin terakhir)
create or replace function public.delete_user(
  p_actor_username text, p_actor_password text, p_username text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_level text;
begin
  perform public.app_require_superadmin(p_actor_username, p_actor_password);
  if p_username = p_actor_username then
    raise exception 'Tidak bisa menghapus akun sendiri';
  end if;
  select level into v_level from public.app_users where username = p_username;
  if v_level = 'SuperAdmin' and (select count(*) from public.app_users where level = 'SuperAdmin') <= 1 then
    raise exception 'Tidak bisa menghapus SuperAdmin terakhir';
  end if;
  delete from public.app_users where username = p_username;
end;
$$;

-- 7. Izin eksekusi fungsi untuk aplikasi web (anon key)
revoke execute on function public.app_require_superadmin(text,text) from public, anon;
revoke execute on function public.app_login(text,text)              from public;
revoke execute on function public.list_users(text,text)             from public;
revoke execute on function public.create_user(text,text,text,text,text,text) from public;
revoke execute on function public.delete_user(text,text,text)       from public;
grant  execute on function public.app_login(text,text)              to anon, authenticated;
grant  execute on function public.list_users(text,text)             to anon, authenticated;
grant  execute on function public.create_user(text,text,text,text,text,text) to anon, authenticated;
grant  execute on function public.delete_user(text,text,text)       to anon, authenticated;

-- 8. Data awal (akun default). Ganti password setelah berhasil login pertama.
insert into public.app_users (username, name, password_hash, level) values
  ('admin',      'Admin',       extensions.crypt('admin123', extensions.gen_salt('bf')), 'Admin'),
  ('superadmin', 'Super Admin', extensions.crypt('super123', extensions.gen_salt('bf')), 'SuperAdmin')
on conflict (username) do nothing;

-- Cek hasil:
-- select username, name, level, is_active from public.app_users;
