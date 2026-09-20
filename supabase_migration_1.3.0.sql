-- Migração para a v1.3.0 — rode no SQL Editor do Supabase.
--
-- Cria a tabela do checklist da viagem. Sem ela o checklist funciona normalmente,
-- mas fica só neste navegador: não sobe pra conta nem aparece em outro aparelho.

create table if not exists public.checklist_items (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  trip_id     uuid not null references public.trips(id) on delete cascade,
  section     text,
  title       text not null,
  notes       text,
  done        boolean not null default false,
  -- progresso, pros itens que são acúmulo e não sim/não (ex: quanto de iene já comprou)
  amount      numeric,
  target      numeric,
  unit        text,
  position    integer not null default 0,
  created_at  timestamptz not null default now()
);

create index if not exists checklist_trip_idx on public.checklist_items (trip_id, position);

alter table public.checklist_items enable row level security;

-- Mesma regra das outras tabelas: cada usuário só enxerga e altera as próprias linhas.
drop policy if exists "checklist_items_select_own" on public.checklist_items;
create policy "checklist_items_select_own" on public.checklist_items
  for select using (auth.uid() = user_id);

drop policy if exists "checklist_items_insert_own" on public.checklist_items;
create policy "checklist_items_insert_own" on public.checklist_items
  for insert with check (auth.uid() = user_id);

drop policy if exists "checklist_items_update_own" on public.checklist_items;
create policy "checklist_items_update_own" on public.checklist_items
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "checklist_items_delete_own" on public.checklist_items;
create policy "checklist_items_delete_own" on public.checklist_items
  for delete using (auth.uid() = user_id);
