-- Atualiza a lista de convidados do IX ENEON (credenciamento/recepção).
-- Fonte: Downloads/Lista de convidados.xlsx (atualizada 2026-07-13).
-- Idempotente: ON CONFLICT DO NOTHING sobre unique(evento_id, nome).
-- Só ADICIONA (os 25 já semeados em 2026-07-09 permanecem; nada é removido).

insert into public.convidados_evento (evento_id, nome)
select e.id, v.nome
from public.eventos e
cross join (values
  ('Aline Silva da Fonte Santa Rosa de Oliveira'),
  ('Adriana Teixeira Reis'),
  ('Ana Cláudia M. Barreto'),
  ('Ana Claudia Moreira Monteiro'),
  ('Ana Letícia Gomes'),
  ('Ana Luiza Zapponi'),
  ('Angela Mitrano Perazzini de Sá'),
  ('Anna Christina de Almeida Porréca'),
  ('Claudia Maria Messias'),
  ('Diana Schnneider'),
  ('Diego Vieira de Mattos'),
  ('Débora Cecília Chaves de Oliveira'),
  ('Heloisa Lessa'),
  ('Isabelle Mangueira de Paula Gaspar'),
  ('Jacqueline Alves Torres'),
  ('José Antônio de Sá Neto'),
  ('Kira Young'),
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
  ('Solange Gonçalves Belchior'),
  ('Claudia Rosane Guedes'),
  ('Lucia Helena Garcia Penna'),
  ('Joana Iabrudi Carinhanha'),
  ('Fernanda Galvão Gonçalves Moreira'),
  ('ANA CUIELA LAURINDO TCHITEMBO'),
  ('AURORA NANKHALI PATENA KAMBINDANGOLO'),
  ('CLARA SUZANETE GOMES DIAS DOS SANTOS'),
  ('EMÍLIA LIANGA MUTEKA KALUELA'),
  ('MARIA DAS DORES LIMA GIME DINIS'),
  ('NEUSA ERICA MANUEL'),
  ('PASCUALINA LUCAS MARIA'),
  ('YALDINA CARLA MAJOR TEIXEIRA')
) as v(nome)
where e.nome = 'IX ENEON 2026'
on conflict (evento_id, nome) do nothing;

-- Conferência: total de convidados do evento após a atualização
select count(*) as total_convidados
from public.convidados_evento c
join public.eventos e on e.id = c.evento_id
where e.nome = 'IX ENEON 2026';
