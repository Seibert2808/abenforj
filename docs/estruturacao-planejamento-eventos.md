# Estruturação e Planejamento de Eventos — ABENFO-RJ

> Playbook reutilizável para montar, operar e encerrar um evento no site da ABENFO-RJ
> (HTML estático + Supabase + Vercel). Descreve a estrutura completa construída no
> **IX ENEON 2026**, que fica como exemplo. Onde aparecer `NOME DO EVENTO`, troque pelo
> evento novo.
>
> Documento vivo. Revisão completa em **10/08/2026** (inclui presença por curso,
> certificado de curso, tipos avaliador/assistente e as armadilhas descobertas no
> pós-evento do IX ENEON).
>
> Guia de operação do dia a dia, específico do IX ENEON: `docs/fluxo-certificados-ix-eneon.md`.

---

## 1. Visão geral, o ciclo de vida de um evento

```
ANTES  →  DURANTE  →  DEPOIS
montar    credenciar   certificar
```

| Fase | O que acontece | Onde |
|---|---|---|
| **Antes** | Criar evento, abrir inscrições (Doity), cursos, submissão e avaliação de trabalhos, programação, modelos de certificado, papéis | admin + Doity |
| **Durante** | Marcar presença do evento, marcar presença dos cursos, marcar trabalhos apresentados | admin |
| **Depois** | Liberar e entregar certificados, atender pedidos avulsos, atualizar a home, arquivar | admin + SQL |

**Princípio que organiza tudo:** o certificado nunca é dado por inscrição, e sim pelo
**motivo** de a pessoa ter direito a ele (presença no evento, presença no curso, papel na
programação, trabalho apresentado). Cada tipo de certificado tem uma trava própria que
verifica esse motivo.

---

## 2. ANTES, montagem do evento

### 2.1 Criar o evento
Tabela `eventos`: `nome`, `tipo` (`congresso` | `forum`), `data_inicio`, `data_fim`, `local`,
`link_externo` (inscrição no Doity). Interruptores que entram em cena depois:
`certificados_liberados`, `permite_presenca`, `presenca_fecha_em`.

### 2.2 Páginas do site
Página do evento (`eventos.html`), página de programação própria (ex.: `programacao-ix-eneon.html`),
páginas de conteúdo/eixos se houver (`eneon-1.html` … `eneon-8.html`), banner na home.
A **programação é a fonte da verdade** dos palestrantes, professores, mesas e comissões, é dela
que saem os papéis curados de certificado.

### 2.3 Inscrições (Doity → nosso banco)
- Inscrição acontece no **Doity**, o admin **importa a planilha** (o importador reconhece o formato).
- Sócia confirmada → `inscricoes_evento` (por `profile_id`). Não-sócia → `inscritos_externos`
  (com `doity_id` e `email`).
- **Monitores** são identificados pela `observacao` da inscrição (contém "monitor").
- ⚠️ **Nunca rodar reimportação destrutiva durante o evento**, o risco é perder as escolhas de
  curso já feitas. Ver `docs/plano-correcao-importacao-cursos.md`.

### 2.4 Cursos pré-encontro
Tabela `cursos`: `evento_id`, `nome`, `vagas`, `data`, `turno`, `local`, `carga_horaria`
(texto, padrão `'4 horas'`, vai impresso no certificado). Inscrição em `inscricoes_curso`
(sócia por `profile_id`, não-sócia por `inscrito_externo_id`), escolha pela sócia em
`escolher-cursos.html`.

⚠️ **Normalize o nome do curso na hora de cadastrar** (sem quebra de linha, sem espaço duplo).
O nome entra literalmente no texto do certificado via `{{curso}}` e sai torto se vier sujo.
Modelo de limpeza: `2026-07-22-normalizar-nomes-cursos.sql`.

### 2.5 Submissão de trabalhos (eventos tipo `congresso`)
- `trabalhos_cientificos`: relator (sócia `profile_id` **ou** externo `inscrito_externo_id`),
  `titulo`, `area`, `eixo_tematico`, `tipo_trabalho`, `resumo`, `autores` (jsonb, até 6),
  `pdf_path`, `status`, `apresentado`, `relator_nome`, `relator_email`.
- Páginas: `regras-trabalhos.html`, `submeter-trabalho.html`, consulta do externo por
  e-mail + Doity (RPCs de `2026-05-27-trabalhos-rpcs-externos.sql`).
- ⚠️ **Grave a chave `email` em cada autor** do jsonb. O formulário grava `{nome, info, eh_relator}`,
  e `info` é campo livre ("E-mail / Instituição"), o que quebrou o certificado de coautoria no
  IX ENEON. Ver §8.4.

### 2.6 Avaliação e resultado
- `trabalhos_avaliacao`, o `status` do trabalho vira `aceito`, `aceito_com_ressalva` ou `recusado`.
- **Aprovado = `aceito` OU `aceito_com_ressalva`.** Todo filtro de trabalho aprovado precisa
  cobrir os dois (§8.3).
- Aprovados aparecem em `trabalhos-aprovados.html` (RPC `trabalhos_aprovados_publico`).

### 2.7 Modelos de certificado e papéis
- **Modelo** (`certificado_modelos`), um por (`evento`, `tipo`): arte base (PNG A4 paisagem
  3508×2480, bucket público `certificados-bases`), `texto_pre`, `texto_template` com campos
  `{{...}}`, `config` (layout) e `ativo`.
- **Papéis curados** (`certificado_papeis`), cadastrados no admin a partir da programação:
  `tipo`, `nome` (com o tratamento na frente: Profª Drª, Enfª Ma. …), `detalhe` (título da
  palestra ou nome do curso) e o e-mail que vincula à conta da sócia.
- Sem conta vinculada, o certificado do papel sai por fora (PDF gerado no admin e enviado por e-mail).

---

## 3. DURANTE, presença

### 3.1 Credenciamento do evento
Admin → aba **Presença** → selecione o evento → **Credenciamento**: lista de inscritos com busca,
botão "Marcar presente" (clicar de novo desmarca), filtros e impressão da lista.
Sócia presente → `participacoes_evento`. Externo presente → `participantes_externos`.
Alternativa: abrir a janela `permite_presenca` para a sócia registrar a própria presença na área.

**Marcar presença já é liberar**: como a declaração está travada na presença, no instante em que
você marca, o certificado da pessoa passa a valer.

### 3.2 Presença dos cursos (separada da presença do evento)
Admin → aba **Cursos** → **"Presença dos cursos"** → escolha o curso → "Marcar presente".
Grava em `inscricoes_curso.presente` (+ `presenca_em`).

- **Walk-in** (apareceu sem estar inscrito): sócia por busca no cadastro; não-sócia por
  nome + e-mail (obrigatório) + nº do Doity.
- **Imprimir lista deste curso**, respeita o filtro presente/ausente.
- **📜 Certificado**, botão em cada linha marcada presente, gera o PDF do curso ali mesmo para
  enviar por e-mail (útil para sócia sem acesso à conta e para não-sócia sem Doity).

### 3.3 Trabalhos apresentados
Admin → aba **Trabalhos científicos** → "Marcar apresentado" nos que foram de fato apresentados,
nem todo trabalho aceito é apresentado. Se o relator mudou na hora, edite `relator_nome`/`relator_email`
no "Ver detalhes" antes de gerar o certificado.

---

## 4. DEPOIS, certificados

### 4.1 As travas
1. `eventos.certificados_liberados`, **interruptor geral** do evento.
2. `certificado_modelos.ativo`, liga/desliga **por tipo** (ex.: segurar `participacao` enquanto
   o credenciamento não termina, liberando só palestrante/professor).
3. **Trava própria de cada tipo**, o motivo da pessoa receber (tabela abaixo).

Com o interruptor ligado e o modelo ativo, ninguém recebe o que não é seu, a trava de cada tipo garante.

### 4.2 Os tipos, quem recebe, como entrega

| Tipo | Quem recebe | Trava própria | Nome impresso | Entrega |
|---|---|---|---|---|
| `participacao` | quem esteve no evento | presença registrada | nome da conta / do inscrito | sócia: área · não-sócia: `declaracao.html` (por Doity) · admin: botão na lista de presença |
| `oficina` | quem esteve no curso pré-encontro | `inscricoes_curso.presente` | idem | sócia: área · não-sócia: `certificado-curso.html` (por Doity) · admin: botão na Presença dos cursos |
| `monitoria` | monitores | papel curado (ou, no caminho antigo, ser monitora na inscrição + presença) | nome curado | sócia: área · admin: botão na lista de papéis |
| `palestrante` | conferencistas e debatedores | papel curado | nome curado, com título | sócia: área · admin: botão na lista de papéis · sem conta: PDF por e-mail |
| `professor` | professores dos cursos | papel curado | nome curado | idem |
| `comissao` | organização | papel curado | nome curado | idem |
| `avaliador` | quem avaliou trabalhos | papel curado | nome curado | idem |
| `assistente` | quem assistiu o professor num curso | papel curado (detalhe = curso) | nome curado | idem |
| `apresentacao` | relator do trabalho | trabalho aprovado + apresentado | nome do relator, com a autoria completa no texto | relator baixa (área ou `trabalho-certificado.html`) · admin: botão "Certificado do relator" |
| `coautoria` | demais autores | idem | nome do autor | mesmo PDF do relator; coautor sócio também baixa na área |

Certificado de trabalho é **um PDF por trabalho, uma página por autor**. O relator baixa o
arquivo completo e repassa a página de cada coautor.

### 4.3 Quem tem papel também recebe participação
Decisão fixada em 31/07/2026: **quem tem papel curado recebe a declaração de participação**.
Isso não é automático, porque quem tem papel não aparece na lista de credenciamento (§8.1).
Depois de cadastrar cada lote de papéis novos, rode
`2026-07-31-participacao-para-quem-tem-papel.sql`, que é idempotente e pode rodar sempre.

### 4.4 Atendimento pós-evento
A política é **reativa**: avisos ficam no site (banner da home, bloco na página do evento e popup
com prazo de expiração) e os pedidos individuais são resolvidos conforme os e-mails chegam.
Não disparar comunicado em massa a cada correção, decisão da Sabrina em 31/07/2026.

### 4.5 Encerramento visual
- Home: trocar o banner de "próximo evento" pelo pós-evento, com os links de certificado
  para quem não é sócia.
- Popup da página do evento com data de expiração (`data-modal-key` / `data-modal-expira`,
  cada página tem popup e memória independentes).
- Área da sócia: o evento sai de "inscrita" e entra no Histórico de participações, por presença.

---

## 5. Modelo de dados

| Tabela | Papel |
|---|---|
| `eventos` | o evento e os interruptores (`certificados_liberados`, `permite_presenca`) |
| `profiles` | sócias (conta): `nome_completo`, `email` |
| `inscricoes_evento` | inscrição de sócia (+ `observacao` p/ monitor) |
| `inscritos_externos` | inscrição de não-sócia (`doity_id`, `email`, `cancelado`) |
| `participacoes_evento` | **presença de sócia** no evento |
| `participantes_externos` | **presença de não-sócia** (`inscrito_externo_id` faz o vínculo) |
| `cursos` | cursos pré-encontro (`carga_horaria`) |
| `inscricoes_curso` | inscrição **e presença** no curso (`presente`, `presenca_em`) |
| `trabalhos_cientificos` | trabalhos (`autores` jsonb, `status`, `apresentado`, relator) |
| `trabalhos_avaliacao` | avaliações (⚠️ `avaliador_nome` é texto curto e às vezes errado) |
| `certificado_modelos` | modelo por evento × tipo (arte, textos, config, `ativo`) |
| `certificado_papeis` | papéis curados (palestrante/professor/comissão/avaliador/assistente) |
| `comunicados` / `descadastros` | log de e-mail em massa e opt-out (LGPD) |

**Storage:** `certificados-bases` (artes, público), `trabalhos-cientificos`, `apresentacoes`.

---

## 6. Certificados, detalhe técnico

- **Motor:** `js/certificado.js`, desenha num canvas sobre a arte base e exporta PDF com jsPDF,
  100% no navegador. `baixarPDF` (1 página), `baixarPDFVarios` (multipágina, trabalhos),
  `aplicarCampos`, `formatarAutores`, `baseUrlDeStorage`.
- **Campos do texto:** `{{nome}}`, `{{curso}}`, `{{oficina}}`, `{{carga_horaria}}`,
  `{{titulo_palestra}}`, `{{comissao}}`, `{{titulo}}` e `{{autores}}` (trabalho).
- **Config de layout (jsonb):** `cor`, `fonte`, `margem`, `band_top`, `pre_size`, `nome_size`,
  `corpo_size`. O espaçamento do nome é proporcional ao `nome_size`, o que evita o nome subir
  sobre o "Certificamos que".
- **Entrega para quem não tem conta = RPC `security definer`** (as tabelas têm RLS de admin).
  O padrão é receber e-mail/Doity, validar o vínculo e devolver só o necessário:
  - `declaracao_participacao_por_doity(doity)`
  - `certificados_curso_por_doity(doity)`
  - `certificados_trabalho_por_doity(email, doity)`
  - `certificados_trabalho_socio()` (sócio logado, relator ou coautor)
- **Regra dos nomes:** os papéis (palestrante, professor, comissão, avaliador, assistente,
  monitoria) usam o **nome curado do papel**, com título. Participação e curso usam o nome da
  conta ou do inscrito. Nome de lista digitada à mão sai torto no PDF, então, ao criar papéis em
  lote, troque pelo `nome_completo` do cadastro sempre que o vínculo existir.
- **O que o admin gera na hora** (independe do interruptor do evento): declaração de participação
  na lista de presença, certificado de curso na Presença dos cursos, certificado do relator na
  lista de trabalhos, **certificado de qualquer papel na aba Certificados** (botão "📜 Certificado"
  em cada linha da lista de papéis) e teste do modelo. Mesa de abertura sai por ferramenta local em
  `ferramentas/` (não versionada).

---

## 7. Checklist para um NOVO evento

**Montagem**
- [ ] Criar o evento em `eventos` (nome, tipo, datas, local, `link_externo`).
- [ ] Publicar a página do evento e a programação.
- [ ] Criar os cursos com `nome` limpo e `carga_horaria` correta.
- [ ] Abrir inscrições no Doity e importar a planilha periodicamente (nunca destrutivo durante o evento).
- [ ] (congresso) Abrir submissão, avaliar, publicar aprovados.
- [ ] Subir as **artes** e os **textos** de cada tipo de certificado.
- [ ] Cadastrar os **papéis** a partir da programação, com título e e-mail para vincular.

**Durante**
- [ ] Credenciar o evento (buscar sempre na lista antes de usar walk-in).
- [ ] Marcar presença curso a curso.
- [ ] Marcar os trabalhos apresentados e corrigir relator trocado.

**Depois**
- [ ] Rodar `participacao-para-quem-tem-papel` depois do último lote de papéis.
- [ ] Ativar os modelos que vão sair e segurar os que não.
- [ ] Ligar `certificados_liberados`.
- [ ] Gerar e enviar por e-mail os PDFs de quem não tem conta.
- [ ] Trocar o banner da home e publicar o popup de certificados com prazo.
- [ ] Conferir que o evento saiu de "inscrita" e entrou no histórico na área da sócia.
- [ ] Guardar a lista de pendências de atendimento (nomes que não casaram, presença duvidosa).

---

## 8. Armadilhas descobertas no IX ENEON (leia antes de operar)

### 8.1 Papel não é presença
Quem tem papel curado **não aparece** na lista de credenciamento, então não tem como ser marcado
presente por ali e fica sem a declaração de participação, mesmo tendo passado o evento inteiro.
Correção: rodar `participacao-para-quem-tem-papel` a cada lote de papéis.

### 8.2 Presença mora em três lugares
O admin mostra "presente" em todos os casos, mas o dado cai em tabelas diferentes, e o erro só
reaparece semanas depois como e-mail de participante:

| Quem | Onde grava | Consequência do erro |
|---|---|---|
| Sócia | `participacoes_evento` (por `profile_id`) | é a única que a área da sócia lê; sócia credenciada como externa fica invisível na própria área |
| Não-sócia inscrita | `participantes_externos` **com `inscrito_externo_id`** | sem esse vínculo, a declaração por Doity responde "não encontramos presença" mesmo com presença marcada |
| Convidado sem Doity | `participantes_externos` com vínculo nulo | correto, não é bug; a entrega é pelo admin ou pelo papel |

**Regra prática:** ao credenciar, procure primeiro na lista de inscritos e no cadastro de sócias,
use walk-in manual só se realmente não achar, porque o walk-in não cria vínculo. Ao diagnosticar
"não aparece meu certificado", descubra primeiro em qual das três categorias a pessoa cai.

### 8.3 Os dois status de aprovação
`aceito_com_ressalva` também tem direito a certificado. Duas RPCs filtravam só `aceito` e
bloquearam 33 trabalhos, 133 páginas de certificado e 32 relatores. Ao mexer em qualquer regra
de trabalho, confira se o filtro cobre **os dois** status.

### 8.4 Coautor casado pelo campo errado
As RPCs procuravam `autores->>'email'`, mas o formulário grava `info` (campo livre "E-mail /
Instituição"). Nenhum coautor sócio conseguia baixar. O conserto limpo é gravar a chave `email`
na submissão, não remendar o `info`.

### 8.5 Nome de avaliador vem do lugar errado
`trabalhos_avaliacao.avaliador_nome` guarda nome curto e às vezes com erro de digitação. Nunca
use esse texto direto num certificado, case com `profiles` e use o `nome_completo` do cadastro.

### 8.6 Walk-in de não-sócia sem e-mail
Desde 30/07/2026 o e-mail é obrigatório no walk-in, justamente para permitir reconciliar depois
quem entrou sem vínculo. Sem e-mail e sem Doity, a pessoa não tem como baixar sozinha, sobra para
o atendimento manual.

### 8.7 Dado cadastral errado
Se aparecer nome, CPF ou data de nascimento errados no cadastro, sinalize e pare, a correção é
feita pela equipe no atendimento, não direto no banco.

---

## 9. SQL comum (troque o nome do evento)

```sql
-- Ligar o interruptor geral
update public.eventos set certificados_liberados = true where nome = 'NOME DO EVENTO';

-- Ativar ou segurar um tipo
update public.certificado_modelos m set ativo = true   -- ou false
where m.tipo = 'participacao'
  and m.evento_id = (select id from public.eventos where nome = 'NOME DO EVENTO');

-- Modelos do evento e situação
select m.tipo, m.ativo from public.certificado_modelos m
join public.eventos e on e.id = m.evento_id
where e.nome = 'NOME DO EVENTO' order by m.tipo;

-- Papéis e forma de entrega
select cp.tipo, cp.nome, cp.detalhe,
  case when cp.profile_id is null then 'e-mail (sem conta)' else 'área da sócia' end as entrega
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'NOME DO EVENTO')
order by cp.tipo, cp.nome;

-- Presença por curso (quantos marcados)
select c.nome as curso, c.turno, c.carga_horaria,
  (select count(*) from public.inscricoes_curso ic where ic.curso_id = c.id) as inscritos,
  (select count(*) from public.inscricoes_curso ic where ic.curso_id = c.id and ic.presente) as presentes
from public.cursos c
where c.evento_id = (select id from public.eventos where nome = 'NOME DO EVENTO')
order by c.turno, c.nome;

-- Quem tem papel e ainda está sem presença no evento
select cp.tipo, cp.nome
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'NOME DO EVENTO')
  and cp.profile_id is not null
  and not exists (
    select 1 from public.participacoes_evento pe
    where pe.evento_id = cp.evento_id and pe.profile_id = cp.profile_id)
order by cp.tipo, cp.nome;
```

---

## 10. Migrações-modelo (copiar e adaptar para o evento novo)

Estrutura, valem para qualquer evento:

| Migração | O que cria |
|---|---|
| `2026-06-08-certificados.sql` | tabelas `certificado_modelos` e `certificado_papeis` |
| `2026-07-01-participacoes-evento.sql` / `2026-07-01-participantes-externos.sql` | presença de sócia e de não-sócia |
| `2026-07-19-declaracao-por-doity.sql` | RPC pública da declaração de participação |
| `2026-07-19-certificado-trabalho.sql` | certificados de apresentação e coautoria |
| `2026-07-21-presenca-e-certificado-curso.sql` | presença por curso, carga horária, modelo `oficina`, RPC pública do curso |
| `2026-07-31-certificados-avaliador-e-assistente.sql` | tipos `avaliador` e `assistente` nos CHECKs e modelos |
| `2026-07-31-participacao-para-quem-tem-papel.sql` | participação para quem tem papel (rodar por último, sempre) |
| `20260720_comunicados.sql` | comunicados e descadastros (e-mail em massa) |

Correções que valem como lição, o evento novo já deve nascer certo: `2026-07-30-certificado-trabalho-aceito-com-ressalva.sql`,
`2026-07-30-certificado-coautor-casar-por-info.sql`, `2026-07-22-normalizar-nomes-cursos.sql`.

Semeadura específica do IX ENEON (serve de exemplo de escrita, não copie os nomes):
`2026-07-19-modelo-comissao-ix-eneon.sql`, `2026-07-19-liberar-palestrante-professor-ix-eneon.sql`,
`2026-07-31-avaliadores-todos.sql`.

**Ordem de execução recomendada num evento novo:** estrutura → modelos e artes → papéis →
(evento acontece) → presenças → `participacao-para-quem-tem-papel` → interruptor geral.

---

## 11. Onde está cada coisa

| O quê | Arquivo |
|---|---|
| Home, banner e popup | `index.html`, `js/main.js`, `css/style.css` |
| Página do evento | `eventos.html` (+ páginas de eixo) |
| Programação | `programacao-ix-eneon.html` |
| Escolha de cursos pela sócia | `escolher-cursos.html` |
| Submissão e regras de trabalho | `submeter-trabalho.html`, `regras-trabalhos.html`, `trabalhos-aprovados.html` |
| Área da sócia (inscrições, certificados, histórico) | `area/cursos.html` |
| Painel admin (importação, trabalhos, presença, cursos, papéis, modelos, comunicados) | `area/admin.html` |
| Motor de certificados | `js/certificado.js` |
| Config Supabase | `js/config.js`, `js/supabase-client.js` |
| Declaração para não-sócia | `declaracao.html` |
| Certificado de curso para não-sócia | `certificado-curso.html` |
| Certificado de trabalho para não-sócia | `trabalho-certificado.html` |
| Descadastro de comunicados | `descadastrar.html` |
| Geradores internos de PDF (palestrantes, mesa) | `ferramentas/` (fora do git) |
| Operação detalhada do IX ENEON | `docs/fluxo-certificados-ix-eneon.md` |
| Setup do e-mail em massa | `docs/COMUNICADOS-setup.md` |

---

## 12. Comunicados por e-mail (infra pronta, desligada por escolha)

Aba **Comunicados** no admin (compositor com pré-visualização, envio de teste, envio para todas
as ativas, histórico), Edge Functions `enviar-comunicado` (via Resend) e `descadastrar`, tabelas
`comunicados` e `descadastros`, página pública `descadastrar.html`.

**Não está ativo.** Falta o passo externo (conta Resend, verificação do domínio com SPF/DKIM,
secrets e deploy das functions), descrito em `docs/COMUNICADOS-setup.md`, e a decisão vigente é
não disparar e-mail em massa. Para notificação individual, continua valendo o padrão antigo:
link do Gmail pré-preenchido pelo admin, com log em `emails_enviados`.

---

## 13. Roadmap, inscrição nativa com pagamento

> Objetivo: inscrição direto na plataforma, substituindo o Doity. Ganhos: sem taxa, dados
> nossos e **número de inscrição próprio** (os certificados por número passariam a usar o
> nosso ID, não o `doity_id`, o que resolve de vez o caso do walk-in sem Doity).

**Requisitos definidos (jul/2026):** Pix e cartão com parcelamento, inscrição cortesia gratuita,
só recibo (sem nota fiscal).

**Provedor recomendado:** Mercado Pago (Checkout Pro). Alternativa: Stripe. Conferir taxas antes de decidir.

```
Formulário de inscrição no site
  → Edge Function cria o pedido pendente (tabela nova: pedidos_inscricao)
  → Checkout do provedor (Pix ou cartão)
  → Webhook (Edge Function) confirma o pagamento
  → cria a inscrição (inscricoes_evento / inscritos_externos) + e-mail com recibo e número
Cortesia: valida quem é sócia ou convidada e cria a inscrição direto.
```

**A decidir quando for construir:** lotes e preços por categoria, política de reembolso, prazo,
número de parcelas. Dá para testar tudo no sandbox antes de abrir.

---

*Este playbook é a estrutura para reuso. O passo a passo específico do IX ENEON 2026 está em
`docs/fluxo-certificados-ix-eneon.md`.*
