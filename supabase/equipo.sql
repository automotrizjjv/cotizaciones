-- Lista de correos autorizados: solo ellos pueden crear su cuenta en la app.
-- Para agregar a alguien: Table Editor → equipo → Insert row (email y nombre).
create table if not exists public.equipo (
  email text primary key,
  nombre text not null,
  creado timestamptz not null default now()
);
alter table public.equipo enable row level security;
revoke all on public.equipo from anon, authenticated;

create or replace function public.validar_registro() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_nombre text;
begin
  select nombre into v_nombre from public.equipo where lower(email) = lower(new.email);
  if v_nombre is null then
    raise exception 'correo_no_autorizado';
  end if;
  new.raw_user_meta_data := coalesce(new.raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('nombre', v_nombre);
  return new;
end $$;
drop trigger if exists validar_registro on auth.users;
create trigger validar_registro before insert on auth.users
  for each row execute function public.validar_registro();

-- Cuenta única del equipo (todos entran con la misma clave)
insert into public.equipo (email, nombre) values ('equipo@automotrizjjv.com', 'Equipo JJV')
on conflict (email) do nothing;
