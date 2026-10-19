-- Migração para a v1.1.0 — rode no SQL Editor do Supabase.
--
-- A aba "Meus dias" passou a guardar horário, título livre e notas por entrada.
-- Sem estas colunas o app continua funcionando (o localStorage é a fonte de verdade),
-- mas a sincronização com o banco falha, porque o insert manda colunas que não existem.

-- horário da entrada no dia (nulo = sem hora marcada)
alter table public.itinerary_items add column if not exists start_time time;

-- título de entradas que não vêm do catálogo ("Trem pra Kyoto", "Almoço com a Yuki")
alter table public.itinerary_items add column if not exists title text;

-- entradas livres não têm atração associada
alter table public.itinerary_items alter column place_id drop not null;

-- a mesma atração agora pode repetir no dia (ex: passar pela estação de manhã e à noite),
-- e várias entradas livres convivem no mesmo dia
alter table public.itinerary_items
  drop constraint if exists itinerary_items_trip_id_day_date_place_id_key;
