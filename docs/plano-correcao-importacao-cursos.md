# Plano de correção — perda de inscrições em cursos na reimportação do Doity

> **Status:** mitigação parcial aplicada (gatilho em 2026-06-28). Correção estrutural
> a executar **depois do IX ENEON 2026**, com calma.
>
> **Regra de ouro até lá:** NÃO rodar reimportação destrutiva do Doity. Ver "Regras
> operacionais até o evento".

## 1. Resumo do problema

Inscrições em **cursos pré-encontro** do IX ENEON "sumiam": pessoas que tinham
escolhido curso apareciam, dias depois, como "não inscrita em nenhum curso" na área
delas. Afetou dezenas de pessoas; recuperação foi manual, caso a caso, sem backup
(plano gratuito do Supabase não tem backup → dado perdido não era recuperável).

## 2. Os dois mecanismos de falha

### Mecanismo 1 — Cascade na migração não-sócia → sócia
- Não-sócias escolhiam curso pelo fluxo `escolher-cursos.html`, gravando em
  `inscricoes_curso` com `inscrito_externo_id` (registro temporário em
  `inscritos_externos`).
- O FK `inscricoes_curso.inscrito_externo_id` foi criado com **`ON DELETE CASCADE`**
  (migration `2026-05-15-vagas-e-inscritos-externos.sql`).
- A reimportação ("Processar inscrições" em `area/admin.html`) **migra** quem tem
  cadastro de sócia confirmado: cria `inscricoes_evento` e **apaga o registro
  `inscritos_externos`** (`idsApagarRec` → `.delete()`).
- O cascade apaga junto a escolha do curso. A migração recria a inscrição no
  **evento**, mas **não** recria a escolha do **curso**. → curso perdido.

### Mecanismo 2 — Rebaixamento de estudante não confirmada
- `perfilConfirmado()` exige, para categoria `estudante`, `cadastro_completo = true`.
- Estudante sócia sem o comprovante (ex.: certificado de mestrado) é **rebaixada** na
  reimportação: cria pendência em `inscritos_externos` e **apaga a
  `inscricoes_evento`** dela.
- Nesse vai-e-volta (rebaixar → reconfirmar depois) a escolha de curso se perde.
- Atinge inscritas com `inscricoes_evento.observacao` NULL (não são as "migradas").
  Ex.: Milena, Mariana. **Este mecanismo ainda NÃO está blindado.**

## 3. Causas-raiz (o que estava errado no desenho)

1. **Reimportação destrutiva:** apaga e recria em vez de só atualizar. Deletes são
   irreversíveis e disparam efeitos colaterais (cascade).
2. **`ON DELETE CASCADE` sobre dado do usuário:** a escolha de curso (com vaga
   escassa) foi configurada para ser apagada junto com um registro administrativo.
3. **Escolha de curso presa a identidade temporária:** a não-sócia escolhia contra um
   registro que o próprio sistema depois apaga. Deveria estar presa ao **perfil**.
4. **Reimportação rodada várias vezes:** o estrago se repetia a cada execução.
5. **Falha silenciosa + sem backup:** apagava sem avisar; sem como desfazer.

## 4. Mitigação já aplicada

- **Gatilho `preservar_cursos_ao_apagar_externo`**
  (`supabase/migrations/2026-06-28-preservar-cursos-ao-migrar-externo.sql`,
  rodado 2026-06-28): `BEFORE DELETE` em `inscritos_externos` reaponta as escolhas de
  curso para o perfil (mesmo e-mail) antes do cascade. **Neutraliza o Mecanismo 1.**
- Recuperação manual das que reclamaram (Alessandra, Juliana Vianna, Milena, Mariana,
  Thayna) via `INSERT` em `inscricoes_curso` ignorando vaga esgotada.
- Lista de conferência para o dia (todas sem curso, com MIGRAÇÃO marcado):
  `Documents/ABENFORJ/ENEON 2026/INSCRIÇÕES/Inscritas sem curso - conferencia ...`.

## 5. Regras operacionais até o evento

- ❌ **NÃO rodar reimportação destrutiva do Doity** (o Mecanismo 2 ainda fere).
- ✅ Recolocar manualmente quem aparecer com comprovante (modelo
  `MODELO-recolocar-pessoa-em-curso.sql`).
- ✅ Usar a lista de conferência impressa no credenciamento.

## 6. Plano de correção (pós-evento)

Ordem sugerida:

1. **Reimportação não-destrutiva** (núcleo). Reescrever "Processar inscrições" em
   `area/admin.html` para ser **aditiva**: só `INSERT`/`UPDATE`, **nunca** `DELETE`
   de `inscritos_externos` ou `inscricoes_evento` que tenham curso/trabalho vinculado.
   Migração não-sócia→sócia deve **reapontar** curso e trabalho ao perfil **antes** de
   qualquer remoção (o gatilho já cobre curso; garantir trabalho também).
2. **Soft-delete em vez de hard-delete.** Padronizar `cancelado`/`status` em todas as
   inscrições; nunca `DELETE`. (Já existe `cancelado` em `inscricoes_evento` e
   `inscritos_externos` — passar a usá-lo no fluxo de importação.)
3. **Regra de elegibilidade de curso** (pedido da Sabrina): escolha de curso só para
   inscrição **confirmada** (sócia OU não-sócia), sempre amarrada ao **perfil**.
   Aposentar (ou blindar) o fluxo `escolher-cursos.html` baseado em `inscrito_externo_id`.
   Bloquear pendências (ex.: estudante sem comprovação).
4. **Blindar o Mecanismo 2.** Confirmar exatamente como a escolha some no rebaixamento
   de estudante e impedir (não apagar `inscricoes_evento`; usar soft-delete; preservar
   `inscricoes_curso`).
5. **Backup.** Subir o Supabase para plano com backup diário / PITR antes do próximo
   evento — para que qualquer perda futura seja recuperável.
6. **Log/aviso na importação.** A importação passa a reportar "X inscrições
   alteradas/removidas, Y cursos reapontados" — fim da falha silenciosa.

## 7. Critérios de aceite

- Rodar a reimportação 2x seguidas **não altera** nenhuma `inscricoes_curso` existente.
- Migrar uma não-sócia (com curso escolhido) para sócia **mantém** o curso no perfil.
- Rebaixar uma estudante não confirmada **não apaga** o curso dela.
- Nenhum `DELETE` em `inscritos_externos`/`inscricoes_evento` no fluxo de importação
  (verificável por busca no código).
- Backup configurado e testado (restore de uma tabela de teste).

## 8. Referências

- Gatilho: `supabase/migrations/2026-06-28-preservar-cursos-ao-migrar-externo.sql`
- FK com cascade: `supabase/migrations/2026-05-15-vagas-e-inscritos-externos.sql`
- Cota sócia/estudante pendente: `supabase/migrations/2026-05-24-inscritos-externos-pendentes.sql`
- Lógica de importação e `perfilConfirmado()`: `area/admin.html` (fluxo "Processar inscrições")
