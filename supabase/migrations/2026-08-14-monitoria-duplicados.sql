-- Limpa os papéis de monitoria DUPLICADOS criados por 2026-08-14-papel-monitoria.sql.
--
-- O que aconteceu (14/08/2026): aquela migração criou papéis a partir de duas
-- fontes, a lista monitores_evento (nome digitado à mão) e as inscrições
-- marcadas "Monitora" (nome do cadastro), e só DEPOIS vinculou as contas. Como
-- a checagem de duplicata na hora do insert só tinha o nome para comparar, quem
-- está escrito diferente nas duas fontes ganhou DOIS papéis: um órfão, com o
-- nome da lista, e um vinculado, com o nome do cadastro.
--
-- No IX ENEON foram exatamente duas pessoas:
--   Gleicia da Cruz Paes            ↔ Gleicia da Cruz Paes Carneiro
--   Rebeca da Silva Guimarães dos Santos ↔ Rebeca Silva Guimarães dos Santos
-- (as mesmas duas que 2026-07-09-marcar-monitores-parte2.sql já tinha achado).
--
-- Aqui apagamos só o órfão, quando todos os tokens do nome dele estão contidos
-- no nome de um papel VINCULADO do mesmo evento e tipo. "da/de/do/dos/das/e"
-- entram na comparação como ruído e são descartados.
--
-- Rode no SQL editor. Idempotente. CONFIRA A ETAPA 2 ANTES DE APAGAR.

-- ── 1. função de tokens do nome (só para esta comparação) ──────────────────
create or replace function public.f_tokens_nome(t text)
returns text[] language sql immutable as $$
  select array(
    select tok
    from unnest(string_to_array(public.f_norm_titulo(t), ' ')) as tok
    where tok <> '' and tok not in ('da','de','do','das','dos','e','a','o')
    order by tok
  );
$$;

-- ── 2. PREVIEW: o que vai ser apagado, e em favor de quem ──────────────────
-- Tem que listar só as duplicatas óbvias. Se aparecer alguém que NÃO é a mesma
-- pessoa do lado direito, pare e me chame.
select orf.nome as vai_apagar, ok.nome as fica, p.email
from public.certificado_papeis orf
join public.certificado_papeis ok
  on ok.evento_id = orf.evento_id and ok.tipo = orf.tipo
 and ok.profile_id is not null
 and public.f_tokens_nome(ok.nome) @> public.f_tokens_nome(orf.nome)
join public.profiles p on p.id = ok.profile_id
where orf.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and orf.tipo = 'monitoria'
  and orf.profile_id is null
order by orf.nome;

-- ── 3. apagar ──────────────────────────────────────────────────────────────
delete from public.certificado_papeis orf
where orf.evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and orf.tipo = 'monitoria'
  and orf.profile_id is null
  and exists (
    select 1 from public.certificado_papeis ok
    where ok.evento_id = orf.evento_id and ok.tipo = orf.tipo
      and ok.profile_id is not null
      and public.f_tokens_nome(ok.nome) @> public.f_tokens_nome(orf.nome)
  );

-- ── 4. conferência: quantos monitores sobraram e quem ainda está sem conta ─
select count(*) filter (where profile_id is not null) as com_conta,
       count(*) filter (where profile_id is null)     as sem_conta,
       count(*)                                       as total
from public.certificado_papeis
where evento_id = (select id from public.eventos where nome = 'IX ENEON 2026')
  and tipo = 'monitoria';
