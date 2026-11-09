# Relatório da noite de melhorias (09/11/2026)

Papel dado pelo usuário: **dono do jogo** por ~7 horas ("procure melhorias, pesquise concorrentes, copie e traga, seja
criativo"). Única regra: fazer backup antes.

## Backup (feito antes de tudo)
- Git: tag e branch `backup-2026-11-09-antes-da-noite` (GitHub). Para voltar a tudo:
  `git checkout backup-2026-11-09-antes-da-noite`.
- Local: `backups/2026-11-09-antes-da-noite/`, com os places locais e um place gerado do código.
- O place publicado tem o histórico de versões da própria Roblox.

## O que entrou no jogo (tudo LIGADO em `src/shared/Features.lua`)
| Novidade | De onde veio a ideia | O que faz | Teste |
|---|---|---|---|
| **Mutações** | Clima + mutação dos simuladores de jardim | Na Hora Dourada, na Chuva de Comida e nas Lucky Boxes, a comida exposta no pátio pode virar **Dourada** (renda e XP ×1,5), **Suculenta** (renda ×1,25, XP ×2) ou **Arco-íris** (renda ×2, XP ×2,5). É permanente e vai junto até num roubo. Cria a escolha "deixar rendendo ou dar ao gigante" | Play: o pão ficou Dourado, renda 1→2; specs |
| **Fusão** | Jogos de "juntar iguais" | Botão FUNDIR na mochila: 3 comidas iguais viram **1 Gigantesca** (ocupa 1 vaga, renda/XP ×3,2, maior no pátio, herda a melhor mutação). Sem sorteio | Play: 3 maçãs (1 Dourada) → 1 Gigantesca Dourada; specs |
| **Gigante Ancestral** | Ideia própria: metas coletivas de servidor | Um golem colossal dorme no pé das montanhas. Toda alimentação de qualquer jogador enche o **Banquete** (comida rara vale mais). Cheio: ele acorda, chove comida (e às vezes caixas e ovos) na praça e todos ganham **+25% de XP por 5 min** | Play: dormindo → 50/100 → acordou, bônus ×1,25, drops caindo; specs |
| **Bem-vindo de volta** | Padrão de retorno dos simuladores | Quem volta depois de 10+ min vê **1 resumo**: renda offline, prêmio diário, missão semanal, ovos, caixas, fome, com botões DIÁRIO/NINHO | Play: painel com 5 linhas |
| **Auras da Loja do Criador** | Pedido do usuário | Fogo/Gelo/Pedra nos gigantes iniciais a partir de GritoRageModeVFX, Ice Wizard e Earth Elemental (auditados: 0 scripts) | Fotos `docs/qa/shots/v4/07-09` |
| **Ovos v2** | Pedido do usuário | Estrelas de cuidado (laço = alimentar o próprio gigante), ovos no mapa (4%), faixas revisadas, aviso de eclosão rara | Play + specs |
| Funções anteriores **ligadas** | — | Pity das Lunchboxes, proteção da sequência, dica de META, primeiro acesso, roubo justo, ovos e efeitos, espécies iniciais, missão semanal | Teste integrado |

**Teste integrado com tudo ligado:** 147 testes passaram, 0 falharam (15 módulos). Nenhum erro de script ao iniciar. No
fluxo de jogador novo aparece **uma janela por vez** (câmera de chegada → "Escolha o seu primeiro Gigante" → "Este é o
seu Gigante. Ele é seu.").

## Segurança
- `Workspace.MainModule` (o pacote malicioso "Racista") foi apagado com a sua autorização. **Falta você salvar e
  republicar.**
- Toda referência da Loja do Criador foi auditada no modo Play antes de virar código; nada foi inserido no place.

## Continua igual (regras)
Nada publicado, nenhum Robux gasto, nenhum upload novo esta noite, nenhum item aleatório pago criado.

## Para você decidir quando acordar
1. **Salvar o place (Ctrl+S)** e testar jogando. Para desligar qualquer novidade: `false` na linha dela em
   `Features.lua`. Para voltar a tudo: a tag de backup.
2. **Pity:** é bom conferir a página de políticas da Roblox sobre itens aleatórios pagos antes de publicar.
3. **Cópia de teste do place:** destrava o ovo de tutorial, o Treinador, o baú de 24 h, a revanche, a fase 1 do Dragão e os
   testes com 2 jogadores e no celular.
4. As notas das revisões cegas continuam entre 7 e 8,3, abaixo de 8,5. O que falta é sempre o mesmo: **2 jogadores e
   celular**.
