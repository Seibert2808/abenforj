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

## As duas travas

1. **Interruptor do evento** `eventos.certificados_liberados` — liga/desliga TUDO do evento de uma vez.
2. **Modelo ativo** `certificado_modelos.ativo` — liga/desliga por TIPO. (Ex.: desativar `participacao` segura só as declarações, mantendo palestrante/professor.)

Além disso, cada tipo tem sua **trava própria** (o "por quê" da pessoa receber):
- participação → precisa de **presença registrada** (não basta estar inscrito);
- palestrante/professor/comissão → precisa do **papel** cadastrado e vinculado;
- monitoria → precisa estar marcada como monitora.

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
