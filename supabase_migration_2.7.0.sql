-- Migração para a v2.7.0 — rode no SQL Editor do Supabase.
--
-- Cria a tabela `expenses`, que alimenta a aba Custos.
--
-- Até rodar isto, a aba Custos FUNCIONA normalmente, só que apenas neste
-- aparelho: o app detecta que a tabela não existe, mantém tudo em
-- localStorage e continua sincronizando as outras quatro tabelas sem erro.
-- Depois de rodar, os gastos passam a aparecer no telefone e no computador.
--
-- Idempotente: pode rodar quantas vezes quiser.

create table if not exists public.expenses (
  id          uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  trip_id     uuid not null references public.trips(id) on delete cascade,

  kind        text not null default 'planejado',  -- planejado | diario
  label       text not null,              -- "Passagem aérea — parcela 2/3"
  group_name  text,                       -- junta parcelas da mesma compra
  category    text,                       -- voo | hospedagem | transporte | comida | passeio | compras | outro
  currency    text not null default 'BRL',-- BRL | JPY
  amount      numeric(12,2) not null default 0,
  method      text,                       -- "Visa ••1511", "Espécie / Revolut JPY"
  charge_date date,                       -- quando o dinheiro sai da conta
  status      text not null default 'agendado',  -- pago | agendado | estimado
  notes       text,
  position    integer not null default 0,
  created_at  timestamptz not null default now()
);

-- Se você rodou a primeira versão desta migração (sem `kind`), esta linha
-- completa o que falta. Em banco novo não faz nada: a coluna já nasceu acima.
alter table public.expenses add column if not exists kind text not null default 'planejado';

-- Consultas da aba são sempre por viagem e ordenadas pela data do débito.
create index if not exists expenses_trip_charge_idx
  on public.expenses (trip_id, charge_date);
create index if not exists expenses_trip_kind_idx
  on public.expenses (trip_id, kind);

-- ---------------------------------------------------------------------------
-- RLS — as mesmas quatro políticas "só as próprias linhas" das outras tabelas.
-- Sem a política de INSERT, o Postgres recusa com 42501 e a aba fica vazia
-- sem erro visível; foi exatamente o que aconteceu com `stays` na 2.0.1.
-- ---------------------------------------------------------------------------
alter table public.expenses enable row level security;

drop policy if exists "expenses_select_own" on public.expenses;
create policy "expenses_select_own" on public.expenses
  for select using (auth.uid() = user_id);

drop policy if exists "expenses_insert_own" on public.expenses;
create policy "expenses_insert_own" on public.expenses
  for insert with check (auth.uid() = user_id);

drop policy if exists "expenses_update_own" on public.expenses;
create policy "expenses_update_own" on public.expenses
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "expenses_delete_own" on public.expenses;
create policy "expenses_delete_own" on public.expenses
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Conferência: deve listar 4 linhas (select, insert, update, delete).
-- ---------------------------------------------------------------------------
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public' and tablename = 'expenses'
order by cmd;
