-- Migração para a v2.16.0 — rode no SQL Editor do Supabase.
--
-- Adiciona a prioridade do item do checklist: 1 = alta, 2 = média, 3 = baixa, null = sem prioridade.
-- Sem esta migração o app continua funcionando e sincronizando normalmente; só que a prioridade
-- fica guardada neste aparelho e não aparece no celular.

alter table public.checklist_items
  add column if not exists priority smallint
  check (priority is null or priority between 1 and 3);
