import 'server-only';

// Tudo o que o público vê passa por aqui.
// Regra: o público nunca lê raw_*. Só a apresentação que a Monira publicou,
// através das vistas monira_public_products / monira_public_ujas.

export const PUBLIC_PRODUCT_COLUMNS = 'id, uja_id, name, description, photos, price_kz, available, created_at';

export type PublicProduct = {
  id: string;
  uja_id: string;
  name: string | null;
  description: string | null;
  photos: string[] | null;
  price_kz: number;
  available: boolean;
  created_at: string;
};

// Um produto só aparece se a revisão já produziu nome e pelo menos uma fotografia.
// Sem isso, não está pronto — não há plano B com o texto bruto.
export function isReady(p: PublicProduct): p is PublicProduct & { name: string; photos: string[] } {
  return Boolean(p.name && p.name.trim() && p.photos && p.photos.length > 0);
}

export function photoUrl(path: string) {
  return `${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/monira-public/${path}`;
}

export function formatKz(value: number) {
  const digits = Math.round(Number(value)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `${digits} Kz`;
}
