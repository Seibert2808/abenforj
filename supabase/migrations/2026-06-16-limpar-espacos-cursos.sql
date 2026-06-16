-- Limpa quebras de linha e espaços duplicados embutidos nos campos de texto
-- de `cursos` (nome, local, descricao). Vieram de quando os cursos foram
-- cadastrados copiando o texto do HTML, que tinha indentação/\r\n no meio.
-- Colapsa qualquer sequência de espaços em um só e remove sobras nas pontas.
-- Idempotente: só atualiza linhas que realmente diferem da forma normalizada.

update public.cursos
  set nome      = btrim(regexp_replace(nome,      '\s+', ' ', 'g')),
      local     = btrim(regexp_replace(local,     '\s+', ' ', 'g')),
      descricao = btrim(regexp_replace(descricao, '\s+', ' ', 'g')),
      updated_at = now()
  where nome      is distinct from btrim(regexp_replace(nome,      '\s+', ' ', 'g'))
     or local     is distinct from btrim(regexp_replace(local,     '\s+', ' ', 'g'))
     or descricao is distinct from btrim(regexp_replace(descricao, '\s+', ' ', 'g'));
