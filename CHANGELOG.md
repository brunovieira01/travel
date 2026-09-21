# Changelog

Versão fica em `APP_VERSION`, no topo do `<script>` do `index.html`, e aparece como badge
ao lado do título. Regra: bump no mesmo commit da mudança — patch para correção,
minor para feature.

## 1.5.1 — 2026-09-21

**Login concluía mas a interface não saía do estado deslogado.** A conta era criada e a
sessão estabelecida, mas a barra continuava em "Salvo só neste navegador", sem erro nenhum
no console.

Causa: `renderAuthBar()` estava **depois** de `await afterLogin()`, dentro do callback de
`onAuthStateChange`. O `afterLogin` consulta a tabela `trips`, e essa chamada ficava
pendurada — provavelmente o lock que o supabase-js v2 mantém durante o callback, que trava
quando outra operação do Supabase é chamada lá dentro. Com a promessa nunca resolvendo,
nada depois do `await` executava e a barra nunca era redesenhada.

Não deu pra reproduzir em teste isolado: sem uma sessão real não há como disparar o
callback, e a allowlist impede criar conta de teste. O diagnóstico vem do comportamento
observado — se `afterLogin` lançasse erro, o `catch` redesenharia a barra e o e-mail
apareceria com "erro ao sincronizar"; como não aparece, ele está pendurado, não falhando.

O que mudou, e vale independentemente da causa exata do travamento:

- O estado é atualizado e a barra desenhada **antes** de qualquer trabalho de banco; o
  `afterLogin` sai do callback via `setTimeout`.
- `afterLogin` ganhou teto de 15 segundos, pra um travamento virar erro visível em vez de
  ficar eternamente em "conectando…".
- Guarda contra `afterLogin` rodar duas vezes (o evento de auth e o `getSession` podiam
  disparar juntos e criar duas linhas em `trips` para a mesma viagem).

## 1.5.0 — 2026-09-21

**Correção grave: o primeiro login apagaria os dados locais.** Em `pullFromSupabase`, o
teste era `if (stays.data)` — e array vazio é *truthy* em JavaScript. Com o banco ainda
sem nenhuma linha, o primeiro login puxaria listas vazias por cima de tudo que tinha sido
montado no navegador: hospedagem e roteiro iriam junto. Agora, quando o banco não tem nada
para a viagem, a primeira sincronização vai no sentido contrário — o que está local sobe.

**Correção de fuso na cobertura das noites.** `new Date("2026-12-02")` é meia-noite **UTC**;
lido com getters locais em UTC-3, retrocedia um dia, e uma reserva de 02→03/12 marcava a
noite de 01/12 como coberta. As datas agora são montadas em horário local.

**Primeira reserva embutida na viagem:** Fukuzumiro, ryokan em Tonosawa (Hakone), 02→03/12,
quarto japonês tipo Sekirei, cancelamento grátis até 29/11/2026. Depois de semeada é um
dado comum — dá pra editar e excluir pela interface. O item correspondente do checklist
("Reservar o ryokan em Hakone") já vem marcado como feito.

## 1.4.0 — 2026-09-20

**Imagem de capa curada para 74 das 85 atrações**, vinda do Wikimedia Commons.

Por que as antigas eram ruins: o app pede uma foto ao Google Places com uma busca em
texto, ele devolve **um** estabelecimento e usa as **fotos enviadas por usuários** dele.
Para nomes próprios (Kiyomizu-dera) funciona. Mas 17 atrações usavam buscas genéricas —
`"karaoke room Japan"`, `"7-Eleven storefront Japan"`, `"basketball arena Japan"` — e aí
vinha um comércio qualquer com foto de cliente: interior, cardápio, foto tremida. Ruim por
construção, não por azar.

Agora cada atração tem `heroImageOverride` com uma foto do Commons, que entra na frente
das do Google. As do Google continuam como secundárias ("+2 fotos"), então nada se perdeu.

Como foram escolhidas, porque o método importa pra confiar no resultado:

- Imagem principal do artigo correspondente na Wikipedia, normalizada pra um thumb de
  1280px (ou o original, quando ele é menor — pedir thumb do tamanho do original faz o
  MediaWiki devolver página de erro).
- **Cada URL foi verificada com requisição real**, confirmando que responde imagem.
- **Todas foram olhadas numa folha de contato**, e 9 que passaram na verificação mas
  estavam erradas ou fracas foram trocadas por escolha manual no Commons: o Bosque de
  Bambu mostrava o rio e não o bambu; teamLab mostrava o logotipo; Den Den Town mostrava
  um prédio corporativo; Hakone-Yumoto repetia a foto do Lago Ashi; Shibuya Sky mostrava a
  torre por fora em vez da vista; "Shinjuku à noite" estava de dia.

Ficaram sem capa curada, de propósito: Muji, B.League e Pokémon Café (na Wikipedia só há
logotipo), Mandarake e Gora Park (sem artigo ou sem imagem), distrito de saquê de Fushimi e
o teleférico Kachi Kachi (sem candidata boa no Commons). Essas seguem com o Google, que
para lojas e lugares específicos costuma acertar.

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
