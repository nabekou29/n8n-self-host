const { Client, GatewayIntentBits } = require("discord.js");
const axios = require("axios");

require("dotenv").config();

// 環境変数から設定を読み込み
const DISCORD_TOKEN = process.env.DISCORD_TOKEN;
const N8N_WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;

// Discord クライアントの初期化
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
    GatewayIntentBits.GuildMembers,
  ],
});

// メンションに反応するボット
// 使い方: @BotName [メッセージ]
// 例: @MyBot こんにちは

// Bot が準備完了時
client.once("ready", () => {
  console.log(`ログインしました: ${client.user.tag}`);
});

// メッセージ受信時の処理
client.on("messageCreate", async (message) => {
  // Bot自身のメッセージは無視
  if (message.author.bot) return;

  // Botへのメンションをチェック
  if (message.mentions.has(client.user)) {
    try {
      // メッセージから様々な情報を収集
      const webhookData = {
        // メッセージ内容（メンション部分を除去）
        content: message.content.replace(/<@!?\d+>/g, '').trim(),
        rawContent: message.content, // 元のメッセージも保存
        messageId: message.id,

        // ユーザー情報
        user: {
          id: message.author.id,
          username: message.author.username,
          discriminator: message.author.discriminator,
          avatarURL: message.author.displayAvatarURL(),
          isBot: message.author.bot,
        },

        // チャンネル情報
        channel: {
          id: message.channel.id,
          name: message.channel.name,
          type: message.channel.type,
        },

        // サーバー情報
        guild: {
          id: message.guild.id,
          name: message.guild.name,
          memberCount: message.guild.memberCount,
          icon: message.guild.iconURL(),
        },

        // タイムスタンプ
        timestamp: message.createdTimestamp,
        createdAt: message.createdAt.toISOString(),

        // 添付ファイル情報
        attachments: message.attachments.map((att) => ({
          name: att.name,
          url: att.url,
          size: att.size,
          contentType: att.contentType,
        })),

        // メンション情報
        mentions: {
          users: message.mentions.users.map((user) => ({
            id: user.id,
            username: user.username,
          })),
          roles: message.mentions.roles.map((role) => ({
            id: role.id,
            name: role.name,
          })),
          everyone: message.mentions.everyone,
        },

        // リアクション情報（既存のリアクション）
        reactions: message.reactions.cache.map((reaction) => ({
          emoji: reaction.emoji.name,
          count: reaction.count,
        })),
      };

      // n8n webhook に送信
      const response = await axios.post(N8N_WEBHOOK_URL, webhookData, {
        headers: {
          "Content-Type": "application/json",
        },
      });

      // 成功メッセージを送信
      await message.reply("✅ Webhookに送信しました！");

      console.log("Webhook送信成功:", response.status);
    } catch (error) {
      console.error("Webhook送信エラー:", error);
      await message.reply("❌ Webhook送信中にエラーが発生しました。");
    }
  }
});

// エラーハンドリング
client.on("error", console.error);

// Bot をログイン
client.login(DISCORD_TOKEN);
