# Changelog

Versão fica em `APP_VERSION`, no topo do `<script>` do `index.html`, e aparece como badge
ao lado do título. Regra: bump no mesmo commit da mudança — patch para correção,
minor para feature.

## 2.2.0 — 2026-09-28

**Mapa utilizável com uma mão só.** Por padrão o Google usa `gestureHandling:
"auto"`, que numa página que rola vira `"cooperative"`: arrastar com um dedo
rolava a página e o mapa mostrava "use dois dedos para mover o mapa". Agora é
`"greedy"` — um dedo arrasta e dá zoom.

O trade-off é real e foi aceito de propósito: **dentro do mapa o dedo não rola
mais a página**. Pra rolar, é preciso arrastar fora do mapa. É o certo pro caso
de uso — de pé numa estação, com a outra mão ocupada.

Junto disso, menos coisa disputando espaço na tela: sumiram os controles de tipo
de mapa, Street View e tela cheia; o zoom foi pro canto inferior direito, onde o
polegar alcança; e `clickableIcons: false` impede que um toque errado abra o card
de restaurante do próprio Google por cima do seu.

**Nomes das atrações aparecem de mais longe.** O limite era zoom 15 — quase
nível de rua, ou seja, era preciso chegar muito perto pra saber o que era cada
pino. Mas mostrar os 85 nomes de uma vez em Tóquio vira sopa de letras. Então
virou escalonado: **essenciais (tier 1) a partir do zoom 12**, com a cidade
inteira na tela; **o resto a partir do 14**, quando você já está num bairro.

Detalhe de implementação que importa: o `setVisible` pode rodar antes do rótulo
existir no DOM (o `onAdd` do overlay vem depois), então o zoom é reconferido no
`draw()`, a cada redesenho. Sem isso alguns nomes ficavam presos escondidos.

**Carrossel de fotos na aba Atrações.** A capa virou um trilho que arrasta de
lado, com pontinhos indicando quantas fotos existem.

- O teto por lugar subiu de **3 para 8 fotos**. A chave do cache mudou
  (`photos_` → `photos2_`) justamente pra forçar uma releitura: o cache antigo
  tinha guardado só 3 e nunca expiraria sozinho.
- **Só a primeira foto é carregada de imediato**; as outras têm
  `loading="lazy"`, então um card que você nem olhou não custa banda nenhuma —
  o que importa com dado móvel no Japão.
- **Arrastar não abre mais o modal.** Num carrossel, arrastar e tocar chegam os
  dois como `click`; agora o modal só abre se o dedo andou menos de 10px. Sem
  isso, tentar ver a segunda foto abriria a ficha do lugar.
- Se a primeira foto falhar, tenta a original antes de desistir e volta pro
  placeholder — nunca fica foto quebrada.

**Texto longo não empurra mais o card pra fora da tela.** Um link colado numa
nota do checklist não tem espaço pra quebrar e, com `white-space: pre-wrap`,
alargava o cartão até a página inteira rolar de lado. `overflow-wrap: anywhere`
nos campos de texto resolve. Medido de novo depois: **zero elementos estourando
a 390px e a 360px**, no catálogo e no checklist.

Nota: no modo Leaflet (usado só quando o Google não carrega) os nomes continuam
em tooltip de hover, que não existe em telefone. Como o site publicado usa o
Google, isso ficou de fora — mas é um buraco conhecido.

## 2.1.0 — 2026-09-27

**A hospedagem não salvava porque o `id` ia nulo.** O erro real, que só apareceu
depois da v2.0.1 parar de engolir as respostas do banco:
`null value in column "id" of relation "stays" violates not-null constraint`.

A coluna `id` de `stays` é NOT NULL e **não tem default**. O app só mandava `id`
quando já era um uuid (vindo de um pull anterior); pra reserva criada aqui o id
era `stay_1727…`, virava `undefined`, sumia do JSON e o Postgres recebia null.
Era também por isso que o checklist era o único que sincronizava: a
`checklist_items` nasceu na migração 1.3.0 com `default gen_random_uuid()`.

Não era RLS, como eu tinha suposto. As políticas do `supabase_migration_2.0.1.sql`
continuam valendo a pena, mas não eram a causa.

Agora todo id sai pronto do app (`uuid()`, com `crypto.randomUUID` e fallback),
tanto pras reservas novas quanto pro roteiro e pro status das atrações — que
teriam o mesmo problema se aquelas tabelas também não tivessem default. Não
precisa rodar nada no banco pra isso funcionar.

**Checklist atualizado com o novo planejamento**, sem perder nada do que você já
tinha marcado:

- **Kawaguchiko saiu, Hakone entrou.** "Trem Fuji Excursion" era reserva só pra
  chegar em Kawaguchiko e foi removido. O aviso de horários de inverno deixou de
  falar de Chureito, Kachi Kachi e Fujisan World Heritage Center e passou a
  falar de Owakudani, Museu ao Ar Livre e barco do Lago Ashi.
- **Seção nova "Hospedagem — as 6 reservas"**, com as datas exatas de cada bloco
  (Tóquio 4 noites, Hakone 1, Kyoto 3, Osaka 2, Tóquio 4, capsule 1) e o total
  de ¥102.000 a ¥167.000. As três tarefas genéricas que existiam antes
  ("Reservar hostels", "Pré-reservar o resto") saíram, porque viraram estas seis.
- **Transporte com os avisos que mudam a compra:** comprar o Free Pass na versão
  de Odawara (¥6.000) e não na de Shinjuku (¥7.100), somada à passagem avulsa
  (¥880) — ¥6.880 no total, ¥1.420 de economia; o Nozomi não para em Odawara,
  então tem que ser Hikari ou Kodama, e o Hikari tem poucas saídas; e o ônibus
  da Izu Hakone, que é parecido com o da Tozan mas não aceita o passe (símbolo:
  "T" laranja vale, leão não).
- **Dinheiro:** ¥120.000 de ¥248.000, com a composição do cenário econômico na
  nota.

**Como a atualização preserva o seu trabalho.** O checklist mora no
localStorage, então trocar o seed não alcançaria a sua lista. Entrou um número
de revisão (`CHECKLIST_REV`): quando ele sobe, `reconcileChecklist()` encaixa o
seed novo na lista existente — mantém o que está marcado, mantém as notas que
**você** escreveu (só as de fatos que mudaram são substituídas), tira o que saiu
do planejamento e preserva inteiros os itens que você mesmo criou. É
idempotente. Depois de puxar do banco a lista é remarcada como antiga, então uma
lista vinda de outro aparelho também é reconciliada e devolvida atualizada.

Verificado com teste contra a função real: 28 asserções, incluindo idempotência,
preservação de marcações, de notas próprias e de itens criados por você.

**Correção menor:** a aba do topo e a barra de baixo agora comparam por
`data-view` em vez de por elemento, então as duas sempre concordam sobre qual
seção está aberta.

## 2.0.1 — 2026-09-27

**A hospedagem nunca chegava no banco, e o app dizia que tinha chegado.**

A tabela `stays` ficava vazia depois de salvar uma reserva, sem erro nenhum na tela. A
causa está no app: o supabase-js v2 **não lança exceção** quando o banco recusa — devolve
`{ data, error }`. O código fazia `await sb.from("stays").insert(rows)` dentro de um
`try/catch` e nunca olhava o `error`. Resultado: a recusa era descartada, `syncState`
virava "on" e a barra dizia "sincronizado" com a tabela vazia.

O mesmo valia pro roteiro (`itinerary_items`) e pro status das atrações
(`place_status`). O `pushChecklist` era o único que checava o erro — e não por acaso era
o único que sincronizava.

Pior: em `pullFromSupabase`, um select que falhasse deixava `data` nulo, e o código
concluía "banco vazio" e subia o local por cima. A falha se escondia sozinha.

Agora toda chamada ao banco passa por `sbRun()`, que lê o `error` e lança com a mensagem
real do Postgres. A barra do topo mostra essa mensagem em vez de um "erro ao sincronizar"
genérico, e salvar uma reserva que o banco recusa abre um aviso na hora — em vez de você
descobrir depois, olhando a tabela.

**Do lado do banco:** as 16 colunas de `stays` foram conferidas uma a uma contra a API e
todas existem, então não era diferença de schema. O que sobra é RLS: a `checklist_items`
nasceu na migração 1.3.0 já com as quatro políticas explícitas, e é justamente a única
tabela que sincronizava. O `supabase_migration_2.0.1.sql` garante as mesmas quatro
políticas em `trips`, `stays`, `itinerary_items` e `place_status`. É idempotente, não
apaga dado e não mexe em coluna nenhuma; no fim ele lista as políticas que ficaram
valendo, pra dar pra conferir.

## 2.0.0 — 2026-09-25

**Redesenho completo na direção "editorial".** Nenhuma funcionalidade saiu: mapa, blocos,
meus dias, atrações, hospedagem, checklist, login, sincronização e detalhes do Google
continuam todos lá, com a mesma lógica. O que mudou foi a casca — e três defeitos reais
que o redesenho expôs.

### Por que mexer no visual

A auditoria do layout antigo mediu o problema em vez de opinar sobre ele:

- **70 das ~103 declarações de `font-size` eram 12px ou 13px.** A interface inteira morava
  numa faixa de um pixel, então nada conseguia ser mais importante que nada. Era por isso
  que parecia um paredão cinza.
- **48 valores distintos de `padding`** e **11 de `border-radius`** — enquanto o token
  `--radius`, que existia, era usado 3 vezes. Não havia sistema, havia hábito.
- **Zero transições** no arquivo todo.
- **Zero media queries.**

Contraste era a única coisa que já estava certa: todos os pares de texto passavam no AA.
A paleta não era o problema; o uso dela era. Por isso a paleta nova também foi medida
antes de entrar — `--seal` (#C4392A) só aparece como preenchimento, porque como texto
pequeno dá 3.34:1; texto na cor do selo usa `--seal-lite`, que dá 5.81:1.

### O que o app ganhou

- **As 85 atrações agora têm capa.** Esta é a mudança central. As 74 imagens curadas na
  v1.4.0 só apareciam nos Blocos — na aba Atrações, que é onde se escolhe para onde ir,
  não havia imagem nenhuma. Agora o card é a foto, com nome e cidade por cima dela.
- **Escala de tipos de verdade**, com serifa (Instrument Serif) nos nomes e títulos e sans
  (Manrope) na interface. Escala de espaço de 4 e um conjunto único de cantos.
- **O tier deixou de gritar.** Antes a pílula "ESSENCIAL" era a coisa mais visível do card,
  mais que o nome do lugar. Agora é um selo pequeno no canto da foto.
- **Detalhe longo colapsa** atrás de "Detalhes", em vez de despejar tudo de uma vez.
- **Ícones SVG no lugar dos emojis** na interface (relógio, dinheiro, reserva, refeição,
  aviso, modos de transporte). Emoji muda de desenho em cada sistema e não acompanha a cor
  do texto. Os ⚠️ que estão dentro das suas descrições continuam lá — aquilo é conteúdo seu,
  não enfeite da interface.

### Ideias trazidas da direção "field tool"

- **Barra de abas embaixo no telefone**, com alvos de toque de 44px+. As abas de cima
  somem abaixo de 760px. Os botões reusam a classe `view-tab` e o `data-view`, então a
  função que já existia passou a controlá-los sem uma linha de JS nova.
- **Marcador de "hoje"** na aba Meus dias. Só aparece durante a viagem — hoje é setembro,
  então ainda não aparece nada, e isso está correto. A data é montada em horário local, e
  não com `toISOString()`, que é UTC e em UTC-3 marcaria o dia errado a noite inteira.
- **Horários em fonte monoespaçada** com números tabulares, nos dias e nos blocos.

### Três defeitos encontrados no caminho

**1. O app rolava de lado em qualquer celular.** O layout tinha piso de largura de 477px:
`.catalog-toolbar` exigia 477px e `.view-tabs` 447px, e nenhum dos dois encolhia. Num
telefone de 390px isso vazava quase 90px — os selos de tier ficavam cortados e a aba
Checklist ficava fora da tela. Agora as barras de aba rolam na horizontal, a grade vira
uma coluna e existem breakpoints. Medido depois: **zero elementos estourando a 390px e a
360px**, nas quatro abas.

**2. A capa curada dependia do Google — e sumia junto com ele.** Quando o Places carrega
mas não autoriza (chave errada, quota estourada, referrer que não bate),
`findPlaceFromQuery` simplesmente **nunca chama o callback**. `getPhotos` ficava pendurada
para sempre e nenhuma capa era desenhada, mesmo com a URL do Commons pronta dentro do
próprio objeto do lugar. Medido: `usingGoogle=true`, `gPlacesSvc=true`, a promessa nunca
resolveu, 0 imagens no DOM. Agora a capa curada é pintada **na hora**, sem esperar rede
nenhuma, e as fotos do Google só melhoram o resultado depois; além disso `getPhotos` tem
teto de 6 segundos, para nunca mais ficar pendurada.

**3. As capas pesavam 4,7x mais do que precisavam.** Cada imagem pedia 1280px de largura
para preencher um espaço de ~190px de altura, sem `loading="lazy"` — cerca de 432 KB por
foto, ~31 MB no conjunto. Isso importa porque o app vai ser usado no Japão, com dado móvel.

A correção óbvia seria trocar 1280 por 640 na URL. **Não funciona**: o Wikimedia passou a
servir só uma lista fixa de larguras, e 640 devolve HTTP 400. As que funcionam são
120/250/330/500/960/1280. Ficou em **500px — 91 KB em média, verificado em 12 URLs reais
suas** — o que leva o conjunto de ~31 MB para ~6,8 MB, somado ao `loading="lazy"`, que faz
o app só baixar o que entra na tela. A troca é feita em tempo de execução por `thumbUrl()`,
então as URLs originais continuam intactas no arquivo; e se algum arquivo não tiver a
versão de 500px, o `onerror` tenta a original antes de desistir. De quebra, os `?utm_*`
que vieram da API do Commons saem da URL.

### Nota

As fontes vêm do Google Fonts. Sem internet elas caem para a serifa e a sans do sistema —
o texto continua legível, só perde o desenho. Depois da primeira visita o navegador guarda
em cache, então em viagem isso não deve aparecer.

## 1.6.0 — 2026-09-23

**Detalhes do Google no modal da atração**: nota e número de avaliações, faixa de preço,
resumo editorial, horário de funcionamento da semana, até 3 avaliações e links para site
oficial, Google Maps e telefone.

**Aviso de horário incompatível.** O dado de horário é cruzado com os horários que você
marcou em "Meus dias": se você agendou Kinkakuji às 20:00 e ele fecha às 17:00, o modal
avisa. Isso é o que transforma a informação em decisão — foi por isso que **não** foi usado
o "aberto agora" do Google: para uma viagem em dezembro planejada em setembro, saber se
está aberto neste instante não serve para nada.

**Menu não existe na API.** Verificado na resposta real do Places: não há nenhum campo de
menu, comida ou prato. O mais próximo é o link do site oficial, que está incluído.

**`business_status`** marca lugares fechados permanente ou temporariamente — útil porque o
próprio checklist já lista seis lugares que fecharam e ainda aparecem em guias.

Notas técnicas:

- O `place_id` agora é resolvido pelo `mapQuery`, que é o destino real. Antes só era
  guardado quando o lugar não tinha `photoQuery` — ou seja, 55 dos 85 nunca tinham
  `place_id`. Isso também corrige os links "Ver no mapa" desses 55, que caíam na busca por
  texto em vez do lugar exato.
- A busca só acontece quando o modal abre, nunca para os 85 de uma vez, e o resultado fica
  guardado por 30 dias. Isso limita o custo (a faixa com nota e avaliações é a mais cara da
  API) e faz o modal funcionar offline depois da primeira abertura.

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
