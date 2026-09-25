import type { Metadata, Viewport } from 'next';
import localFont from 'next/font/local';
import './globals.css';

// Fontes dentro do projecto (OFL, ver src/app/fonts). Sem pedidos a serviços externos.
// Fraunces: identidade e momentos editoriais. Instrument Sans: toda a interface.
const display = localFont({
  src: './fonts/fraunces.woff2',
  weight: '100 900',
  variable: '--font-display',
  display: 'swap',
  adjustFontFallback: 'Times New Roman',
});

const text = localFont({
  src: './fonts/instrument-sans.woff2',
  weight: '400 700',
  variable: '--font-text',
  display: 'swap',
  adjustFontFallback: 'Arial',
});

export const metadata: Metadata = {
  title: 'Monira',
  description: 'Descobre o que chegou à Monira.',
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#FFFFFF',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt" className={`${display.variable} ${text.variable}`}>
      <body>{children}</body>
    </html>
  );
}
