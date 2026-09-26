import 'server-only';
import { after } from 'next/server';
import { deliver } from './transport';

// Avisos da Monira. Curtos e operacionais: o que aconteceu + um botão para agir.
// Quem recebe e se recebe é decidido na base de dados (009_avisos); aqui só se escreve e envia.

export type NotificationEvent =
  | { kind: 'message'; to: string; conversationId: string; productName: string | null; body: string }
  | { kind: 'product_published'; to: string; productId: string; productName: string }
  | { kind: 'product_changes'; to: string; productId: string; productName: string; note: string }
  | { kind: 'application_approved'; to: string; ujaName: string | null }
  | { kind: 'application_rejected'; to: string; note: string | null }
  | { kind: 'order_new'; to: string; orderId: string; orderNumber: string; productName: string | null; totalKz: number; paymentMethod: string };

function siteUrl(path: string) {
  const base = (process.env.SITE_URL ?? 'https://monira-app.vercel.app').replace(/\/$/, '');
  return `${base}${path}`;
}

function escape(s: string) {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

function render(title: string, lines: string[], action: { label: string; path: string }) {
  const url = siteUrl(action.path);
  const text = [title, '', ...lines, '', `${action.label}: ${url}`, '', 'Monira'].join('\n');
  const html = `<!doctype html><html lang="pt"><body style="margin:0;padding:24px;background:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#1a1a1a">
<div style="max-width:480px">
<p style="margin:0 0 16px;font-size:18px;font-weight:600;line-height:1.35">${escape(title)}</p>
${lines.map((l) => `<p style="margin:0 0 12px;font-size:16px;line-height:1.5;color:#3a3a3a">${escape(l)}</p>`).join('')}
<p style="margin:20px 0 28px"><a href="${url}" style="display:inline-block;padding:14px 24px;border-radius:24px;background:#1a1a1a;color:#ffffff;text-decoration:none;font-size:16px;font-weight:600">${escape(action.label)}</a></p>
<p style="margin:0;font-size:13px;color:#8a8a8a">Monira</p>
</div></body></html>`;
  return { text, html };
}

export function composeNotification(e: NotificationEvent) {
  switch (e.kind) {
    case 'message': {
      const subject = e.productName ? `Nova mensagem sobre ${e.productName}` : 'Nova mensagem na tua Uja';
      return { subject, ...render(subject, [`Um cliente perguntou: “${e.body}”`], { label: 'Responder', path: `/conversas/${e.conversationId}` }) };
    }
    case 'product_published': {
      const subject = `Publicado: ${e.productName}`;
      return { subject, ...render(subject, ['O teu produto já pode ser encontrado na Monira.'], { label: 'Ver produto', path: `/produto/${e.productId}` }) };
    }
    case 'product_changes': {
      const subject = `A Monira pediu alterações: ${e.productName}`;
      return { subject, ...render(subject, [e.note], { label: 'Corrigir', path: `/painel/produtos/${e.productId}/corrigir` }) };
    }
    case 'application_approved': {
      const subject = 'A tua Uja foi aprovada';
      const line = `${e.ujaName ?? 'A tua Uja'} já existe na Monira. Para começar, abre-a em Minha Uja.`;
      return { subject, ...render(subject, [line], { label: 'Abrir o painel', path: '/painel' }) };
    }
    case 'order_new': {
      const subject = `Novo pedido: ${e.productName ?? e.orderNumber}`;
      const total = `${Math.round(e.totalKz).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')} Kz`;
      const pay = e.paymentMethod === 'on_pickup' ? `Recebes ${total} no levantamento.` : `Recebes ${total} na entrega.`;
      return { subject, ...render(subject, [`Pedido ${e.orderNumber}.`, pay], { label: 'Ver pedido', path: `/painel/pedidos/${e.orderId}` }) };
    }
    case 'application_rejected': {
      const subject = 'Resposta ao teu pedido para vender';
      return { subject, ...render(subject, [e.note ?? 'A Monira respondeu ao teu pedido.'], { label: 'Ver pedido', path: '/vender' }) };
    }
  }
}

// Agenda o envio para depois da resposta ao utilizador.
export function sendNotificationEmail(event: NotificationEvent) {
  const { subject, text, html } = composeNotification(event);
  after(() => deliver({ to: event.to, subject, text, html }).then(() => undefined));
}
