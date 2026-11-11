# FEED A GIANT V3 — GAME DESIGN DOCUMENT, MVP EXECUTÁVEL
Versão 3.0 · 11/11/2026 · Aprovado conceitualmente, sujeito a QA antes do lançamento

## 1. Identidade e proposta

**Nome provisório de comunicação:** Feed a Giant. Não renomear jogo sem pesquisar conflitos de títulos.
**Promessa em 10 segundos:** Monte no seu gigante, dispute ingredientes, escape com sua comida e alimente-o para crescer e correr melhor.
**Fantasia:** “Esse é o MEU gigante; eu o desenvolvi, montei nele e consegui aquela carga”.
**Público principal:** jogadores Roblox menores de 16, sem excluir adultos. Brincadeira estilizada e competição leve, sem gore, linguagem agressiva ou FOMO punitivo.
**Gênero:** coleção e cuidado de criatura + corrida de entrega e roubo de carga com risco delimitado + receitas e temporizadores paralelos. NÃO é MMORPG, tycoon passivo dominante, PvP de combate completo, cozinha simulador de restaurante, dungeon ou gacha comercial.
**Referência de mercado:** jogos de roubo, coleta e fuga, como Steal an Egg, inspiram a clareza visual do risco; não reproduzir logotipos, personagens, interface, pista ou recompensas idênticas de terceiros.

### Os quatro verbos obrigatórios

1. **MONTAR:** convocar o gigante ativo e controlá-lo, com avatar montado entre ombros/costas.
2. **PEGAR E ESCAPAR:** disputar uma carga que está no mundo; risco só enquanto em transporte contestado.
3. **PREPARAR:** combinar ingredientes, descobrir receitas e cozinhar em duas panelas paralelas, com funcionamento offline.
4. **ALIMENTAR:** gigante pega a comida, mastiga e reage, gera progressão perceptível e melhorias moderadas para a próxima coleta.

Qualquer funcionalidade que não sustente um desses quatro verbos é secundária.

## 2. O ciclo jogável de 80–180 segundos

A. Na base o gigante pede comida e aponta um objetivo opcional; há pelo menos um alimento simples garantido próximo.
B. Jogador monta no gigante em menos de 3 s após pressionar a interação de convocação; tutorial ensina mover e sprintar.
C. Corre até a pista/mercado central. As cargas surgem em locais visíveis: comida pronta leve, ingredientes de cozinha e pergaminhos de receita. O jogador escolhe risco e valor.
D. Pega uma carga com o gigante, exibida fisicamente nas mãos/costas do modelo, não só como contador.
E. Retorna à zona de depósito da própria base. A carga pode ser disputada temporariamente durante o retorno. Se perder, o jogador tem outra opção de carga próxima; não perde itens salvos.
F. Entrega depositada vira item do inventário atual, preservando identificador/quantidade/raridade e integridade transacional. Pergaminhos podem desbloquear receitas no Livro; ingredientes vão ao inventário.
G. Escolhe: alimento comum diretamente para o gigante, ou 2 ingredientes em uma panela para descobrir uma receita. As duas panelas funcionam em paralelo e offline.
H. Alimenta. O gigante direciona os olhos, usa mãos, abre a boca, mastiga e demonstra satisfação antes de surgir o número de XP. Aumenta estágio visual/força, dentro de limites.
I. Nova rodada é levemente diferente: a mesma carga pesa menos, novo ingrediente permite receita nova ou outra criatura requer abordagem distinta.

**O ciclo NÃO obriga cozinhar nem lutar.** Quem quiser apenas alimentação rápida e coleção consegue jogar; quem gosta de disputa acessa a pista. A pista é o melhor caminho para variedade, não o único caminho economicamente viável.

### Sessões

- 3–5 min: escolher/reencontrar gigante, 1 coleta curta, 1 entrega, 1 alimentação com reação.
- 8–12 min: duas ou três viagens, uma receita curta, conferir livro, progredir.
- 20 min: caçada a ingredientes raros, experimentar combinações, reagir a outras pessoas e iniciar preparo especial.
- Retorno após horas/dias: prato pronto em panela, gigante e coleção preservados, próxima receita desejada e outras rotas/cargas. Retorno não é obrigatório para manter níveis ou ovos.

## 3. Três modos de participação

**Modo humano na base:** avatar normal para interagir com livros, panelas, ovos, HUD e personalização. A base é área segura.
**Modo montado no gigante:** controle direto da criatura em terceira pessoa; avatar preso visualmente em assento sobre ombros/parte superior das costas. Tamanho padronizado de ~3 vezes um avatar humano para os três bípedes; cifra exata determinada por câmera, rig e colisões. Anda, vira, corre, interage e carrega. Não transformar permanentemente o avatar do jogador em um gigante: estados humano e montado precisam de ida/volta seguros.
**Modo espectador simples:** quando não está participando de disputa, vê outras pessoas correrem da praça/passeio sem colisão invasiva e sem ser obrigado a entrar em PvP.

Ponto de atenção: **“gigante no ombro” é uma montagem visual/rig, não VehicleSeat com tração de rodas**. Evitar física caótica e transmissão de comandos insegura. Controle de criatura, validação de posse e integridade ficam no servidor.

### Controles

- PC: WASD movimento, Shift sprint, E pegar/depositar/interagir, Q habilidade elemental, F montar/desmontar, câmera mouse.
- Mobile: analógico padrão/semelhante, botões de sprint, interagir, poder e desmontar visíveis com mão direita; nenhum gesto complexo obrigatório.
- Console: left stick mover, botão frontal interagir, gatilho sprint, bumper especial, botão voltar desmontar; respeitar mapeamento real após teste de gamepad.
- Contexto: ação “Pegar” só aparece perto do objeto elegível e se o jogador não estiver com carga; o HUD explica peso, status e caminho para casa.
- A câmera deve mostrar gigante e carga sem cabeça do avatar ou ombros bloquearem a visão, com afastamento adaptado por obstáculo e sem motion sickness.

## 4. O mundo — manter a ilha, construir só uma pista de qualidade

O projeto existente contém uma ilha com bases radiais e praça central. Antes de modificar, o Claude deve medir por script a ocupação do Workspace e conferir o place atual. **NÃO remover as oito bases ou mover construções sem um mapa de conflitos e backup.**

### Layout objetivo

- **Oito bases pessoais** existentes, retrabalhadas visualmente; cada uma com plataforma do gigante, duas panelas legíveis, livro de receitas e nicho do ovo/coleção. Mais espaço útil que um quadrado simples, mas sem construir mansões.
- **Praça de encontro** entre bases, com caminho claro até a pista; área social de observação, sem 10 sistemas competindo por atenção.
- **Pista do Banquete (nova atração principal):** corredor/pátio retilíneo muito legível, largura suficiente para ultrapassagem de dois gigantes e fuga lateral. Hipótese inicial: 180–240 studs de comprimento e 40–60 studs de largura, dimensionados ao rig real; se não couber na ilha atual sem destruir bases, criar uma plataforma anexa compacta com ponte e visual coerente, não um continente. Comprimento final é decisão de teste, não exigência literal.
- **Zona de coleta:** pickups distribuídos em faixas de risco por distância; comida leve mais perto, ingredientes combináveis no meio, carga pesada/pergaminhos raros em pontos disputados. Não deixar uma linha perfeita de botões que automatize o jogo.
- **Zona de entrega:** claramente marcada para cada player, posição alcançável em todas as rotas, feedback sonoro e visual claro.
- **Zonas seguras:** base e segmento inicial de acesso; não permitir capturar carga na área privada.
- **Observação:** avatares humanos conseguem ver os gigantes; pedestres não precisam atravessar a pista, e obstáculos não trancam a câmera.

### Distribuição de cenário

A pista NÃO deve ser uma estrada vazia gigantesca. Criar interesse visual em camadas: bordas de brinquedo, torres pequenas, banners, painéis, caixas de ingredientes, bandeiras de sinalização, animação leve de produção de comida, arborização fora da faixa útil. As linhas de visão precisam permitir reconhecer carga, rota e perseguidor.

### O que ficará de fora da ilha ativa

- Arena grande de BOXE / torneios: fechar acesso e esconder promoção no HUD; preservar código, recebíveis e histórico.
- Academia de Colossos: não ativar/expandir; manter data schema se já existir.
- Boca do Colosso/expedição: não construir; desativar convite e portal.
- Cozinha social cooperativa anterior: preservar código sob flag, mas não forçar 2 pessoas para alimentar ou cozinhar.
- Trilha de checkpoint, mirante de fotos, boss ou eventos secundários: desligar banners automáticos se competirem com o ciclo; preservação técnica, decisão visual baseada em mapa e desempenho.
- Nova moeda para pista, ovos, panelas, ranks: nenhuma.
- Roubo permanente de ovos, itens e comida de inventário: não misturar com o novo roubo de CARGA TRANSITÓRIA. Se já existir código de roubo de ovos, manter desativado para o primeiro teste e não deletar dados.

## 5. Pista: seleção, posse e roubo

### Cargas

- **Comida pronta leve:** serve para alimentação direta e será sempre acessível, com valor baixo.
- **Ingredientes comuns:** usados em receitas fáceis, spawn frequente, carregamento leve.
- **Ingredientes raros:** utilizados em combinações especiais, respawn mais lento e localização claramente sinalizada.
- **Carga pesada:** exige mais transporte; desaceleração conforme força. Não impedir iniciante de levar; apenas torna a decisão de risco mais evidente.
- **Pergaminho de receita:** concede DESCOBERTA permanentemente quando entregue, não remove receita antiga de outra pessoa. Pegá-lo não é obrigatório: uma receita também pode ser descoberta por combinação real na panela.

### Estados de carga (máquina de estado)

WORLD_AVAILABLE → RESERVED → CARRIED(owner,carrier,nonce) → (DROPPED | DEPOSITED | EXPIRED).
Pode haver troca por interceptação apenas quando CARRIED e fora de zona segura, com tempo de imunidade após o golpe. DROPPED é visível por curto tempo, elegível para novo pickup sem duplicar. DEPOSITED é terminal e cria UM crédito de inventário/livro, idempotente.
O servidor valida proximidade, player vivo, gigante montado e pertencente ao player, estado, cooldown, limite, origem, rota e destino.

### Interceptação sem combate completo

O jogador rival aperta o botão contextual de “Interromper” ao se aproximar do carregador (alcance curto, telegráfo de animação). Se conseguir, a carga cai fisicamente numa área recuperável. **Não rouba instantaneamente item salvo nem dá socos repetidos sem contrajogo.** O dono tem chance de recuperação. Nas primeiras duas entregas de uma conta nova, cargas ficam protegidas. Cooldowns por atacante e alvo impedem bullying.
Sem animação de boxe elaborada; inicialmente um gesto curto e uma reação de cambalear sem ragdoll disruptivo. O jogador escolhe se arrisca em região aberta.

### Robustez

Se carga cair fora do mundo, reposicionar no último checkpoint seguro ou despawnar e restaurar o pickup; nunca duplicar inventário. Se portador desconectar, liberar mundo novamente sem dar item. Bloquear farme em conta alternativa e combinações repetitivas, inclusive pares de jogadores. Carga não gera moeda nem XP ao cair, apenas na entrega/alimentação válida.

## 6. Força, velocidade, carga e progressão

### Progressão

Crescimento físico da criatura NA BASE tem três estágios Bebê → Jovem → Colosso. Durante corrida, rig e hitbox são padronizados (~3x avatar) para evitar caos em câmera e desigualdade de alcance. Há uma distinção visual de corpo, material e detalhes; nunca usar expansão de “balão” como animação primária.

**Força:** reduz apenas uma parte da penalidade de peso; valor limitado em disputa.
**Agilidade:** melhora moderadamente velocidade base e recuperação de corrida; teto próximo de jogadores novos.
**Domínio:** resultado do uso/experiência, sem RPG de dezenas de atributos.

Um gigante evoluído deve sentir progressão, mas um iniciante ágil deve conseguir fugir com comida leve.

### Balanceamento HIPOTÉTICO para protótipo

Velocidade de referência dos gigantes montados: 20 studs/s; sprint curto até 27 studs/s enquanto houver fôlego. Alimentação melhora teto base de modo limitado (máx. +8% antes de boosts). Penalidade de cargas: leves 0%, médias -10%, pesadas -25% para iniciante; força elevada pode reduzir penalidade pesada, mas nunca eliminá-la completamente (piso -8%). Os números são proposta, sujeitos a playtest mobile; não configurar como constants espalhadas.
Fôlego: 100 pontos, sprint consome ~20/s, recuperação ~14/s fora do sprint e sem interrupções bruscas. Nenhum sprint infinito por pagamento.

### Elementos

Cada criatura possui UM poder contextual, acionado por Q/botão mobile. Poderes devem ter mesma ordem de utilidade em uma rodada, com efeitos legíveis, cooldown e limites controlados no servidor.

| Elemento | Poder MVP | Função na pista | Proposta de limite |
|---|---|---|---|
| Pedra | Passada Firme | Reduz parcialmente a penalidade de peso por 4 s | redução máxima de 40% da penalidade, cooldown 25 s |
| Fogo | Arrancada | +12% de velocidade por 3 s, mas não ignora carga | cooldown 25 s, gasto de fôlego adicional |
| Gelo | Escudo Frio | Resiste a uma interrupção válida por 2 s | cooldown 30 s, sinal visual claro, não bloqueia todo contato |

**Balanceamento:** efeitos arredondados em tabela central, sem knockback em massa. Fogo não deve dominar cargas leves, Pedra não deve dominar todas as pesadas, Gelo não deve virar imunidade permanente. Equiparar tempo médio de entrega entre elementos no cenário alvo (tolerância inicial 10–15%, hipótese de QA). Não prometer vantagem elementar no boxe: boxe fica fora do MVP; hooks podem ser previstos, não implementados.

### Peso das cargas

Cada tipo tem WeightClass e CarryPenaltyConfig, não simulação de massa física instável. Modelos de alimentos são visuais; física principal da locomoção não depende de dezenas de joints nos alimentos. Definir CFrame/Attachment nas mãos do rig com LOD para terceiros, colisão desabilitada na carga carregada; o servidor mantém identificador e calcula a velocidade autorizada.

## 7. Criaturas e coleção

Primeiro piloto de qualidade: Golem de Pedra. A intenção do MVP é oferecer três identidades, Pedra/Fogo/Gelo, **somente se as três possuírem silhuetas distintas e animações básicas funcionais**. Nenhum modelo rígido inflável é aceito como “feito”. Se não houver tempo/licença válida, o teste pode começar com Pedra jogável e duas opções visivelmente “em desenvolvimento”, não falsos modelos completos; comunicar ao dono antes de publicar.

Reaproveitar modelos já existentes após auditoria de licença e possibilidade de retopologia/rig. O “Dragão Vermelho” e “Dragão de Cristal” existentes são candidatos; não presumir que são bípedes, R15 ou legalmente redistribuíveis. Teste técnico: um rig locomotor compartilhado para gigantes bípedes, com substituição de pele e diferenças de corpo. Animar por ossos/peças articuladas, não escalonar uma malha inteira durante idle. Se um dragão quadrúpede não encaixar sem distorção, optar por modelo bípede próprio ou adiar, não forçar o mesmo movimento.

Ovos atuais e coleção: um gigante ativo, os demais com dados preservados. Incubação/coleção não deve dominar a HUD no primeiro minuto. Primeiro ovo/espécie pode ser de escolha garantida; ovos pagos aleatórios só após revisão de política e odds. Mistura, reprodução, fusão e mutação do gigante ficam pós-MVP.

## 8. Ingredientes, combinações e Livro de Receitas

**Objetivo:** dar uma segunda camada significativa ao roubo. É mais interessante sair da pista com um ingrediente que completa uma receita do que obter apenas +XP.

### Ingredientes de design (IDs e nomes provisórios — mapear para catálogo REAL existente)

1. apple (maçã): comum / leve.
2. bread (pão): comum / leve.
3. cheese (queijo): comum / leve.
4. meat (carne): comum / média.
5. potato (batata): comum / leve.
6. honey (mel): incomum / leve.
7. pepper_rare (pimenta rara): raro / leve.
8. colossal_fruit (fruta colossal): raro / pesada.

Não inserir IDs arbitrários diretamente no DataStore. Claude deve mapear cada ingrediente para uma definição existente em Config/Foods ou adicionar via migração documentada; peso, raridade, asset e origem são dados definidos pelo servidor.

### Receitas iniciais propostas — 6, DETERMINÍSTICAS

| Ingredientes | Receita visível | Classe | Tempo proposto | Resultado |
|---|---|---|---|---|
| pão + queijo | Torrada de queijo | Comum | 12 s | alimento pronto básico |
| maçã + pão | Torrada de maçã | Comum | 15 s | alimento pronto e primeira descoberta |
| carne + batata | Ensopado | Incomum | 35 s | comida mais nutritiva |
| fruta + mel | Fruta caramelizada | Rara | 90 s | boa alimentação, reação visual |
| carne + pimenta rara | Carne apimentada | Lendária | 12 min | progresso alto com teto e efeito especial |
| fruta colossal + mel | Banquete de Frutas | Mítica | 30 min | prato extraordinário, animação especial e progresso limitado |

Os nomes são genéricos de propósito. Se uma combinação não possuir assets, troque o modelo por composição procedimental de ingredientes, mantendo visual legível. A raridade é da definição da receita, NÃO um sorteio infinito. A qualidade depende de ações futuras; no MVP não há minijogo obrigatório de cortar/misturar. **Descoberta por combinação:** primeira produção válida registra a receita no Livro. Pergaminho achado na pista também pode revelar antecipadamente ingredientes/tempo e conceder desbloqueio de uma receita específica, mas não deve retirar o valor de experimentar combinações.

Receita desconhecida: mostrar prévia de “combinação não descoberta”, não destruir ingredientes sem aviso. No MVP, se não houver definição de receita para o par, retornar os ingredientes, mostrar tentativa sem consumo e sugerir procurar outro par. Nunca criar toda combinação possível de 8 ingredientes. Produto de cozinha tem ID único de resultado, sem depender de texto do nome.

**Economia:** comparar valor de alimentar ingredientes individualmente e o prato pronto; o benefício da receita deve valer o tempo e a organização, sem multiplicação arbitrária de XP. Um prato especial pode revelar reação/marco visual em vez de dominar estatísticas. Ingrediente raro que também entra diretamente na barriga não deve ser totalmente inútil sem cozinhar.

### Livro de Receitas no HUD

Ícone de livro discreto; painel compacto em desktop/mobile, não escurecer o jogo.
Lista 6 entradas numeradas com estado DESCUBERTA/BLOQUEADA; ao descobrir, exibir dois ícones de ingrediente, nome do prato, tempo de preparo, resultado e o que falta. Para receitas ainda não encontradas, fornecer pistas legíveis sem solução integral. O livro é por jogador, persistente. Botões de receitas só acionam preparação quando player está perto da panela, com ingredientes suficientes e panela ociosa. Todas as informações de propriedade são recebidas do servidor.

## 9. Duas panelas de verdade, cozimento offline

Cada base tem dois objetos físicos distintos: Panela A e Panela B. **AMBAS aceitam receitas rápidas ou lentas**; jogador não é obrigado a reservar uma para lendária. Se ambas estiverem ocupadas, alimentação direta de alimentos comuns do inventário continua disponível. Não vender a solução do problema como passe pago obrigatório.

### Estados por slot

EMPTY → INPUT_VALIDATED → COOKING(startedAtUtc, endsAtUtc, recipeId, inputNonce) → READY → CLAIMED.
Quando começa a preparação, ingredientes são debitados de maneira transacional e gravados com job persistente, de forma resistente a desconexão. Horário UTC do servidor é autoridade; cliente pode só interpolar contagem regressiva. Se player sair, job continua pelo cálculo de relógio na próxima carga de perfil. Nunca exigir uma task executando 3 horas online para completar.
Ao terminar, panela muda visualmente, som e vapor; prato NÃO se perde até ser coletado. Claim é idempotente, somente dono, com proteção de capacidade de inventário (segura em READY se cheio). Após claim, receita pode ser iniciada de novo.

### Primeiras durações

Comuns 12–15 s, incomum 35 s, rara 90 s, lendária 12 min, mítica 30 min. São tempos para testar; **não usar 2–3 h no MVP**, pois alonga artificialmente um ciclo ainda não validado. Preparos de 1–3 h podem ser avaliados depois com D1/D7 reais. Sem pagamento para acelerar no teste inicial.

### VFX e áudio

Líquido estilizado animado; bolhas que aumentam discretamente conforme raridade; vapor claro para bom preparo; brilho colorido e uma pequena fanfarra para especiais; fumaça escura apenas para erro de qualidade em eventual atualização. Nada de física real de fluidos ou fumaça que encobre câmera. “Pronto” deve emitir som curto satisfatório que não sobrepõe dezenas de panelas vizinhas. Panela no mundo tem três indicadores claros: vazio, tempo restante e pronto.

## 10. Alimentação e progresso

Animação é um requisito funcional. Sequência mínima: gigante percebe comida, olha/acompanha, braço se estende, mão agarra alimento, leva à boca, mandíbula abre, mastiga duas vezes, engole, gesticula e retorna ao idle sem teleportar partes. O alimento só é consumido após validação de posse pelo servidor, com um único commit e efeito sincronizado. Nenhum número aparecendo antes da ação visual.
Crescimento nos três estágios com silhuetas diferentes, não “boneco de posto” expandindo a cada mordida. Escala de base limitada; na pista, altura/collision envelope constante. Preservar níveis e dados existentes; rever decaimento por ausência antes de ativá-lo.

**Feedback obrigatório:** barra de desenvolvimento pouco invasiva; visualização física do crescimento; áudio distinto para comida comum/especial, partículas contidas, expressão/perfil de personalidade opcional. No MVP personalidade avançada não cria nova progressão.

## 11. Retenção até quatro semanas — sem prometer resultado

- Dia 1: “Meu gigante realmente move e come. Descobri meu primeiro prato.”
- Dias 2–7: completar o livro de 6 receitas, dois preparos offline em paralelo, desenvolver os três elementos, dominar trajetos e cargas.
- Dias 8–28: coleção de criaturas/variantes existentes (apenas se rig e arte prontos), marcos estéticos permanentes por livros e entregas, competição social voluntária, títulos por recordes e variedade de ingredientes na pista.
- Sem perder nível, gigante, ovos ou item em ausência. A panela continua cozinhando.
- Não criar “missão diária obrigatória” que zera em caso de falta. Objetivos podem ser retomados.
- Não criar pontuação “força infinita” que invalida o equilíbrio da pista. Fase Colosso alcançada não encerra a diversão: o jogador agora usa o gigante para disputar ingredientes difíceis, descobrir combinações e desenvolver outras criaturas.
- Longo prazo é HIPÓTESE; V3 não comprova ainda retenção de 28 dias. Métricas reais orientam a continuação.

## 12. Onboarding (meta de 3 min para diversão, não tutorial infinito)

0–20 s: avatar aparece na base com um gigante bebê próximo e uma única ação clara “Alimente-o”.
20–45 s: pega alimento próximo, gigante reage fisicamente e muda pequeno detalhe visual. Primeira alimentação não pode ser roubada.
45–90 s: mostrar opção “Montar”; câmera muda com suavidade, personagem fica nos ombros, controle é direto. Fala curta “Vá até a pista e pegue algo”.
90–150 s: a primeira carga leve é visível e segura; player leva de volta à base, deposita, vê celebração.
150–210 s: panela ensina combinar dois ingredientes de exemplo, com tempo de preparo curto; livro registra descoberta. 
A partir daí: jogador escolhe livremente entre nova corrida, outra alimentação, ovo ou cozinhar. **Não mostrar academia, boxe, Boca, quatro lojas e oito eventos ao mesmo tempo**. Onboarding adaptativo: dicas só quando pessoa não progride, com opção de pular; sem overlay escuro.

## 13. P0 / P1 / P2 e riscos do produto

P0 = um Golem montável, animações, pista, disputa mínima, entrega, alimentação confiável, uma panela por base para teste técnico, transação, analytics; depois segunda panela, receita e Livro para fechar V3 antes de teste pago.
P1 = os três elementais com qualidade igual, três boosts equilibrados, seis receitas, duas panelas offline, onboarding, base detalhada. **Estes são requisitos para a V3 candidata ao anúncio**, mas implantar após P0.
P2 = variações de eventos da pista, mais espécies, experiência de caixa social, campeonatos e arena de boxe somente após dados.
Regras: qualidade visual não é enfeite; fraqueza de montagem, corrida ou deglutição bloqueia progresso. Nenhuma feature pode mascarar um ciclo central que não diverte.

## 14. Situações negativas com tratamento explícito

- Jogador entra com servidor vazio: ainda consegue todos ingredientes comuns e pelo menos um raro através de rotação do mapa, sem rivais; não necessita bot para alimentar.
- Jogador perde 3 disputas: oferecer rota segura com comida útil; evitar perseguição infinita; proteção temporária curta, sem conceder vitória.
- Player desconecta montado: soltar carga sem duplicar, avatar volta normal ao entrar.
- Player desconecta cozinhando: terminar pelo relógio do servidor; mesma receita segura READY.
- Player troca gigante com receita em preparo: panelas são do jogador/base, receita permanece válida, comida pronta vai ao inventário e pode ser dada à criatura atual.
- Player troca gigante carregando: bloquear até entregar/largar, informar no HUD.
- Servidor encerra durante delivery: conceder exatamente uma vez via nonce/ledger persistente ou recuperar estado seguro; nunca premiar duas vezes.
- Cliente lento ou celular: LOD em criaturas distantes, música/VFX simplificados, controle sem gestos impossíveis.
- Exploit envia “sou o dono”/“meu cooldown acabou”/“minha receita lendária terminou”: ignorar; servidor lê dados autoritativos.
- Servidor com 8 jogadores: ajustar largura e número de pickups; evitar 8 câmeras com efeitos extremos; simular lotação antes de release.

## 15. Métricas de diversão / hipóteses

Não medir só “30 minutos online”. Medir primeiro feed, segunda alimentação voluntária, primeira montaria, primeira carga, primeira entrega, perda/recuperação da carga, primeira combinação, primeiro preparo e conclusão da receita, retorno D1, dias jogados e duração ativa.
Nenhuma hipótese deve ser chamada de benchmark oficial. Se poucos jogadores montam no gigante, problema de visibilidade/tutorial. Se montam mas não retornam com carga, problema de pista/câmera/roubo. Se entregam mas não cozinham, revisar affordance e valor do Livro. Se cozinham mas não alimentam de novo, revisar animação e gratificação da criatura.
Pronto para teste exploratório somente após o QA do arquivo 04.

## 16. Contrato de NÃO implementação na V3

NÃO criar: boxe de dois modos, danos persistentes, poder de espancar avatar, roubo de receita descoberta de outro player, roubo da base, alimentação forçada toda hora, custo de dois itens para fuso de gigantes, novas moedas, boost pay-to-win, sessão de 3 h obrigatória, dungeon de Boca, novos mundos grandes, sistemas extensos de RPG, adoção de 20 espécies em paralelo, mudança irreversível de saves.
V3 substitui V2 como escopo de execução. Código existente não envolvido nesta rodada deve ser preservado e desativado visualmente, nunca removido sem plano de migração/rollback.