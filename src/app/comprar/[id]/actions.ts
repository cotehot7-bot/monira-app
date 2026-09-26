'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/db/server';
import { sendNotificationEmail } from '@/lib/notify';

export type BuyState = { status: 'idle' } | { status: 'error'; message: string };

const MESSAGES: Record<string, string> = {
  not_signed_in: 'A tua sessão terminou. Entra outra vez.',
  invalid_phone: 'Indica um telefone válido, para a loja te contactar.',
  own_uja: 'Não podes comprar na tua própria Uja.',
  uja_closed: 'Esta Uja está fechada neste momento.',
  payment_unavailable: 'Esta forma de pagamento não está disponível.',
  too_many_open_orders: 'Tens demasiados pedidos por concluir. Espera que algum termine.',
  product_unavailable: 'Este produto já não está disponível.',
  out_of_stock: 'Este produto esgotou.',
  invalid_option: 'Escolhe uma opção válida.',
  option_required: 'Escolhe uma opção.',
  invalid_zone: 'Escolhe onde queres receber.',
  address_required: 'Indica a morada de entrega.',
  delivery_unavailable: 'Esta Uja não faz entregas agora.',
  pickup_unavailable: 'Esta Uja não tem levantamento agora.',
};

export async function createOrder(productId: string, _prev: BuyState, formData: FormData): Promise<BuyState> {
  const supabase = await createClient();
  const mode = String(formData.get('mode') ?? '');
  const zone = String(formData.get('zone_id') ?? '');
  const option = String(formData.get('option_id') ?? '');

  // O browser envia intenção; preço, entrega e total são calculados na base de dados.
  const { data: order, error } = await supabase.rpc('monira_create_order', {
    p_product_id: productId,
    p_option_id: option || null,
    p_delivery_mode: mode,
    p_zone_id: mode === 'delivery' && zone ? zone : null,
    p_address: mode === 'delivery' ? String(formData.get('address') ?? '') : null,
    p_phone: String(formData.get('phone') ?? ''),
    p_payment_method: mode === 'delivery' ? 'on_delivery' : 'on_pickup',
  });
  if (error || !order) {
    const code = error ? Object.keys(MESSAGES).find((c) => error.message.includes(c)) : null;
    return { status: 'error', message: code ? MESSAGES[code] : 'Não foi possível fazer o pedido. Tenta outra vez.' };
  }

  const { data: notice } = await supabase.rpc('monira_order_notification', { p_order_id: order.id });
  const n = Array.isArray(notice) ? notice[0] : null;
  if (n?.email) {
    sendNotificationEmail({
      kind: 'order_new', to: n.email, orderId: n.order_id, orderNumber: n.order_number,
      productName: n.product_name, totalKz: Number(n.total_kz), paymentMethod: n.payment_method,
    });
  }

  revalidatePath('/pedidos');
  redirect(`/pedidos/${order.id}?novo=1`);
}
