-- Monitores do IX ENEON: lista de nomes (independente de cadastro de sócia),
-- para aparecerem na lista de inscritos/recepção com o tipo "Monitoria".
-- Muitos monitores são estudantes sem cadastro no site, por isso ficam numa
-- tabela própria (nome solto), não em inscricoes_evento (que exige profile).

create table if not exists public.monitores_evento (
  id          uuid        primary key default gen_random_uuid(),
  evento_id   uuid        not null references public.eventos(id) on delete cascade,
  nome        text        not null,
  created_at  timestamptz not null default now(),
  unique (evento_id, nome)
);

alter table public.monitores_evento enable row level security;
drop policy if exists "Monitores: admin tudo" on public.monitores_evento;
create policy "Monitores: admin tudo" on public.monitores_evento
  for all using (public.is_admin()) with check (public.is_admin());

-- Insere a lista de monitores do IX ENEON 2026 (idempotente).
insert into public.monitores_evento (evento_id, nome)
select e.id, m.nome
from public.eventos e
cross join (values
  ('Mariana Ornellas Branco'),
  ('Carolina Bandeira Levy de Araújo'),
  ('Michele Carneiro Martins'),
  ('Tamires Alexandra Ferreira dos Santos'),
  ('Isabela Cabral da Cunha Souza'),
  ('Pâmela da Silva Chuff'),
  ('Sarah de Jesus de Aquino'),
  ('Nalim Carolina Rodrigues Leite'),
  ('Greicelane da Silva Soares'),
  ('Victórya da Costa Barreto Pinto Pires'),
  ('Marcelle da Silva Ferreira'),
  ('Juliana Ferreira Loureiro'),
  ('Marina Luiza Feitosa Oliveira'),
  ('Isabel Graça dos Santos'),
  ('Yasmim Feliciano Sales'),
  ('Bruna Macedo de Souza'),
  ('Júlia Rodrigues Melo'),
  ('Camille de Oliveira Antunes Victorino'),
  ('Alba Valéria Magalhães Ribeiro Costa'),
  ('Letícia Dutra Macedo'),
  ('Rebeca da Silva Guimarães dos Santos'),
  ('Maria Eduarda de Souza Brazileiro de Jesus'),
  ('Ludmila Espinoso da Silva'),
  ('Monique dos Santos Mattos'),
  ('Gleicia da Cruz Paes'),
  ('Alana Marques Rodrigues de Almeida'),
  ('Alanna Lorosa dos Santos'),
  ('Ana Gabriela Ferreira de Araujo'),
  ('Ana Clara Ribeiro do Nascimento'),
  ('Fabricia de Oliveira Falcão'),
  ('Miriã Pimentel de Sá'),
  ('Manoella de Oliveira Ramos Ferreira'),
  ('Mariana Zampa de Oliveira')
) as m(nome)
where e.nome = 'IX ENEON 2026'
on conflict (evento_id, nome) do nothing;
