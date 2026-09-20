# Changelog

Versão fica em `APP_VERSION`, no topo do `<script>` do `index.html`, e aparece como badge
ao lado do título. Regra: bump no mesmo commit da mudança — patch para correção,
minor para feature.

## 1.1.0 — 2026-09-19

O cronograma planejado saiu da aba "Meu roteiro", que ninguém associava a cronograma, e
virou sub-aba do Cronograma. A aba agora tem:

- **Blocos** — o agrupamento de atrações por bairro/período que já existia, intacto.
- **Meus dias** — o dia a dia real da viagem (28/11 a 13/12).

E o construtor de dias ganhou o que faltava pra ser um cronograma de verdade:

- **Horário por entrada.** Quem tem horário se ordena sozinho no dia; quem não tem fica
  depois, na ordem manual (↑↓). Por isso as entradas com hora não mostram as setas — o
  horário é que define onde elas ficam.
- **Entradas livres**, sem atração do catálogo — "Trem pra Kyoto", "Almoço com a Yuki".
- **Notas por entrada**, e edição num modal, no mesmo padrão da aba Hospedagem.

Notas técnicas:

- O formato salvo mudou de `["id_da_atracao"]` para objetos com horário/título/notas. A
  conversão roda sozinha na primeira abertura; nada do que já estava montado se perde.
- Exige rodar `supabase_migration_1.1.0.sql` no SQL Editor do Supabase. Sem isso o app
  funciona normal (o localStorage é a fonte de verdade), mas a sincronização falha, porque
  o insert manda colunas que ainda não existem.

## 1.0.1 — 2026-09-19

- Login por e-mail: avisa explicitamente quando a página está aberta via `file://`, caso em
  que o link mágico não tem como funcionar (o Supabase recusa o redirect).
- O redirect agora é `origin + pathname` em vez de `location.href`, que levava query/hash
  junto e não batia com a allowlist do Supabase.
- Erro de login passa a mostrar o status e a URL de redirect usada, e vai pro console —
  antes só aparecia a mensagem solta, sem o dado que aponta a causa.

## 1.0.0 — 2026-09-19

Primeira versão numerada. Estado do app no momento em que o versionamento entrou:

- Mapa (Google Maps com fallback Leaflet/OpenStreetMap/OSRM)
- Cronograma por dia
- Catálogo de atrações
- Meu roteiro
- Hospedagem
- Sincronização opcional via Supabase
