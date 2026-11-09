# Pendências que só podem ser feitas depois de publicar o jogo

## Notificação "Ovo pronto" (`Features.EggNotifications`, estrutura em `src/server/Services/EggNotificationService.lua`)
**Pré-requisito da Roblox:** jogo publicado com pelo menos **100 visitas**, sem moderação ativa
(vault: *Experience Notifications and Return Prompts* §2).

| Passo | Quem | Detalhe |
|---|---|---|
| 1. Criar a mensagem | Dono (Creator Dashboard → Engagement → Notifications) | Até 99 caracteres, ex.: "Seu {eggName} chocou! Venha ver quem nasceu." Copiar o id e colocar em `EggNotificationService.MESSAGE_ID` |
| 2. Pacote Open Cloud | Diretor (com autorização) | Instalar o pacote oficial da Creator Store em ServerScriptService; `send` chama `createUserNotification(userId, {payload = {messageId, type = "MOMENT", parameters = {eggName = {stringValue = ...}}}})` |
| 3. Fila no MemoryStore | Diretor | Uma chave por usuário, ordenada pela hora em que o ovo choca; reivindicar antes de enviar (dois servidores não mandam duas vezes); não enviar se o jogador estiver online; validade de no máximo 45 dias |
| 4. Ligar | Dono | `Features.EggNotifications = true` |

**Regras já decididas:** no máximo 1 aviso por ovo; só para quem está offline; só 13+ que ativaram notificações (a Roblox
filtra); nunca depender só do aviso (a dica de META "Seu ovo choca em X min" cobre quem está online).
**Caminho alternativo (fora do jogo):** `POST https://apis.roblox.com/cloud/v2/users/{userId}/notifications`, com chave de
API de escopo `user.user-notification:write` e `source.universe = universes/{universeId}`.
**Métrica:** `egg_notification_sent` (no envio) e `egg_notification_clicked` (pelo `launchData` na entrada).
