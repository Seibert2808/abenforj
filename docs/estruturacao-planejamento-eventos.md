# Estruturação e Planejamento de Eventos — ABENFO-RJ

> Playbook reutilizável para montar, operar e encerrar um evento no site da ABENFO-RJ
> (site estático + Supabase + Vercel). Generaliza a estrutura construída no **IX ENEON 2026**,
> que fica como exemplo. Sempre que aparecer `IX ENEON 2026`, troque pelo nome do novo evento.
>
> Documento vivo. Atualizado em 20/07/2026.

---

## 1. Visão geral — o ciclo de vida de um evento

```
ANTES  →  DURANTE  →  DEPOIS
montar    credenciar   certificar
```

| Fase | O que acontece | Onde |
|---|---|---|
| **Antes** | Criar evento, abrir inscrições (Doity), cursos, submissão e avaliação de trabalhos, programação, modelos de certificado | admin + Doity |
| **Durante** | Marcar presença (credenciamento), marcar trabalhos apresentados | admin |
| **Depois** | Liberar e entregar certificados, atualizar home, arquivar | admin + SQL |

---

## 2. ANTES — montagem do evento

### 2.1 Criar o evento
Tabela `eventos`: `nome`, `tipo` (`congresso` | `forum`), `data_inicio`, `data_fim`, `local`, `link_externo` (link de inscrição no Doity).
Campos que entram em cena depois: `certificados_liberados` (bool), `permite_presenca` (bool), `presenca_fecha_em`.

### 2.2 Inscrições (Doity → nosso banco)
- Inscrições são feitas no **Doity**; o admin **importa a planilha** (reconhece o formato Doity).
- Sócias confirmadas → `inscricoes_evento` (via `profile_id`). Não-sócias → `inscritos_externos` (com `doity_id`, `email`).
- ⚠️ **Regra de ouro:** nunca rodar reimportação destrutiva do Doity durante o evento (risco de perder escolhas de curso). Ver `docs/plano-correcao-importacao-cursos.md`.
- **Monitores** são marcados pela `observacao` da inscrição (contém "monitor").

### 2.3 Cursos pré-encontro (opcional)
Tabela `cursos` (`evento_id`, `nome`, `vagas`, `data`, `turno`, `local`). Inscrição em `inscricoes_curso` (sócia por `profile_id`, externo por `inscrito_externo_id`).

### 2.4 Submissão de trabalhos (eventos tipo `congresso`)
- Tabela `trabalhos_cientificos`: relator (sócia `profile_id` **ou** externo `inscrito_externo_id`), `titulo`, `area`, `eixo_tematico`, `tipo_trabalho`, `resumo`, `autores` (jsonb: `{nome, email, instituicao, eh_relator}` — até 6), `pdf_path`, `status`.
- Páginas: `regras-trabalhos.html`, `submeter-trabalho.html`. Externos submetem/consultam por **e-mail + Doity** (RPCs em `trabalhos-rpcs-externos`).

### 2.5 Avaliação e resultado
- `trabalhos_avaliacao`; `status` vira `aceito`/`recusado` no admin.
- Aprovados aparecem em `trabalhos-aprovados.html` (RPC pública `trabalhos_aprovados_publico`).

### 2.6 Programação
Página HTML própria (ex.: `programacao-ix-eneon.html`). Fonte da verdade dos **palestrantes**, **professores** e **comissões** (usada para cadastrar os papéis de certificado).

### 2.7 Modelos de certificado
No admin (seção de certificados do evento), suba a **arte base** (PNG A4 paisagem, 3508×2480) e o **texto** de cada tipo. Um modelo por (`evento`, `tipo`). Detalhes técnicos na seção 6.

---

## 3. DURANTE — presença

### 3.1 Credenciamento (admin marca a presença)
Admin → **Participantes / Presença** → selecione o evento → **Credenciamento**:
- Lista os inscritos (sócias + externos) com busca e botão **"Marcar presente"**.
- Sócia presente → `participacoes_evento`. Externo presente → `participantes_externos`.
- Alternativa: abrir a janela `permite_presenca` para a **sócia registrar a própria presença** na área logada.

### 3.2 Trabalhos apresentados
Admin → lista de trabalhos → **"Marcar apresentado"** nos que foram de fato apresentados (nem todos os aceitos são).

---

## 4. DEPOIS — certificados

### 4.1 As duas travas (+ a trava de cada tipo)
1. `eventos.certificados_liberados` — **interruptor geral** do evento (liga tudo).
2. `certificado_modelos.ativo` — liga/desliga **por tipo**.
3. **Trava própria de cada tipo** (o "porquê" da pessoa receber):
   - participação → **presença** registrada;
   - palestrante/professor/comissão → **papel** cadastrado e vinculado;
   - monitoria → ser **monitora** (inscrição) **e** presente;
   - apresentação/coautoria → estar num **trabalho aceito e apresentado**.

Com o interruptor ligado e o modelo ativo, ninguém recebe o que não é seu — a trava de cada tipo garante.

### 4.2 Tipos de certificado, quem recebe e como entrega

| Tipo | Quem | Nome no certificado | Entrega |
|---|---|---|---|
| **participação** | presentes | nome da conta (sócia) / do inscrito (externo) | sócia: área · externo: `declaracao.html` (por Doity) |
| **palestrante** | conferencista/debatedores | papel curado (com título) | sócio: área · sem conta: PDF por e-mail |
| **professor** | professores dos cursos | papel curado (com título) | idem |
| **comissão** | organização | papel curado (com título) | idem |
| **monitoria** | monitores presentes | nome da conta | sócia: área |
| **apresentação** | relator do trabalho | nome do autor | 1 PDF por trabalho (relator baixa) |
| **coautoria** | coautores | nome do autor | mesmo PDF; sócio-coautor também baixa na área |

- **Papéis curados** (`certificado_papeis`): cadastrados no admin, com o **tratamento na frente do nome** (Profª Drª, Enfª Ma. …). Vinculam à conta por e-mail/nome; sem conta, saem por e-mail.
- **Certificado de trabalho:** um único PDF, **uma página por autor** (relator = apresentação, demais = coautoria). O relator baixa e repassa. Externo baixa em `trabalho-certificado.html` (e-mail + Doity).

### 4.3 Encerramento visual
- Home: trocar o banner de "Próximo evento" por pós-evento (aviso de certificados + páginas para não-sócios).
- Área da sócia: eventos já realizados saem de "inscrita" e entram no **Histórico de participações** (por presença).

---

## 5. Modelo de dados (tabelas-chave)

| Tabela | Papel |
|---|---|
| `eventos` | o evento + interruptores (`certificados_liberados`, `permite_presenca`) |
| `profiles` | sócias (conta): `nome_completo`, `email` |
| `inscricoes_evento` | inscrição de sócia (+ `observacao` p/ monitor) |
| `inscritos_externos` | inscrição de não-sócia (`doity_id`, `email`, `cancelado`) |
| `participacoes_evento` | **presença de sócia** |
| `participantes_externos` | **presença de externo** (`inscrito_externo_id`) |
| `cursos` / `inscricoes_curso` | cursos pré-encontro |
| `trabalhos_cientificos` | trabalhos (`autores` jsonb, `status`, `apresentado`) |
| `certificado_modelos` | modelo por evento×tipo (arte, texto, config, `ativo`) |
| `certificado_papeis` | papéis manuais (palestrante/professor/comissão) |

**Storage:** `certificados-bases` (artes, **público**), `trabalhos-cientificos`, `apresentacoes`.

---

## 6. Certificados — detalhe técnico

- **Motor:** `js/certificado.js` — desenha num canvas sobre a arte base e exporta PDF (jsPDF, no navegador). `baixarPDF` (1 página) e `baixarPDFVarios` (multipágina, p/ trabalhos).
- **Modelo (`certificado_modelos`):** `base_path` (arte no bucket público), `texto_pre` ("Certificamos que"), `texto_template` (com campos `{{...}}`), `config` (layout).
- **Campos do texto:** `{{carga_horaria}}`, `{{titulo_palestra}}`, `{{curso}}`, `{{comissao}}`, `{{titulo}}` (trabalho).
- **Config de layout (jsonb):** `cor`, `fonte`, `margem`, `band_top`, `pre_size`, `nome_size`, `corpo_size`. O espaçamento do nome é proporcional ao `nome_size` (evita o nome subir sobre o "Certificamos que").
- **Entrega para externos = RPCs `security definer`** (as tabelas têm RLS de admin). Padrão: recebem e-mail/Doity, validam presença/vínculo e devolvem só o necessário:
  - `declaracao_participacao_por_doity(doity)` — declaração de participação.
  - `certificados_trabalho_por_doity(email, doity)` — certificados de trabalho.
  - `certificados_trabalho_socio()` — trabalhos do sócio logado (relator ou coautor por e-mail).
- **Regra dos nomes:** para palestrante/professor/comissão o certificado usa o **nome curado do papel** (com título), não o nome da conta. Participação/monitoria usam o nome da conta/inscrito.

---

## 7. Checklist para um NOVO evento

**Montagem**
- [ ] Criar o evento em `eventos` (nome, tipo, datas, local, `link_externo`).
- [ ] Publicar página do evento + programação.
- [ ] Abrir inscrições no Doity; importar a planilha no admin (periodicamente).
- [ ] (congresso) Abrir submissão de trabalhos; avaliar; publicar aprovados.
- [ ] Subir as **artes** e textos dos modelos de certificado (por tipo).
- [ ] Cadastrar **papéis** (palestrante/professor/comissão) com título, a partir da programação.

**Durante**
- [ ] Credenciamento: marcar presença dos inscritos.
- [ ] Marcar quais trabalhos foram apresentados.

**Depois**
- [ ] Ativar os modelos que vão sair (`ativo = true`) e desativar os que não (ex.: segurar participação até terminar o credenciamento).
- [ ] Ligar o interruptor `certificados_liberados`.
- [ ] Gerar/enviar PDFs de quem não tem conta (palestrantes/comissão por e-mail).
- [ ] Trocar o banner da home para pós-evento (+ links `declaracao.html` e `trabalho-certificado.html`).
- [ ] Conferir que eventos passados saíram de "inscrita" na área da sócia.

---

## 8. SQL comum (troque o nome do evento)

```sql
-- Ligar o interruptor geral
update public.eventos set certificados_liberados = true where nome = 'NOME DO EVENTO';

-- Ativar / segurar um tipo de certificado
update public.certificado_modelos m set ativo = true   -- ou false
where m.tipo = 'participacao'
  and m.evento_id = (select id from public.eventos where nome = 'NOME DO EVENTO');

-- Conferir papéis e forma de entrega
select cp.tipo, cp.nome, cp.detalhe,
  case when cp.profile_id is null then 'e-mail (sem conta)' else 'área da sócia' end as entrega
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'NOME DO EVENTO')
order by cp.tipo, cp.nome;

-- Conferir modelos ativos do evento
select m.tipo, m.ativo from public.certificado_modelos m
join public.eventos e on e.id = m.evento_id
where e.nome = 'NOME DO EVENTO' order by m.tipo;
```

> Dica: os scripts do IX ENEON em `supabase/migrations/2026-07-*` servem de **modelo** para semear papéis, comissão e modelos de certificado num novo evento — é só adaptar nomes e textos.

---

## 9. Onde está cada coisa (arquivos)

| O quê | Arquivo |
|---|---|
| Home / banner | `index.html`, `css/style.css` |
| Área da sócia (inscrições, certificados, presença) | `area/cursos.html` |
| Painel admin (import, trabalhos, credenciamento, papéis, modelos) | `area/admin.html` |
| Motor de certificados | `js/certificado.js` |
| Config Supabase | `js/config.js`, `js/supabase-client.js` |
| Declaração p/ externo (por Doity) | `declaracao.html` |
| Certificado de trabalho p/ externo | `trabalho-certificado.html` |
| Gerador interno de PDFs (palestrantes) | `ferramentas/gerar-certificados-palestrantes.html` |
| Fluxo operacional detalhado | `docs/fluxo-certificados-ix-eneon.md` |

---

## 10. Roadmap — inscrição nativa com pagamento (futuro)

> Objetivo: inscrição **direto na plataforma**, substituindo/complementando o Doity.
> Ganhos: sem taxa do Doity, dados 100% nossos e **número de inscrição próprio**
> (os certificados por "número" passam a usar o nosso ID, não o `doity_id`).

**Requisitos definidos (jul/2026):**
- Pagamento: **Pix + cartão** (com parcelamento).
- **Inscrição cortesia** (gratuita) para sócias/convidados — sem pagamento.
- **Só recibo** (sem nota fiscal): comprovante do provedor + e-mail de confirmação.

**Provedor recomendado:** **Mercado Pago (Checkout Pro)** — Pix + cartão parcelado, em português, público BR. Alternativa: **Stripe** (se quiser padronizar com outros projetos ou cartão internacional). *Conferir taxas atuais antes de decidir.*

**Arquitetura (cabe no stack atual — site estático + Supabase):**
```
Formulário de inscrição no site
  → Edge Function cria "pedido" pendente (tabela nova: pedidos_inscricao)
  → Checkout do provedor (Pix/cartão)
  → Webhook (Edge Function) confirma o pagamento
  → cria a inscrição (inscricoes_evento / inscritos_externos) + e-mail com recibo e número
Cortesia: valida quem é sócia/convidado e cria a inscrição direto (sem pagamento).
```
- **1 Supabase Edge Function** para o webhook (não precisa de servidor novo).
- Tabela nova de **pedidos/inscrições pendentes** (status: pendente/pago/cancelado).
- **Lotes/categorias** com preços (sócia, não-sócia, estudante) — como no Doity.

**A decidir quando for construir:** lotes e preços, política de reembolso/cancelamento, prazo, número de parcelas no cartão.

**Esforço:** médio. Dá para testar tudo no **sandbox** do provedor antes de abrir de verdade.

---

*Este playbook resume a estrutura para reuso. Para o passo a passo específico do IX ENEON 2026, ver `docs/fluxo-certificados-ix-eneon.md`.*
