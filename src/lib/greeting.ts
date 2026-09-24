// Saudação pela hora de Luanda.
export function greeting() {
  const hour = Number(
    new Intl.DateTimeFormat('pt-PT', { hour: 'numeric', hourCycle: 'h23', timeZone: 'Africa/Luanda' }).format(new Date()),
  );
  if (hour < 12) return 'Bom dia';
  if (hour < 19) return 'Boa tarde';
  return 'Boa noite';
}
