# Evidências — Especificação v3, parte 1 (08/11/2026)

Studio: place aberto "Alimente um Gigante" (115578986093768), com o código sincronizado pelo `rojo serve` do usuário.
**Testes só no modo Play** (descartado ao parar); nada foi salvo no place. Commit do código: `326e369` + ajuste de luz da carne.

## 1. Verificador Luau
`luau_check.py --project .` → fwjelaa-check PASS · selene PASS · StyLua PASS · luau-lsp PASS · **overall PASS (86 arquivos)**.

## 2. Testes automáticos (servidor do Play, módulos reais)
Saída do console: `[FwjelaaTests] 88 passed, 0 failed, 9 spec modules` (72 antigos + 16 de `tests/V3.spec.luau`).
As linhas "boom" e "bug" no console são erros provocados de propósito pelos specs de Signal e PlayerData.

Verificação extra pelo comando (mesmas funções), **0 falhas**:
- interruptores todos desligados;
- pity: 48 caixas sem mudança, 50ª com mínimo Épico, não rebaixa Lendária, zera com Épica;
- tela de chances com pity soma 100,00% e não lista nada abaixo de Épica;
- simulação 2.000 jogadores × 200 caixas comuns: pior intervalo sem Épica = **50** (limite 50); média 24,8 caixas;
- sequência diária: < 48 h intacta; > 48 h com proteção mantém e gasta 1; sem proteção zera; função desligada = regra antiga;
- roubo: novato protegido, limite diário, contador reinicia no dia seguinte;
- migração: perfil antigo mantém moedas 123.456, nível 42, sequência 5, inventário, caixa guardada e espécie, e ganha os 6 campos novos.

## 3. Fluxo real no Play (1 jogador; funções ligadas por atributo só nessa sessão)
- 2 compras de Lunchbox Comum pelo remote do jogo: o contador do pity subiu 1 → 2 (estado enviado ao cliente); métrica `gacha_roll:common/Uncommon/base`.
- Todas as 14 janelas com o fundo `Dim_*` em transparência 1 (antes 0,45).
- Dica de objetivo: o servidor escolheu `task_done` ("Tarefa concluída: resgate no DIÁRIO!") e registrou `objective_shown`. Depois de guardar o presente, a linha de META mostrou "Abra sua Lunchbox guardada na base!" em verde (foto 01).
- Presente de boas-vindas: caixas guardadas 0 → 1 (`common`); a 2ª chamada não repete; `welcomeGiven=true`.
- Porção da Carne Gigante na cabeça: peças Meat, Fat, Bone, BoneKnob soldadas (fotos 02 e 03).
- Rodada final com tudo DESLIGADO (padrão): nenhum erro de script no console.

## 4. Não testado
- 2 jogadores (limite de roubo e proteção de novato no caminho real; só a regra pura e o código foram vistos).
- Câmera de chegada e efeito dobrado da 1ª alimentação: o perfil de teste já tinha jogado (`totalFeeds=40`), então o caminho "jogador novo" não disparou. Só foi lido o código.
- Celular e controle físico; DataStore real (o Studio usa memória).

Fotos: `docs/qa/shots/fase8/01_loja_sem_escurecer_dica_presente.jpg`, `02_carne_antes_ajuste_luz.jpg`, `03_carne_pernil_final.jpg`.

## 5. Revisão cega (1 revisor, rubrica system) e correções
- Nota **6,7** (notas [1,1,1,2,2,2], pesos 3,3,2,2,1,1 → 16/24; soma refeita pelo diretor). Abaixo de 8,5 = **rascunho**.
- Bugs apontados e corrigidos:
  - rebirth volta o nível a 1 e virava proteção de novato → agora vale o maior nível já alcançado e quem renasceu nunca é novato (`GameLogic.victimProgress`);
  - veterano que refizesse o tutorial ganharia o presente → só conta marcada como novata na 1ª entrada (`onboardingAt = -1`, `OnboardingService.giftEligible`).
- Apontado e mantido de propósito: o limite diário conta roubos CONCLUÍDOS (entregues na base); roubo derrubado no caminho não conta.
- Depois das correções: verificador PASS (86) e suíte no Play **`[FwjelaaTests] 90 passed, 0 failed, 9 spec modules`**.
- Para passar de 8,5 falta: teste com 2 jogadores (roubo, novato, limite), caminho "jogador novo" ao vivo, medição no celular.
