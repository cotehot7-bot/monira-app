export default function Praca() {
  return (
    <main style={{
      minHeight: '100dvh',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '2rem',
      background: '#FFFFFF',
    }}>
      <h1 style={{
        fontSize: '2.5rem',
        fontWeight: 700,
        color: '#6B21A8',
        letterSpacing: '-0.02em',
        marginBottom: '0.5rem',
      }}>
        MONIRA
      </h1>
      <p style={{
        fontSize: '1rem',
        color: '#6B7280',
        marginBottom: '2rem',
      }}>
        A cidade digital onde o comércio acontece.
      </p>
      <p style={{
        fontSize: '0.875rem',
        color: '#9CA3AF',
      }}>
        Em construção — brevemente.
      </p>
    </main>
  );
}
