import 'server-only';
import nodemailer, { type Transporter } from 'nodemailer';

// Transporte de email. TEMPORÁRIO: hoje SMTP do Gmail (monira.entrar).
// Trocar para o serviço transaccional do domínio Monira = mudar as variáveis
// SMTP_* na Vercel (ou esta função). Os eventos em ./index.ts não mudam.
//
// Variáveis: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS (secreta), EMAIL_FROM.
export type OutgoingEmail = { to: string; subject: string; text: string; html: string };

let transporter: Transporter | null = null;

function getTransporter() {
  if (transporter) return transporter;
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) return null;
  const port = Number(SMTP_PORT ?? 465);
  transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port,
    secure: port === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
  return transporter;
}

// Nunca lança: um aviso que falha não pode estragar a acção de quem o provocou.
export async function deliver(email: OutgoingEmail): Promise<boolean> {
  const t = getTransporter();
  if (!t) {
    console.warn('[avisos] SMTP não configurado — aviso não enviado:', email.subject);
    return false;
  }
  try {
    await t.sendMail({ from: process.env.EMAIL_FROM ?? process.env.SMTP_USER, ...email });
    return true;
  } catch (err) {
    console.error('[avisos] falhou o envio:', email.subject, err instanceof Error ? err.message : err);
    return false;
  }
}
