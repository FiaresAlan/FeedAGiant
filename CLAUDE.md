# Feed a Giant — instruções do projeto (Roblox)

**Idioma:** toda comunicação, documentação e relatório em **português brasileiro**.

O procedimento geral (pesquisa no vault, skills, delegação, revisão, nota mínima 8,5) está na skill global `roblox-director` (`C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\skill\SKILL.md`). Siga-o em toda tarefa. Projeto **existente**: não usar o scaffold de projetos novos.

## Comece por aqui
1. `docs/HANDOFF_NEXT_SESSION.md`: estado atual, próxima tarefa e condições do usuário.
2. `docs/GAME_BRIEF.md`: briefing e tabela de decisões. Não decidir estilo, economia ou monetização que não estejam nele.
3. `docs/DIAGNOSTICO_E_PLANO.md`: diagnóstico e as 5 fases aprovadas (não reformular).
4. `.fwjelaa/ledger.jsonl`: notas de qualidade de cada sistema e asset.

## Estrutura
`src/shared` → ReplicatedStorage.Shared · `src/server` → ServerScriptService.Server · `src/client` → StarterPlayer.StarterPlayerScripts.Client (Rojo, `default.project.json`).

## Comandos
```
python "C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\tools\luau_check.py" --project .
rojo build -o build/FeedAGiant-test.rbxl      # place de teste (nunca sobrescrever FeedAGiant.rbxl sem commit)
```
Blender: `C:\Users\Administrador\Desktop\blender-5.4.0-alpha+main.50d477803fa8-windows.amd64-release\blender.exe`

## Regras do usuário (resumo; texto completo no handoff §2)
- Commit antes de toda alteração importante. Testar sempre numa cópia do place.
- Autonomia técnica. Justificar antes de mudanças irreversíveis de economia, monetização, identidade visual ou experiência.
- Nada de publicar, gastar Robux ou fazer upload comercial sem autorização.
- Celular primeiro. Entregas testadas. Rubricas Fwjelaa ≥ 8,5.

## Fatos do projeto
- Place ID / Universe ID: não publicado.
- Dono dos assets: conta do usuário.
- Estilo de arte: **cartoon pintado (stylised PBR)**, decidido em 07/11/2026 (ver `docs/GAME_BRIEF.md` §5).
- GitHub: https://github.com/FiaresAlan/FeedAGiant (`main`).
