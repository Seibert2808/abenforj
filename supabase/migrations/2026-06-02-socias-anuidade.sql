-- Lista oficial de SÓCIAS QUITES (anuidade paga) por ano. Serve de referência
-- para o admin sinalizar, nas inscrições do ENEON, quem já é sócia da ABENFO-RJ
-- mesmo sem cadastro no site. Cruzamento por e-mail (lower/trim).
-- Admin-only (RLS). Não usado no fluxo público nem na contagem de sócias do evento.

create table if not exists public.socias_anuidade (
  id         uuid        primary key default gen_random_uuid(),
  nome       text        not null,
  email      text,
  ano        int         not null default 2026,
  criado_em  timestamptz not null default now()
);

create index if not exists socias_anuidade_email_idx
  on public.socias_anuidade (lower(email));

alter table public.socias_anuidade enable row level security;

drop policy if exists "SociasAnuidade: admin tudo" on public.socias_anuidade;
create policy "SociasAnuidade: admin tudo"
  on public.socias_anuidade for all
  using (public.is_admin())
  with check (public.is_admin());

-- Carga 2026 (idempotente: limpa o ano antes de inserir, pode rodar de novo).
delete from public.socias_anuidade where ano = 2026;
insert into public.socias_anuidade (nome, email, ano) values
  ('Adriana Lenho de Figueiredo Pereira', 'adrianalenho.uerj@gmail.com', 2026),
  ('Adriana Teixeira Reis', 'adriana.driefa@gmail.com', 2026),
  ('Alan Messala de Aguiar Britto', 'alanmessala@yahoo.com.br', 2026),
  ('Alessandra Teixeira Velasco', 'alessandra.t.velasco@gmail.com', 2026),
  ('Alexandra Baptista', null, 2026),
  ('Ana Beatriz Azevedo Queiroz', 'abaqueiroz@hotmail.com', 2026),
  ('Ana Beatriz Morais da Silva', 'abms.uerj@gmail.com', 2026),
  ('Ana Carolina Mendes Soares Benevenuto Maia', 'anacarolinamendes.s@hotmail.com', 2026),
  ('Ana Caroline Damazio Araujo', 'ana.30s2022@gmail.com', 2026),
  ('Ana Leticia Monteiro Gomes', 'analeticia.eean.ufrj@gmail.com', 2026),
  ('Anderson William Cruz da Silva', 'andersonsilvapsf@gmail.com', 2026),
  ('André Luiz Baptista Reis', 'andre.rbl@gmail.com', 2026),
  ('Arlexieviny Rodrigues Silva', 'eviny.rodrigues@hotmail.com', 2026),
  ('Barbara de Abreu Cardoso', 'barbaraac249@gmail.com', 2026),
  ('Bárbara Lemos Barroso', 'barbaralemosb@gmail.com', 2026),
  ('Bianca Lemos de Carvalho', 'biancalemos.carvalho@gmail.com', 2026),
  ('Carla Oliveira Shubert', 'carlashubert@yahoo.com.br', 2026),
  ('Cristiane Rodrigues da Rocha', 'crica.rocha@hotmail.com', 2026),
  ('Daniele da Silva Cornelio', 'dani.silvaesilva@hotmail.com', 2026),
  ('Danielle Rodrigues do Couto', 'danicouto2007@gmail.com', 2026),
  ('Debora de Carvalho Ranciaro', 'deboraranciaro@yahoo.com.br', 2026),
  ('Edymara Tatagiba Medina', 'edymaramedina@gmail.com', 2026),
  ('Elisa da Conceição Rodrigues', 'elisadaconceicao@gmail.com', 2026),
  ('Emília da Costa Moreira Falcão', 'emilia.dacosta@yahoo.com.br', 2026),
  ('Flávia Muniz da Costa Borges', 'flavia991@hotmail.com', 2026),
  ('Fernanda Galvão Gonçalves Moreira', 'ferngalvao@gmail.com', 2026),
  ('Francisca Leia de Sousa', 'paismca@mesquita.rj.gov.br', 2026),
  ('Giullia Taldo Rodrigues', 'giullia.enfobstetra@gmail.com', 2026),
  ('Glaucelaine da Silva Teixeira', 'glausilva@hotmail.com', 2026),
  ('Gláucia Lemgruber Schuabb', 'glaucialschuabb@gmail.com', 2026),
  ('Gleicia da Cruz Paes Carneiro', 'gleiciapaes@yahoo.com.br', 2026),
  ('Heloisa Ferreira Lessa', 'heloisa.lessa@terra.com.br', 2026),
  ('Iraci do Carmo de França', 'franca.iraci@gmail.com', 2026),
  ('Ivana Oliveira Martins', 'ivana_oliveira45@hotmail.com', 2026),
  ('Jaciara Lady Costa da Silva', 'enf_jaciara@hotmail.com', 2026),
  ('Joana Iabrudi Carinhanha', 'joanaiabrudi@gmail.com', 2026),
  ('Joyce Becker Silveira', 'beckerjoyce31@gmail.com', 2026),
  ('Jordana Brock Carneiro', 'jordanabrock@yahoo.com.br', 2026),
  ('Josy da Silva Côrtes Batista', 'josycortes29@gmail.com', 2026),
  ('Juliana Serpa Monteiro Sales', 'juserpa12@gmail.com', 2026),
  ('Julianne de Lima Sales Feijoli', 'juliannefeijoli@gmail.com', 2026),
  ('Kellen Teles Lopes Paredes', 'kellenteleslopes@gmail.com', 2026),
  ('Eleny Correia da Silva', 'leny.cs@hotmail.com', 2026),
  ('Luciane Pereira de Almeida', 'luciane.almeida.013@gmail.com', 2026),
  ('Luana Asturiano da Silva', 'luanaasturiano@hotmail.com', 2026),
  ('Marcele Zveiter', 'marcelezveiter@hotmail.com', 2026),
  ('Marceli Aparecida de Souza Vieira', 'marcelivieira86@gmail.com', 2026),
  ('Marcia Villela Bittencourt', 'mavibi@uol.com.br', 2026),
  ('Maira Antonieta Rubio Tyrrel', 'tyrrell2004@hotmail.com', 2026),
  ('Mariana Roza Leonardo', 'marianarozaleo@gmail.com', 2026),
  ('Maysa Luduvice Gomes', 'maysa.luduvice@gmail.com', 2026),
  ('Michele de Lima Janotti Quaresma', 'michelleljqrj@hotmail.com', 2026),
  ('Michele Spindola de Souza Freire', 'michelespindola@hotmail.com', 2026),
  ('Milayd de Andrade Zamboni', 'milayd10@icloud.com', 2026),
  ('Milena Ferreira de Araújo', 'milenaaraujoesf@gmail.com', 2026),
  ('Nathalia Cristina de Souza Almeida', 'nathcrist07@hotmail.com', 2026),
  ('Patrícia Salles Damasceno de Matos', 'patriciasallesd@gmail.com', 2026),
  ('Priscila de Souza Nogueira', 'nogueira.sesrj@gmail.com', 2026),
  ('Priscila Paiva de Almeida Mendonça', 'paivappa@hotmail.com', 2026),
  ('Priscilla Holanda de Oliveira Santos', 'enf.priscillaholanda@gmail.com', 2026),
  ('Raiane da Silva Rachid', 'raianerachid485@gmail.com', 2026),
  ('Rosana dos Santos Corrêa', 'rosanacorreaseap@gmail.com', 2026),
  ('Rozânia Bisego Xavier', 'rozania.bicego@gmail.com', 2026),
  ('Sabrina Lins Seibert', 'sabrinalinsseibert@gmail.com', 2026),
  ('Simone Pereira dos Santos', 'simonepersan@gmail.com', 2026),
  ('Thaís Moreira Lopes', 'thais_moreira_lopes@hotmail.com', 2026),
  ('Thaíssa Fernandes de Oliveira', 'enfthaissaoliveira@gmail.com', 2026),
  ('Thamyris Tavares Monteiro', 'thamyristavaresmonteiro@gmail.com', 2026);
