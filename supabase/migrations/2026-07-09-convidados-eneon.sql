-- Convidados do IX ENEON: palestrantes (da programação) + convidados avulsos,
-- para aparecerem na lista de inscritos/recepção com o tipo "Convidado".
-- Mesmo padrão de monitores_evento (nome solto, sem depender de cadastro).

create table if not exists public.convidados_evento (
  id          uuid        primary key default gen_random_uuid(),
  evento_id   uuid        not null references public.eventos(id) on delete cascade,
  nome        text        not null,
  created_at  timestamptz not null default now(),
  unique (evento_id, nome)
);

alter table public.convidados_evento enable row level security;
drop policy if exists "Convidados: admin tudo" on public.convidados_evento;
create policy "Convidados: admin tudo" on public.convidados_evento
  for all using (public.is_admin()) with check (public.is_admin());

insert into public.convidados_evento (evento_id, nome)
select e.id, m.nome
from public.eventos e
cross join (values
  ('Adriana Teixeira Reis'),
  ('Ana Cláudia M. Barreto'),
  ('Ana Luiza Zapponi'),
  ('Angela Mitrano Perazzini de Sá'),
  ('Anna Christina de Almeida Porréca'),
  ('Claudia Maria Messias'),
  ('Diego Vieira de Mattos'),
  ('Débora Cecília Chaves de Oliveira'),
  ('Heloisa Lessa'),
  ('Isabelle Mangueira de Paula Gaspar'),
  ('Jacqueline Alves Torres'),
  ('José Antônio de Sá Neto'),
  ('Marcele Sampaio de Freitas Guimarães Ribeiro'),
  ('Marcele Zveiter'),
  ('Mariana Moreira Tangari'),
  ('Marilanda Lopes de Lima'),
  ('Maysa Luduvice Gomes'),
  ('Michele de Lima Janotti Quaresma'),
  ('Midian Oliveira Dias'),
  ('Patrícia Santos Barbastefano'),
  ('Reginaldo Lemos Soares Ferreira'),
  ('Renata Alves de Lima Nunes Barbosa'),
  ('Rubem Figueiredo Sadok Menna Barreto'),
  ('Simone Pereira dos Santos'),
  ('Solange Gonçalves Belchior')
) as m(nome)
where e.nome = 'IX ENEON 2026'
on conflict (evento_id, nome) do nothing;
