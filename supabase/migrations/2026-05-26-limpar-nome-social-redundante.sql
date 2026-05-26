-- Limpa nome_social em perfis onde a pessoa preencheu o mesmo valor do
-- nome_completo (provavelmente nao entendeu pra que serve o campo). Nome
-- social so faz sentido quando difere do nome de registro — quando igual,
-- nao agrega informacao e ainda atrapalha a renderizacao da carteirinha.

update public.profiles
  set nome_social = null
  where nome_social is not null
    and nome_completo is not null
    and lower(trim(nome_social)) = lower(trim(nome_completo));
