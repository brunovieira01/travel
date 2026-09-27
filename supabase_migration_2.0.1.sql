-- Migração para a v2.0.1 — rode no SQL Editor do Supabase.
--
-- POR QUE ESTA MIGRAÇÃO EXISTE
--
-- A tabela `stays` ficava vazia mesmo depois de salvar uma reserva, sem erro
-- nenhum na tela. Duas causas somadas:
--
--   1. No app: o supabase-js v2 devolve { data, error } em vez de lançar
--      exceção. O código fazia `await sb.from("stays").insert(rows)` dentro de
--      um try/catch e nunca olhava o `error` — então a recusa do banco era
--      descartada, `syncState` virava "on" e a barra dizia "sincronizado".
--      Isso já foi corrigido no index.html (a v2.0.1 mostra o erro real).
--
--   2. No banco: a recusa em si. As colunas foram todas verificadas uma a uma
--      contra a API e existem (id, user_id, trip_id, name, city, address, type,
--      status, checkin, checkout, price, booked_on, site, code, notes,
--      created_at), então não é diferença de schema. O que sobra é RLS: a
--      `checklist_items` nasceu na migração 1.3.0 já com as quatro políticas
--      explícitas — e é justamente a única que sincroniza. As tabelas mais
--      antigas provavelmente têm RLS ligado sem política de INSERT, o que faz o
--      Postgres recusar com 42501 ("new row violates row-level security policy").
--
-- Esta migração é idempotente: pode rodar quantas vezes quiser, não apaga dado
-- nenhum e não muda nenhuma coluna. Só garante que cada tabela tenha as quatro
-- políticas "só as próprias linhas", iguais às do checklist.

-- ---------------------------------------------------------------------------
-- trips
-- ---------------------------------------------------------------------------
alter table public.trips enable row level security;

drop policy if exists "trips_select_own" on public.trips;
create policy "trips_select_own" on public.trips
  for select using (auth.uid() = user_id);

drop policy if exists "trips_insert_own" on public.trips;
create policy "trips_insert_own" on public.trips
  for insert with check (auth.uid() = user_id);

drop policy if exists "trips_update_own" on public.trips;
create policy "trips_update_own" on public.trips
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "trips_delete_own" on public.trips;
create policy "trips_delete_own" on public.trips
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- stays  — a tabela do problema
-- ---------------------------------------------------------------------------
alter table public.stays enable row level security;

drop policy if exists "stays_select_own" on public.stays;
create policy "stays_select_own" on public.stays
  for select using (auth.uid() = user_id);

drop policy if exists "stays_insert_own" on public.stays;
create policy "stays_insert_own" on public.stays
  for insert with check (auth.uid() = user_id);

drop policy if exists "stays_update_own" on public.stays;
create policy "stays_update_own" on public.stays
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "stays_delete_own" on public.stays;
create policy "stays_delete_own" on public.stays
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- itinerary_items  (aba "Meus dias")
-- ---------------------------------------------------------------------------
alter table public.itinerary_items enable row level security;

drop policy if exists "itinerary_items_select_own" on public.itinerary_items;
create policy "itinerary_items_select_own" on public.itinerary_items
  for select using (auth.uid() = user_id);

drop policy if exists "itinerary_items_insert_own" on public.itinerary_items;
create policy "itinerary_items_insert_own" on public.itinerary_items
  for insert with check (auth.uid() = user_id);

drop policy if exists "itinerary_items_update_own" on public.itinerary_items;
create policy "itinerary_items_update_own" on public.itinerary_items
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "itinerary_items_delete_own" on public.itinerary_items;
create policy "itinerary_items_delete_own" on public.itinerary_items
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- place_status  ("já fui" por atração)
-- ---------------------------------------------------------------------------
alter table public.place_status enable row level security;

drop policy if exists "place_status_select_own" on public.place_status;
create policy "place_status_select_own" on public.place_status
  for select using (auth.uid() = user_id);

drop policy if exists "place_status_insert_own" on public.place_status;
create policy "place_status_insert_own" on public.place_status
  for insert with check (auth.uid() = user_id);

drop policy if exists "place_status_update_own" on public.place_status;
create policy "place_status_update_own" on public.place_status
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "place_status_delete_own" on public.place_status;
create policy "place_status_delete_own" on public.place_status
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Conferência: lista o que ficou valendo. Deve aparecer 4 linhas por tabela.
-- ---------------------------------------------------------------------------
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('trips','stays','itinerary_items','place_status','checklist_items')
order by tablename, cmd;
