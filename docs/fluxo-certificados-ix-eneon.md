# Fluxo de certificados e credenciamento — IX ENEON 2026

> Guia de operação. Como marcar presença e como cada tipo de certificado é
> liberado e entregue. Atualizado em 19/07/2026.

## Tipos de certificado

| Tipo | Quem | Como o nome é definido | Origem |
|---|---|---|---|
| **participação** | quem esteve presente | nome da conta (sócia) / do inscrito (externo) | presença |
| **palestrante** | conferencista + debatedores | papel curado (com título) | `certificado_papeis` |
| **professor** | professores dos cursos pré-encontro | papel curado (com título) | `certificado_papeis` |
| **comissão** | organização | papel curado (com título) | `certificado_papeis` |
| **monitoria** | monitores | — | (a definir) |
| **avaliador** | quem avaliou trabalhos científicos | papel curado (sem detalhe) | `certificado_papeis` |
| **assistente** | quem assistiu o professor num curso pré-encontro | papel curado (detalhe = curso) | `certificado_papeis` |

## As duas travas

1. **Interruptor do evento** `eventos.certificados_liberados` — liga/desliga TUDO do evento de uma vez.
2. **Modelo ativo** `certificado_modelos.ativo` — liga/desliga por TIPO. (Ex.: desativar `participacao` segura só as declarações, mantendo palestrante/professor.)

Além disso, cada tipo tem sua **trava própria** (o "por quê" da pessoa receber):
- participação → precisa de **presença registrada** (não basta estar inscrito);
- palestrante/professor/comissão/avaliador/assistente → precisa do **papel** cadastrado e vinculado;
- monitoria → precisa estar marcada como monitora.

> ⚠️ **Papel não é presença.** Quem tem papel curado (palestrante, professor,
> comissão, avaliador, assistente) **não aparece** na lista de credenciamento do admin — logo
> não tem como ser marcado presente por ali e **não recebe a declaração de
> participação**, mesmo tendo passado o evento inteiro na UERJ. Para liberar,
> insira a presença em `participacoes_evento` (exemplo na migração
> `2026-07-31-jose-antonio-participacao-e-coautoria.sql`, seções A2 e D — a D
> lista todo mundo nessa situação).

Ou seja: com o interruptor ligado e o modelo ativo, **ninguém recebe o que não é seu** — a trava de cada tipo garante isso.

## Credenciamento — marcar presença (o admin faz)

`area/admin.html` → seção **Participantes / Presença** → selecione **IX ENEON**.

1. Em **"Credenciamento — marcar presença"**, aparece a lista de inscritos (sócias + externos), com busca.
2. Clique **"Marcar presente"** em quem esteve (da lista de assinatura). Fica **✓ Presente**. Clicar de novo desmarca.
   - Sócias → gravam em `participacoes_evento`.
   - Externos → gravam em `participantes_externos` (ligados ao inscrito).
3. **A marcação de presença É a liberação**: como a declaração está travada na presença e o modelo de participação fica ativo, assim que você marca a pessoa, a declaração dela passa a valer.

## Como cada um recebe

- **Sócia** (palestrante/professor/comissão/participação): entra na **área da sócia** → aba de certificados → baixa em PDF. Só aparece se tiver o papel/presença e o evento estiver liberado.
- **Externo — participação**: baixa sozinho em **`declaracao.html`**, digitando o **número do Doity** (DOI-XXXX). Só funciona se a presença dele foi marcada.
- **Externo — palestrante/professor/comissão** (sem conta): a organização gera o PDF e envia por e-mail:
  - palestrantes → `ferramentas/gerar-certificados-palestrantes.html` (uso interno, não publicado);
  - participação de externo, avulso → botão **"Baixar declaração"** na Lista de presença do admin.

## Presença e certificado por CURSO (oficina)

Os cursos pré-encontro têm **presença própria** (separada da presença do evento): só quem
esteve **presente no curso** recebe o **certificado de curso** (tipo `oficina`, carga horária
**4 horas**). A arte/layout é a mesma da declaração de participação, mudando só o texto (cita o
curso e a carga horária).

**Marcar presença (o admin faz):** `area/admin.html` → selecione o evento (IX ENEON) → aba
**Cursos** → seção **"Presença dos cursos"**. Escolha o curso, marque **"Marcar presente"** em
quem esteve. Clicar de novo desmarca. Grava em `inscricoes_curso.presente`.

- **Adicionar na hora (walk-in):** quem apareceu sem estar inscrito.
  - *Sócia* → busca pelo nome/e-mail no cadastro → "+ Adicionar" (inscreve no curso + marca presente).
  - *Não-sócia* → nome + e-mail + nº Doity (cria o inscrito externo do evento + inscreve + presente).
- **Imprimir lista deste curso:** botão na própria seção (respeita o filtro presente/ausente).

**Como cada um recebe:**
- **Sócia:** área da sócia → aba de certificados → um **"Certificado de curso · «nome»"** por curso
  presente. Só aparece com o evento liberado e o modelo `oficina` ativo.
- **Não-sócia:** baixa sozinha em **`certificado-curso.html`**, pelo **número do Doity**. Sai **um
  PDF** com **uma página por curso** em que teve presença (manhã e/ou tarde).

As travas são as mesmas: interruptor do evento (`certificados_liberados`) + modelo ativo
(`certificado_modelos.oficina.ativo`) + a trava própria = **presença no curso**.

## Certificado de trabalho (apresentação + coautoria)

- Só trabalhos **aceitos** e marcados **apresentado** (botão na lista de trabalhos do admin) geram certificado.
- É **um PDF por trabalho, uma página por autor**: relator = "apresentação", demais = "coautoria".
- **Quem baixa:** o **relator** (sócio na área / externo em `trabalho-certificado.html` por e-mail+Doity) baixa o PDF completo e repassa a cada coautor a página dele.
- Se um **coautor for sócio**, ele também vê e baixa o **mesmo PDF completo** na área dele (casado pelo e-mail da conta na lista de autores).

## Comandos úteis (SQL, no Supabase)

Ligar o interruptor do evento:
```sql
update public.eventos set certificados_liberados = true where nome = 'IX ENEON 2026';
```

Ativar/segurar um tipo (ex.: participação):
```sql
update public.certificado_modelos m set ativo = true   -- ou false para segurar
where m.tipo = 'participacao'
  and m.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026');
```

Conferir papéis e entrega:
```sql
select cp.tipo, cp.nome, cp.detalhe,
  case when cp.profile_id is null then 'e-mail (sem conta)' else 'área da sócia' end as entrega
from public.certificado_papeis cp
where cp.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
order by cp.tipo, cp.nome;
```

## Migrações desta rodada (rodar no SQL editor, uma vez)

- `2026-07-19-ajuste-titulos-e-musical-ix-eneon.sql` — título da Isabelle + musical.
- `2026-07-19-liberar-palestrante-professor-ix-eneon.sql` — títulos + liga o interruptor.
- `2026-07-19-modelo-comissao-ix-eneon.sql` — modelo + papéis da organização.
- `2026-07-19-credenciamento-inscrito-externo.sql` — coluna p/ toggle de presença de externo.
- `2026-07-19-declaracao-por-doity.sql` — RPC da declaração pública por número do Doity.
- `2026-07-21-presenca-e-certificado-curso.sql` — presença por curso (`inscricoes_curso.presente`),
  carga horária do curso, modelo `oficina` e RPC pública `certificados_curso_por_doity`.
- `2026-07-31-certificados-avaliador-e-assistente.sql` — tipos novos `avaliador` e
  `assistente` (CHECKs + modelos + papéis do José Antônio e da Adriane); traz no fim
  a lista de todos os avaliadores de `trabalhos_avaliacao` e um bloco comentado para
  estender o certificado a todos eles.
- `2026-07-31-avaliadores-todos.sql` — cria o papel de avaliador para todos os nomes de
  `trabalhos_avaliacao`, casando com o cadastro para usar o **nome completo correto**
  (os nomes da tabela são curtos e alguns têm erro de digitação). Quem não casa sai
  listado para cadastrar à mão.
- `2026-07-31-jose-antonio-participacao-e-coautoria.sql` — presença do José Antônio de Sá Neto
  + grava a chave `email` na entrada dele da lista de autores (é o que a RPC de coautoria
  procura). Termina listando quem mais tem papel sem presença.
