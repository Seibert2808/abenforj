-- Normaliza nomes proprios (nome_completo, nome_social, e nome em inscritos_externos)
-- aplicando title case em portugues — "ANA SOUZA" / "ana souza" -> "Ana Souza".
-- Preposicoes (de, da, do, das, dos, e) ficam em minusculo, exceto se forem
-- a primeira palavra. Espelha a logica do helper window.abenfo.utils.tituloPt no frontend.

create or replace function public.titulo_pt(s text) returns text
language plpgsql
immutable
as $$
declare
  partes text[];
  resultado text := '';
  parte text;
  pequenas text[] := array['de','da','do','das','dos','e'];
  i int := 0;
begin
  if s is null then return null; end if;
  partes := regexp_split_to_array(trim(lower(s)), '\s+');
  foreach parte in array partes loop
    if length(parte) = 0 then continue; end if;
    if i > 0 and parte = any(pequenas) then
      resultado := resultado || ' ' || parte;
    else
      resultado := resultado || (case when i = 0 then '' else ' ' end)
        || upper(left(parte, 1)) || substring(parte from 2);
    end if;
    i := i + 1;
  end loop;
  return resultado;
end;
$$;

-- Aplica retroativamente nas tabelas existentes
update public.profiles
  set nome_completo = public.titulo_pt(nome_completo)
  where nome_completo is not null
    and nome_completo <> public.titulo_pt(nome_completo);

update public.profiles
  set nome_social = public.titulo_pt(nome_social)
  where nome_social is not null
    and nome_social <> public.titulo_pt(nome_social);

update public.inscritos_externos
  set nome = public.titulo_pt(nome)
  where nome is not null
    and nome <> public.titulo_pt(nome);
