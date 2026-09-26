'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/db/server';
import { sendNotificationEmail } from '@/lib/notify';
import type { SupabaseClient } from '@supabase/supabase-js';

async function notifyCustomer(supabase: SupabaseClient, orderId: string, kind: 'order_delivering' | 'order_cancelled') {
  const { data } = await supabase.rpc('monira_order_status_notification', { p_order_id: orderId, p_kind: kind });
  const n = Array.isArray(data) ? data[0] : null;
  if (!n?.email) return;
  if (kind === 'order_delivering') {
    sendNotificationEmail({ kind, to: n.email, orderId: n.order_id, orderNumber: n.order_number, productName: n.product_name, ujaName: n.uja_name });
  } else {
    sendNotificationEmail({ kind, to: n.email, orderId: n.order_id, orderNumber: n.order_number, productName: n.product_name, reason: n.reason });
  }
}

export type OrderActionState = { status: 'idle' } | { status: 'done'; message: string } | { status: 'error'; message: string };

const MESSAGES: Record<string, string> = {
  not_allowed: 'Sem permissão para este pedido.',
  invalid_transition: 'Este pedido já mudou de estado. Recarrega a página.',
  payment_not_confirmed: 'O pagamento ainda não foi confirmado.',
  invalid_method: 'Escolhe como recebeste o pagamento.',
  invalid_reason: 'Escreve o motivo (até 300 caracteres).',
};

function fail(message: string): OrderActionState {
  const code = Object.keys(MESSAGES).find((c) => message.includes(c));
  return { status: 'error', message: code ? MESSAGES[code] : 'Não foi possível. Tenta outra vez.' };
}

function refresh(orderId: string) {
  revalidatePath(`/painel/pedidos/${orderId}`);
  revalidatePath('/painel/pedidos');
  revalidatePath('/painel');
}

export async function startDelivery(orderId: string): Promise<OrderActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc('monira_advance_order', { p_order_id: orderId });
  if (error) return fail(error.message);
  await notifyCustomer(supabase, orderId, 'order_delivering');
  refresh(orderId);
  return { status: 'done', message: 'A entregar.' };
}

// "Entregue e pago" / "Levantado e pago": a loja declara que recebeu (≠ confirmação do prestador).
export async function completeOffline(orderId: string, _prev: OrderActionState, formData: FormData): Promise<OrderActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc('monira_complete_offline_order', { p_order_id: orderId, p_method: String(formData.get('method') ?? '') });
  if (error) return fail(error.message);
  refresh(orderId);
  return { status: 'done', message: 'Concluído.' };
}

export async function cancelOrder(orderId: string, _prev: OrderActionState, formData: FormData): Promise<OrderActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc('monira_cancel_order', { p_order_id: orderId, p_reason: String(formData.get('reason') ?? '') });
  if (error) return fail(error.message);
  await notifyCustomer(supabase, orderId, 'order_cancelled');
  refresh(orderId);
  return { status: 'done', message: 'Pedido cancelado.' };
}
