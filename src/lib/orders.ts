// Linguagem dos pedidos. Estados internos (new, delivering…) nunca aparecem como estão.
export const ORDER_STATUS_SELLER: Record<string, string> = {
  new: 'Novo',
  delivering: 'A entregar',
  completed: 'Concluído',
  cancelled: 'Cancelado',
};

export const ORDER_STATUS_BUYER: Record<string, string> = {
  new: 'Pedido feito',
  delivering: 'A caminho',
  completed: 'Concluído',
  cancelled: 'Cancelado',
};

export const OFFLINE_METHOD: Record<string, string> = {
  cash: 'dinheiro',
  tpa: 'TPA',
  transfer: 'transferência',
};

export function paymentLine(method: string | null, state: string | null, side: 'buyer' | 'seller', totalLabel: string) {
  if (state === 'confirmed' || state === 'seller_reported') return 'Pago';
  if (method === 'on_delivery') return side === 'seller' ? `Receber ${totalLabel} na entrega` : `Pagamento na entrega · ${totalLabel}`;
  if (method === 'on_pickup') return side === 'seller' ? `Receber ${totalLabel} no levantamento` : `Pagamento no levantamento · ${totalLabel}`;
  return '';
}
