# FeedAGiant — qualidade de gameplay e checklist de QA
**Data:** 09/11/2026 · **Estado:** código implementado em branch, **não testado no Roblox Studio**.

## Proteção antes de testar
- Backup antes das mudanças desta rodada: `backup/2026-11-09-antes-melhorias-gamefeel` (PR anterior no commit `8f587f0284294e32bf05e67f449dd8f33fda9365`).
- Código novo: `codex/feedagiant-qualidade-prelancamento-2026-11-09`.
- Sem merge no `main`, sem salvar/substituir o place oficial, sem publicar, sem Robux.
- Para restaurar esta rodada: usar a branch de backup, que preserva o estado do PR antes das novas animações.

## O que foi alterado e o que NÃO foi alterado
1. **Alimentação:** a comida continua voando e a mordida ocorre no tempo existente. Adicionado `Highlight` temporário local, efeito por raridade, texto da primeira mordida e do nível obtido. Não muda XP, probabilidade de crítico, comida nem velocidade.
2. **Evolução:** evento inclui o estágio anterior para mostrar `ANTES → DEPOIS`. Mantém curva de tamanho, estágios e VFX já existentes.
3. **Ovos:** eclosão agora usa rachaduras 2D simuladas, fragmentos por raridade, menos tempo e fundo transparente. A revelação tenta mostrar o **modelo 3D real da espécie** a partir de `Workspace.GiantStatues.Statue_<id>`. Com StreamingEnabled ou malha ausente, a revelação mantém o texto existente. Não muda chance, tempo de incubação nem entregas.
4. **Disputa:** aviso pequeno de comida Épica+ a até 150 studs, apenas após nível 5 e no máximo um a cada 7 s. Não volta com painel permanente e não mostra seta para todos os drops. Não muda mecânica de roubo nem drops.
5. **Arena:** barra de vida pisca ao receber dano, sem criar um painel adicional. Não altera dano, combate, posicionamento ou resultados.
6. **Gigantes na base:** olhar suave para visitantes à frente, com busca a cada 0,7 s, apenas no cliente; placa de identificação mostra tamanho em vezes e só aparece a até 155 studs. Sem qualquer mudança na progressão.
7. **Pré-lançamento (PR anterior):** limite de recolha no pátio, validação de lote da Lunchbox, fundo de abertura transparente, analítica do primeiro/segundo feed e 3 testes de capacidade.

## Verificações obrigatórias antes de merge
| Teste | Passos | Aprovação |
|---|---|---|
| 1. Compilar Luau | Rodar o verificador do `CLAUDE.md`, Rojo build em cópia e suíte do `tests/Runner.luau` | 0 erro e todos testes passando |
| 2. Primeiro minuto | Entrar com conta nova, escolher espécie, alimentar 2 vezes, concluir tutorial | texto da primeira mordida aparece 1 vez e não bloqueia o HUD |
| 3. Reação do gigante | Alimentar comidas comum, épica e crítica perto da base; observar outro jogador | mordida/voo sincronizados, destaque some, sem acumular Highlight |
| 4. Primeira evolução | Chegar ao primeiro novo estágio; continuar alimentando após evolução | antes/depois correto, nenhuma mudança brusca para escala 1 |
| 5. Ovo comum e lendário | Iniciar eclusão após tempo; esperar eclodir, repetir com dois ovos | 1 recompensa por ovo, VFX sem tela preta e sem travar fila |
| 6. Espécie real no ovo | Fazer eclosão perto da praça com `GiantStatues` carregado | miniatura 3D da espécie correta, sem Scripts clonados |
| 7. Fallback de ovo | Testar com `StreamingEnabled` ou estátua ausente | texto do resultado permanece legível, nenhuma exceção |
| 8. Movimento reduzido | Ativar preferência, abrir caixa e eclodir ovo | sem rotação/tremida longa e sem tela escura |
| 9. Raridade próxima | No nível >= 5, receber drop Épico a <150 studs; outro a >150 | aviso só perto, autoesconde em ~2,2 s; sem spam |
| 10. Arena PvP/bot | Abrir luta, receber 1 golpe, sair/desconectar | barras de HP piscam, status limpa e não há exceção |
| 11. Visitar bases | Jogador A aproxima-se do gigante de B a <40 studs; recua | gigante olha levemente, volta ao idle, placas legíveis |
| 12. Celular físico | 15 min num Android intermediário; incluir eclosão e combate | legibilidade, controles acessíveis e FPS estável |
| 13. Perfil/recibo | Mochila com 300 e 2000 itens, abrir Lunchbox comum/paga, sair/reentrar | não duplicar ou perder comida, compra não confirma sem entrega |
| 14. Segurança do place | Abrir CÓPIA do place que o usuário salvou e conferir `Workspace.MainModule` | ausente no place final, sem scripts estranhos |
| 15. Multiplayer | 2 clientes testando ovos/roubo, boss e arena | sem desync, softlock, duplicação ou roubo de último ovo |

## Riscos conhecidos
- **Ainda sem rig por ossos para vários gigantes.** O movimento é procedural, não movimento facial real.
- **Rachaduras do ovo são efeitos 2D**, não fragmentação física da malha. O preview 3D depende de existir a estátua no cliente; a ausência não afeta o resultado concedido no servidor.
- **Efeitos audiovisuais ainda exigem validação real em dispositivos**, principalmente com muitos gigantes e ovos simultâneos.
- **Testes desta rodada:** inspeção estática das alterações e equilíbrio de delimitadores. O Roblox Studio, Rojo, Selene, DataStore e compras com Robux **não foram executados neste chat**.

## Go / No-Go
Lançamento de teste apenas se: lugar sem módulo suspeito, compilação/suíte verdes, eclosão no celular e em multiplayer funcionando, primeira alimentação fluida, DataStore persistindo e produtos pagos corretos. Qualquer falha de segurança, dados ou recibos = **no-go**. Publicidade paga somente após métricas observadas de aquisição e retenção.
