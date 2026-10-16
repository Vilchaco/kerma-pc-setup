// Envio de avisos: Telegram (TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID) y/o Slack (SLACK_WEBHOOK_URL).
export async function notify(text) {
  const out = [];
  const tok = process.env.TELEGRAM_BOT_TOKEN, chat = process.env.TELEGRAM_CHAT_ID;
  if (tok && chat) {
    const r = await fetch(`https://api.telegram.org/bot${tok}/sendMessage`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ chat_id: chat, text, parse_mode: 'HTML', disable_web_page_preview: true }),
    });
    out.push('telegram ' + r.status);
  }
  const slack = process.env.SLACK_WEBHOOK_URL;
  if (slack) {
    const plain = text.replace(/<[^>]+>/g, '');
    const r = await fetch(slack, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ text: plain }) });
    out.push('slack ' + r.status);
  }
  return out;
}

