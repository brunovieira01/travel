# Changelog

Versão fica em `APP_VERSION`, no topo do `<script>` do `index.html`, e aparece como badge
ao lado do título. Regra: bump no mesmo commit da mudança — patch para correção,
minor para feature.

## 2.8.1 — 2026-10-04

**As reservas apareciam repetidas na Hospedagem — bug meu, da 2.7.0.**

O `pushStays` carimbava um uuid nos ids que não eram uuid, mas **só na linha
enviada ao banco**: o local continuava com `stay-fukuzumiro`. Então o banco
recebia um id novo a cada push, e o `reconcileStays` que introduzi na 2.7.0
casava por id. Resultado: a reserva voltava do banco como uuid, o reconcile
não a reconhecia mais como vinda do seed, e adicionava outra. Uma cópia por
sincronização.

Reproduzido antes de consertar, e o número bate com o que você viu:

    cópias por ciclo de sync:  2 → 4 → 6 → 8 → 10

Dois consertos, porque um só não bastava:

- **`stabilizeIds`** carimba o uuid e **grava de volta no local**. O id passa
  a convergir, e o ida-e-volta ao banco deixa de inventar identidade nova.
  Vale pra `stays` e pra `expenses`.
- **`reconcileStays` casa por nome + check-in**, não por id — duas reservas
  com o mesmo nome *e* a mesma data de entrada são a mesma reserva. O id não
  sobrevive ao banco; esse par sobrevive.

Como efeito colateral útil, o reconcile agora **junta as cópias que já estão
salvas**: a lista se limpa sozinha no próximo carregamento, sem você apagar
nada à mão. Entre cópias sobrevive a mais preenchida — a que tem suas
edições — e ela mantém o id que o banco já conhece. A reserva que você mesmo
criou passa intocada.

### Passagem aérea: R$ 2.582,17 era cada parcela, não o total

Eu havia lido o valor como total e dividido em 3 (860,72 + 860,72 + 860,73).
É o contrário: **são 3 parcelas de R$ 2.582,17**, sempre no dia 28
(set/out/nov).

| | antes | agora |
|---|---|---|
| cada parcela | R$ 860,72 | **R$ 2.582,17** |
| total da passagem | R$ 2.582,17 | **R$ 7.746,51** |
| novembro | R$ 1.457,97 | **R$ 3.179,41** |
| total em real | R$ 3.179,41 | **R$ 8.343,75** |

O `splitInstallments` continua existindo e testado — é o que divide um total
quando *você* marca "Parcelar". Só não era o caso desta compra.

Pra correção chegar a um aparelho que já tinha os valores velhos salvos, um
`reconcileExpenses` com `EXPENSES_REV`. Ele sobrescreve valor, moeda e data
de propósito — são os fatos que estavam errados — e preserva situação e nota
se você mexeu.

**O cuidado que importa nesse reconcile:** lançamento do dia a dia passa
intocado e **não é deduplicado**. Dois "Comida" de ¥20 no mesmo dia são dois
gastos reais, e juntá-los apagaria dinheiro de verdade. Só o que vem do seed
é reconciliado. Tem teste dedicado pra isso.

O `pullFromSupabase` também marca a revisão dos custos como antiga antes de
salvar o que veio do banco — senão a linha velha reinstalaria o valor errado
por cima da correção.

### Verificação

20 asserções novas, e a primeira coisa escrita foi o repro do bug, não o
conserto. Cobrem: o ciclo de sync ficando em 2 reservas em vez de subir;
6 linhas duplicadas colapsando em 3 com a cópia editada sobrevivendo e o id
do banco preservado; idempotência; a passagem corrigida sem perder os ids;
e as duas entradas idênticas de ¥20 **não** sendo juntadas. 7 suítes no
total, todas passando.

## 2.8.0 — 2026-10-04

**"No Japão": lançar gasto em três toques.** A aba Custos virou duas
sub-abas, porque são duas perguntas diferentes e misturá-las estragaria as
duas:

| | pergunta | formato |
|---|---|---|
| **Previsto** | quanto sai da conta em cada mês | poucos registros, data futura, parcela |
| **No Japão** | quanto já torrei hoje | muitos registros, iene, data de hoje |

Duzentos ramen na mesma lista soterrariam a parcela da passagem, e o total
de dezembro viraria um número sem significado. Mesma tabela, campo `kind`
separando (`planejado` | `diario`).

O lançamento é um campo de valor grande, seis categorias em chip
(🍜 comida · 🚃 transporte · ⛩️ passeio · 🛍️ compras · 🏪 konbini · outro) e
**Lançar**. Iene é o padrão, data é hoje, Enter lança. Depois de lançar,
**só o valor e o texto limpam** — categoria, moeda e data ficam onde
estavam, porque lançar três refeições seguidas no mesmo dia é o caso normal
e reescolher tudo toda vez é o que faz esse tipo de tela ser abandonada na
segunda semana. O "o que foi" é opcional: em branco, vira o nome da
categoria.

A lista agrupa por dia, do mais recente pro mais antigo, com o número do dia
da viagem ("dia 3 da viagem", calculado a partir do `itinerary`). **Dentro do
dia, o último lançamento vem primeiro** — quem acabou de lançar precisa ver o
lançamento aparecer, e no fim da lista ele nasceria fora da tela.

Três cartões: gasto total da viagem, hoje, e média por dia. A média é por
**dia com gasto**, não por dia de calendário: dividir por dias em que você
não lançou nada daria um número artificialmente baixo. Abaixo, uma barra de
proporção por categoria.

### Correções pegas no caminho

- **Editar um gasto do dia apagava a categoria.** O `<select>` do modal era
  montado sempre com as categorias de planejamento, e "konbini" não está
  nelas — o valor caía em `""` ao abrir, e salvar gravava vazio. Agora a
  lista depende do `kind`, e a categoria atual é sempre incluída.
- **Registro gravado antes desta versão não tem `kind`** e sumiria das duas
  listas, já que as duas filtram por ele. O `getExpenses()` trata ausência
  como `planejado`.

### Migração

`supabase_migration_2.7.0.sql` ganhou a coluna `kind`. Se você ainda não
rodou, é o mesmo arquivo de sempre, uma vez só. Se já rodou a versão
anterior, **rode de novo**: o `alter table ... add column if not exists`
completa o que falta e o resto não faz nada.

### Verificação

33 asserções novas, dirigindo a tela como um dedo dirige — clicando nos
chips, digitando no campo e apertando Lançar. Cobrem o que o uso real
quebraria: o estado que fica entre lançamentos, a ordem dentro do dia, a
média por dia-com-gasto, a soma da barra dando 100%, lançar em real com o
toggle, editar um konbini sem perder a categoria, e um registro antigo sem
`kind` não sumindo. Com as anteriores, são 6 suítes, todas passando.

## 2.7.0 — 2026-10-04

**Aba Custos.** A pergunta que ela responde é uma só: *quanto sai da minha
conta, e quando*. Por isso a unidade de registro é o **débito**, não a compra
— uma passagem em 3x são três linhas, em três meses, porque é assim que o
dinheiro sai. `chargeDate` é quando o dinheiro sai, não quando se comprou nem
quando se usa: a W-Inn é hospedagem de 28/11 mas aparece em **novembro**, e o
ryokan, reservado em setembro, aparece em **dezembro**.

    set 2026   R$   860,72        (cinza: já saiu)
    out 2026   R$   860,72
    nov 2026   R$ 1.457,97        parcela 3/3 + W-Inn
    dez 2026   R$ 1.789,48 ~      ¥53.900 em espécie

Quatro cartões no topo: total previsto, já pago, a pagar e — separado de
propósito — **quanto separar em iene**. Esse último não é fatura de cartão: é
dinheiro que precisa estar na conta iene do Revolut antes de 02/12, e somar
com o resto esconderia justamente o que precisa de ação.

Os três lançamentos reais já vêm semeados:

| o quê | quanto | sai em |
|---|---|---|
| Passagem aérea 1/3 | R$ 860,72 | 28/09/2026 · pago |
| Passagem aérea 2/3 | R$ 860,72 | 28/10/2026 |
| Passagem aérea 3/3 | R$ 860,73 | 28/11/2026 |
| TOKYO-W-INN Asakusa | R$ 597,24 | 24/11/2026 · Visa ••1511 |
| Fukuzumiro (ryokan) | ¥53.900 | 02/12/2026 · espécie |

Nada além disso foi inventado: não há estimativa chutada para as hospedagens
que faltam. O resto se lança na própria aba.

**Parcelamento sem perder centavo.** R$ 2.582,17 em 3x não divide redondo. O
`splitInstallments` distribui em centavos e joga a diferença na última
parcela — 860,72 + 860,72 + **860,73** —, que é o que o cartão faz. E
`addMonths` prende no último dia do mês: 31/01 + 1 mês vira 28/02, não 03/03,
senão a parcela pularia de mês sozinha.

**Câmbio é estimativa e está escrito na tela.** ¥ e R$ só se somam para
totalizar, a 1 ¥ = R$ 0,0332 (cotação de 02/10/2026), editável na própria
aba. O que se paga em iene continua guardado em iene; a conversão nunca
substitui o valor real.

### A aba funciona antes da migração

`expenses` é tabela nova — precisa rodar `supabase_migration_2.7.0.sql` no SQL
Editor do Supabase. Até lá a aba funciona normalmente, só que **apenas neste
aparelho**: a leitura de `expenses` ficou fora do `Promise.all` do
`pullFromSupabase` de propósito, porque dentro dele o 42P01 ("relation does
not exist") derrubaria a leitura das outras quatro tabelas junto. A falta da
tabela é tratada como "ainda não migrou", não como erro de sincronização.

### TOKYO-W-INN Asakusa entrou na Hospedagem

28/11 → 02/12, 4 noites, 1 cama. Kotobuki 4-6-1 1F, Taito. Reserva
1207315601937650.

Duas coisas que o e-mail diz e vale ter à mão:

- **O débito (24/11) cai um dia antes de fechar o cancelamento grátis**
  (25/11, 23:59). Cancelando, é estorno, não "não cobrança".
- A "taxa de acomodação na chegada" deve ser **¥0**: Tóquio só cobra a partir
  de ¥10.000 por pessoa por noite, e esta diária fica bem abaixo disso.

Pra isso aparecer num aparelho que já tinha dados salvos foi preciso um
`STAYS_REV` + `reconcileStays`, iguais aos do checklist: o `getStays()` antigo
via `saved` e retornava cedo, então o seed só valia em aparelho virgem e a
W-Inn nunca chegaria aqui. A reconciliação preserva o que você editou à mão e
só preenche campo vazio. O `pullFromSupabase` também marca a revisão como
antiga antes de salvar o que veio do banco — senão a linha velha do banco
apagaria a reserva nova.

### Verificação

33 asserções no DOM de verdade, via jsdom. As que importam são as de dinheiro:
as 3 parcelas somando exatamente R$ 2.582,17; `splitInstallments` devolvendo o
total original em 999,99/7, 1.234,56/12, 50/4 e 0,05/2; 31/01 + 1 mês caindo
em 28/02, e em 29/02 em ano bissexto; o total de novembro dando R$ 1.457,97; e
`reconcileStays` trazendo a reserva nova sem apagar status, nota nem a reserva
que você mesmo criou.

## 2.6.0 — 2026-10-04

**Os Blocos passaram a saber em que data cabem.** Até aqui a aba era um menu
de 31 rotas temáticas sem nenhuma ligação com as 6 reservas — dava pra abrir
"Fuji — amanhecer" sem nada no ecrã dizendo que não existe noite reservada em
Fuji. Agora a faixa de abas tem cabeçalho por cidade, com a janela de noites:

| grupo | janela | blocos |
|---|---|---|
| Tóquio | 28/11–02/12 + 08/12–12/12 · 8 noites | 15 |
| Hakone | 02/12–03/12 · 1 noite | 3 |
| Kyoto | 03/12–06/12 · 3 noites | 8 |
| Osaka | 06/12–08/12 · 2 noites | 4 |
| Fora do roteiro | sem noite reservada | 2 |

O agrupamento é **por cidade, não por reserva**. Tóquio tem duas reservas
separadas e os mesmos 15 blocos servem as duas: agrupar por reserva
duplicaria 15 abas em 30, com duas abas disputando o mesmo `currentDayIndex`.

Nara entra na janela de Kyoto, porque é bate-volta de lá. A primeira versão
mapeava cidade → janela e por isso abria um grupo "Nara · 03–06/12 · 3
noites" separado, repetindo as mesmas 3 noites de Kyoto num segundo
cabeçalho — como se fossem 6. Passou a mapear cada cidade pra
**cidade-âncora** da reserva (a primeira de `cities`, onde se dorme de
verdade), e a contar as noites uma vez, na âncora.

Nada foi apagado: bloco de cidade sem noite cai em "Fora do roteiro", que é
onde os 2 blocos de Fuji estão. Continuam abrindo e funcionando.

As datas ficam em `trip.itinerary`, no código, e **não** saem de
`getStays()`. Motivo: são fixas (passagem comprada), e `getStays()` é dado do
usuário — pode estar vazio num aparelho novo e guarda cidade como texto livre
("Hakone, Tonosawa"), que não casa com as cidades do catálogo. Os Blocos
mudariam de forma de aparelho pra aparelho. Custo aceito: mudar uma data
exige mexer em `itinerary` **e** no `CHECKLIST_SEED`.

Viagem sem `itinerary` (uma futura) cai na faixa corrida de antes.

### Fujiyoshida não abre mais a aba Atrações

As cidades eram ordenadas com `Object.keys(groups).sort()` — alfabético. O
resultado era abrir Atrações em **Fujiyoshida**, a única cidade onde não se
dorme nenhuma noite, e encontrar **Tóquio** (8 das 15 noites, 48 das 89
atrações) em último. Agora a ordem é a do roteiro, em `trip.cityOrder`:

    antes:  Fujiyoshida · Hakone · Kyoto · Nara · Osaka · Tóquio
    agora:  Tóquio · Hakone · Kyoto · Nara · Osaka · Fujiyoshida

Fujiyoshida ficou no fim de propósito — está no catálogo, fora do roteiro.
Cidade que não esteja em `cityOrder` vai pro fim em ordem alfabética, nunca é
descartada: quem consome a lista faz `order.filter(k => groups[k])`, então uma
cidade ausente dali simplesmente desapareceria do catálogo.

O agrupamento por bairro passou a usar `localeCompare("pt")` em vez de
`.sort()`, que compara code point e jogaria qualquer acento pro fim. Hoje
nenhum bairro tem acento, então isto não corrige nada visível — só evita que
o próximo bairro acentuado entre torto.

### Bloco novo: "Conhecer gente (solo)"

Pensado pro dia 3 (segunda, 30/11), em Tóquio:

- **Free walking tour** em Nihonbashi (Tokyo Free Walking Tour) ou Asakusa
  (Tokyo Localized). Grupos pequenos, sem reserva, mas a saída é no horário
  exato e a inscrição fecha 20 min antes. Gorjeta de ¥1.000–2.000 é o
  esperado — os guias são voluntários. Leve dinheiro vivo.
- **Café de intercâmbio de idioma** — Mickey House, Takadanobaba, ¥500 sem
  limite de tempo, com café e chá à vontade. A mesa de japonês roda segunda,
  quinta e sábado à noite: **o dia 3 cai numa segunda**, então encaixa.
- **Aula de culinária** em Asakusa (sushi US$40–60; gyoza/ramen e udon
  US$78–85; workshop de matcha ~US$33) e **bike tour**, ambos com reserva.
- Fecha no karaokê que já existia no catálogo.

Blocos ganharam um campo `note` opcional, pro conselho que não é lugar nenhum
e portanto não cabe em slot — começar pela área comum do hostel, levar
dinheiro pra gorjeta, dizer sim com frequência. Renderiza no topo da timeline;
bloco sem `note` renderiza igual a antes.

São 4 atrações novas (89 no total) e 1 bloco novo (32). O `konbini` entrou num
bloco e saiu da lista de órfãos — restam 4 (`ramen-estacao`, `seven-eleven`,
`silk-hat`, `fuji-excursion`).

### Verificação

22 asserções: 6 sobre a ordem das cidades (ordem do roteiro, estabilidade
contra input embaralhado, subconjunto filtrado, cidade não listada no fim,
viagem sem `cityOrder`, nada descartado), 8 sobre o agrupamento (ordem dos
grupos, Tóquio somando as duas reservas, singular/plural de "noite", Nara
dentro de Kyoto, Fuji isolado, cada bloco exatamente uma vez) e 8 contra o DOM
de verdade, via jsdom (5 cabeçalhos, 32 abas, cabeçalho em primeiro, "fora do
roteiro" marcado, uma só aba ativa, o `note` renderizando como HTML no topo da
timeline, bloco sem `note` sem elemento sobrando, e a ordem das cidades como
ela sai no ecrã).

## 2.5.0 — 2026-10-02

**A lista da rota agora é uma lista de verdade.** O `<datalist>` do navegador
prometia "escolha ou digite pra filtrar" e não entregava: no telefone ele não
abre como lista nenhuma — fica esperando você digitar pra talvez sugerir algo.
O texto no campo dizia uma coisa e o comportamento era outra.

Então a lista passou a ser nossa: **toca e ela abre inteira, com as 85 opções
pra rolar** (com um cabeçalho dizendo quantas são), e **digitar filtra**. Ela
fica em `position:fixed`, pendurada na raiz da página, pra não ser cortada pelo
`overflow` da barra do mapa — no telefone isso acontecia.

Detalhes que importam no uso real:

- **Escolher é no `click`, não no `mousedown`.** Arrastar pra rolar a lista no
  telefone não seleciona nada, porque o navegador cancela o `click` quando
  houve rolagem. Mesmo cuidado que o carrossel já tinha.
- **Tocar de novo reabre.** `focus` não basta: se o campo já está focado, o
  evento não dispara. O `click` cobre esse caminho, que é o que a mão faz.
- **Sem filtro, nada vem pré-selecionado**, pra Enter não escolher um item que
  você não olhou. Com filtro, o primeiro já vem marcado e Enter aceita.
- **Setas, Enter e Esc** funcionam no teclado, e a lista abre pra cima quando
  não há espaço embaixo.
- O trecho que casou aparece em **negrito**, pra ficar claro por que aquele
  item apareceu.

### A busca

Ignora acento — digitar "toquio" acha "Tóquio", o que em português é
obrigatório. E casa por **palavra**, não só pelo começo do rótulo:

| digitando | acha |
|---|---|
| `ashi` | Lago Ashi + cruzeiro (começo de outra palavra) |
| `livre` | Museu ao Ar Livre de Hakone |
| `hak mus` | Museu ao Ar Livre de Hakone (dois pedaços, fora de ordem) |
| `kyoto fus` | Fushimi Inari · Kyoto (um pedaço é a cidade) |
| `broadway` | Nakano Broadway |

A ordem de preferência é: começo do nome > começo de outra palavra > no meio de
uma palavra. Todo pedaço digitado tem que casar com algo — é E, não OU, senão
digitar mais deixaria a lista maior. Tem teste pra isso: 18 asserções contra os
rótulos reais, incluindo a monotonicidade ("k" → 62, "ki" → 9, "kiy" → 2).

Casar por **iniciais** ("mal" pra "Museu ao Ar Livre") foi implementado e
**removido**: as iniciais reais ali são `maaldhh`, porque "ao" e "de" também
contam — o exemplo que justificava a regra não funcionava. E ela dava a
pontuação mais alta de todas, então duas letras digitadas jogavam um item
esquisito na frente de um nome que casava de verdade.

`resolveRoutePoint` passou a usar a mesma busca pra texto digitado sem escolher
da lista, mas só aceita o melhor palpite quando ele ganha do segundo colocado
com folga. Empate devolve null: é melhor pedir pra escolher do que traçar rota
pro lugar errado.

### Botão de atualizar, no topo

Pequeno, do lado do número da versão — em todas as abas, porque o cabeçalho é
o mesmo. Ele **não recarrega à toa**: busca o arquivo publicado ignorando
cache, lê o `APP_VERSION` de lá e compara. Se for mais nova, avisa e recarrega
com um parâmetro novo na URL (que é o que fura o cache do navegador e do CDN).
Se não, responde "já está na versão mais nova (vX)" e pronto.

A comparação é número por número, não texto: como texto, `"2.10.0" < "2.9.0"`,
e o botão nunca mais atualizaria depois da 2.9. Tem teste com esse caso.

Só recarrega se a publicada for **mais nova** — nunca se for mais velha. Durante
um deploy o CDN ainda serve a anterior por alguns instantes, e comparar por
diferença faria o botão voltar pra versão antiga.

### Correção de armadilha no próprio arquivo

Um comentário no `<style>` continha a tag de abertura do `body` escrita por
extenso. As ferramentas de teste injetam o script de verificação na primeira
ocorrência dessa tag — então o script ia pra dentro do comentário, dentro do
`<style>`, e nenhuma verificação rodava: três tentativas de teste voltaram
vazias antes de a causa aparecer. O comentário foi reescrito, com um aviso pra
não repetir.

## 2.4.0 — 2026-10-02

**As fotos pararam de quebrar porque pararam de vencer.** O sintoma era muito
específico — a primeira foto de cada atração abria, a segunda em diante vinha
como quadrado quebrado — e a causa estava exatamente aí: a primeira foto é a
capa curada do Wikimedia, e a partir da segunda eram fotos do Google Places.

A URL que o Places devolve é **assinada e tem prazo**. Nós guardávamos essa URL
no localStorage **sem TTL nenhum** (`photos2_<id>`), e `getPhotos` lia o cache
antes de qualquer outra coisa. Então a URL era buscada uma vez, guardada pra
sempre, vencia alguns dias depois e nunca mais era renovada. A capa seguia de
pé só porque ela é do Wikimedia e é recolocada na frente da lista a cada
abertura. Comparar: as mesmas chaves guardavam detalhe do Google com
`GD_TTL = 30 dias` — as fotos foram as únicas que ficaram sem prazo.

**Todo slide agora se defende sozinho.** Esta é a outra metade do bug, e é o
que estava de fato na tela: só o PRIMEIRO slide tinha `onerror`. Os de 2 a 8
não tinham nenhum, então uma foto morta ficava ali como quadrado quebrado.
Agora cada slide tenta a versão original antes de desistir e, se ela também
falhar, **sai do carrossel**; as bolinhas são refeitas com o que sobrou, e o
placeholder só volta se não restar foto nenhuma. Vale pros dois carrosséis: o
da aba Atrações e o do modal.

**A galeria virou uma lista fixa de URLs do Wikimedia, embutida no arquivo** —
464 fotos em 85 lugares, até 7 por atração mais a capa. URL do Commons não
vence, não pede chave, não gasta cota e sai de um CDN global.

**De quebra, saíram 85 chamadas cobradas do Places por render do catálogo.**
`renderCatalog` chamava `loadHeroImage` pra cada lugar, e cada uma disparava uma
`findPlaceFromQuery` só pra pegar foto. O `place_id` — que deixa o link "Ver no
mapa" mais preciso — continua sendo resolvido, mas só quando o modal do lugar
abre, que é quando ele serve pra algo. Até lá o link usa o nome do lugar, que
já funcionava.

**`getPhotos` ficou síncrono.** Não há mais nada pra esperar, então o carrossel
pinta no mesmo quadro em que o card aparece — sem o piscar que existia enquanto
o Places respondia, e sem o risco de pintar num nó que ainda não entrou no DOM.

**Limpeza das chaves vencidas.** As URLs do Places já guardadas no aparelho são
apagadas uma vez (`photos_rev = 3`). Ninguém mais as lê, então é higiene:
libera espaço no localStorage e garante que nenhuma volte a ser desenhada.

### De onde vem cada foto, e por que isso importa

Duas fontes, com confiança diferente:

- **364 fotos vêm das imagens do artigo da Wikipedia** do lugar. Confiáveis:
  alguém escolheu aquelas fotos pra ilustrar aquele lugar.
- **100 vêm de busca por texto no Commons**, usada só pra quem tem artigo pobre
  ou nenhum. Essa fonte sozinha **erra feio**: casar palavra em nome de arquivo
  não sabe nada de geografia. Ela trouxe um *passeio de barco na lagoa da
  Tijuca* pro barco de Osaka, um *Oxxo mexicano* pro konbini, uma *Muji de
  Guangzhou*, *Walden Pond* (Massachusetts) pra Hakone, um *Van Gogh* e uma
  *xilogravura do Tokaido* pro castelo de Odawara.

Então foto de busca só entra com três cercas: o nome do arquivo tem que citar o
próprio lugar (nome, cidade ou título do artigo); não pode cair num filtro de
assunto (luta, recorte de jornal, foto de trem — foi assim que saíram cinco
fotos do trem Cassiopeia da ficha de Omiya e uma luta da ficha de Yokohama); e
não pode citar OUTRA cidade da viagem (foi assim que saíram as lojas Uniqlo de
Osaka da ficha de Shinjuku). Em todas as fontes caem fora ícone, mapa, logo,
gravura, pintura, maquete e foto de época.

Oito lugares ficaram só com a capa, ou sem foto: `mandarake`,
`nintendo-shibuya`, `gu-ginza`, `balada-osaka`, `barco-osaka`,
`basquete-bleague`, `shibuya-sky`, `fushimi-sake`. São lojas, uma balada e
atrações sem artigo — preferimos nenhuma foto a foto do lugar errado.

**Sobre a verificação das URLs, com honestidade:** a intenção era conferir as
464 uma por uma com requisição real. Não deu: o Wikimedia passa a responder
**429** quando a gente insiste, e numa tentativa em paralelo ele reprovou 670 de
707 URLs que, testadas depois uma a uma, respondem `200 image/jpeg`. Ou seja, o
veredito era da nossa pressa, não das URLs. O que sustenta a qualidade então é:
as URLs saem da própria API do Wikimedia (o arquivo existe, a largura é
conhecida); só entram arquivos de 1000px ou mais, o que garante que o thumb de
500px seja menor que o original — condição pro MediaWiki gerar thumb; uma
amostra foi conferida de fato; e o `armSlides` cobre o resto em tempo de
execução, removendo qualquer slide que não carregue. Nenhuma URL ruim vira
quadrado quebrado na tela, que era a reclamação original.

### Sobre guardar as fotos no Supabase (foi considerado e recusado)

Caberia: a biblioteca inteira dá ~34 MB e o plano gratuito tem 1 GB de
armazenamento e 5 GB de egress por mês. O que mata é outra linha: **projeto
gratuito é pausado depois de 1 semana sem uso.** Pausado, o Storage para de
responder junto com o banco — ou seja, as fotos sumiriam exatamente no cenário
de "não abri o app essa semana", e o pior momento possível pra isso acontecer é
no Japão. Hospedar no Supabase também gastaria egress a cada visualização, no
mesmo orçamento que a sincronização usa, pra servir o que o Wikimedia já serve
de graça, em CDN e sem prazo. Além disso, re-hospedar as fotos do Google Places
seria contra os termos deles — as do Commons, não.

O Supabase Storage faz sentido pra um caso que o Wikimedia não cobre: **as
fotos que o Bruno tirar na viagem.** Aí o conteúdo é dele e não existe em outro
lugar. A pausa por inatividade continua valendo como risco.

### Achados que ficaram pra depois (nas capas, não na galeria nova)

Das 74 capas antigas: 9 apontam pra `thumb.wikimedia.org` em vez do canônico
`upload.wikimedia.org`, e 7 são link direto pro arquivo (sem `/thumb/`), então
são servidas em tamanho original em vez de reduzidas. Não foram tocadas aqui de
propósito: funcionam hoje, e consertar sem poder verificar — com o Wikimedia
nos barrando — é o tipo de mudança às cegas que já deu errado duas vezes nesta
sessão. Vale uma passada quando o limite liberar. Três delas também merecem
troca por mérito: `USJLogo2024.png` é um logo, `CandiesVendingMachine1952.jpg`
é de 1952, e `Onsen_in_Nachikatsuura` é de Wakayama, não de onde deveria.

## 2.3.0 — 2026-09-28

**A rota agora sai de uma lista, não de texto livre — e por isso passa a
funcionar.** O motivo de "quase nunca funcionar" não era o Japão nem o
transporte público: os campos eram texto solto e iam pro geocoder do Google,
que **não está ativado nesta chave** (já tinha aparecido como "API not
activated" quando a chave foi auditada). Sem geocoder, a origem e o destino
nunca viravam coordenada de verdade.

Os três campos (onde estou, de onde, para onde) viraram combos com filtro: a
lista traz as **85 atrações da viagem e os hotéis já cadastrados**, e digitar
filtra. O que vai pra API são as coordenadas exatas do lugar escolhido — não há
mais o que o geocoder errar. Aceita o rótulo inteiro ("Kiyomizu-dera · Kyoto"),
só o nome, ou um trecho que só case com um item; texto livre continua valendo
como último recurso.

**Hotéis no mapa, em amarelo, com o nome sempre visível.** As reservas guardam
nome e cidade, não coordenada — quem resolve isso é o Places (que está ativado),
e o resultado fica guardado, então é uma busca por hotel, uma vez só. O pino
amarelo não se confunde com os das atrações, mostra as datas junto do nome e
abre a reserva quando tocado. Os hotéis também entram na lista de rota, então dá
pra traçar "hotel → atração" direto.

**"Já fui" carimba a visita em Meus dias.** Era só "some do mapa". Agora, ao
marcar, a atração entra no dia de hoje com a hora e o minuto do clique, e um
aviso curto confirma. É o que tira a necessidade de digitar horário: o ato de
marcar é o registro.

Só registra se **hoje for um dia da viagem** — fora dela (planejando em
setembro) ele continua só marcando como visitado, porque senão criaria entradas
em datas que não existem no roteiro. Marcar duas vezes não duplica.

**Atrações do Fuji rebaixadas pro tier 3.** As 5 de Fujiyoshida (Chureito,
Honcho Street, Fujisan World Heritage Center, Kachi Kachi Yama e o Trem Fuji
Excursion) saíram da prioridade quando Kawaguchiko deu lugar a Hakone. As 10 de
Hakone não foram tocadas — Owakudani, Lago Ashi, Santuário Hakone, Museu ao Ar
Livre e Hakone Yuryo seguem tier 1. A distinção foi feita pelo campo `city`, e
não por procurar "Fuji" no texto: metade das descrições de Hakone também cita o
Fuji, e o filtro por texto teria rebaixado o destino errado.

**Correção: os botões do mapa estavam sem estilo desde a 2.0.0.** "Definir" e
"Traçar rota" não têm classe própria e dependiam de uma regra
`.map-toolbar button` que saiu na reforma do CSS — viraram botões brancos
padrão do navegador. Passou despercebido porque as conferências visuais da 2.0.0
cobriram catálogo, checklist, hospedagem e dias, e não a aba do mapa.

**Painel de rota recolhido no telefone.** Aberto, os cinco campos empurravam o
mapa pra baixo da dobra — e o mapa é justamente o que importa ali. Agora ficam
atrás de um botão "Traçar rota entre dois pontos", e o mapa subiu de 46vh pra
56vh. No desktop nada mudou: a barra continua inteira, numa linha.

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
