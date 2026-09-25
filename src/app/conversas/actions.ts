'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/db/server';
import { sendNotificationEmail } from '@/lib/notify';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// "Conversar sobre este produto". Sem sessão, vai entrar e volta ao produto.
export async function startConversation(productId: string) {
  if (!UUID.test(productId)) redirect('/');
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?next=/produto/${productId}`);

  const { data: conversationId, error } = await supabase.rpc('monira_start_conversation', { p_product_id: productId });
  if (error || !conversationId) {
    // own_uja: quem vende abriu o próprio produto — leva-o às suas conversas.
    redirect(error?.message.includes('own_uja') ? '/painel/conversas' : `/produto/${productId}`);
  }
  redirect(`/conversas/${conversationId}`);
}

export type SendState = { status: 'idle' } | { status: 'sent'; at: number } | { status: 'error'; message: string };

export async function sendMessage(conversationId: string, _prev: SendState, formData: FormData): Promise<SendState> {
  const body = String(formData.get('body') ?? '').trim();
  if (!body) return { status: 'idle' };
  if (body.length > 4000) return { status: 'error', message: 'A mensagem é demasiado longa.' };

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { status: 'error', message: 'A tua sessão terminou. Entra outra vez.' };

  // A base de dados confirma que quem escreve faz parte da conversa.
  const { data: message, error } = await supabase
    .from('monira_messages')
    .insert({ conversation_id: conversationId, sender_user_id: user.id, body })
    .select('id')
    .single();
  if (error || !message) return { status: 'error', message: 'Não foi possível enviar. Tenta outra vez.' };

  // A base de dados decide se a loja é avisada (nunca pelas próprias mensagens; no máximo um aviso por conversa a cada 10 min).
  const { data: notice } = await supabase.rpc('monira_message_notification', { p_message_id: message.id });
  const n = Array.isArray(notice) ? notice[0] : null;
  if (n?.email) {
    sendNotificationEmail({ kind: 'message', to: n.email, conversationId: n.conversation_id, productName: n.product_name, body: n.body });
  }

  revalidatePath(`/conversas/${conversationId}`);
  revalidatePath('/painel/conversas');
  return { status: 'sent', at: Date.now() };
}
