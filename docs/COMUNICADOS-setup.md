# Comunicados por e-mail em massa — guia de ativação

Funcionalidade nova no painel admin (`area/admin.html` → aba **Comunicados**) que envia
um e-mail com a identidade da ABENFO-RJ para **todas as associadas ativas**, usando
**Resend** (envio) + **Supabase Edge Functions** (backend).

O código já está pronto no repositório. Falta a configuração externa abaixo — são passos
que **só quem tem acesso ao Resend e ao Supabase** pode executar (uma vez só).

---

## O que foi criado no repositório

| Arquivo | O que é |
|---|---|
| `supabase/migrations/20260720_comunicados.sql` | Tabelas `comunicados` (log) e `descadastros` (opt-out) |
| `supabase/migrations/2026-08-11-fila-comunicados.sql` | Tabela `comunicado_destinatarios` (a fila, uma linha por destinatária) |
| `supabase/migrations/2026-08-11-cron-fila-comunicados.sql` | Agendamento diário do processamento da fila |
| `supabase/functions/enviar-comunicado/index.ts` | Valida admin, monta a fila e dispara o primeiro lote |
| `supabase/functions/processar-fila-comunicados/index.ts` | Envia o lote de cada dia seguinte (chamado pelo Cron) |
| `supabase/functions/_shared/envio.ts` | Envio via Resend, controle de cota diária e reenvio |
| `supabase/functions/descadastrar/index.ts` | Registra um opt-out (chamada pela página pública) |
| `supabase/functions/_shared/cors.ts` | CORS compartilhado |
| `descadastrar.html` | Página pública de descadastro (link do rodapé do e-mail) |
| `area/admin.html` (aba Comunicados) | Formulário + pré-visualização + teste + envio geral + andamento da fila |

---

## Passo a passo da ativação

### 1. Criar conta no Resend e verificar o domínio
1. Crie conta em <https://resend.com> (tem plano gratuito).
2. Em **Domains → Add Domain**, adicione `abenforj.org.br`.
3. O Resend mostra registros **DNS** (SPF, DKIM e, opcionalmente, DMARC). Adicione-os no
   painel onde o DNS do `abenforj.org.br` é gerenciado (provavelmente o mesmo do Vercel/registrador).
4. Aguarde a verificação ficar **verde** (pode levar de minutos a algumas horas).
   > Sem o domínio verificado, o Resend só deixa enviar para o **seu próprio e-mail** de teste.
5. Em **API Keys**, crie uma chave (**Sending access**) e copie o valor (começa com `re_…`).

### 2. Instalar a CLI do Supabase e conectar ao projeto
```bash
npm install -g supabase        # ou: brew install supabase/tap/supabase
supabase login                 # abre o navegador para autenticar
cd caminho/para/dev/abenforj
supabase link --project-ref jetyugyyhdzllfckjhnq
```

### 3. Rodar a migração (criar as tabelas)
Opção A (painel): abra o Supabase → **SQL Editor** → cole o conteúdo de
`supabase/migrations/20260720_comunicados.sql` → **Run**.

Opção B (CLI): `supabase db push`

### 4. Definir os "secrets" das funções
Gere um segredo aleatório para os links de descadastro (ex.: no terminal
`openssl rand -hex 32`) e rode:
```bash
supabase secrets set \
  RESEND_API_KEY="re_sua_chave_aqui" \
  COMUNICADOS_FROM="ABENFO-RJ <comunicados@abenforj.org.br>" \
  COMUNICADOS_REPLY_TO="abenforio@gmail.com" \
  UNSUB_SECRET="cole_o_segredo_aleatorio_aqui" \
  SITE_URL="https://abenforj.org.br"
```
> `COMUNICADOS_FROM` precisa usar um endereço **@abenforj.org.br** (domínio verificado no passo 1).
> Não é preciso setar `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` — o Supabase injeta sozinho.

Além desses, a fila precisa de mais um secret:

```bash
supabase secrets set FILA_SECRET="outro_segredo_aleatorio"
```
> `FILA_SECRET` é o que prova que a chamada diária veio do agendador, e não de fora.
> Opcionalmente, `LIMITE_DIARIO` (padrão 95) ajusta a cota diária caso o plano do Resend mude.

### 5. Publicar as funções
```bash
supabase functions deploy enviar-comunicado
supabase functions deploy processar-fila-comunicados
supabase functions deploy descadastrar
```
> A conta usada no `supabase login` precisa ser a **dona do projeto** (`abenforio@gmail.com`).
> Com outra conta os comandos falham com 403, mesmo tendo login feito.

### 5b. Agendar o processamento diário da fila
Abra `supabase/migrations/2026-08-11-cron-fila-comunicados.sql`, troque
`COLE_AQUI_O_FILA_SECRET` pelo valor real do secret, e rode no **SQL Editor**.
Confira depois com:
```sql
select * from cron.job_run_details order by start_time desc limit 10;
```

### 6. Publicar a página de descadastro
`descadastrar.html` já está no repositório; ao dar push/deploy do site (Vercel),
ela fica em `https://abenforj.org.br/descadastrar.html`.

---

## Como usar (no dia a dia)
1. Entre no painel admin → aba **Comunicados**.
2. Preencha **assunto**, **título**, **mensagem** (e, se quiser, **URL da imagem** e **botão**).
3. Clique **Pré-visualizar** para ver como fica.
4. Clique **Enviar teste para mim** e confira o e-mail na sua caixa.
5. Só então clique **Enviar para todas as ativas**. O primeiro lote sai na hora e o resto
   sai sozinho, um lote por dia. Acompanhe pela barra de andamento no histórico.
6. Programe-se: com 263 associadas, a mensagem leva **3 dias** para chegar a todas. Para
   uma convocação com data marcada, dispare com pelo menos uma semana de antecedência.

---

## Como a fila funciona

O plano gratuito do Resend entrega cerca de **100 e-mails por dia**. A base tem 263
associadas ativas, então um disparo único seria recusado no meio. Por isso o envio passa
por uma fila:

1. Ao clicar em **Enviar para todas as ativas**, a função cria o comunicado e grava uma
   linha por destinatária em `comunicado_destinatarios`, todas como `pendente`.
2. Ainda nesse clique, ela envia o primeiro lote (o que couber na cota do dia).
3. Todo dia às 10:00 de Brasília, o Cron chama `processar-fila-comunicados`, que envia o
   lote seguinte. Repete até a fila zerar.
4. O histórico no painel mostra a barra de andamento, quantas faltam e em quantos dias.

Detalhes que importam:

- **A cota é diária e compartilhada.** Cada rodada desconta o que já saiu desde a
  meia-noite UTC, então rodar duas vezes no mesmo dia não duplica nem estoura o limite.
  O teto usado é 95, e não 100, para sobrar folga para os envios de teste.
- **Erro passageiro não perde ninguém.** Se o Resend recusar o lote por cota ou cair,
  as destinatárias voltam para `pendente` e entram no lote seguinte. Só viram `falha`
  depois de 5 tentativas, ou em erro definitivo (e-mail inválido, por exemplo).
- **Dá para adiantar.** O botão *Enviar o próximo lote agora* roda o lote do dia na hora,
  sem esperar as 10:00. Útil se a cota do dia ainda não foi usada.
- **Se um dia a ABENFO assinar o Resend pago**, basta subir o secret `LIMITE_DIARIO`
  (ex.: `LIMITE_DIARIO=5000`) e o envio passa a sair de uma vez só, sem mexer no código.

## Limites e observações importantes
- **Volume mensal:** o plano gratuito do Resend também tem teto de 3.000 e-mails/mês.
  Um disparo para as 263 associadas consome cerca de 9% disso.
- **Descadastro (LGPD):** todo e-mail leva um rodapé "Não quero mais receber comunicados".
  Quem clicar entra na tabela `descadastros` e é automaticamente excluído dos próximos envios.
- **Segurança:** a função de envio só roda para quem é `is_admin` no banco — o anonKey público
  não consegue disparar e-mails.
- **E-mails transacionais** (redefinição de senha etc.) continuam pelo fluxo atual, sem relação
  com esta funcionalidade.
