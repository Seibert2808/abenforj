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
| `supabase/functions/enviar-comunicado/index.ts` | Envia o e-mail em massa (valida admin, remove descadastrados, envia via Resend, registra log) |
| `supabase/functions/descadastrar/index.ts` | Registra um opt-out (chamada pela página pública) |
| `supabase/functions/_shared/cors.ts` | CORS compartilhado |
| `descadastrar.html` | Página pública de descadastro (link do rodapé do e-mail) |
| `area/admin.html` (aba Comunicados) | Formulário + pré-visualização + envio de teste + envio geral + histórico |

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

### 5. Publicar as funções
```bash
supabase functions deploy enviar-comunicado
supabase functions deploy descadastrar
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
5. Só então clique **Enviar para todas as ativas**. O histórico registra cada envio.

---

## Limites e observações importantes
- **Plano do Resend:** o gratuito envia ~100 e-mails/dia (3.000/mês). Se a base de
  associadas for maior, será preciso um plano pago do Resend antes do primeiro disparo geral.
- **Tempo de execução:** o envio é feito em lotes de 100. Para listas muito grandes
  (milhares), pode ser necessário evoluir para uma fila — hoje atende bem algumas centenas.
- **Descadastro (LGPD):** todo e-mail leva um rodapé "Não quero mais receber comunicados".
  Quem clicar entra na tabela `descadastros` e é automaticamente excluído dos próximos envios.
- **Segurança:** a função de envio só roda para quem é `is_admin` no banco — o anonKey público
  não consegue disparar e-mails.
- **E-mails transacionais** (redefinição de senha etc.) continuam pelo fluxo atual, sem relação
  com esta funcionalidade.
