import Link from 'next/link';
import { type PublicProduct, photoUrl, formatKz } from '@/lib/public';
import styles from './ProductGrid.module.css';

type Ready = PublicProduct & { name: string; photos: string[] };
type UjaLabel = { name: string; verified: boolean };

// Grelha de produtos publicados. Usada no Início e na Uja.
// `ujaById` é opcional: dentro da própria Uja não faz sentido repetir o nome.
export default function ProductGrid({ products, ujaById }: { products: Ready[]; ujaById?: Map<string, UjaLabel> }) {
  return (
    <ul className={styles.grid}>
      {products.map((p) => {
        const uja = ujaById?.get(p.uja_id);
        return (
          <li key={p.id}>
            <Link href={`/produto/${p.id}`} className={styles.card}>
              {/* eslint-disable-next-line @next/next/no-img-element -- fotografia já tratada pela Monira (JPEG ≤1600 px) */}
              <img src={photoUrl(p.photos[0])} alt={p.name} loading="lazy" className={styles.photo} />
              <span className={styles.name}>{p.name}</span>
              <span className={styles.price}>{formatKz(p.price_kz)}</span>
              {uja && (
                <span className={styles.uja}>
                  {uja.name}
                  {uja.verified && <VerifiedMark size={14} />}
                </span>
              )}
              {!p.available && <span className={styles.soldOut}>Esgotado</span>}
            </Link>
          </li>
        );
      })}
    </ul>
  );
}

export function VerifiedMark({ size = 15 }: { size?: number }) {
  return (
    <svg aria-label="Uja verificada" role="img" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="#6b21a8" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="9" />
      <path d="M8 12.5l2.7 2.5L16 9.5" />
    </svg>
  );
}
