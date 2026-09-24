// ═══════════════════════════════════════════════════════════
// MONIRA — TypeScript Types
// ═══════════════════════════════════════════════════════════

export interface Avenue {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  color: string | null;
  icon: string | null;
  position: number;
  active: boolean;
}

export interface Vendor {
  id: string;
  user_id: string;
  name: string;
  slug: string;
  phone: string;
  whatsapp: string;
  photo_url: string | null;
  province: string | null;
  city: string | null;
  delivery_modes: string[];
  verified: boolean;
  plan: 'free' | 'residente' | 'premium';
  rating: number;
  total_sales: number;
  response_time_minutes: number | null;
  active: boolean;
}

export interface Uja {
  id: string;
  vendor_id: string;
  name: string;
  slug: string;
  avenue_id: string;
  description: string | null;
  status: 'draft' | 'pendente_aprovacao' | 'active' | 'paused';
  is_open: boolean;
  image_raw_url: string | null;
  image_url: string | null;
  logo_raw_url: string | null;
  logo_url: string | null;
  pickup_enabled: boolean;
  pickup_address: string | null;
  whatsapp: string | null;
  phone: string | null;
  vendor?: Vendor;
  avenue?: Avenue;
  products?: Product[];
}

export interface Product {
  id: string;
  uja_id: string;
  raw_name: string | null;
  raw_description: string | null;
  raw_photos: string[] | null;
  price_kz: number;
  name: string | null;
  description: string | null;
  photos: string[] | null;
  category: string | null;
  tags: string[];
  stock: number;
  active: boolean;
  featured: boolean;
  auto_generated: boolean;
  admin_reviewed: boolean;
  needs_review: boolean;
  options?: ProductOption[];
}

export interface ProductOption {
  id: string;
  product_id: string;
  name: string;
  position: number;
  active: boolean;
}

export interface UjaDeliveryZone {
  id: string;
  uja_id: string;
  name: string;
  fee_kz: number;
  active: boolean;
  position: number;
}

export interface Bur {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  avenue_id: string | null;
  type: 'editorial' | 'sazonal' | 'promo';
  cover_image: string | null;
  active: boolean;
  starts_at: string | null;
  ends_at: string | null;
  products?: Product[];
}

export interface Buyer {
  id: string;
  user_id: string;
  name: string | null;
  phone: string;
  province: string | null;
  rating: number;
  total_purchases: number;
}

// Pedido: compra directa, 1 produto. Valores são snapshot calculado pelo servidor.
export type OrderStatus = 'new' | 'delivering' | 'completed' | 'cancelled';
export type DeliveryMode = 'delivery' | 'pickup';

export interface Order {
  id: string;
  order_number: string;
  product_id: string;
  uja_id: string;
  buyer_id: string;
  option_id: string | null;
  option_name: string | null;
  price_kz: number;
  quantity: number;
  delivery_fee_kz: number;
  total_kz: number;
  delivery_mode: DeliveryMode;
  delivery_zone_id: string | null;
  delivery_zone_name: string | null;
  delivery_address: string | null;
  delivery_notes: string | null;
  status: OrderStatus;
  delivering_at: string | null;
  completed_at: string | null;
  cancelled_at: string | null;
  created_at: string;
  product?: Product;
  buyer?: Buyer;
}

// Pagamento: abstracto. Nenhum prestador no domínio — `provider` é configuração.
// 'confirmed' = a Monira recebeu uma confirmação válida. O UI mostra "Pago".
export type PaymentRequestStatus = 'requested' | 'confirmed' | 'failed' | 'expired';
export type OrderPaymentState = PaymentRequestStatus | 'none';

export interface MerchantAccount {
  id: string;
  vendor_id: string;
  provider: string;
  status: 'pending' | 'active' | 'disabled';
}

export interface PaymentRequest {
  id: string;
  order_id: string;
  provider: string;
  amount_kz: number;
  status: PaymentRequestStatus;
  requested_at: string;
  expires_at: string;
  resolved_at: string | null;
}

export interface Conversation {
  id: string;
  uja_id: string;
  customer_id: string;
  product_id: string | null;
  order_id: string | null;
  created_at: string;
  last_message_at: string | null;
}

export interface Message {
  id: string;
  conversation_id: string;
  sender_user_id: string;
  body: string;
  created_at: string;
}

export interface Review {
  id: string;
  order_id: string;
  from_user_id: string;
  to_user_id: string;
  rating: number;
  comment: string | null;
  type: 'visitante_avalia_morador' | 'morador_avalia_visitante';
}

export interface Application {
  id: string;
  user_id: string;
  name: string;
  phone: string;
  description: string | null;
  avenue_id: string | null;
  province: string | null;
  delivery_modes: string[];
  sample_photos: string[] | null;
  status: 'pendente' | 'aprovado' | 'rejeitado';
}
