-- Migração para a v2.11.0 — rode no SQL Editor do Supabase.
--
-- Deixa UMA aba pública: "Meus dias".
--
-- Quem abre o site sem entrar não vê mais o app inteiro (isso acabou na
-- v2.11.0): vê o roteiro montado, só pra ler. Pra isso a sessão anônima
-- precisa poder LER duas tabelas — e só duas:
--
--   trips             → id e slug da viagem marcada como pública
--   itinerary_items   → as paradas de cada dia dessa viagem
--
-- `stays`, `expenses` e `checklist_items` ficam de fora de propósito.
-- Hospedagem, custos e checklist seguem invisíveis sem login, que é o que
-- você pediu: ninguém chega no nome do hotel, no endereço, no número da
-- reserva nem no PIN.
--
-- ⚠️ O que entra em "Meus dias" vira público de verdade: horários, atrações
-- e as NOTAS que você escrever em cada parada. Não escreva ali número de
-- reserva nem nada que não possa ser lido por estranhos.
--
-- Pra desligar tudo depois, sem desfazer a migração:
--   update public.trips set is_public = false where slug = 'japan-2026';
--
-- Idempotente: pode rodar quantas vezes quiser.

-- ---------------------------------------------------------------------------
-- 1. a chave que liga e desliga, por viagem
-- ---------------------------------------------------------------------------
alter table public.trips add column if not exists is_public boolean not null default false;

-- ---------------------------------------------------------------------------
-- 2. leitura anônima, limitada às viagens marcadas como públicas
--
-- `to anon` é o que segura a corda: a política vale só pra quem chega SEM
-- sessão. As políticas que já existem (auth.uid() = user_id) continuam
-- valendo pra você, e políticas se somam — ninguém perde acesso ao que já
-- tinha, e o anônimo não ganha nada além do que está marcado como público.
-- ---------------------------------------------------------------------------
drop policy if exists "trips_select_public" on public.trips;
create policy "trips_select_public" on public.trips
  for select to anon using (is_public);

drop policy if exists "itinerary_items_select_public" on public.itinerary_items;
create policy "itinerary_items_select_public" on public.itinerary_items
  for select to anon using (
    exists (select 1 from public.trips t where t.id = trip_id and t.is_public)
  );

-- ---------------------------------------------------------------------------
-- 3. liga a viagem do Japão
-- ---------------------------------------------------------------------------
update public.trips set is_public = true where slug = 'japan-2026';

-- ---------------------------------------------------------------------------
-- Conferência.
--
-- A primeira consulta deve listar a viagem do Japão com is_public = true.
-- A segunda deve listar exatamente DUAS políticas novas, as duas em SELECT
-- e as duas com roles = {anon}. Se aparecer política de anon em stays,
-- expenses ou checklist_items, algo foi longe demais — apague.
-- ---------------------------------------------------------------------------
select slug, title, is_public from public.trips order by slug;

select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public' and 'anon' = any(roles)
order by tablename, policyname;
