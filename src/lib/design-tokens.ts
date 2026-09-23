// ═══════════════════════════════════════════════════════════
// MONIRA — Design Tokens
// Branco premium + Purple Monira + Grafite/Preto + Cinzas
// "O luxo visual está na simplicidade"
// ═══════════════════════════════════════════════════════════

export const MONIRA_COLORS = {
  // Primary
  white: '#FFFFFF',
  purple: '#6B21A8',         // Purple Monira — accent principal
  purpleLight: '#7C3AED',    // Hover
  purpleSoft: '#F3E8FF',     // Background suave
  purpleMuted: '#EDE9FE',    // Cards com accent

  // Neutrals
  grafite: '#1A1A1A',        // Texto principal
  grafiteLight: '#2D2D2D',   // Texto secundário forte
  cinza900: '#374151',       // Texto body
  cinza600: '#6B7280',       // Texto muted
  cinza400: '#9CA3AF',       // Placeholders
  cinza200: '#E5E7EB',       // Borders
  cinza100: '#F3F4F6',       // Background cards
  cinza50: '#F9FAFB',        // Background page

  // Functional
  success: '#059669',        // Verificado, confirmado
  warning: '#D97706',        // Atenção
  danger: '#DC2626',         // Erro
} as const;

export const MONIRA_TYPOGRAPHY = {
  // Font: definir depois (candidata: font proprietária ou Inter como fallback)
  fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  // Scale
  hero: '2rem',       // 32px — títulos de página
  h1: '1.5rem',       // 24px — secções
  h2: '1.25rem',      // 20px — sub-secções
  h3: '1.125rem',     // 18px — cards
  body: '1rem',       // 16px — texto corrido
  small: '0.875rem',  // 14px — labels, metadata
  caption: '0.75rem', // 12px — timestamps, badges
  // Weights
  regular: 400,
  medium: 500,
  semibold: 600,
  bold: 700,
} as const;

export const MONIRA_SPACING = {
  xs: '4px',
  sm: '8px',
  md: '16px',
  lg: '24px',
  xl: '32px',
  xxl: '48px',
  xxxl: '64px',
} as const;

export const MONIRA_RADIUS = {
  sm: '6px',
  md: '8px',
  lg: '12px',
  xl: '16px',
  full: '9999px',
} as const;

// ═══════════════════════════════════════════════════════════
// MONIRA LANGUAGE — Vocabulário proprietário
// ═══════════════════════════════════════════════════════════

export const MONIRA_LANG = {
  city: 'Monira',
  citizen: 'Moniri',
  vendor: 'Morador',
  vendors: 'Moradores',
  buyer: 'Visitante',
  buyers: 'Visitantes',
  shop: 'Uja',
  shops: 'Ujas',
  curation: 'Bur',
  curations: 'Burs',
  avenue: 'Avenida',
  avenues: 'Avenidas',
  plaza: 'Praça',
} as const;
