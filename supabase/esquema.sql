-- AUTOMOTRIZ JJV · Base compartida del Sistema de Cotizaciones
-- Ejecutar una vez en Supabase → SQL Editor.

create table if not exists public.documentos (
  coleccion text not null,
  id text not null,
  datos jsonb,
  borrado boolean not null default false,
  actualizado timestamptz not null default clock_timestamp(),
  actualizado_por uuid default auth.uid(),
  primary key (coleccion, id)
);
create index if not exists documentos_actualizado on public.documentos (actualizado);

create or replace function public.tocar_documento() returns trigger
language plpgsql set search_path = public as $$
begin
  new.actualizado := clock_timestamp();
  new.actualizado_por := auth.uid();
  return new;
end $$;
drop trigger if exists documentos_tocar on public.documentos;
create trigger documentos_tocar before insert or update on public.documentos
  for each row execute function public.tocar_documento();

alter table public.documentos enable row level security;
drop policy if exists "equipo lee" on public.documentos;
drop policy if exists "equipo agrega" on public.documentos;
drop policy if exists "equipo modifica" on public.documentos;
create policy "equipo lee" on public.documentos for select to authenticated using (true);
create policy "equipo agrega" on public.documentos for insert to authenticated with check (true);
create policy "equipo modifica" on public.documentos for update to authenticated using (true) with check (true);
revoke all on public.documentos from anon;
grant select, insert, update on public.documentos to authenticated;

-- Numeración compartida (cotizaciones, clientes, repuestos)
create table if not exists public.contadores (
  nombre text primary key,
  valor bigint not null default 0
);
alter table public.contadores enable row level security;
revoke all on public.contadores from anon, authenticated;

create or replace function public.reservar(p_nombre text, p_cantidad int default 1) returns bigint
language sql security definer set search_path = public as $$
  insert into public.contadores (nombre, valor) values (p_nombre, greatest(p_cantidad, 1))
  on conflict (nombre) do update set valor = public.contadores.valor + greatest(excluded.valor, 1)
  returning valor;
$$;
create or replace function public.ajustar_contador(p_nombre text, p_minimo bigint) returns bigint
language sql security definer set search_path = public as $$
  insert into public.contadores (nombre, valor) values (p_nombre, greatest(p_minimo, 0))
  on conflict (nombre) do update set valor = greatest(public.contadores.valor, excluded.valor)
  returning valor;
$$;
revoke all on function public.reservar(text, int) from public, anon;
revoke all on function public.ajustar_contador(text, bigint) from public, anon;
grant execute on function public.reservar(text, int) to authenticated;
grant execute on function public.ajustar_contador(text, bigint) to authenticated;
