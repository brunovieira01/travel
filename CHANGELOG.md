# Changelog

Versão fica em `APP_VERSION`, no topo do `<script>` do `index.html`, e aparece como badge
ao lado do título. Regra: bump no mesmo commit da mudança — patch para correção,
minor para feature.

## 1.3.0 — 2026-09-20

**Mapa do dia e tempo de deslocamento** em "Meus dias":

- Cada dia tem "ver no mapa" — abre um mapa com as paradas na ordem do dia.
- Entre entradas consecutivas aparece a estimativa de trajeto, e o cabeçalho do dia soma
  o deslocamento total.
- A estimativa **não** usa a Directions API de propósito: ela não cobre transporte público
  do Japão (devolve `ZERO_RESULTS` em qualquer rota, como o próprio código já anotava), e
  é de trem que se anda em Tóquio. Então o cálculo é em cima da distância, em três faixas
  — a pé, trem urbano, shinkansen. Custa zero de quota e funciona offline, que é o caso no
  meio de Kyoto sem sinal. É estimativa, e a interface diz isso.

**Aviso de conflito com a hospedagem.** Se o dia tem parada numa cidade diferente da que
você dorme naquela noite, o dia mostra um alerta. Cruza com a aba Hospedagem.

**Aba Checklist nova**, semeada com o conteúdo do `checklist_mestre.md`:

- Botão de check por item, agrupado por seção, com contador por seção.
- Edição em modal: título, seção, observações.
- Itens de **acúmulo** viram barra de progresso — é o caso do iene comprado (¥60.000 de
  ¥245.000). Basta preencher "já tenho" e "meta".
- Dá pra criar itens novos e restaurar a lista original.

Correção: as tiles escuras da CARTO passaram a exigir chave e estampavam "API KEY
REQUIRED" no mapa. O mapa do dia usa OSM, que é livre, com o tom escuro vindo de filtro CSS.

Exige rodar `supabase_migration_1.3.0.sql` pro checklist sincronizar com a conta. Sem isso
ele funciona, mas fica só neste navegador.

## 1.2.0 — 2026-09-20

Login por **e-mail e senha**, numa tela própria, no lugar do link mágico.

- O link mágico dependia de redirect configurado no painel do Supabase, e era exatamente
  aí que quebrava: o token era emitido, mas entregue em `http://localhost:3000`. Senha não
  redireciona, então some a classe inteira de problema.
- Tela de login na abertura, com "Entrar" e "Criar conta". Mensagens de erro traduzidas —
  "Invalid login credentials" virou algo que dá pra agir.
- Escape "usar só neste navegador", pra não travar o app quando não há conta ou internet.
  O botão "Entrar" no topo traz a tela de volta; "Sair" também.

Nota de escopo: isto é a arquitetura de login. Os dados do usuário (roteiro, hospedagem,
status) já ficam por conta, via RLS. As viagens em si ainda são fixas no JS — criar viagens
novas pela interface exige mover a definição das viagens pro banco, que é um passo à parte.

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
