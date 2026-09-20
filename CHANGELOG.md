# Changelog

Versão fica em `APP_VERSION`, no topo do `<script>` do `index.html`, e aparece como badge
ao lado do título. Regra: bump no mesmo commit da mudança — patch para correção,
minor para feature.

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
