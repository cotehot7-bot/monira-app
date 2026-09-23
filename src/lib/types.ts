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
  vendor?: Vendor;
  avenue?: Avenue;
  products?: Product[];
}

export interface Product {
  id: string;
  uja_id: string;
  vendor_id: string;
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

export type OrderStatus = 'criado' | 'pago' | 'confirmado' | 'entregue' | 'cancelado' | 'disputado';
export type PaymentStatus = 'pendente' | 'pago' | 'falhado' | 'reembolsado';

export interface Order {
  id: string;
  order_number: string;
  product_id: string;
  uja_id: string;
  vendor_id: string;
  buyer_id: string;
  price_kz: number;
  quantity: number;
  total_kz: number;
  payment_method: string;
  payment_ref: string | null;
  payment_status: PaymentStatus;
  delivery_mode: string | null;
  delivery_notes: string | null;
  status: OrderStatus;
  product?: Product;
  vendor?: Vendor;
  buyer?: Buyer;
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
